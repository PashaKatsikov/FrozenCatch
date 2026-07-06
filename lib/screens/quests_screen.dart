import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_quest.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';
import '../widgets/frost_button.dart';

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  IconData _iconFor(QuestType type) {
    switch (type) {
      case QuestType.catchFish:
        return Icons.set_meal;
      case QuestType.totalClicks:
        return Icons.touch_app;
      case QuestType.catchLarge:
        return Icons.waves;
      case QuestType.catchLegendary:
        return Icons.star;
      case QuestType.playRounds:
        return Icons.casino;
      case QuestType.newClickRecord:
        return Icons.bolt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();

    return Scaffold(
      backgroundColor: AppColors.deepIce,
      appBar: AppBar(
        backgroundColor: AppColors.midIce,
        foregroundColor: Colors.white,
        title: const Text('Daily Quests'),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: gs.quests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final quest = gs.quests[index];
          return FrostPanel(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: quest.isComplete
                      ? AppColors.successGreen
                      : AppColors.midIce,
                  child: Icon(_iconFor(quest.type), color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: quest.progressRatio,
                          minHeight: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(
                            quest.isComplete
                                ? AppColors.successGreen
                                : AppColors.accentGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${quest.progress.clamp(0, quest.target)}/${quest.target}  •  +${quest.reward} pts',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 84,
                  child: FrostButton(
                    label: quest.claimed ? 'Done' : 'Claim',
                    height: 38,
                    fontSize: 12,
                    enabled: quest.isComplete && !quest.claimed,
                    gradient: quest.claimed
                        ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                        : AppColors.goldGradient,
                    onTap: () => gs.claimQuest(quest.id),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
