import 'dart:async';
import 'dart:io';
import 'dart:ui' show FlutterView;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../runtime/agent_mint.dart';
import '../runtime/beacon_hub.dart';
import '../runtime/icy_cache.dart';
import '../runtime/insight.dart';
import '../runtime/tide_sensor.dart';
import '../theme/app_colors.dart';
import 'no_signal_stage.dart';

// ============================================================
// CONTENT STAGE — full-screen WebView (gray content)
// ============================================================
// Hosts the destination URL with:
//   • Forged device UA (see agent_mint.dart)
//   • Both orientations, immersive system UI
//   • Non-http(s) scheme hand-off to the OS
//   • Redirect-loop recovery (up to 3 retries)
//   • Live connectivity guard (jump straight to No-Signal, no DNS
//     probe — probing while offline can hang for seconds and lets
//     the WebView show the native error page)
//   • Warm push URL loading
//   • File upload via a native chooser routed over a MethodChannel
//   • Third-party cookies + inline autoplay + DRM auto-grant
//   • Safe-area / keyboard JS injection
// ============================================================

class ContentStage extends StatefulWidget {
  const ContentStage({
    super.key,
    required this.destination,
    required this.cache,
    required this.beaconHub,
    required this.tideSensor,
  });

  final String destination;
  final IcyCache cache;
  final BeaconHub beaconHub;
  final TideSensor tideSensor;

  @override
  State<ContentStage> createState() => _ContentStageState();
}

class _ContentStageState extends State<ContentStage>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _spinning = true;
  bool _offlineRouted = false;
  String? _lastMainFrameUrl;
  int _redirectRetries = 0;
  Timer? _offlineDebounce;
  StreamSubscription<List<ConnectivityResult>>? _tideSub;

  // Rotation-glitch guard. Some Android devices (HyperOS/MIUI, older Adreno
  // GPUs) show a torn/stale frame for a few hundred ms while the WebView's
  // hybrid-composition surface is being re-created after a rotation. We mask
  // it with a solid opaque cover for ~350 ms, driven by didChangeMetrics.
  Size? _lastSize;
  bool _rotationMask = false;
  Timer? _rotationMaskTimer;

  // Clarity funnel state — reset per-navigation.
  bool _offerReached = false; // first successful main-frame load happened
  bool _pageHadError = false; // reset each navigation; blocks false success

  // Regex matchers for WebView funnel classification.
  static final RegExp _depositRx = RegExp(
    r'(deposit|cashier|top.?up|replenish|payment|checkout|wallet|пополн|депозит|касс|оплат|внести|платеж)',
    caseSensitive: false,
  );
  static final RegExp _registerRx = RegExp(
    r'(sign.?up|regist|create.?account|onboarding|регистрац|зарегистр)',
    caseSensitive: false,
  );
  static final RegExp _loginRx = RegExp(
    r'(sign.?in|log.?in|log.?on|/auth\b|authoriz|войти|вход|авториз)',
    caseSensitive: false,
  );

  // MethodChannel MUST match the value used by MainActivity.kt.
  // [FINGERPRINT] — unique per project (was `tower/upload` in the template).
  static const MethodChannel _uploadPipe =
      MethodChannel('frozencatch/media_bridge');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Insight.screen('web');
    Insight.event('web_open');
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _wireController();

    widget.beaconHub.onLiveDestination = (String url) {
      if (mounted) _controller.loadRequest(Uri.parse(url));
    };

    // Debounce a full 700 ms so VPN flicker does not route to offline.
    _tideSub = widget.tideSensor.transitions
        .listen((List<ConnectivityResult> r) {
      final bool allNone = r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _offlineDebounce?.cancel();
        return;
      }
      _offlineDebounce?.cancel();
      _offlineDebounce = Timer(const Duration(milliseconds: 700), () {
        _routeOfflineImmediate();
      });
    });
  }

  void _enterImmersive() {
    // Full immersive hides both bars. The keyboard is handled by the JS
    // scroll fix (visualViewport), so no window resize is needed.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enterImmersive();
      Insight.event('web_foreground');
    } else if (state == AppLifecycleState.paused) {
      Insight.event('web_background');
    }
  }

  @override
  void didChangeMetrics() {
    // Fires when the display size / orientation changes. We detect a real
    // rotation (short vs long edge swap) and drop an opaque cover on top of
    // the WebView while its surface is being re-created — this hides the
    // frame-tear that some Android devices show mid-rotation.
    final FlutterView? view =
        WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
            ? WidgetsBinding.instance.platformDispatcher.views.first
            : null;
    if (view == null) return;
    final Size current = view.physicalSize;
    final Size? previous = _lastSize;
    _lastSize = current;
    if (previous == null) return;
    final bool prevLandscape = previous.width > previous.height;
    final bool nowLandscape = current.width > current.height;
    if (prevLandscape == nowLandscape) return;

    if (!mounted) return;
    setState(() => _rotationMask = true);
    _rotationMaskTimer?.cancel();
    // 350 ms covers the worst-case surface swap seen on HyperOS + Adreno 6xx.
    // We also re-apply immersive mode after the transition — the system bars
    // sometimes reappear after a rotation.
    _rotationMaskTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _enterImmersive();
      setState(() => _rotationMask = false);
    });
  }

  void _wireController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(frostHttp.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          _pageHadError = false;
          if (mounted) setState(() => _spinning = true);
        },
        onPageFinished: (String url) {
          if (mounted) setState(() => _spinning = false);
          _redirectRetries = 0;
          _injectSafeAreaOverride();
          _injectKeyboardScrollFix();
          _installInsightProbe();
          _trackWebPage(url);
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          _pageHadError = true;
          final String reason = _classifyWebError(err);
          final String failed = _lastMainFrameUrl ?? widget.destination;
          final String host = Uri.tryParse(failed)?.host ?? '';
          Insight.event('web_error');
          Insight.tag('web_error_reason', reason);
          Insight.tag('web_last_error', '${err.errorCode}:${err.description}');
          if (host.isNotEmpty) Insight.tag('web_error_host', host);
          if (!_offerReached) {
            Insight.event('web_offer_unreachable');
            Insight.tag('offer_reached', 'false');
            Insight.tag('offer_unreachable_reason', reason);
          } else {
            Insight.event('web_error_after_load');
          }
          final String desc = err.description.toLowerCase();
          final bool redirectLoop = desc.contains('too_many_redirects') ||
              desc.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (redirectLoop &&
              _lastMainFrameUrl != null &&
              _redirectRetries < 3) {
            _redirectRetries++;
            _controller.loadRequest(Uri.parse(_lastMainFrameUrl!));
            return;
          }
          // Cover the WebView with the spinner immediately so the native
          // Android error page never shows.
          if (mounted) setState(() => _spinning = true);
          final bool dnsOrDrop = desc.contains('name_not_resolved') ||
              desc.contains('err_name_not_resolved') ||
              desc.contains('internet_disconnected') ||
              desc.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (dnsOrDrop) {
            _routeOfflineImmediate();
          } else {
            _routeOfflineIfDown();
          }
        },
        onNavigationRequest: (NavigationRequest req) {
          final Uri? uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          const Set<String> inline = <String>{
            'http',
            'https',
            'about',
            'data',
            'blob',
          };
          if (inline.contains(uri.scheme)) {
            if (req.isMainFrame) _lastMainFrameUrl = req.url;
            return NavigationDecision.navigate;
          }
          Insight.event('web_external');
          Insight.tag('web_external_scheme', uri.scheme);
          _openExternal(uri);
          return NavigationDecision.prevent;
        },
      ));

    _tunePlatform();
    _controller.loadRequest(Uri.parse(widget.destination));
  }

  void _tunePlatform() {
    if (!Platform.isAndroid) return;
    if (_controller.platform is! AndroidWebViewController) return;
    final AndroidWebViewController a =
        _controller.platform as AndroidWebViewController;

    // Inline autoplay video — TZ §"Inline autoplay video".
    a.setMediaPlaybackRequiresUserGesture(false);

    // Auto-grant DRM / MIDI etc. so partner streams play without a
    // permission modal. Camera / mic requests only fire on explicit
    // user opt-in inside the site, so this echoes the browser default.
    a.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );

    // Native file chooser routed over MethodChannel — see MainActivity.kt.
    a.setOnShowFileSelector(_pickAttachments);

    // Third-party cookies for OAuth / payment provider round-trips.
    final AndroidWebViewCookieManager cookieMan = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookieMan.setAcceptThirdPartyCookies(a, true);
  }

  Future<List<String>> _pickAttachments(FileSelectorParams p) async {
    try {
      final List<Object?>? picked =
          await _uploadPipe.invokeMethod<List<Object?>>('choose',
              <String, Object>{
        'multiple': p.mode == FileSelectorMode.openMultiple,
        'mimeTypes': p.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _routeOfflineIfDown() async {
    if (_offlineRouted) return;
    final bool online = await widget.tideSensor.hasSignal();
    if (online) return;
    _routeOfflineImmediate();
  }

  void _routeOfflineImmediate() {
    if (_offlineRouted || !mounted) return;
    _offlineRouted = true;
    final String next = _lastMainFrameUrl ?? widget.destination;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalStage(
          retryBuilder: (_) => ContentStage(
            destination: next,
            cache: widget.cache,
            beaconHub: widget.beaconHub,
            tideSensor: widget.tideSensor,
          ),
        ),
      ),
    );
  }

  // ── JS injected on every onPageFinished ─────────────────────

  void _injectKeyboardScrollFix() {
    _controller.runJavaScript(r'''
(function(){
  if (window.__fcKbFix) return; window.__fcKbFix = true;
  function isField(el){return el&&(el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable);}
  function bring(){
    var el=document.activeElement; if(!isField(el))return;
    var vp=window.visualViewport;
    if(vp){
      var r=el.getBoundingClientRect(); var bottom=vp.offsetTop+vp.height;
      if(r.bottom>bottom-20||r.top<vp.offsetTop){el.scrollIntoView({behavior:'auto',block:'nearest'});}
    } else { el.scrollIntoView({behavior:'auto',block:'nearest'}); }
  }
  document.addEventListener('focusin',function(e){ if(isField(e.target)) setTimeout(bring,350); });
  if(window.visualViewport){
    var prev=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height; if(h<prev) setTimeout(bring,120); prev=h;
    });
  }
})();
''');
  }

  void _injectSafeAreaOverride() {
    // Zero out custom safe-area CSS variables the partner site may
    // declare (--sat / --sab / --safe-top / ...), and clear the top
    // padding of well-known sticky header classes ONLY. Do NOT touch
    // html/body/#app/#root left/right padding — that would strip the
    // site's own gutters and squash the content. See
    // .cursor/rules/webview_safe_area_injection.mdc.
    _controller.runJavaScript(r'''
(function(){
  if(window.__fcSa) return; window.__fcSa=true;
  var ID='__fc_sa_style';
  var CSS=
    ':root{'+
    '--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;'+
    '--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;'+
    '--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;'+
    '--safe-top:0px!important;--safe-bottom:0px!important;'+
    '--safe-left:0px!important;--safe-right:0px!important;'+
    '}'+
    // Only decorative sticky-header classes get their top padding zeroed.
    '.gameview-mobile-header,.app-header,.js-safe-top{'+
    'padding-top:0!important;margin-top:0!important;'+
    '}';
  function kbOpen(){
    if(!window.visualViewport)return false;
    return window.visualViewport.height<window.innerHeight*0.75;
  }
  function apply(){
    if(kbOpen()) return;
    var head=document.head||document.documentElement; if(!head) return;
    var m=document.querySelector('meta[name="viewport"]');
    if(m && !/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content')||'')){
      var c=(m.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      m.setAttribute('content', c+(c?', ':'')+'viewport-fit=contain');
    }
    var s=document.getElementById(ID);
    if(!s){ s=document.createElement('style'); s.id=ID; head.appendChild(s); }
    if(s.textContent!==CSS) s.textContent=CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var o=history[fn];
    history[fn]=function(){var r=o.apply(this,arguments); setTimeout(apply,80); setTimeout(apply,400); return r;};
  });
  window.addEventListener('popstate',function(){setTimeout(apply,80);});
  setInterval(apply,2500);
})();
''');
  }

  // ── Clarity web-funnel helpers ───────────────────────────────

  void _trackWebPage(String url) {
    final Uri? uri = Uri.tryParse(url);
    Insight.screenName('web:${uri == null ? url : '${uri.host}${uri.path}'}');
    Insight.event('web_page');
    Insight.tag('web_last_url', url);
    if (!_offerReached && !_pageHadError) {
      _offerReached = true;
      Insight.event('web_offer_reached');
      Insight.tag('offer_reached', 'true');
      if (uri?.host != null) Insight.tag('offer_host', uri!.host);
    }
    if (_depositRx.hasMatch(url)) {
      Insight.event('web_cashier_page');
      Insight.tag('reached_cashier', 'true');
    }
    _trackAuthPage(url);
  }

  void _trackAuthPage(String url) {
    if (_registerRx.hasMatch(url)) {
      Insight.event('web_register_page');
      Insight.tag('reached_register', 'true');
    } else if (_loginRx.hasMatch(url)) {
      Insight.event('web_login_page');
      Insight.tag('reached_login', 'true');
    }
  }

  static String _classifyWebError(WebResourceError err) {
    final String d = err.description.toLowerCase();
    final int c = err.errorCode;
    if (d.contains('connection_refused') || d.contains('connection refused')) {
      return 'connection_refused';
    }
    if (d.contains('too_many_redirects') || d.contains('too many redirects')) {
      return 'redirect_loop';
    }
    if (d.contains('name_not_resolved') ||
        d.contains('address_unreachable') ||
        d.contains('unknownhost') ||
        c == -2) {
      return 'dns_unresolved';
    }
    if (d.contains('timed out') || d.contains('timeout') || c == -8) {
      return 'timeout';
    }
    if (d.contains('internet_disconnected') ||
        d.contains('network_changed') ||
        c == -6) {
      return 'no_network';
    }
    if (d.contains('connection_reset')) return 'connection_reset';
    if (d.contains('connection_closed') || d.contains('empty_response')) {
      return 'connection_closed';
    }
    if (d.contains('ssl') || d.contains('cert') || c == -11) {
      return 'ssl_error';
    }
    if (d.contains('blocked')) return 'blocked';
    return 'other';
  }

  void _installInsightProbe() {
    _controller.addJavaScriptChannel(
      'AegisInsight',
      onMessageReceived: (JavaScriptMessage m) => _onWebSignal(m.message),
    );
    _controller.runJavaScript(r'''
(function(){
  if (window.__aegisInsight) return; window.__aegisInsight = true;
  function send(t){ try { AegisInsight.postMessage(t); } catch(e){} }
  var DEP=/(deposit|cashier|top.?up|add funds|replenish|payment|pay now|checkout|withdraw|пополн|депозит|касс|оплат|внести|вывод|платеж)/i;
  var REG=/(sign.?up|regist|create.?account|регистрац|зарегистр)/i;
  var LOG=/(sign.?in|log.?in|log.?on|войти|вход|авториз)/i;
  var lastPath='';
  function reportPath(){ var p=location.pathname+location.search; if(p!==lastPath){ lastPath=p; send('path:'+p);} }
  reportPath();
  ['pushState','replaceState'].forEach(function(fn){ var o=history[fn]; history[fn]=function(){ var r=o.apply(this,arguments); setTimeout(reportPath,60); return r; }; });
  window.addEventListener('popstate',function(){ setTimeout(reportPath,60); });
  document.addEventListener('click',function(e){
    try{ var el=e.target;
      for(var i=0;i<4&&el;i++){
        var t=((el.innerText||el.value||(el.getAttribute&&el.getAttribute('aria-label'))||'')+'').trim();
        if(t){ if(DEP.test(t)){send('deposit_click:'+t.slice(0,60));return;}
               if(REG.test(t)){send('register_click:'+t.slice(0,60));return;}
               if(LOG.test(t)){send('login_click:'+t.slice(0,60));return;} }
        el=el.parentElement;
      }
    }catch(x){}
  },true);
  document.addEventListener('submit',function(e){
    try{ var f=e.target;
      var pw=f.querySelectorAll?f.querySelectorAll('input[type="password"]'):[];
      var blob=((f.innerText||'')+' '+(f.getAttribute('action')||'')+' '+(f.className||''));
      var confirm=f.querySelector&&(f.querySelector('input[name*="confirm" i]')||f.querySelector('input[name*="repeat" i]'));
      if(pw&&pw.length>=2){send('auth_submit:register');return;}
      if(pw&&pw.length===1){ send('auth_submit:'+((confirm||REG.test(blob))?'register':'login')); return; }
      if(REG.test(blob)){send('auth_submit:register');return;}
      if(LOG.test(blob)){send('auth_submit:login');return;}
      send('form_submit');
    }catch(x){ send('form_submit'); }
  },true);
})();
''');
  }

  void _onWebSignal(String raw) {
    final int i = raw.indexOf(':');
    final String type = i < 0 ? raw : raw.substring(0, i);
    final String data = i < 0 ? '' : raw.substring(i + 1);
    switch (type) {
      case 'path':
        Insight.event('web_spa_route');
        Insight.tag('web_last_path', data);
        if (_depositRx.hasMatch(data)) {
          Insight.event('web_cashier_page');
          Insight.tag('reached_cashier', 'true');
        }
        _trackAuthPage(data);
      case 'deposit_click':
        Insight.event('web_deposit_click');
        Insight.tag('deposit_intent', 'true');
        if (data.isNotEmpty) Insight.tag('deposit_label', data);
      case 'register_click':
        Insight.event('web_register_click');
        Insight.tag('register_intent', 'true');
      case 'login_click':
        Insight.event('web_login_click');
        Insight.tag('login_intent', 'true');
      case 'auth_submit':
        if (data == 'register') {
          Insight.event('web_register_submit');
          Insight.tag('attempted_register', 'true');
        } else {
          Insight.event('web_login_submit');
          Insight.tag('attempted_login', 'true');
        }
      case 'form_submit':
        Insight.event('web_form_submit');
    }
  }

  Future<void> _back() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineDebounce?.cancel();
    _rotationMaskTimer?.cancel();
    _tideSub?.cancel();
    widget.beaconHub.onLiveDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _back();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Keep a safe zone around the camera cutout in BOTH
            // orientations (top in portrait, side in landscape). The
            // bottom inset is not applied — the keyboard is handled
            // by the JS scroll fix. This is the fix for
            // gray_part_pitfalls.md §14 (landscape notch clipping).
            SafeArea(
              bottom: false,
              child: WebViewWidget(controller: _controller),
            ),
            if (_spinning && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accentGold),
                  ),
                ),
              ),
            // Opaque cover shown briefly during a physical rotation, so the
            // WebView's surface swap never becomes visible to the user.
            if (_rotationMask)
              const Positioned.fill(
                child: ColoredBox(color: Colors.black),
              ),
          ],
        ),
      ),
    );
  }
}
