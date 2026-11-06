import 'dart:convert';

import '../domain/puzzle.dart';
import 'puzzle_generator.dart';

class ContentValidationException implements Exception {
  const ContentValidationException(this.errors);
  final List<String> errors;
  @override
  String toString() => 'Invalid puzzle content: ${errors.join('; ')}';
}

abstract final class PuzzleValidator {
  /// Ignore labels, IDs, rewards, and seeds when checking for padded repeats.
  /// Target selections and visual mutations remain part of the fingerprint.
  static String fingerprint(Puzzle puzzle) {
    final scene = puzzle.scene;
    final objects =
        (scene?.objects.map((o) {
                final json = o.toJson()..remove('id');
                return jsonEncode(json);
              }).toList() ??
              <String>[])
          ..sort();
    final targets =
        (scene?.objects.where((o) => puzzle.answerIds.contains(o.id)).map((o) {
                final json = o.toJson()..remove('id');
                return jsonEncode(json);
              }).toList() ??
              <String>[])
          ..sort();
    return jsonEncode({
      'mode': puzzle.mode.slug,
      if (scene != null)
        'scene': {
          'template': scene.template,
          'palette': scene.palette,
          'layout': scene.layout,
          'objects': objects,
          'targets': targets,
        },
      'rounds': puzzle.rounds.map((r) => r.toJson()).toList(),
    });
  }

  static List<String> validate(Puzzle puzzle) {
    final errors = <String>[];
    void check(bool ok, String message) {
      if (!ok) errors.add('${puzzle.id}: $message');
    }

    check(
      RegExp(r'^[a-z0-9][a-z0-9_-]{2,99}$').hasMatch(puzzle.id),
      'invalid ID',
    );
    check(puzzle.mode != GameMode.daily, 'daily must contain core puzzles');
    check(
      puzzle.title.isNotEmpty && puzzle.title.length <= 120,
      'invalid title',
    );
    check(
      puzzle.category.isNotEmpty && puzzle.category.length <= 60,
      'invalid category',
    );
    check(
      puzzle.difficulty >= 1 && puzzle.difficulty <= 5,
      'difficulty outside 1–5',
    );
    check(puzzle.level >= 1 && puzzle.level <= 10000, 'invalid level number');
    check(puzzle.reward >= 0 && puzzle.reward <= 1000, 'invalid reward');
    check(
      puzzle.timeLimitSeconds >= 0 && puzzle.timeLimitSeconds <= 3600,
      'invalid timer',
    );
    check(
      puzzle.parSeconds > 0 && puzzle.parSeconds <= 3600,
      'invalid par time',
    );
    check(puzzle.generatorVersion == 1, 'unsupported generator version');
    check(puzzle.seed >= 0 && puzzle.seed <= 0xffffffff, 'invalid seed');
    check(
      puzzle.validation == 'automated' || puzzle.validation == 'reviewed',
      'unvalidated content',
    );
    if (puzzle.mode.isScene) {
      final scene = puzzle.scene;
      if (scene == null) {
        errors.add('${puzzle.id}: missing scene');
        return errors;
      }
      check(sceneTemplates.contains(scene.template), 'unknown scene template');
      check(scene.palette >= 0 && scene.palette < 6, 'invalid scene palette');
      check(
        scene.layout >= 0 &&
            scene.layout <= 1000 &&
            scene.seed >= 0 &&
            scene.seed <= 0xffffffff,
        'invalid scene layout/seed',
      );
      check(
        scene.objects.length >= 5 && scene.objects.length <= 60,
        'invalid object count',
      );
      final ids = scene.objects.map((o) => o.id).toSet();
      check(ids.length == scene.objects.length, 'duplicate scene IDs');
      check(
        puzzle.answerIds.toSet().length == puzzle.answerIds.length,
        'duplicate answers',
      );
      check(
        puzzle.answerIds.every(ids.contains),
        'answer not present in scene',
      );
      check(
        puzzle.mode == GameMode.differences
            ? puzzle.answerIds.length == 5
            : puzzle.answerIds.length >= 5 && puzzle.answerIds.length <= 10,
        'invalid target count',
      );
      for (final o in scene.objects) {
        check(
          o.region.valid && o.region.width >= .055 && o.region.height >= .055,
          'invalid/tiny region ${o.id}',
        );
        check(objectKinds.contains(o.kind), 'unknown object ${o.kind}');
        check(
          o.alternateKind == null || objectKinds.contains(o.alternateKind),
          'unknown alternate object',
        );
        check(
          o.color >= 0 &&
              o.color < 6 &&
              (o.alternateColor == null ||
                  (o.alternateColor! >= 0 && o.alternateColor! < 6)),
          'invalid object color',
        );
        check(
          o.rotation.isFinite && o.rotation.abs() <= .5,
          'invalid rotation',
        );
        check(
          o.variant >= 0 &&
              o.variant <= 2 &&
              (o.alternateVariant == null ||
                  (o.alternateVariant! >= 0 &&
                      o.alternateVariant! <= 2 &&
                      o.alternateVariant != o.variant)),
          'invalid or identical object variant',
        );
        check(
          o.alternateKind == null || o.alternateKind != o.kind,
          'identical alternate silhouette',
        );
        check(
          o.alternateColor == null || o.alternateColor != o.color,
          'identical alternate color',
        );
      }
      for (var i = 0; i < scene.objects.length; i++) {
        for (var j = i + 1; j < scene.objects.length; j++) {
          check(
            !scene.objects[i].region.overlaps(scene.objects[j].region),
            'overlapping answer regions',
          );
        }
      }
      final edited = scene.objects
          .where((o) => o.hasDifference)
          .map((o) => o.id)
          .toSet();
      if (puzzle.mode == GameMode.differences) {
        check(
          edited.length == 5 && edited.containsAll(puzzle.answerIds),
          'edits do not match the five answers',
        );
      } else {
        check(edited.isEmpty, 'hidden-object scene has unintended alternates');
      }
      check(puzzle.rounds.isEmpty, 'scene should not contain grid rounds');
    } else {
      check(puzzle.scene == null, 'grid puzzle has unexpected scene');
      check(
        puzzle.rounds.isNotEmpty && puzzle.rounds.length <= 30,
        'invalid round count',
      );
      for (final r in puzzle.rounds) {
        check(r.columns >= 2 && r.columns <= 6, 'invalid column count');
        check(r.tiles.length >= 2 && r.tiles.length <= 36, 'invalid grid size');
        check(
          r.answers.isNotEmpty &&
              r.answers.toSet().length == r.answers.length &&
              r.answers.every((i) => i >= 0 && i < r.tiles.length),
          'invalid answer indexes',
        );
        check(
          [...r.tiles, ...r.preview, if (r.target != null) r.target!].every(
            (t) =>
                objectKinds.contains(t.kind) &&
                t.color >= 0 &&
                t.color < 6 &&
                t.variant >= 0 &&
                t.variant <= 2,
          ),
          'invalid tile',
        );
        if (r.answers.isEmpty ||
            r.answers.any((i) => i < 0 || i >= r.tiles.length)) {
          continue;
        }
        if (puzzle.mode == GameMode.odd) {
          check(r.answers.length == 1, 'odd puzzle has multiple answers');
          final normal = r.tiles
              .asMap()
              .entries
              .where((e) => !r.answers.contains(e.key))
              .map((e) => e.value.signature)
              .toSet();
          check(
            normal.length == 1 &&
                !normal.contains(r.tiles[r.answers.first].signature),
            'not exactly one odd tile',
          );
        } else if (puzzle.mode == GameMode.quick) {
          check(
            r.target != null && r.answers.length == 1,
            'missing/ambiguous quick target',
          );
          if (r.target != null) {
            final matches = r.tiles
                .asMap()
                .entries
                .where((e) => e.value.signature == r.target!.signature)
                .map((e) => e.key)
                .toSet();
            check(
              matches.length == 1 && matches.contains(r.answers.first),
              'ambiguous target',
            );
          }
        } else if (puzzle.mode == GameMode.memory) {
          check(
            r.rule != null && r.preview.isNotEmpty && r.preview.length <= 12,
            'invalid memory preview',
          );
          check(
            r.previewSeconds >= 2 && r.previewSeconds <= 10,
            'invalid preview duration',
          );
          final before = r.preview.map((t) => t.kind).toList();
          final after = r.tiles.map((t) => t.kind).toList();
          switch (r.rule) {
            case MemoryRule.disappeared:
              check(
                r.target != null &&
                    before.contains(r.target!.kind) &&
                    r.tiles[r.answers.first].kind == r.target!.kind,
                'incorrect disappearance answer',
              );
            case MemoryRule.added:
              final added = after.where((k) => !before.contains(k)).toList();
              check(
                added.length == 1 &&
                    r.tiles[r.answers.first].kind == added.first,
                'incorrect addition answer',
              );
            case MemoryRule.moved:
              check(
                before.length == after.length && r.answers.length == 2,
                'invalid position swap',
              );
              if (before.length == after.length) {
                final changes = [
                  for (var i = 0; i < before.length; i++)
                    if (before[i] != after[i]) i,
                ];
                check(
                  changes.length == 2 && changes.toSet().containsAll(r.answers),
                  'incorrect moved positions',
                );
              }
            case MemoryRule.duplicated:
              final duplicates = before
                  .toSet()
                  .where((k) => before.where((v) => v == k).length == 2)
                  .toList();
              check(
                duplicates.length == 1 &&
                    r.tiles[r.answers.first].kind == duplicates.first,
                'incorrect duplicate answer',
              );
            case null:
              break;
          }
        }
      }
    }
    for (final path in [puzzle.imageA, puzzle.imageB].whereType<String>()) {
      check(
        RegExp(r'^assets/scenes/[a-z0-9_-]+-[ab]\.png$').hasMatch(path),
        'unsafe image path',
      );
    }
    return errors;
  }

  static void validateCatalog(List<Puzzle> puzzles) {
    final errors = <String>[];
    final ids = <String>{};
    final fingerprints = <String>{};
    for (final puzzle in puzzles) {
      if (!ids.add(puzzle.id)) errors.add('Duplicate puzzle ID: ${puzzle.id}');
      errors.addAll(validate(puzzle));
      if (!fingerprints.add(fingerprint(puzzle))) {
        errors.add('Repeated puzzle content: ${puzzle.id}');
      }
    }
    if (errors.isNotEmpty) throw ContentValidationException(errors);
  }
}
