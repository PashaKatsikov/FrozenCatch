import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import 'frost_action_button.dart';

// ============================================================
// NO-SIGNAL STAGE — offline splash + retry
// ============================================================
// Shown on frame ONE when the first launch has no connectivity,
// and on any subsequent connectivity drop from inside the WebView.
// Retry rebuilds whatever screen the caller supplied — the router
// hands it a fresh copy of itself so the full boot pipeline replays.
//
// Layout invariants (per gray_part_pitfalls.md §14, §18):
//   • Landscape uses NO SafeArea and pins the button to the true
//     horizontal center — the notch inset in landscape would push
//     the content off-center on notched devices otherwise.
//   • Portrait uses SafeArea so the retry button doesn't collide
//     with the status bar or the on-screen nav gesture area.
// ============================================================

class NoSignalStage extends StatefulWidget {
  const NoSignalStage({super.key, required this.retryBuilder});

  /// Route builder used to rebuild the retry target (usually a fresh
  /// ArcticRouter that replays the full pipeline).
  final WidgetBuilder retryBuilder;

  @override
  State<NoSignalStage> createState() => _NoSignalStageState();
}

class _NoSignalStageState extends State<NoSignalStage> {
  bool _retrying = false;

  Future<void> _handleRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    // A short beat so the user sees the pressed state react — otherwise
    // the screen swap feels instantaneous and confusing on flaky networks.
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.retryBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Size size = mq.size;
    final bool landscape = size.width > size.height;
    final String bg = landscape
        ? AppAssets.nowifiHorizontal
        : AppAssets.nowifiVertical;

    // Button proportions per gray_part_pitfalls.md §18 — capped so it
    // never becomes a full-bleed pill on landscape / tablets, and
    // shrunk in landscape so it doesn't overlap the artwork.
    final double buttonWidth = landscape
        ? size.width * 0.34
        : (size.width * 0.72).clamp(240.0, 380.0);
    final double bottomOffset = size.height * (landscape ? 0.10 : 0.08);

    final Widget button = FrostActionButton(
      label: 'Try Again',
      icon: Icons.refresh_rounded,
      width: buttonWidth,
      busy: _retrying,
      onPressed: _handleRetry,
    );

    // Landscape variant: SafeArea intentionally omitted so the button
    // sits on the true horizontal center. The camera cutout does not
    // hit the bottom-center gutter, so this is safe.
    if (landscape) {
      return Scaffold(
        backgroundColor: AppColors.deepIce,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              bg,
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomOffset,
              child: Center(child: button),
            ),
          ],
        ),
      );
    }

    // Portrait — normal SafeArea handling.
    return Scaffold(
      backgroundColor: AppColors.deepIce,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            bg,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x99000000)],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomOffset),
                child: button,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
