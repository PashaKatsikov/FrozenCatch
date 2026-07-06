import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';

/// Rarity tier of a catch, mirroring the escalating fish sizes described in
/// the game design: tiny -> small -> medium -> large -> huge -> legendary.
enum FishRarity { common, uncommon, rare, epic, mythic, legendary }

class FishSpecies {
  const FishSpecies({
    required this.tier,
    required this.name,
    required this.asset,
    required this.rarity,
    required this.basePoints,
    required this.displayScale,
    required this.minCps,
  });

  /// 1-based tier, 1 = smallest common fish, 10 = legendary trophy fish.
  final int tier;
  final String name;
  final String asset;
  final FishRarity rarity;
  final int basePoints;

  /// Relative on-screen scale so bigger catches visibly look bigger.
  final double displayScale;

  /// Minimum "clicks per second" (normalized for difficulty) required to
  /// land this fish.
  final double minCps;

  Color get color {
    switch (rarity) {
      case FishRarity.common:
        return Colors.white70;
      case FishRarity.uncommon:
        return AppColors.successGreen;
      case FishRarity.rare:
        return AppColors.rareCyan;
      case FishRarity.epic:
        return const Color(0xFF6C9BFF);
      case FishRarity.mythic:
        return const Color(0xFFFF7BD6);
      case FishRarity.legendary:
        return AppColors.accentGold;
    }
  }

  String get sizeLabel {
    switch (tier) {
      case 1:
        return 'Tiny catch';
      case 2:
        return 'Small catch';
      case 3:
        return 'Modest catch';
      case 4:
        return 'Decent catch';
      case 5:
        return 'Medium catch';
      case 6:
        return 'Solid catch';
      case 7:
        return 'Large catch';
      case 8:
        return 'Big catch';
      case 9:
        return 'Huge catch';
      default:
        return 'LEGENDARY CATCH';
    }
  }

  bool get isSuccessTier => tier >= 5;
  bool get isLargeTier => tier >= 7;
  bool get isLegendary => tier == 10;
}

/// Master registry of all catchable fish, ordered from smallest to the
/// legendary trophy fish. Uses the 10 fish art assets bundled with the game.
class FishCatalog {
  FishCatalog._();

  static final List<FishSpecies> all = [
    FishSpecies(
      tier: 1,
      name: 'Ice Minnow',
      asset: AppAssets.fish[0],
      rarity: FishRarity.common,
      basePoints: 10,
      displayScale: 0.42,
      minCps: 0,
    ),
    FishSpecies(
      tier: 2,
      name: 'Frost Sprat',
      asset: AppAssets.fish[1],
      rarity: FishRarity.common,
      basePoints: 22,
      displayScale: 0.50,
      minCps: 1.4,
    ),
    FishSpecies(
      tier: 3,
      name: 'Silver Dace',
      asset: AppAssets.fish[2],
      rarity: FishRarity.uncommon,
      basePoints: 40,
      displayScale: 0.58,
      minCps: 2.4,
    ),
    FishSpecies(
      tier: 4,
      name: 'Glacier Perch',
      asset: AppAssets.fish[3],
      rarity: FishRarity.uncommon,
      basePoints: 65,
      displayScale: 0.66,
      minCps: 3.4,
    ),
    FishSpecies(
      tier: 5,
      name: 'Blue Trout',
      asset: AppAssets.fish[4],
      rarity: FishRarity.rare,
      basePoints: 100,
      displayScale: 0.74,
      minCps: 4.4,
    ),
    FishSpecies(
      tier: 6,
      name: 'Crystal Char',
      asset: AppAssets.fish[5],
      rarity: FishRarity.rare,
      basePoints: 150,
      displayScale: 0.82,
      minCps: 5.4,
    ),
    FishSpecies(
      tier: 7,
      name: 'Arctic Salmon',
      asset: AppAssets.fish[6],
      rarity: FishRarity.epic,
      basePoints: 220,
      displayScale: 0.90,
      minCps: 6.4,
    ),
    FishSpecies(
      tier: 8,
      name: 'Frozen King Salmon',
      asset: AppAssets.fish[7],
      rarity: FishRarity.epic,
      basePoints: 320,
      displayScale: 0.98,
      minCps: 7.4,
    ),
    FishSpecies(
      tier: 9,
      name: 'Glacial Leviathan',
      asset: AppAssets.fish[8],
      rarity: FishRarity.mythic,
      basePoints: 460,
      displayScale: 1.08,
      minCps: 8.6,
    ),
    FishSpecies(
      tier: 10,
      name: 'Frozen Catch Legend',
      asset: AppAssets.fish[9],
      rarity: FishRarity.legendary,
      basePoints: 750,
      displayScale: 1.2,
      minCps: 10.0,
    ),
  ];

  static FishSpecies byTier(int tier) =>
      all[tier.clamp(1, all.length) - 1];
}
