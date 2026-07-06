import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/game_state.dart';
import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../widgets/frost_button.dart';
import 'cosmetics_screen.dart';
import 'game_screen.dart';
import 'quests_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    return Scaffold(
      backgroundColor: AppColors.deepIce,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(gameState.selectedLocation.asset, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                      icon: const Icon(Icons.settings, color: Colors.white, size: 28),
                    ),
                  ),
                  const Spacer(flex: 2),
                  Hero(
                    tag: 'game-logo',
                    child: Image.asset(
                      AppAssets.gameLogo,
                      width: 230,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FrostPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    borderRadius: 18,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, color: AppColors.accentGold, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Best score: ${gameState.bestScore}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 3),
                  FrostButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    fontSize: 22,
                    height: 64,
                    gradient: AppColors.goldGradient,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const GameScreen()),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FrostButton(
                          label: 'Quests',
                          icon: Icons.checklist_rounded,
                          height: 50,
                          fontSize: 14,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const QuestsScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FrostButton(
                          label: 'Records',
                          icon: Icons.bar_chart_rounded,
                          height: 50,
                          fontSize: 14,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RecordsScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FrostButton(
                    label: 'Anglers & Locations',
                    icon: Icons.landscape_rounded,
                    height: 50,
                    fontSize: 14,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CosmeticsScreen()),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
