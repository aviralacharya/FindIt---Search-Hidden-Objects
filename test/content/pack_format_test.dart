import 'dart:convert';
import 'dart:io';

import 'package:findit/core/content/pack_format.dart';
import 'package:findit/core/content/puzzle_generator.dart';
import 'package:findit/core/content/puzzle_validator.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/pack_schema.dart';

Map<String, dynamic> _pack() => {
  'schemaVersion': 1,
  'contentVersion': 1,
  'packId': 'codec-fixture',
  'title': 'A little codec fixture',
  'license': 'Original generated test artwork.',
  'puzzles': [
    PuzzleGenerator.generate(
      GameMode.odd,
      seed: 2912345,
      level: 61,
      id: 'codec-odd',
    ).toJson(),
  ],
};

void main() {
  test('pure decoding round-trips canonical packs and bounds metadata', () {
    final source = _pack();
    final decoded = PackFormat.decode(source);
    expect(decoded.toJson(), source);
    expect(
      () => PackFormat.decode({...source, 'schemaVersion': 2}),
      throwsFormatException,
    );
    expect(
      () => PackFormat.decode({...source, 'license': ' '}),
      throwsFormatException,
    );
    expect(
      () => PackFormat.decode({...source, 'title': 'x' * 121}),
      throwsFormatException,
    );
    expect(
      () => PackFormat.decode(source, installedPackIds: ['codec-fixture']),
      throwsFormatException,
    );
    expect(
      () => PackFormat.decode(source, existingPuzzles: decoded.puzzles),
      throwsFormatException,
    );
  });

  test(
    'unknown properties and remote image paths are discarded recursively',
    () {
      final source = _pack()..['trackingUrl'] = 'https://tracker.invalid/event';
      final puzzle = (source['puzzles'] as List).first as Map<String, dynamic>;
      puzzle['imageA'] = 'https://tracker.invalid/image.png';
      puzzle['metadata'] = {'untrusted': 'script'};
      final round = (puzzle['rounds'] as List).first as Map<String, dynamic>;
      round['script'] = 'untrusted';
      final canonical = jsonEncode(PackFormat.decode(source).toJson());
      expect(canonical, isNot(contains('tracker')));
      expect(canonical, isNot(contains('untrusted')));
      expect(canonical, isNot(contains('imageA')));
    },
  );

  test('pure decoding rejects reserved daily IDs and relabeled repeats', () {
    final source = _pack();
    final puzzle = (source['puzzles'] as List).first as Map<String, dynamic>;
    puzzle['id'] = 'daily-unauthorized';
    expect(() => PackFormat.decode(source), throwsFormatException);
    puzzle['id'] = 'codec-second';
    final existing = PackFormat.decode(_pack()).puzzles;
    expect(
      () => PackFormat.decode(source, existingPuzzles: existing),
      throwsFormatException,
    );
    source['puzzles'] = [
      puzzle,
      {...puzzle, 'id': 'codec-third'},
    ];
    expect(
      () => PackFormat.decode(source),
      throwsA(isA<ContentValidationException>()),
    );
  });

  test(
    'publisher example contains three hidden scenes without launch repeats',
    () {
      final base = PackFormat.decode(
        jsonDecode(File('assets/content/catalog.json').readAsStringSync())
            as Map<String, dynamic>,
        bundled: true,
      );
      final example = PackFormat.decode(
        jsonDecode(File('config/packs/example-v1.json').readAsStringSync())
            as Map<String, dynamic>,
        existingPuzzles: base.puzzles,
      );
      expect(example.puzzles.map((p) => p.mode).toSet(), {GameMode.hidden});
      expect(
        example.puzzles.every((p) => p.imageA == null && p.imageB == null),
        isTrue,
      );
      expect(example.puzzles, hasLength(3));
      expect(example.puzzles.map((p) => p.level), [61, 62, 63]);
      expect(example.puzzles.every((p) => p.answerIds.length >= 5), isTrue);
    },
  );

  test('generated schema matches the checked-in publisher schema', () {
    final saved = jsonDecode(
      File('config/packs/pack-v1.schema.json').readAsStringSync(),
    );
    expect(saved, packSchema());
    expect(
      (packSchema()['properties'] as Map)['puzzles']['items'][r'$ref'],
      r'#/$defs/puzzle',
    );
    final puzzleSchema = (packSchema()[r'$defs'] as Map)['puzzle'] as Map;
    expect(puzzleSchema['properties']['mode'], {'const': 'hidden'});
    expect(puzzleSchema['required'], contains('scene'));
    expect(puzzleSchema['properties']['rounds']['maxItems'], 0);
  });
}
