import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ============================================================
// FROST ACTION BUTTONS — buttons used by the gray-shell screens
// ============================================================
// A pair of buttons distinct from the native game's [FrostButton]
// so the two experiences read differently: the gray shell uses
// icy-cyan glass buttons with a diamond notch and a scale-on-tap;
// the native game uses the rounded gradient pill.
//
// Both classes intentionally use `GestureDetector` (not `InkWell`)
// so the tap animation is deterministic and immune to Material
// overlay artefacts on top of the background artwork.
// ============================================================

/// Primary action button used on the No-Signal and Beacon-Prompt screens.
class FrostActionButton extends StatefulWidget {
  const FrostActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width,
    this.compact = false,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback onPressed;
  final double? width;
  final bool compact;
  final IconData? icon;
  final bool busy;

  @override
  State<FrostActionButton> createState() => _FrostActionButtonState();
}

class _FrostActionButtonState extends State<FrostActionButton> {
  double _scale = 1.0;

  void _pressDown() => setState(() => _scale = 0.94);
  void _pressUp() => setState(() => _scale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.busy ? null : (_) => _pressDown(),
      onTapCancel: widget.busy ? null : _pressUp,
      onTapUp: widget.busy
          ? null
          : (_) {
              _pressUp();
              widget.onPressed();
            },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 95),
        child: Container(
          width: widget.width,
          height: widget.compact ? 48 : 56,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 1.6,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.deepIce.withValues(alpha: 0.55),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                offset: const Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (widget.icon != null) ...<Widget>[
                      Icon(widget.icon,
                          color: Colors.white,
                          size: widget.compact ? 18 : 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.compact ? 15 : 18,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                        letterSpacing: 0.5,
                        shadows: const <Shadow>[
                          Shadow(
                            color: Color(0x66000000),
                            offset: Offset(0, 2),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary button used for the "Skip" action on the Beacon Prompt.
/// A muted variant of [FrostActionButton] with the same footprint —
/// visual weight comes from the softer gradient, not from a tiny
/// text link (see gray_part_pitfalls.md §12).
class FrostSecondaryButton extends StatefulWidget {
  const FrostSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final double? width;
  final bool compact;

  @override
  State<FrostSecondaryButton> createState() => _FrostSecondaryButtonState();
}

class _FrostSecondaryButtonState extends State<FrostSecondaryButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 95),
        child: Container(
          width: widget.width,
          height: widget.compact ? 46 : 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.compact ? 14 : 16,
              fontWeight: FontWeight.w700,
              height: 1.0,
              letterSpacing: 0.5,
              shadows: const <Shadow>[
                Shadow(
                  color: Color(0x99000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
