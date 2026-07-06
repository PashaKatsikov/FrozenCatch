import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'frost_button.dart';

/// Compact strip of the key counters called out by the game design: current
/// score, best score, fish caught, tap record and catch streak.
class TopStatsBar extends StatelessWidget {
  const TopStatsBar({
    super.key,
    required this.score,
    required this.bestScore,
    required this.fishCaught,
    required this.clickRecord,
    required this.streak,
  });

  final int score;
  final int bestScore;
  final int fishCaught;
  final int clickRecord;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: 18,
      opacity: 0.20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Stat(icon: Icons.auto_awesome, value: '$score', color: AppColors.accentGold),
          _Stat(icon: Icons.emoji_events, value: '$bestScore', color: Colors.white),
          _Stat(icon: Icons.set_meal, value: '$fishCaught', color: Colors.white),
          _Stat(icon: Icons.bolt, value: '$clickRecord', color: AppColors.rareCyan),
          _Stat(
            icon: Icons.local_fire_department,
            value: '$streak',
            color: streak > 0 ? AppColors.accentOrange : Colors.white54,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.color});

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
