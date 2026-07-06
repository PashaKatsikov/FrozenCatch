import 'package:flutter/material.dart';

/// A chunky, comic-style text with an outline stroke and a soft drop shadow,
/// used for headings and score pop-ups to match the game's playful art style.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    required this.fontSize,
    this.fillColor = Colors.white,
    this.strokeColor = const Color(0xFF0B4A78),
    this.strokeWidth = 4,
    this.fontWeight = FontWeight.w900,
    this.textAlign,
    this.letterSpacing = 0.5,
  });

  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final FontWeight fontWeight;
  final TextAlign? textAlign;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: 1.05,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: textAlign,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.35),
                offset: const Offset(0, 3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        Text(
          text,
          textAlign: textAlign,
          style: baseStyle.copyWith(color: fillColor),
        ),
      ],
    );
  }
}
