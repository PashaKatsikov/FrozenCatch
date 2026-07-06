import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fish.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';
import '../widgets/frost_button.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    final bestFish = gs.bestFishTier > 0 ? FishCatalog.byTier(gs.bestFishTier) : null;

    final stats = <_StatEntry>[
      _StatEntry(Icons.emoji_events, 'Best score', '${gs.bestScore}'),
      _StatEntry(Icons.auto_awesome, 'Current score', '${gs.sessionScore}'),
      _StatEntry(Icons.set_meal, 'Fish caught', '${gs.totalFishCaught}'),
      _StatEntry(Icons.touch_app, 'All-time taps', '${gs.totalClicksAllTime}'),
      _StatEntry(Icons.bolt, 'Tap record (1 round)', '${gs.clickRecord}'),
      _StatEntry(Icons.local_fire_department, 'Best streak', '${gs.bestStreak}'),
      _StatEntry(Icons.trending_up, 'Current streak', '${gs.currentStreak}'),
      _StatEntry(Icons.casino, 'Rounds played', '${gs.roundsPlayedTotal}'),
      _StatEntry(Icons.trending_up, 'Difficulty level', '${gs.level + 1}'),
    ];

    return Scaffold(
      backgroundColor: AppColors.deepIce,
      appBar: AppBar(
        backgroundColor: AppColors.midIce,
        foregroundColor: Colors.white,
        title: const Text('Records'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (bestFish != null)
            FrostPanel(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Image.asset(bestFish.asset, width: 90, height: 90),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Best catch ever',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bestFish.name,
                          style: TextStyle(
                            color: bestFish.color,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          bestFish.sizeLabel,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, index) => _StatCard(entry: stats[index]),
          ),
        ],
      ),
    );
  }
}

class _StatEntry {
  const _StatEntry(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.entry});
  final _StatEntry entry;

  @override
  Widget build(BuildContext context) {
    return FrostPanel(
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(entry.icon, color: AppColors.accentGold, size: 22),
          const SizedBox(height: 6),
          Text(
            entry.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            entry.label,
            maxLines: 2,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
