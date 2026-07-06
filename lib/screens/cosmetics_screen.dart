import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/angler.dart';
import '../models/game_state.dart';
import '../theme/app_colors.dart';

class CosmeticsScreen extends StatelessWidget {
  const CosmeticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.deepIce,
        appBar: AppBar(
          backgroundColor: AppColors.midIce,
          foregroundColor: Colors.white,
          title: const Text('Anglers & Locations'),
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppColors.accentGold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(text: 'Anglers'),
              Tab(text: 'Locations'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_AnglersTab(), _LocationsTab()],
        ),
      ),
    );
  }
}

class _AnglersTab extends StatelessWidget {
  const _AnglersTab();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return GridView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: Angler.all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final angler = Angler.all[index];
        final unlocked = gs.isAnglerUnlocked(angler);
        final selected = gs.selectedAnglerId == angler.id;
        return _CosmeticCard(
          image: angler.portraitAsset,
          name: angler.name,
          unlocked: unlocked,
          selected: selected,
          lockLabel: 'Catch ${angler.unlockRequirement} fish',
          onTap: unlocked ? () => gs.selectAngler(angler) : null,
        );
      },
    );
  }
}

class _LocationsTab extends StatelessWidget {
  const _LocationsTab();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    return GridView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: LakeLocation.all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final loc = LakeLocation.all[index];
        final unlocked = gs.isLocationUnlocked(loc);
        final selected = gs.selectedLocationId == loc.id;
        return _CosmeticCard(
          image: loc.asset,
          name: loc.name,
          unlocked: unlocked,
          selected: selected,
          lockLabel: 'Best score ${loc.unlockScore}',
          onTap: unlocked ? () => gs.selectLocation(loc) : null,
        );
      },
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.image,
    required this.name,
    required this.unlocked,
    required this.selected,
    required this.lockLabel,
    required this.onTap,
  });

  final String image;
  final String name;
  final bool unlocked;
  final bool selected;
  final String lockLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.midIce.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.accentGold : Colors.white24,
              width: selected ? 3 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ColorFiltered(
                          colorFilter: unlocked
                              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                              : const ColorFilter.mode(Colors.black54, BlendMode.saturation),
                          child: Image.asset(image, fit: BoxFit.cover),
                        ),
                      ),
                      if (!unlocked)
                        const Align(
                          alignment: Alignment.center,
                          child: Icon(Icons.lock, color: Colors.white70, size: 30),
                        ),
                      if (selected)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(Icons.check_circle, color: AppColors.successGreen),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (!unlocked)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          lockLabel,
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
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
