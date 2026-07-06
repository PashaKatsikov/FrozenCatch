import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../theme/app_colors.dart';
import '../widgets/frost_button.dart';
import '../widgets/ice_hole.dart';
import '../widgets/round_result_card.dart';
import '../widgets/top_stats_bar.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _Ripple {
  _Ripple(this.id, this.offset);
  final int id;
  final Offset offset;
}

class _GameScreenState extends State<GameScreen> {
  final List<_Ripple> _ripples = [];
  int _rippleSeed = 0;
  GameState? _gameState;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the reference while the widget is still mounted so dispose()
    // never needs to walk the (possibly deactivated) element tree.
    _gameState = context.read<GameState>();
  }

  @override
  void dispose() {
    _gameState?.cancelRound();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details, GameState gs) {
    if (gs.phase != RoundPhase.active) return;
    gs.registerTap();
    HapticFeedback.lightImpact();
    final id = _rippleSeed++;
    setState(() => _ripples.add(_Ripple(id, details.localPosition)));
    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      setState(() => _ripples.removeWhere((r) => r.id == id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();

    return Scaffold(
      backgroundColor: AppColors.deepIce,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(gs.selectedLocation.asset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      ),
                      Expanded(
                        child: TopStatsBar(
                          score: gs.sessionScore,
                          bestScore: gs.bestScore,
                          fishCaught: gs.totalFishCaught,
                          clickRecord: gs.clickRecord,
                          streak: gs.currentStreak,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      final holeSize = w * 0.40;
                      final holeCenter = Offset(w * 0.68, h * 0.34);
                      final rodTip = Offset(w * 0.40, h * 0.30);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Fishing line from rod tip to the hole.
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _FishingLinePainter(from: rodTip, to: holeCenter),
                            ),
                          ),
                          Positioned(
                            left: holeCenter.dx - holeSize / 2,
                            top: holeCenter.dy - holeSize / 2,
                            child: IceHole(size: holeSize, isActive: gs.phase == RoundPhase.active),
                          ),
                          Positioned(
                            left: -w * 0.06,
                            bottom: -h * 0.02,
                            child: Image.asset(
                              gs.selectedAngler.seatedAsset,
                              height: h * 0.62,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          Align(
                            alignment: const Alignment(0, -0.78),
                            child: _CenterReadout(gs: gs),
                          ),
                          for (final r in _ripples)
                            Positioned(
                              left: r.offset.dx - 28,
                              top: r.offset.dy - 28,
                              child: const _TapRipple(),
                            ),
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (d) => _handleTapDown(d, gs),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                  child: _BottomControls(gs: gs),
                ),
              ],
            ),
          ),
          if (gs.phase == RoundPhase.countdown) _CountdownOverlay(value: gs.countdownValue),
          if (gs.phase == RoundPhase.result && gs.lastResult != null)
            RoundResultCard(
              result: gs.lastResult!,
              onContinue: () {
                gs.acknowledgeResult();
                gs.beginCountdown();
              },
            ),
        ],
      ),
    );
  }
}

class _CenterReadout extends StatelessWidget {
  const _CenterReadout({required this.gs});
  final GameState gs;

  @override
  Widget build(BuildContext context) {
    if (gs.phase != RoundPhase.active) return const SizedBox.shrink();
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey(gs.clicks),
          tween: Tween(begin: 1.25, end: 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: Text(
            '${gs.clicks}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3))],
            ),
          ),
        ),
        const Text(
          'TAPS',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.gs});
  final GameState gs;

  @override
  Widget build(BuildContext context) {
    switch (gs.phase) {
      case RoundPhase.idle:
        return FrostButton(
          label: 'START ROUND',
          icon: Icons.play_circle_fill,
          height: 60,
          fontSize: 20,
          gradient: AppColors.goldGradient,
          onTap: gs.beginCountdown,
        );
      case RoundPhase.countdown:
        return const _HintText('Get ready to tap fast!');
      case RoundPhase.active:
        final ratio = (gs.timeRemaining / gs.roundDuration).clamp(0.0, 1.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 14,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(
                  ratio > 0.3 ? AppColors.rareCyan : AppColors.accentRed,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _HintText('TAP ANYWHERE — AS FAST AS YOU CAN!'),
          ],
        );
      case RoundPhase.result:
        return const SizedBox(height: 60);
    }
  }
}

class _HintText extends StatelessWidget {
  const _HintText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(value),
            tween: Tween(begin: 0.4, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Text(
              value > 0 ? '$value' : 'GO!',
              style: const TextStyle(
                color: AppColors.accentGold,
                fontSize: 96,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 4))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TapRipple extends StatelessWidget {
  const _TapRipple();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.6),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (context, scale, child) {
        return Opacity(
          opacity: (1.4 - scale).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.4),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FishingLinePainter extends CustomPainter {
  _FishingLinePainter({required this.from, required this.to});
  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final control = Offset((from.dx + to.dx) / 2, max(from.dy, to.dy) + 26);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FishingLinePainter oldDelegate) =>
      oldDelegate.from != from || oldDelegate.to != to;
}
