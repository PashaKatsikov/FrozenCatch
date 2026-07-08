import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../runtime/beacon_hub.dart';
import '../runtime/catch_tracker.dart';
import '../runtime/harbor_gate.dart';
import '../runtime/icy_cache.dart';
import '../runtime/tide_sensor.dart';
import '../settings/identity.dart';
import '../theme/app_colors.dart';
import 'arctic_router.dart';

/// Root MaterialApp for Frozen Catch. Owns the long-lived runtime
/// bridges and hands them to the [ArcticRouter], which decides whether
/// the app opens the WebView or the native game.
class ChassisApp extends StatelessWidget {
  const ChassisApp({
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
  Widget build(BuildContext context) {
    // GameState is provided above MaterialApp so every route on the
    // game side (Home, Play, Records, Cosmetics, Quests, Settings)
    // can read it regardless of navigation depth. It carries no
    // network dependency, so wiring it here does not affect the
    // gray-part boot.
    return ChangeNotifierProvider<GameState>(
      create: (_) => GameState(),
      child: MaterialApp(
        title: FrostIdentity.displayName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: AppColors.midIce,
          scaffoldBackgroundColor: AppColors.deepIce,
          fontFamily: 'Roboto',
        ),
        home: ArcticRouter(
          cache: cache,
          tideSensor: tideSensor,
          catchTracker: catchTracker,
          harborGate: harborGate,
          beaconHub: beaconHub,
        ),
      ),
    );
  }
}
