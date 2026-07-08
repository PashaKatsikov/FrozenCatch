import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../settings/identity.dart';
import '../settings/sealed_keys.dart';
import 'agent_mint.dart';

// ============================================================
// CATCH TRACKER — AppsFlyer install attribution + deep links
// ============================================================
// Owns the AppsFlyer SDK lifecycle and folds every attribution
// payload into a single flat map ready for the gate POST. Merge
// order:
//   1. `onInstallConversionData`  (overwrites)
//   2. `onDeepLinking`            (putIfAbsent — first write wins)
//   3. `onAppOpenAttribution`     (putIfAbsent)
//   4. Device-side fields         (overwrite — see composeGateBody)
//
// Organic false-positive workaround: on the first callback we
// occasionally receive `af_status == "Organic"` even for paid
// installs. When that happens we sleep for a few seconds and re-query
// the GCD API for the real attribution (see gray_part_pitfalls.md
// / android_gray_guide.md).
//
// If the dev key is empty (credentials not yet supplied), the tracker
// short-circuits — the completers finish instantly with an empty map
// so the boot sequence does not sit for 30 s waiting for a callback
// that will never fire.
// ============================================================

class CatchTracker {
  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installPayload;
  Map<String, dynamic>? _deepLinkPayload;
  Map<String, dynamic>? _appOpenPayload;

  final Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkReady = Completer<void>();

  bool _kindled = false;

  /// Wires the SDK. Idempotent (safe to call twice).
  Future<void> kindle() async {
    if (_kindled) return;
    _kindled = true;

    final String devKey = FrostIdentity.attributionDevKey;
    if (devKey.isEmpty) {
      // No credentials yet — signal completion so the router does not stall.
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
      return;
    }

    final AppsFlyerOptions cfg = AppsFlyerOptions(
      afDevKey: devKey,
      appId: FrostIdentity.iosStoreNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );
    final AppsflyerSdk sdk = AppsflyerSdk(cfg);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) async {
      final Map<String, dynamic> parsed = _flatten(raw);
      final String? status = parsed['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: FrostIdentity.organicRecheckDelaySeconds),
        );
        final Map<String, dynamic>? real = await _fetchGcdAttribution();
        _installPayload = real ?? parsed;
      } else {
        _installPayload = parsed;
      }
      _finishInstall(_installPayload ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic raw) {
      _appOpenPayload = _flatten(raw);
    });

    sdk.onDeepLinking((DeepLinkResult r) {
      final Map<String, dynamic>? click = r.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkPayload = Map<String, dynamic>.from(click);
      }
      _finishDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _finishInstall(<String, dynamic>{});
      _finishDeepLink();
    }
  }

  /// Waits up to [seconds] for the install conversion payload.
  Future<Map<String, dynamic>> waitForInstall({int seconds = 30}) {
    return _installReady.future.timeout(
      Duration(seconds: seconds),
      onTimeout: () => <String, dynamic>{},
    );
  }

  /// Waits up to 5 s for the deep-link callback. Absence is normal.
  Future<void> waitForDeepLink() {
    return _deepLinkReady.future
        .timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<String?> afUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assembles the flat JSON body posted to the gate endpoint.
  Future<Map<String, dynamic>> composeGateBody({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installPayload != null) body.addAll(_installPayload!);
    _deepLinkPayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpenPayload
        ?.forEach((String k, dynamic v) => body.putIfAbsent(k, () => v));

    // Device-side fields — these ALWAYS overwrite whatever the SDK
    // provided, per the gate contract.
    body['af_id'] = await afUid() ?? '';
    body['bundle_id'] = FrostIdentity.bundleId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = FrostIdentity.storeId;
    body['locale'] = locale;

    // Contract §3, §5 — omit both keys if FCM is not initialised; never
    // send empty strings or null (the backend distinguishes them).
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = FrostIdentity.messagingProjectId;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    if (kDebugMode) {
      debugPrint('[CatchTracker] gate body: ${jsonEncode(body)}');
    }
    return body;
  }

  Future<Map<String, dynamic>?> _fetchGcdAttribution() async {
    try {
      final String? deviceId = await afUid();
      if (deviceId == null) return null;
      final String appId = Platform.isIOS
          ? FrostIdentity.iosStoreNumericId
          : FrostIdentity.bundleId;
      final String url = composeGcdQuery(appId, deviceId);
      if (url.isEmpty) return null;

      final response = await frostHttp.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${FrostIdentity.attributionDevKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _finishInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _finishDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  /// Extracts the actual payload map from whatever wrapper the SDK
  /// gives us (`{"payload": {...}}`, `{"data": {...}}` or the raw map).
  static Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic core = raw['payload'] ?? raw['data'] ?? raw;
    if (core is Map) {
      return core.map<String, dynamic>(
        (dynamic k, dynamic v) =>
            MapEntry<String, dynamic>(k.toString(), v),
      );
    }
    return <String, dynamic>{};
  }
}
