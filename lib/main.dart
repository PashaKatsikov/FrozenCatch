import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chassis/chassis_app.dart';
import 'runtime/agent_mint.dart';
import 'runtime/beacon_hub.dart';
import 'runtime/catch_tracker.dart';
import 'runtime/harbor_gate.dart';
import 'runtime/icy_cache.dart';
import 'runtime/insight.dart';
import 'runtime/tide_sensor.dart';
import 'theme/app_colors.dart';

// ============================================================
// main.dart — Frozen Catch bootstrap
// ============================================================
// Order of operations MUST NOT change without reading
// android_gray_guide.md § "Setup Checklist":
//
//   1. WidgetsFlutterBinding      — required before any plugin call.
//   2. Firebase + App Check       — wrapped in try/catch because
//      google-services.json may not have landed yet; failure here
//      must never block startup. The gray branch simply stays
//      dormant and the app opens the fishing game.
//   3. Orientation whitelist      — all four so the loading and
//      content screens can rotate freely. The native game re-locks
//      to portrait itself once ArcticRouter routes into it.
//   4. Transparent status bar     — background artwork goes
//      edge-to-edge.
//   5. frostHttp.ignite()         — reads device info and mints the
//      forged User-Agent used by BOTH the HTTP client AND the
//      WebView (see agent_mint.dart).
//   6. IcyCache.hydrate()         — loads SharedPreferences into
//      memory so ArcticRouter can pick a branch synchronously on
//      the first frame (no blank splash).
//   7. Bridges constructed        — Beacon and Catch bridges are
//      built here but only `warm()` / `kindle()` inside ArcticRouter,
//      once the UI is up.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check are optional until credentials land. Both are
  // wrapped so a missing google-services.json cannot prevent boot.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.deepIce,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Mint the UA BEFORE any bridge issues its first request — HarborGate
  // uses the primed value on its very first HTTP call.
  await frostHttp.ignite();

  final IcyCache cache = IcyCache();
  await cache.hydrate();

  final TideSensor tideSensor = TideSensor();
  final CatchTracker catchTracker = CatchTracker();
  final HarborGate harborGate = HarborGate(cache);
  final BeaconHub beaconHub = BeaconHub(cache);

  // ClarityWidget must be the outermost wrapper so replay covers every
  // native screen. The config is constructed via Insight.config (guarded).
  runApp(
    ClarityWidget(
      clarityConfig: Insight.config,
      app: ChassisApp(
        cache: cache,
        tideSensor: tideSensor,
        catchTracker: catchTracker,
        harborGate: harborGate,
        beaconHub: beaconHub,
      ),
    ),
  );
}
