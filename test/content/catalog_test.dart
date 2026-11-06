import 'dart:convert';

import 'package:findit/core/content/hidden_catalog.dart';
import 'package:findit/core/content/puzzle_validator.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/puzzles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = HiddenCatalog.launchCatalog();
  test('60 unique hidden-object levels with complete progression', () {
    expect(catalog.length, 60);
    expect(catalog.map((p) => p.id).toSet().length, 60);
    expect(catalog.map(PuzzleValidator.fingerprint).toSet().length, 60);
    expect(catalog.map((p) => p.mode).toSet(), {GameMode.hidden});
    expect(() => PuzzleValidator.validateCatalog(catalog), returnsNormally);
    for (final mode in [GameMode.hidden]) {
      final levels = catalog.where((p) => p.mode == mode).toList();
      expect(levels.length, 60);
      expect(levels.map((p) => p.level), List.generate(60, (i) => i + 1));
      expect(levels.map((p) => p.difficulty).toSet(), {1, 2, 3, 4, 5});
    }
  });

  test(
    'bundled catalog matches deterministic generation and all 60 scenes exist',
    () async {
      final json = jsonDecode(
        await rootBundle.loadString('assets/content/catalog.json'),
      ) as Map<String, dynamic>;
      expect(json['schemaVersion'], 1);
      expect(json['puzzles'], catalog.map((p) => p.toJson()).toList());
      var scenes = 0;
      for (final puzzle in catalog) {
        for (final path in [puzzle.imageA, puzzle.imageB].whereType<String>()) {
          expect(
            (await rootBundle.load(path)).lengthInBytes,
            greaterThan(1000),
            reason: path,
          );
          scenes++;
        }
      }
      expect(scenes, 60);
    },
  );

  test('duplicate IDs and relabeled puzzle content are rejected', () {
    expect(
      () => PuzzleValidator.validateCatalog([catalog.first, catalog.first]),
      throwsA(isA<ContentValidationException>()),
    );
    final relabeled = changePuzzle(catalog.first, {
      'id': 'renamed-puzzle',
      'title': 'A different label',
      'seed': 99,
      'level': 900,
    });
    expect(
      PuzzleValidator.fingerprint(relabeled),
      PuzzleValidator.fingerprint(catalog.first),
    );
    expect(
      () => PuzzleValidator.validateCatalog([catalog.first, relabeled]),
      throwsA(isA<ContentValidationException>()),
    );
  });

  test(
    'scene fingerprints ignore object IDs and harmless draw-order changes',
    () {
      final puzzle = fixture(GameMode.differences);
      final json = deepJson(puzzle.toJson());
      final scene = json['scene'] as Map<String, dynamic>;
      final objects = (scene['objects'] as List).cast<Map<String, dynamic>>();
      final renamed = <String, String>{
        for (var i = 0; i < objects.length; i++)
          objects[i]['id'] as String: 'new-object-$i',
      };
      for (final object in objects) {
        object['id'] = renamed[object['id']];
      }
      scene['objects'] = objects.reversed.toList();
      json['answerIds'] = (json['answerIds'] as List)
          .map((id) => renamed[id])
          .toList();
      expect(
        PuzzleValidator.fingerprint(Puzzle.fromJson(json)),
        PuzzleValidator.fingerprint(puzzle),
      );
    },
  );

  test('invalid metadata and unsafe paths are rejected', () {
    final puzzle = fixture(GameMode.hidden);
    for (final changes in [
      {'id': '../../evil'},
      {'difficulty': 6},
      {'reward': -1},
      {'level': 0},
      {'seed': -1},
      {'generatorVersion': 2},
      {'validation': 'unvalidated'},
      {'timeLimitSeconds': 99999},
      {'imageA': 'https://example.com/tracker.png'},
    ]) {
      expect(
        PuzzleValidator.validate(changePuzzle(puzzle, changes)),
        isNotEmpty,
        reason: changes.toString(),
      );
    }
  });

  test('unambiguous odd, quick, and five-change scene rules are enforced', () {
    final odd = deepJson(fixture(GameMode.odd).toJson());
    final oddRound = (odd['rounds'] as List).first as Map<String, dynamic>;
    oddRound['tiles'] = List.generate(
      (oddRound['tiles'] as List).length,
      (_) => {'kind': 'apple', 'color': 0, 'variant': 0},
    );
    expect(PuzzleValidator.validate(Puzzle.fromJson(odd)), isNotEmpty);
    final quick = deepJson(fixture(GameMode.quick).toJson());
    final quickRound = (quick['rounds'] as List).first as Map<String, dynamic>;
    quickRound['tiles'] = List.generate(
      (quickRound['tiles'] as List).length,
      (_) => quickRound['target'],
    );
    expect(PuzzleValidator.validate(Puzzle.fromJson(quick)), isNotEmpty);
    final spot = fixture(GameMode.differences);
    expect(
      PuzzleValidator.validate(
        changePuzzle(spot, {'answerIds': spot.answerIds.take(4).toList()}),
      ),
      isNotEmpty,
    );
  });
}
