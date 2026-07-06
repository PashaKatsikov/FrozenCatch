import 'dart:math';

import 'package:flutter/material.dart';

/// Paints the fishing hole cut into the ice: a dark water pit with a frosty
/// rim and a few crack lines radiating outward, matching the icy art style.
class IceHolePainter extends CustomPainter {
  IceHolePainter({required this.rippleProgress});

  /// 0..1, drives an expanding ripple ring while a round is active.
  final double rippleProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Outer icy rim.
    final rimPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.95), const Color(0xFFBEE9FF)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, rimPaint);

    // Dark water pit.
    final waterPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Color(0xFF0B2E52), Color(0xFF04121F)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.82));
    canvas.drawCircle(center, radius * 0.82, waterPaint);

    // Subtle inner highlight.
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.06;
    canvas.drawCircle(center, radius * 0.6, highlight);

    // Crack lines on the rim.
    final crackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final crackAngles = [0.3, 1.1, 2.0, 2.8, 3.6, 4.5, 5.3, 5.9];
    for (final a in crackAngles) {
      final start = Offset(
        center.dx + cos(a) * radius * 0.86,
        center.dy + sin(a) * radius * 0.86,
      );
      final end = Offset(
        center.dx + cos(a) * radius * 1.12,
        center.dy + sin(a) * radius * 1.12,
      );
      canvas.drawLine(start, end, crackPaint);
    }

    // Expanding ripple while the round is active.
    if (rippleProgress > 0) {
      final rippleRadius = radius * 0.5 * (0.4 + rippleProgress * 0.6);
      final ripplePaint = Paint()
        ..color = Colors.lightBlueAccent.withValues(
          alpha: (1 - rippleProgress) * 0.55,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawCircle(center, rippleRadius, ripplePaint);
    }
  }

  @override
  bool shouldRepaint(covariant IceHolePainter oldDelegate) =>
      oldDelegate.rippleProgress != rippleProgress;
}

/// The animated ice hole widget: bobbing red-and-white float plus periodic
/// ripple pulses while a round is in progress.
class IceHole extends StatefulWidget {
  const IceHole({super.key, required this.size, required this.isActive});

  final double size;
  final bool isActive;

  @override
  State<IceHole> createState() => _IceHoleState();
}

class _IceHoleState extends State<IceHole> with TickerProviderStateMixin {
  late final AnimationController _bobController;
  late final AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isActive) _rippleController.repeat();
  }

  @override
  void didUpdateWidget(covariant IceHole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_rippleController.isAnimating) {
      _rippleController.repeat();
    } else if (!widget.isActive) {
      _rippleController.stop();
    }
  }

  @override
  void dispose() {
    _bobController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bobController, _rippleController]),
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: IceHolePainter(
                  rippleProgress: widget.isActive ? _rippleController.value : 0,
                ),
              ),
              Positioned(
                top: widget.size * 0.30 +
                    (widget.isActive ? sin(_bobController.value * pi * 2) * 5 : 0),
                child: _Bobber(size: widget.size * 0.16),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Bobber extends StatelessWidget {
  const _Bobber({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: SizedBox(
            width: size,
            height: size,
            child: Column(
              children: [
                Expanded(child: Container(color: Colors.redAccent)),
                Expanded(child: Container(color: Colors.white)),
              ],
            ),
          ),
        ),
        Container(
          width: 2,
          height: size * 0.6,
          color: Colors.white70,
        ),
      ],
    );
  }
}
