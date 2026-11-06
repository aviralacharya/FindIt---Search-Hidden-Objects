import '../config/app_config.dart';
import 'daily_challenge.dart';
import 'game_engine.dart';
import 'puzzle.dart';

class LevelRecord {
  const LevelRecord({
    required this.id,
    required this.mode,
    required this.stars,
    required this.bestScore,
    required this.bestElapsedMs,
    required this.accuracy,
    required this.bestCombo,
    required this.plays,
  });
  final String id;
  final GameMode mode;
  final int stars;
  final int bestScore;
  final int bestElapsedMs;
  final double accuracy;
  final int bestCombo;
  final int plays;
  bool get daily => id.startsWith('daily-');
}

class SavedGame {
  const SavedGame(this.engineJson, this.dailyKey);
  final Map<String, dynamic> engineJson;
  final String? dailyKey;
  String get puzzleId =>
      (engineJson['puzzle'] as Map<String, dynamic>)['id'] as String;
  GameEngine restore() => GameEngine.restore(engineJson);
  Map<String, dynamic> toJson() => {'engine': engineJson, 'dailyKey': dailyKey};
  factory SavedGame.fromJson(Map<String, dynamic> j) =>
      SavedGame(j['engine'] as Map<String, dynamic>, j['dailyKey'] as String?);
}

class PlayerProgress {
  const PlayerProgress({
    this.coins = AppConfig.initialCoins,
    this.earnedCoins = 0,
    this.records = const {},
    this.daily = const {},
    this.savedGame,
    this.savedGameError,
  });
  final int coins;
  final int earnedCoins;
  final Map<String, LevelRecord> records;
  final Map<String, DailyChallenge> daily;
  final SavedGame? savedGame;
  final String? savedGameError;
  Iterable<LevelRecord> get levels => records.values.where((r) => !r.daily);
  int get completedLevels => levels.length;
  int get totalStars => levels.fold(0, (total, record) => total + record.stars);
  int completedFor(GameMode mode) => levels.where((r) => r.mode == mode).length;
  int starsFor(GameMode mode) =>
      levels.where((r) => r.mode == mode).fold(0, (t, r) => t + r.stars);
  int currentStreak(DateTime now) => DailyChallenge.streak(daily.values, now);
  int get bestStreak => DailyChallenge.bestStreak(daily.values);

  List<Achievement> get achievements => [
    Achievement(
      'first',
      'First discovery',
      'Complete your first puzzle.',
      records.isNotEmpty,
      records.length,
      1,
    ),
    Achievement(
      'curious',
      'Curious mind',
      'Complete 25 different levels.',
      completedLevels >= 25,
      completedLevels,
      25,
    ),
    Achievement(
      'sharp',
      'Eagle eyes',
      'Earn three stars on 10 levels.',
      levels.where((r) => r.stars == 3).length >= 10,
      levels.where((r) => r.stars == 3).length,
      10,
    ),
    Achievement(
      'explorer',
      'Little explorer',
      'Discover all three featured scenes.',
      ['hidden-001', 'hidden-002', 'hidden-003'].every(records.containsKey),
      [
        'hidden-001',
        'hidden-002',
        'hidden-003',
      ].where(records.containsKey).length,
      3,
    ),
    Achievement(
      'seeker',
      'Treasure hunter',
      'Complete 10 hidden-object levels.',
      completedFor(GameMode.hidden) >= 10,
      completedFor(GameMode.hidden),
      10,
    ),
    Achievement(
      'combo',
      'In the flow',
      'Reach a combo of 10.',
      records.values.any((r) => r.bestCombo >= 10),
      records.values.fold(0, (v, r) => r.bestCombo > v ? r.bestCombo : v),
      10,
    ),
    Achievement(
      'streak',
      'A daily delight',
      'Build a 7-day streak.',
      bestStreak >= 7,
      bestStreak,
      7,
    ),
    Achievement(
      'collector',
      'Treasure keeper',
      'Earn 1,000 coins through hidden-object searches.',
      earnedCoins >= 1000,
      earnedCoins,
      1000,
    ),
  ];
}

class Achievement {
  const Achievement(
    this.id,
    this.title,
    this.description,
    this.unlocked,
    this.current,
    this.goal,
  );
  final String id;
  final String title;
  final String description;
  final bool unlocked;
  final int current;
  final int goal;
  double get progress => (current / goal).clamp(0, 1);
}

class CompletionReceipt {
  const CompletionReceipt({
    required this.coins,
    required this.dailyBonus,
    required this.stars,
    required this.firstCompletion,
    required this.score,
  });
  final int coins;
  final int dailyBonus;
  final int stars;
  final bool firstCompletion;
  final int score;
  Map<String, dynamic> toJson() => {
    'coins': coins,
    'dailyBonus': dailyBonus,
    'stars': stars,
    'firstCompletion': firstCompletion,
    'score': score,
  };
  factory CompletionReceipt.fromJson(Map<String, dynamic> j) =>
      CompletionReceipt(
        coins: j['coins'] as int,
        dailyBonus: j['dailyBonus'] as int,
        stars: j['stars'] as int,
        firstCompletion: j['firstCompletion'] as bool,
        score: j['score'] as int,
      );
}
