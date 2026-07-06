import 'fish.dart';

/// Snapshot of everything that happened at the end of a single fishing round,
/// used to render the result popup and score breakdown.
class RoundResult {
  const RoundResult({
    required this.fish,
    required this.clicks,
    required this.cps,
    required this.basePoints,
    required this.clickBonus,
    required this.streakBonus,
    required this.rareBonus,
    required this.comboBonus,
    required this.recordBonus,
    required this.totalPoints,
    required this.isNewClickRecord,
    required this.isNewBestScore,
    required this.streakAfter,
  });

  final FishSpecies fish;
  final int clicks;
  final double cps;
  final int basePoints;
  final int clickBonus;
  final int streakBonus;
  final int rareBonus;
  final int comboBonus;
  final int recordBonus;
  final int totalPoints;
  final bool isNewClickRecord;
  final bool isNewBestScore;
  final int streakAfter;
}
