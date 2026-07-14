import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../contracts/gate_verdict.dart';
import '../contracts/launch_mode.dart';
import '../overlay/beacon_prompt_stage.dart';
import '../overlay/content_stage.dart';
import '../overlay/no_signal_stage.dart';
import '../runtime/beacon_hub.dart';
import '../runtime/catch_tracker.dart';
import '../runtime/harbor_gate.dart';
import '../runtime/icy_cache.dart';
import '../runtime/insight.dart';
import '../runtime/tide_sensor.dart';
import '../screens/home_screen.dart';
import '../theme/app_assets.dart';
import '../theme/app_colors.dart';

// ============================================================
// ARCTIC ROUTER — the boot pipeline + loading screen (Frozen Catch)
// ============================================================
// One screen owns the whole "figure out which experience to show"
// decision. The loading artwork is drawn while attribution, gate
// verdict, deep links and connectivity all resolve; then we push
// exactly one route (Home game, WebView content or No-Signal) and
// this screen goes away.
//
// State-machine responsibilities (mirrors the guide §"Gray Flow
// State Machine"):
//   • First launch      → connectivity gate → attribution → gate →
//                         WebView or game (verdict is persisted).
//   • Returning + gray  → deferred push URL wins → else fresh gate,
//                         with cached URL as last-known-good fallback.
//   • Returning + game  → straight to HomeScreen, no network work.
//
// First-frame offline guard: if the very first launch has no signal
// AND we have never persisted a verdict, we render the No-Signal
// screen immediately (frame 1). Retry rebuilds THIS router — the
// pipeline is idempotent.
// ============================================================

class ArcticRouter extends StatefulWidget {
  const ArcticRouter({
    super.key,
    required this.cache,
    required this.tideSensor,
    required this.catchTracker,
    required this.harborGate,
    required this.beaconHub,
  });

  final IcyCache cache;
  final TideSensor tideSensor;
  final CatchTracker catchTracker;
  final HarborGate harborGate;
  final BeaconHub beaconHub;

  @override
  State<ArcticRouter> createState() => _ArcticRouterState();
}

class _ArcticRouterState extends State<ArcticRouter> {
  double _progress = 0.04;
  int _dotIndex = 0;
  Timer? _dotTicker;
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    Insight.screen('loading');
    _dotTicker = Timer.periodic(const Duration(milliseconds: 430), (_) {
      if (!mounted) return;
      setState(() => _dotIndex = (_dotIndex + 1) % 4);
    });
    widget.beaconHub.onTokenSwap = _resendGateWithToken;
    _drive();
  }

  @override
  void dispose() {
    _dotTicker?.cancel();
    widget.beaconHub.onTokenSwap = null;
    super.dispose();
  }

  void _liftProgress(double target) {
    if (mounted) setState(() => _progress = target.clamp(0.0, 1.0));
  }

  // ── Pipeline dispatch ──────────────────────────────────────

  Future<void> _drive() async {
    await widget.beaconHub.warm();
    _liftProgress(0.18);

    switch (widget.cache.readMode()) {
      case LaunchMode.game:
        await _routeToGame(initialLift: 0.42);
        return;
      case LaunchMode.gray:
        await _resumeGray();
        return;
      case LaunchMode.surface:
        await _firstLaunch();
        return;
    }
  }

  Future<void> _firstLaunch() async {
    if (!await widget.tideSensor.hasSignal()) {
      // Frame-one offline path — the No-Signal screen renders
      // immediately, no black screen ever visible.
      _routeToOffline();
      return;
    }
    _liftProgress(0.36);

    await widget.catchTracker.kindle();
    await Future.wait<void>(<Future<void>>[
      widget.catchTracker.waitForInstall(),
      widget.catchTracker.waitForDeepLink(),
    ]);
    _liftProgress(0.72);

    final GateVerdict verdict = await _askGate();
    if (verdict.approved && verdict.hasDestination) {
      await widget.cache.commitMode(LaunchMode.gray);
      _liftProgress(1.0);
      await _settle();
      _routeToGray(verdict.destination!);
    } else {
      // Persist offline commit ONCE — never re-issue a config request
      // for the lifetime of this install (contract §9).
      await widget.cache.commitMode(LaunchMode.game);
      await _routeToGame(initialLift: 0.88);
    }
  }

  Future<void> _resumeGray() async {
    if (!await widget.tideSensor.hasSignal()) {
      _liftProgress(1.0);
      _routeToOffline();
      return;
    }
    _liftProgress(0.36);

    // Cold-start push URL wins over every other decision.
    final String? deferred = await widget.cache.consumeDeferredDestination();
    if (deferred != null) {
      Insight.event('route_push_link');
      _liftProgress(1.0);
      await _settle();
      _routeToGray(deferred);
      return;
    }

    final String? lastKnown = await widget.cache.readDestination();

    await widget.catchTracker.kindle();
    await Future.wait<void>(<Future<void>>[
      widget.catchTracker.waitForInstall(seconds: 10),
      widget.catchTracker.waitForDeepLink(),
    ]);
    _liftProgress(0.72);

    final GateVerdict verdict = await _askGate();
    _liftProgress(1.0);
    await _settle();

    if (verdict.approved && verdict.hasDestination) {
      _routeToGray(verdict.destination!);
    } else if (lastKnown != null && lastKnown.isNotEmpty) {
      Insight.event('route_cached_link');
      _routeToGray(lastKnown);
    } else {
      _routeToOffline();
    }
  }

  Future<GateVerdict> _askGate() async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.catchTracker.composeGateBody(
      locale: locale,
      pushToken: widget.beaconHub.token,
    );
    // Identify the session by af_id as soon as attribution is available.
    Insight.identify(
      body['af_id']?.toString(),
      tags: <String, String>{
        'af_status': body['af_status']?.toString() ?? '',
        'media_source': body['media_source']?.toString() ?? '',
        'campaign': body['campaign']?.toString() ?? '',
        'os': body['os']?.toString() ?? '',
        'locale': body['locale']?.toString() ?? '',
      },
    );
    return widget.harborGate.query(body);
  }

  Future<void> _resendGateWithToken(String token) async {
    final String locale = Platform.localeName.replaceAll('-', '_');
    final Map<String, dynamic> body =
        await widget.catchTracker.composeGateBody(
      locale: locale,
      pushToken: token,
    );
    // Fire-and-forget; caching is handled inside the gate.
    unawaited(widget.harborGate.query(body));
  }

  Future<void> _settle() =>
      Future<void>.delayed(const Duration(milliseconds: 320));

  // ── Route helpers ──────────────────────────────────────────

  Future<void> _routeToGame({required double initialLift}) async {
    Insight.tag('run_mode', 'native');
    Insight.event('route_native');
    _liftProgress(initialLift);
    // The native game is portrait-only.
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    await _precacheGameArt();
    _liftProgress(1.0);
    await _settle();
    if (_routed || !mounted) return;
    _routed = true;
    // GameState is provided above MaterialApp in ChassisApp — no
    // per-route provider needed. The game runs even without internet.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (BuildContext _, Animation<double> anim, Animation<double> _) => FadeTransition(
          opacity: anim,
          child: const HomeScreen(),
        ),
      ),
    );
  }

  Future<void> _precacheGameArt() async {
    final List<String> paths = <String>[
      AppAssets.gameLogo,
      AppAssets.bgAurora,
      AppAssets.bgNorthernLights,
      AppAssets.bgSnowValley,
      AppAssets.fishermanSeated,
      AppAssets.fishermanAgedSeated,
      AppAssets.fisherFemaleSeated,
      AppAssets.fishermanStanding,
      AppAssets.fishermanAgedStanding,
      AppAssets.fisherFemaleStanding,
      ...AppAssets.fish,
    ];
    for (final String p in paths) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(p), context);
      } catch (_) {}
    }
  }

  void _routeToGray(String destination) {
    if (_routed || !mounted) return;
    _routed = true;
    Insight.tag('run_mode', 'web');
    Insight.event('route_web');
    final bool needsBeaconPrompt =
        widget.cache.shouldShowBeaconPrompt();
    if (needsBeaconPrompt) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BeaconPromptStage(
            cache: widget.cache,
            beaconHub: widget.beaconHub,
            tideSensor: widget.tideSensor,
            grayDestination: destination,
          ),
        ),
      );
    } else {
      // Returning user skips the invite — tag their permission state now
      // so the dashboard never sees a blank notif_permission for this branch.
      Insight.tag(
        'notif_permission',
        widget.cache.isBeaconAllowed()
            ? 'granted'
            : widget.cache.isBeaconOsBlocked()
                ? 'os_denied'
                : 'snoozed',
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ContentStage(
            destination: destination,
            cache: widget.cache,
            beaconHub: widget.beaconHub,
            tideSensor: widget.tideSensor,
          ),
        ),
      );
    }
  }

  void _routeToOffline() {
    if (_routed || !mounted) return;
    _routed = true;
    Insight.event('route_offline');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoSignalStage(
          retryBuilder: (_) => ArcticRouter(
            cache: widget.cache,
            tideSensor: widget.tideSensor,
            catchTracker: widget.catchTracker,
            harborGate: widget.harborGate,
            beaconHub: widget.beaconHub,
          ),
        ),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape = size.width > size.height;
    final String bg = landscape
        ? AppAssets.loadingHorizontal
        : AppAssets.loadingVertical;

    return Scaffold(
      backgroundColor: AppColors.deepIce,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x88000000)],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.10,
                  vertical: size.height * (landscape ? 0.06 : 0.08),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _LoadingCaption(dotCount: _dotIndex),
                    const SizedBox(height: 14),
                    _ProgressRibbon(progress: _progress),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCaption extends StatelessWidget {
  const _LoadingCaption({required this.dotCount});

  final int dotCount;

  @override
  Widget build(BuildContext context) {
    final String dots = '.' * dotCount;
    final String padding = '.' * (3 - dotCount);
    return Text.rich(
      TextSpan(
        children: <TextSpan>[
          const TextSpan(text: 'Loading'),
          TextSpan(text: dots),
          TextSpan(
            text: padding,
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        shadows: <Shadow>[
          Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _ProgressRibbon extends StatelessWidget {
  const _ProgressRibbon({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 18,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) => Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: c.maxWidth * progress.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.accentGold.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
