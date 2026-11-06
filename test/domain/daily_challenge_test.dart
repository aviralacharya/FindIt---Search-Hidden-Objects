import 'package:findit/core/content/puzzle_validator.dart';
import 'package:findit/core/domain/daily_challenge.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

DailyChallenge claimed(DateTime date) {
  final daily = DailyChallenge.forDate(date);
  return DailyChallenge(
    dayKey: daily.dayKey,
    puzzles: daily.puzzles,
    completedIds: daily.puzzles.map((p) => p.id).toSet(),
    bonusClaimed: true,
  );
}

void main() {
  test(
    'strict civil-date parsing includes leap days and rejects normalization',
    () {
      expect(parseDayKey('2028-02-29'), DateTime.utc(2028, 2, 29));
      expect(parseDayKey('2026-12-31'), DateTime.utc(2026, 12, 31));
      for (final value in [
        '2026-02-29',
        '2026-04-31',
        '2026-13-01',
        '2026-00-01',
        '2026-11-00',
        '2026-1-04',
        '26-11-04',
        '2026-11-4',
        '2026-11-04T00:00:00Z',
        ' 2026-11-04',
        '',
      ]) {
        expect(() => parseDayKey(value), throwsFormatException, reason: value);
      }
    },
  );

  test('366 leap-year sets are valid, unique, and hidden-object-only', () {
    final fingerprints = <String>{};
    for (var i = 0; i < 366; i++) {
      final date = DateTime.utc(2028, 1, 1).add(Duration(days: i));
      final daily = DailyChallenge.forDate(date);
      expect(daily.puzzles.map((p) => p.mode).toSet(), {GameMode.hidden});
      expect(daily.completed, isFalse);
      expect(daily.bonusClaimed, isFalse);
      expect(
        () => PuzzleValidator.validateCatalog(daily.puzzles),
        returnsNormally,
      );
      for (final puzzle in daily.puzzles) {
        expect(
          fingerprints.add(PuzzleValidator.fingerprint(puzzle)),
          isTrue,
          reason: puzzle.id,
        );
      }
    }
    expect(fingerprints.length, 1098);
  });

  test('completion is immutable, date-specific, and safely round-trips', () {
    final initial = DailyChallenge.forDate(DateTime(2026, 11, 4));
    var daily = initial;
    for (final puzzle in daily.puzzles) {
      daily = daily.complete(puzzle.id);
    }
    expect(initial.completedIds, isEmpty);
    expect(daily.completed, isTrue);
    expect(daily.bonusClaimed, isFalse);
    daily = daily.complete(daily.puzzles.first.id, bonusClaimed: true);
    expect(daily.completedIds.length, 3);
    expect(DailyChallenge.fromJson(daily.toJson()).toJson(), daily.toJson());
  });

  test('current streak retains yesterday, ignores future days, and breaks at a gap', () {
    final now = DateTime(2026, 11, 4, 0, 1);
    final history = [
      claimed(DateTime(2026, 11, 2)),
      claimed(DateTime(2026, 11, 3)),
      claimed(DateTime(2026, 11, 5)),
    ];
    expect(DailyChallenge.streak(history, now), 2);
    history.add(claimed(DateTime(2026, 11, 4)));
    expect(DailyChallenge.streak(history, now), 3);
    expect(DailyChallenge.streak(history, DateTime(2026, 11, 8)), 0);
    expect(DailyChallenge.streak([], now), 0);
  });

  test(
    'streak arithmetic handles leap, year, and DST-adjacent civil dates',
    () {
      final leap = [
        for (var i = 0; i < 4; i++) claimed(DateTime(2028, 2, 27 + i)),
      ];
      expect(DailyChallenge.streak(leap, DateTime(2028, 3, 1)), 4);
      expect(DailyChallenge.bestStreak([...leap.reversed, leap.first]), 4);
      final year = [
        for (var i = 0; i < 7; i++) claimed(DateTime(2026, 12, 28 + i)),
      ];
      expect(DailyChallenge.streak(year, DateTime(2027, 1, 3)), 7);
      final spring = [
        for (var i = 0; i < 5; i++) claimed(DateTime(2026, 3, 6 + i)),
      ];
      expect(DailyChallenge.bestStreak(spring), 5);
      final fall = [
        for (var i = 0; i < 5; i++) claimed(DateTime(2026, 10, 30 + i)),
      ];
      expect(DailyChallenge.streak(fall, DateTime(2026, 11, 3)), 5);
    },
  );

  test('incomplete sets never contribute to a streak', () {
    final yesterday = DailyChallenge.forDate(DateTime(2026, 11, 3));
    final today = claimed(DateTime(2026, 11, 4));
    expect(DailyChallenge.streak([yesterday, today], DateTime(2026, 11, 4)), 1);
    expect(DailyChallenge.bestStreak([yesterday, today]), 1);
  });
}
