import '../content/featured_scenes.dart';
import 'puzzle.dart';

String localDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
    throw FormatException('Invalid day key', key);
  }
  final parts = key.split('-').map(int.parse).toList();
  if (parts.length != 3) throw FormatException('Invalid day key', key);
  // UTC civil dates avoid 23/25-hour DST days affecting streak arithmetic.
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (localDayKey(date) != key) {
    throw FormatException('Invalid civil date', key);
  }
  return date;
}

class DailyChallenge {
  const DailyChallenge({
    required this.dayKey,
    required this.puzzles,
    this.completedIds = const {},
    this.bonusClaimed = false,
  });
  final String dayKey;
  final List<Puzzle> puzzles;
  final Set<String> completedIds;
  final bool bonusClaimed;
  bool get completed => puzzles.every((p) => completedIds.contains(p.id));

  DailyChallenge complete(String id, {bool? bonusClaimed}) => DailyChallenge(
    dayKey: dayKey,
    puzzles: puzzles,
    completedIds: {...completedIds, id},
    bonusClaimed: bonusClaimed ?? this.bonusClaimed,
  );

  Map<String, dynamic> toJson() => {
    'dayKey': dayKey,
    'puzzles': puzzles.map((p) => p.toJson()).toList(),
    'completedIds': completedIds.toList(),
    'bonusClaimed': bonusClaimed,
  };
  factory DailyChallenge.fromJson(Map<String, dynamic> j) => DailyChallenge(
    dayKey: j['dayKey'] as String,
    puzzles: (j['puzzles'] as List)
        .map((p) => Puzzle.fromJson(p as Map<String, dynamic>))
        .toList(),
    completedIds: (j['completedIds'] as List).cast<String>().toSet(),
    bonusClaimed: j['bonusClaimed'] as bool,
  );

  static DailyChallenge forDate(DateTime date) {
    final key = localDayKey(date);
    final daySeed = stableSeed('findit-daily-v1-$key');
    final difficulty = date.weekday >= 6 ? 4 : 2 + daySeed % 2;
    return DailyChallenge(
      dayKey: key,
      puzzles: [
        for (var scene = 1; scene <= 3; scene++)
          FeaturedScenes.create(
            scene,
            seed: stableSeed('$key-hidden-$scene-v1'),
            level: 1 + daySeed % 60,
            id: 'daily-$key-hidden-$scene',
            difficulty: difficulty,
            bundledImage: false,
          ),
      ],
    );
  }

  static int streak(Iterable<DailyChallenge> history, DateTime now) {
    final days = history
        .where((d) => d.bonusClaimed)
        .map((d) => d.dayKey)
        .toSet();
    if (days.isEmpty) return 0;
    var current = parseDayKey(localDayKey(now));
    if (!days.contains(localDayKey(current))) {
      current = current.subtract(const Duration(days: 1));
    }
    var total = 0;
    while (days.contains(localDayKey(current))) {
      total++;
      current = current.subtract(const Duration(days: 1));
    }
    return total;
  }

  static int bestStreak(Iterable<DailyChallenge> history) {
    final keys =
        history
            .where((d) => d.bonusClaimed)
            .map((d) => d.dayKey)
            .toSet()
            .toList()
          ..sort();
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final key in keys) {
      final date = parseDayKey(key);
      run = previous != null && date.difference(previous).inDays == 1
          ? run + 1
          : 1;
      if (run > best) best = run;
      previous = date;
    }
    return best;
  }
}
