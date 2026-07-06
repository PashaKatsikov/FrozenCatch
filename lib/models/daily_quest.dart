enum QuestType {
  catchFish,
  totalClicks,
  catchLarge,
  catchLegendary,
  playRounds,
  newClickRecord,
}

class DailyQuest {
  DailyQuest({
    required this.id,
    required this.type,
    required this.title,
    required this.target,
    required this.reward,
    this.progress = 0,
    this.claimed = false,
  });

  final String id;
  final QuestType type;
  final String title;
  final int target;
  final int reward;
  int progress;
  bool claimed;

  bool get isComplete => progress >= target;

  double get progressRatio => target == 0 ? 0 : (progress / target).clamp(0, 1).toDouble();

  static List<DailyQuest> defaultTemplate() => [
        DailyQuest(
          id: 'catch_30_fish',
          type: QuestType.catchFish,
          title: 'Catch 30 fish',
          target: 30,
          reward: 300,
        ),
        DailyQuest(
          id: 'click_5000',
          type: QuestType.totalClicks,
          title: 'Make 5000 taps',
          target: 5000,
          reward: 500,
        ),
        DailyQuest(
          id: 'catch_10_large',
          type: QuestType.catchLarge,
          title: 'Catch 10 large fish',
          target: 10,
          reward: 400,
        ),
        DailyQuest(
          id: 'catch_3_legendary',
          type: QuestType.catchLegendary,
          title: 'Catch 3 legendary fish',
          target: 3,
          reward: 1000,
        ),
        DailyQuest(
          id: 'play_10_rounds',
          type: QuestType.playRounds,
          title: 'Play 10 rounds',
          target: 10,
          reward: 200,
        ),
        DailyQuest(
          id: 'new_click_record',
          type: QuestType.newClickRecord,
          title: 'Set a new tap record',
          target: 1,
          reward: 350,
        ),
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'progress': progress,
        'claimed': claimed,
      };
}
