import 'package:flutter/material.dart';

import '../runtime/beacon_hub.dart';
import '../runtime/icy_cache.dart';
import '../runtime/tide_sensor.dart';
import '../settings/identity.dart';
import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import 'content_stage.dart';
import 'frost_action_button.dart';

// ============================================================
// BEACON PROMPT — "Enable notifications?" gateway
// ============================================================
// Shown once before the WebView on the first entry into gray mode,
// and again after every Skip cooldown (3 days) until the user
// either grants the permission or the OS blocks any further asking.
//
// Layout invariants (per user brief):
//   • Landscape has NO SafeArea and both buttons are pinned to the
//     true horizontal center via `Center()` inside a full-width
//     Positioned. The camera cutout on notched landscape devices
//     would otherwise push the buttons off-center.
//   • Accept + Skip sit on the same padding rail with matching
//     button styles so neither looks like an afterthought.
// ============================================================

class BeaconPromptStage extends StatelessWidget {
  const BeaconPromptStage({
    super.key,
    required this.cache,
    required this.beaconHub,
    required this.tideSensor,
    required this.grayDestination,
  });

  final IcyCache cache;
  final BeaconHub beaconHub;
  final TideSensor tideSensor;
  final String grayDestination;

  Future<void> _accept(BuildContext context) async {
    final bool granted = await beaconHub.requestPermission();
    if (!granted) {
      await cache.writePromptCooldown(_cooldownStamp());
    }
    if (context.mounted) _proceed(context);
  }

  Future<void> _skip(BuildContext context) async {
    await cache.writePromptCooldown(_cooldownStamp());
    if (context.mounted) _proceed(context);
  }

  int _cooldownStamp() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      FrostIdentity.beaconPromptCooldownSeconds;

  void _proceed(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ContentStage(
          destination: grayDestination,
          cache: cache,
          beaconHub: beaconHub,
          tideSensor: tideSensor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Size size = mq.size;
    final bool landscape = size.width > size.height;
    final String bg = landscape
        ? AppAssets.notificationsHorizontal
        : AppAssets.notificationsVertical;

    // Sizing per gray_part_pitfalls.md §12/§18.
    final double acceptWidth = landscape
        ? size.width * 0.34
        : (size.width * 0.72).clamp(240.0, 380.0);
    final double skipWidth = landscape
        ? size.width * 0.22
        : (size.width * 0.50).clamp(180.0, 280.0);
    final double bottomOffset = size.height * (landscape ? 0.08 : 0.09);
    final double buttonGap = landscape ? 10 : 14;

    final Widget accept = FrostActionButton(
      label: 'Accept',
      icon: Icons.notifications_active_rounded,
      compact: landscape,
      width: acceptWidth,
      onPressed: () => _accept(context),
    );

    final Widget skip = FrostSecondaryButton(
      label: 'Skip',
      compact: landscape,
      width: skipWidth,
      onPressed: () => _skip(context),
    );

    final Widget stack = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        accept,
        SizedBox(height: buttonGap),
        skip,
      ],
    );

    // Landscape: no SafeArea, buttons pinned to the true horizontal
    // center regardless of notch. See user brief.
    if (landscape) {
      return Scaffold(
        backgroundColor: AppColors.deepIce,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(bg,
                fit: BoxFit.cover, width: size.width, height: size.height),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0x88000000)],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomOffset,
              child: Center(child: stack),
            ),
          ],
        ),
      );
    }

    // Portrait — SafeArea kept, buttons on a padded rail.
    return Scaffold(
      backgroundColor: AppColors.deepIce,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg,
              fit: BoxFit.cover, width: size.width, height: size.height),
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
                padding: EdgeInsets.only(bottom: bottomOffset),
                child: stack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
