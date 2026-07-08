import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

import '../settings/sealed_keys.dart';

// ============================================================
// AGENT MINT — HTTP client wearing a real-device User-Agent
// ============================================================
// Every outbound call (gate POST, GCD retry, push image fetch) plus
// the WebView itself use the same forged User-Agent. It is built at
// startup from `device_info_plus` (real Android release + brand +
// model + build id) so that identical installs on different devices
// naturally diverge — a hard-coded UA would cluster all our devices
// into one signature.
//
// Chrome and WebKit version fragments come from the cipher so the
// major bump between projects is not visible in the plaintext.
//
// GAME THEME CATEGORY — Frozen Catch is a casual ice-fishing clicker;
// it is neither a slot game nor a crash/aviator game per
// .cursor/rules/gray_user_agent.mdc §2. Consequently we do NOT append
// the `appid/<pkg> appname/<Name>` suffix. If the partner backend for
// this build later demands one, add the suffix inside `_composeUa()`
// and RE-BUILD — the choice is cached per-install on the backend.
// ============================================================

class MintedHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  String _userAgent = _fallbackUa;

  static const String _fallbackUa =
      'Mozilla/5.0 (Linux; Android 15; Pixel 8 Build/AP4A.250205.002) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 '
      'Mobile Safari/537.36';

  String get userAgent => _userAgent;

  /// Reads the running device and assembles the UA. Call once in main()
  /// BEFORE any bridge issues its first request.
  Future<void> ignite() async {
    final String chrome = _fallback(unsealChromeTag(), '151.0.7748.106');
    final String webkit = _fallback(unsealWebKitTag(), '537.36');

    try {
      final DeviceInfoPlugin device = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final AndroidDeviceInfo a = await device.androidInfo;
        // NOTE: `a.version.release` is the Android RELEASE string ("15",
        // "14", ...) — NOT the SDK integer. This is the version that a
        // real Chrome exposes in its UA. Do not swap for `sdkInt` here.
        final String build =
            a.display.isNotEmpty ? a.display : (a.id.isNotEmpty ? a.id : 'AP');
        _userAgent = _composeUa(
          release: a.version.release,
          brand: a.brand,
          model: a.model,
          buildTag: build,
          chrome: chrome,
          webkit: webkit,
        );
      } else if (Platform.isIOS) {
        // Kept for parity — this template is Android-only, but a shell
        // fork could conceivably run on iOS with the same UA logic.
        final IosDeviceInfo i = await device.iosInfo;
        final String os = i.systemVersion.replaceAll('.', '_');
        _userAgent =
            'Mozilla/5.0 (iPhone; CPU iPhone OS $os like Mac OS X) '
            'AppleWebKit/$webkit (KHTML, like Gecko) '
            'Version/${i.systemVersion} Mobile/15E148 Safari/$webkit';
      }
    } catch (_) {
      // Keep the fallback UA (still looks like a real Chrome).
    }
  }

  static String _composeUa({
    required String release,
    required String brand,
    required String model,
    required String buildTag,
    required String chrome,
    required String webkit,
  }) {
    return 'Mozilla/5.0 (Linux; Android $release; '
        '$brand $model Build/$buildTag) '
        'AppleWebKit/$webkit (KHTML, like Gecko) '
        'Chrome/$chrome Mobile Safari/$webkit';
  }

  static String _fallback(String candidate, String otherwise) =>
      candidate.isNotEmpty ? candidate : otherwise;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // putIfAbsent so a caller can still override the UA explicitly.
    request.headers.putIfAbsent('User-Agent', () => _userAgent);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

/// Process-wide client — used by every runtime bridge (harbor_gate,
/// catch_tracker's GCD retry, beacon_hub's image fetch).
final MintedHttpClient frostHttp = MintedHttpClient();
