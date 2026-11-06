import 'dart:convert';

import 'package:findit/core/content/puzzle_generator.dart';
import 'package:findit/core/domain/daily_challenge.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FNV seeds match independent unsigned 32-bit reference vectors', () {
    const expected = {
      '': 2166136261,
      'FindIt': 1575618823,
      'findit-v1-spot-1': 1686647908,
      'findit-daily-v1-2026-11-04': 2728322236,
      '2028-02-29-memory-v1': 3106610214,
      'Look closely 🌿': 3356595898,
    };
    for (final entry in expected.entries) {
      expect(stableSeed(entry.key), entry.value, reason: entry.key);
    }
  });

  test(
    'PRNG matches independent reference vectors, including high-bit seeds',
    () {
      for (final entry in <int, List<int>>{
        0: [563, 577, 494, 947, 749, 198, 764, 15, 102, 943, 835, 297],
        0xffffffff: [61, 820, 996, 915, 516, 907, 378, 735, 495, 117, 582, 55],
      }.entries) {
        final random = SeededRandom(entry.key);
        expect(List.generate(12, (_) => random.nextInt(1000)), entry.value);
      }
      expect(() => SeededRandom(0).nextInt(0), throwsArgumentError);
      expect(() => SeededRandom(0).nextInt(-1), throwsArgumentError);
    },
  );

  test('generation and shuffle are repeatable without Random or hashCode', () {
    final a = PuzzleGenerator.launchCatalog();
    final b = PuzzleGenerator.launchCatalog();
    expect(
      jsonEncode(a.map((p) => p.toJson()).toList()),
      jsonEncode(b.map((p) => p.toJson()).toList()),
    );
    final first = List.generate(52, (i) => i);
    final second = List<int>.of(first);
    SeededRandom(12345).shuffle(first);
    SeededRandom(12345).shuffle(second);
    expect(first, second);
    expect(first.toSet().length, 52);
  });

  test('a daily date has fixed puzzle IDs and seeds across runtimes', () {
    final daily = DailyChallenge.forDate(DateTime(2026, 11, 4));
    expect(daily.dayKey, '2026-11-04');
    expect(daily.puzzles.map((p) => p.id), [
      'daily-2026-11-04-hidden-1',
      'daily-2026-11-04-hidden-2',
      'daily-2026-11-04-hidden-3',
    ]);
    expect(daily.puzzles.map((p) => p.level).toSet(), {17});
    expect(daily.puzzles.every((p) => p.difficulty == 2), isTrue);
    expect(
      jsonEncode(daily.toJson()),
      jsonEncode(
        DailyChallenge.forDate(DateTime.utc(2026, 11, 4, 23)).toJson(),
      ),
    );
  });
}
