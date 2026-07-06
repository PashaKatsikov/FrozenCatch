import 'package:flutter/material.dart';

import '../models/round_result.dart';
import '../theme/app_colors.dart';
import 'frost_button.dart';

/// Full-screen result overlay shown when a round ends: the caught fish,
/// its size label and a breakdown of every bonus that contributed to score.
class RoundResultCard extends StatelessWidget {
  const RoundResultCard({
    super.key,
    required this.result,
    required this.onContinue,
  });

  final RoundResult result;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final fish = result.fish;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 380),
            curve: Curves.elasticOut,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: FrostPanel(
                borderRadius: 26,
                opacity: 0.22,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (fish.isLegendary)
                      const Text(
                        '★ LEGENDARY ★',
                        style: TextStyle(
                          color: AppColors.accentGold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    Text(
                      fish.sizeLabel.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: fish.color,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            fish.color.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Image.asset(fish.asset, fit: BoxFit.contain),
                    ),
                    Text(
                      fish.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _breakdownRow('Taps', '${result.clicks}'),
                    _breakdownRow('Base points', '+${result.basePoints}'),
                    _breakdownRow('Tap bonus', '+${result.clickBonus}'),
                    if (result.streakBonus > 0)
                      _breakdownRow('Streak bonus', '+${result.streakBonus}'),
                    if (result.rareBonus > 0)
                      _breakdownRow('Rarity bonus', '+${result.rareBonus}'),
                    if (result.comboBonus > 0)
                      _breakdownRow('Combo bonus', '+${result.comboBonus}'),
                    if (result.recordBonus > 0)
                      _breakdownRow('New record!', '+${result.recordBonus}',
                          color: AppColors.accentGold),
                    const Divider(color: Colors.white24, height: 22),
                    Text(
                      '+${result.totalPoints} pts',
                      style: const TextStyle(
                        color: AppColors.accentGold,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (result.isNewBestScore)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'New best score!',
                          style: TextStyle(
                            color: AppColors.successGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    FrostButton(
                      label: 'Next round',
                      icon: Icons.arrow_forward_rounded,
                      height: 50,
                      onTap: onContinue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
