import 'dart:convert';
import 'dart:io';

import 'package:findit/core/content/hidden_catalog.dart';
import 'package:findit/core/content/puzzle_validator.dart';
import 'package:findit/core/domain/puzzle.dart';

void main() {
  final puzzles = HiddenCatalog.launchCatalog();
  PuzzleValidator.validateCatalog(puzzles);
  for (final directory in [
    'assets/content',
    'assets/scenes',
    'assets/branding',
    'assets/audio',
    'assets/legal',
    'assets/fonts',
    'verification/screenshots',
  ]) {
    Directory(directory).createSync(recursive: true);
  }
  File('assets/content/catalog.json').writeAsStringSync(
    jsonEncode({
      'schemaVersion': 1,
      'contentVersion': 1,
      'packId': 'findit-hidden-originals-v1',
      'license': 'FindIt original vector artwork reused locally; three enhanced compositions created for FindIt - Search Hidden Objects. See assets/legal/original-assets.txt.',
      'puzzles': puzzles.map((p) => p.toJson()).toList(),
    }),
  );
  File('assets/content/validation.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'count': puzzles.length,
      'checks': [
        'unique IDs',
        'answer correctness',
        'hidden-object-only content',
        'all listed targets are present',
        'non-overlapping regions',
        'minimum target dimensions',
        'safe asset references',
        'bounded data',
      ],
      'byMode': {
        for (final mode in [GameMode.hidden])
          mode.slug: puzzles.where((p) => p.mode == mode).length,
      },
      'pixelValidation': 'Run flutter test tool/export_hidden_art_test.dart',
      'humanReview': 'Original vector art. Independent editorial/art review remains a release gate.',
    }),
  );
  stdout.writeln(
    'Validated ${puzzles.length} hidden-object levels, including three enhanced featured scenes.',
  );
}
