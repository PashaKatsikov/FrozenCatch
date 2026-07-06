import '../theme/app_assets.dart';

/// A selectable, unlockable angler (character) shown seated by the ice hole.
class Angler {
  const Angler({
    required this.id,
    required this.name,
    required this.seatedAsset,
    required this.portraitAsset,
    required this.unlockRequirement,
  });

  final String id;
  final String name;
  final String seatedAsset;
  final String portraitAsset;

  /// Total fish that must be caught (lifetime) to unlock this angler.
  final int unlockRequirement;

  static const List<Angler> all = [
    Angler(
      id: 'fisherman',
      name: 'Jack the Angler',
      seatedAsset: AppAssets.fishermanSeated,
      portraitAsset: AppAssets.fishermanStanding,
      unlockRequirement: 0,
    ),
    Angler(
      id: 'aged',
      name: 'Old Man Frost',
      seatedAsset: AppAssets.fishermanAgedSeated,
      portraitAsset: AppAssets.fishermanAgedStanding,
      unlockRequirement: 40,
    ),
    Angler(
      id: 'female',
      name: 'Elsa Snowline',
      seatedAsset: AppAssets.fisherFemaleSeated,
      portraitAsset: AppAssets.fisherFemaleStanding,
      unlockRequirement: 100,
    ),
  ];

  static Angler byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => all.first);
}

/// A selectable, unlockable winter lake location used as the game background.
class LakeLocation {
  const LakeLocation({
    required this.id,
    required this.name,
    required this.asset,
    required this.unlockScore,
  });

  final String id;
  final String name;
  final String asset;

  /// Best score required to unlock this location.
  final int unlockScore;

  static const List<LakeLocation> all = [
    LakeLocation(
      id: 'crystal_bay',
      name: 'Crystal Bay',
      asset: AppAssets.bgAurora,
      unlockScore: 0,
    ),
    LakeLocation(
      id: 'aurora_lake',
      name: 'Aurora Lake',
      asset: AppAssets.bgNorthernLights,
      unlockScore: 1500,
    ),
    LakeLocation(
      id: 'snow_valley',
      name: 'Snow Valley',
      asset: AppAssets.bgSnowValley,
      unlockScore: 4000,
    ),
  ];

  static LakeLocation byId(String id) =>
      all.firstWhere((l) => l.id == id, orElse: () => all.first);
}
