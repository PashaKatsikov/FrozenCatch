import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'angler.dart';
import 'daily_quest.dart';
import 'fish.dart';
import 'round_result.dart';

enum RoundPhase { idle, countdown, active, result }

/// Central game state: round/timer logic, scoring, persistence of records,
/// progression and daily quests. Exposed to the widget tree via [ChangeNotifier]
/// / provider so every screen reacts to the same source of truth.
class GameState extends ChangeNotifier {
  GameState() {
    _load();
  }

  static const _kBestScore = 'fc_best_score';
  static const _kTotalFish = 'fc_total_fish';
  static const _kTotalClicks = 'fc_total_clicks';
  static const _kClickRecord = 'fc_click_record';
  static const _kBestFishTier = 'fc_best_fish_tier';
  static const _kBestStreak = 'fc_best_streak';
  static const _kCurrentStreak = 'fc_current_streak';
  static const _kRoundsPlayed = 'fc_rounds_played';
  static const _kSelectedAngler = 'fc_selected_angler';
  static const _kSelectedLocation = 'fc_selected_location';
  static const _kQuestDate = 'fc_quest_date';
  static const _kQuestPrefix = 'fc_quest_';

  bool _loaded = false;
  bool get loaded => _loaded;

  SharedPreferences? _prefs;

  // ---- Lifetime / persisted stats ----
  int bestScore = 0;
  int totalFishCaught = 0;
  int totalClicksAllTime = 0;
  int clickRecord = 0;
  int bestFishTier = 0;
  int bestStreak = 0;
  int currentStreak = 0;
  int roundsPlayedTotal = 0;
  String selectedAnglerId = Angler.all.first.id;
  String selectedLocationId = LakeLocation.all.first.id;

  // ---- In-memory session score (resets each app launch) ----
  int sessionScore = 0;

  // ---- Round runtime state ----
  RoundPhase phase = RoundPhase.idle;
  int countdownValue = 3;
  double timeRemaining = 0;
  double roundDuration = 5.0;
  int clicks = 0;
  RoundResult? lastResult;
  int _lastTier = 0;

  Timer? _timer;
  final Random _random = Random();

  List<DailyQuest> quests = DailyQuest.defaultTemplate();

  Angler get selectedAngler => Angler.byId(selectedAnglerId);
  LakeLocation get selectedLocation => LakeLocation.byId(selectedLocationId);

  int get level => (roundsPlayedTotal / 8).floor().clamp(0, 10);
  double get difficultyMultiplier => 1.0 + level * 0.06;

  bool isAnglerUnlocked(Angler a) => totalFishCaught >= a.unlockRequirement;
  bool isLocationUnlocked(LakeLocation l) => bestScore >= l.unlockScore;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    bestScore = prefs.getInt(_kBestScore) ?? 0;
    totalFishCaught = prefs.getInt(_kTotalFish) ?? 0;
    totalClicksAllTime = prefs.getInt(_kTotalClicks) ?? 0;
    clickRecord = prefs.getInt(_kClickRecord) ?? 0;
    bestFishTier = prefs.getInt(_kBestFishTier) ?? 0;
    bestStreak = prefs.getInt(_kBestStreak) ?? 0;
    currentStreak = prefs.getInt(_kCurrentStreak) ?? 0;
    roundsPlayedTotal = prefs.getInt(_kRoundsPlayed) ?? 0;
    selectedAnglerId = prefs.getString(_kSelectedAngler) ?? Angler.all.first.id;
    selectedLocationId =
        prefs.getString(_kSelectedLocation) ?? LakeLocation.all.first.id;

    _restoreOrResetQuests(prefs);

    _loaded = true;
    notifyListeners();
  }

  void _restoreOrResetQuests(SharedPreferences prefs) {
    final today = _todayKey();
    final storedDate = prefs.getString(_kQuestDate);
    quests = DailyQuest.defaultTemplate();
    if (storedDate == today) {
      for (final q in quests) {
        q.progress = prefs.getInt('$_kQuestPrefix${q.id}_progress') ?? 0;
        q.claimed = prefs.getBool('$_kQuestPrefix${q.id}_claimed') ?? false;
      }
    } else {
      prefs.setString(_kQuestDate, today);
      for (final q in quests) {
        prefs.setInt('$_kQuestPrefix${q.id}_progress', 0);
        prefs.setBool('$_kQuestPrefix${q.id}_claimed', false);
      }
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _persistQuests() async {
    final prefs = _prefs;
    if (prefs == null) return;
    for (final q in quests) {
      await prefs.setInt('$_kQuestPrefix${q.id}_progress', q.progress);
      await prefs.setBool('$_kQuestPrefix${q.id}_claimed', q.claimed);
    }
  }

  Future<void> claimQuest(String id) async {
    final quest = quests.firstWhere((q) => q.id == id);
    if (!quest.isComplete || quest.claimed) return;
    quest.claimed = true;
    sessionScore += quest.reward;
    if (sessionScore > bestScore) {
      bestScore = sessionScore;
      await _prefs?.setInt(_kBestScore, bestScore);
    }
    await _persistQuests();
    notifyListeners();
  }

  // ---------------- Round lifecycle ----------------

  void beginCountdown() {
    if (phase != RoundPhase.idle && phase != RoundPhase.result) return;
    phase = RoundPhase.countdown;
    countdownValue = 3;
    lastResult = null;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      countdownValue--;
      if (countdownValue <= 0) {
        t.cancel();
        _startRound();
      } else {
        notifyListeners();
      }
    });
  }

  void _startRound() {
    roundDuration = (5.0 - level * 0.15).clamp(3.2, 5.0);
    timeRemaining = roundDuration;
    clicks = 0;
    phase = RoundPhase.active;
    notifyListeners();

    const tick = Duration(milliseconds: 30);
    _timer?.cancel();
    _timer = Timer.periodic(tick, (t) {
      timeRemaining -= tick.inMilliseconds / 1000.0;
      if (timeRemaining <= 0) {
        timeRemaining = 0;
        t.cancel();
        _endRound();
      }
      notifyListeners();
    });
  }

  void registerTap() {
    if (phase != RoundPhase.active) return;
    clicks++;
    notifyListeners();
  }

  void _endRound() {
    final cps = clicks / roundDuration;
    final effectiveCps = cps / difficultyMultiplier;

    int tier = 1;
    for (final species in FishCatalog.all) {
      if (effectiveCps >= species.minCps) {
        tier = species.tier;
      }
    }

    if (tier == 10) {
      final legendaryThreshold = FishCatalog.byTier(10).minCps;
      if (effectiveCps < legendaryThreshold + 2.0) {
        final chance = (0.35 + currentStreak * 0.03).clamp(0.0, 0.85);
        if (_random.nextDouble() > chance) {
          tier = 9;
        }
      }
    }

    final species = FishCatalog.byTier(tier);

    final bool isNewClickRecord = clicks > clickRecord;
    if (isNewClickRecord) {
      clickRecord = clicks;
      unawaited(_prefs?.setInt(_kClickRecord, clickRecord));
    }

    if (species.isSuccessTier) {
      currentStreak++;
    } else {
      currentStreak = 0;
    }
    bestStreak = max(bestStreak, currentStreak);

    final basePoints = species.basePoints;
    final clickBonus = clicks * 2;
    final streakBonus = currentStreak >= 3 ? min(currentStreak * 15, 500) : 0;
    final rareBonus = species.isLegendary
        ? 300
        : (species.rarity == FishRarity.mythic ? 120 : 0);
    final comboBonus = (_lastTier >= 7 && species.tier >= 7) ? 150 : 0;
    final recordBonus = isNewClickRecord ? 250 : 0;

    final total = basePoints +
        clickBonus +
        streakBonus +
        rareBonus +
        comboBonus +
        recordBonus;

    sessionScore += total;
    final bool isNewBestScore = sessionScore > bestScore;
    if (isNewBestScore) {
      bestScore = sessionScore;
      unawaited(_prefs?.setInt(_kBestScore, bestScore));
    }

    totalFishCaught++;
    totalClicksAllTime += clicks;
    roundsPlayedTotal++;
    if (species.tier > bestFishTier) bestFishTier = species.tier;
    _lastTier = species.tier;

    unawaited(_persistStats());

    _updateQuests(
      species: species,
      clicksThisRound: clicks,
      isNewClickRecord: isNewClickRecord,
    );

    lastResult = RoundResult(
      fish: species,
      clicks: clicks,
      cps: cps,
      basePoints: basePoints,
      clickBonus: clickBonus,
      streakBonus: streakBonus,
      rareBonus: rareBonus,
      comboBonus: comboBonus,
      recordBonus: recordBonus,
      totalPoints: total,
      isNewClickRecord: isNewClickRecord,
      isNewBestScore: isNewBestScore,
      streakAfter: currentStreak,
    );
    phase = RoundPhase.result;
    notifyListeners();
  }

  void _updateQuests({
    required FishSpecies species,
    required int clicksThisRound,
    required bool isNewClickRecord,
  }) {
    for (final q in quests) {
      switch (q.type) {
        case QuestType.catchFish:
          q.progress = min(q.progress + 1, q.target);
          break;
        case QuestType.totalClicks:
          q.progress = min(q.progress + clicksThisRound, q.target);
          break;
        case QuestType.catchLarge:
          if (species.isLargeTier) {
            q.progress = min(q.progress + 1, q.target);
          }
          break;
        case QuestType.catchLegendary:
          if (species.isLegendary) {
            q.progress = min(q.progress + 1, q.target);
          }
          break;
        case QuestType.playRounds:
          q.progress = min(q.progress + 1, q.target);
          break;
        case QuestType.newClickRecord:
          if (isNewClickRecord) q.progress = q.target;
          break;
      }
    }
    unawaited(_persistQuests());
  }

  Future<void> _persistStats() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setInt(_kTotalFish, totalFishCaught);
    await prefs.setInt(_kTotalClicks, totalClicksAllTime);
    await prefs.setInt(_kBestFishTier, bestFishTier);
    await prefs.setInt(_kBestStreak, bestStreak);
    await prefs.setInt(_kCurrentStreak, currentStreak);
    await prefs.setInt(_kRoundsPlayed, roundsPlayedTotal);
  }

  void acknowledgeResult() {
    phase = RoundPhase.idle;
    notifyListeners();
  }

  /// Called when the player navigates away mid-round: stops any pending
  /// timers and quietly resets to idle without recording a catch.
  void cancelRound() {
    if (phase == RoundPhase.active || phase == RoundPhase.countdown) {
      _timer?.cancel();
      phase = RoundPhase.idle;
      clicks = 0;
      notifyListeners();
    }
  }

  Future<void> selectAngler(Angler a) async {
    if (!isAnglerUnlocked(a)) return;
    selectedAnglerId = a.id;
    await _prefs?.setString(_kSelectedAngler, a.id);
    notifyListeners();
  }

  Future<void> selectLocation(LakeLocation l) async {
    if (!isLocationUnlocked(l)) return;
    selectedLocationId = l.id;
    await _prefs?.setString(_kSelectedLocation, l.id);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
