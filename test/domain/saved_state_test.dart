import 'package:findit/core/content/puzzle_generator.dart';
import 'package:findit/core/domain/game_engine.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/puzzles.dart';

void main() {
  final catalog = PuzzleGenerator.launchCatalog();
  for (final mode in GameMode.values.where((mode) => mode != GameMode.daily)) {
    test(
      '${mode.slug} valid opening and completed saves restore unchanged',
      () {
        final puzzle = fixture(mode);
        final opening = GameEngine(puzzle, sessionId: 'opening-${mode.slug}');
        expect(
          GameEngine.restore(deepJson(opening.toJson())).toJson(),
          opening.toJson(),
        );
        final completed = solve(puzzle, sessionId: 'completed-${mode.slug}');
        expect(
          GameEngine.restore(deepJson(completed.toJson())).toJson(),
          completed.toJson(),
        );
      },
    );

    test(
      '${mode.slug} restores every reachable phase across all 60 levels',
      () {
        for (final puzzle in catalog.where((puzzle) => puzzle.mode == mode)) {
          for (final relaxed in [false, true]) {
            final game = GameEngine(puzzle, relaxed: relaxed);
            void checkSnapshot() {
              final restored = GameEngine.restore(deepJson(game.toJson()));
              if (game.phase == PlayPhase.betweenRounds) {
                expect(restored.roundIndex, game.roundIndex + 1);
                expect(restored.selectedTiles, isEmpty);
                expect(restored.eliminated, isEmpty);
                expect(restored.correctTaps, game.correctTaps);
                expect(restored.combo, game.combo);
                expect(restored.hints, game.hints);
                expect(restored.elapsedMs, game.elapsedMs);
                expect(
                  restored.phase,
                  mode == GameMode.memory
                      ? PlayPhase.preview
                      : PlayPhase.answering,
                );
                expect(
                  GameEngine.restore(deepJson(restored.toJson())).toJson(),
                  restored.toJson(),
                );
              } else {
                expect(restored.toJson(), game.toJson());
              }
            }

            checkSnapshot();
            while (!game.finished) {
              if (game.phase == PlayPhase.betweenRounds) {
                game.nextRound();
                checkSnapshot();
              }
              if (game.phase == PlayPhase.preview) {
                game.tick(100);
                checkSnapshot();
                game.finishPreview();
                checkSnapshot();
              }
              if (mode.isScene) {
                game.tapScene(0, 0);
              } else {
                game.tapTile(
                  game.currentRound.tiles.asMap().keys.firstWhere(
                    (index) => !game.currentRound.answers.contains(index),
                  ),
                );
              }
              checkSnapshot();
              expect(game.applyHint(), isTrue);
              checkSnapshot();
              if (game.phase == PlayPhase.preview) {
                game.tick(100);
                checkSnapshot();
                game.finishPreview();
                checkSnapshot();
              }
              if (mode.isScene) {
                final object = puzzle.scene!.objects.firstWhere(
                  (object) => object.id == game.hintObjectId,
                );
                game.tick(400);
                game.tapScene(object.region.centerX, object.region.centerY);
                checkSnapshot();
              } else {
                for (final answer in game.currentRound.answers) {
                  game.tick(400);
                  game.tapTile(answer);
                  checkSnapshot();
                }
              }
            }
            expect(game.completed, isTrue, reason: puzzle.id);
            if (game.timed) {
              final timedOut = GameEngine(puzzle)
                ..tick(puzzle.timeLimitSeconds * 1000 + 1);
              expect(timedOut.phase, PlayPhase.timedOut);
              expect(
                GameEngine.restore(deepJson(timedOut.toJson())).toJson(),
                timedOut.toJson(),
              );
            }
          }
        }
      },
    );
  }

  final puzzle = fixture(GameMode.odd);
  for (final mutation in <String, Object>{
    'roundIndex': 10000,
    'mistakes': -1,
    'hints': -1,
    'correctTaps': 1,
    'combo': 1,
    'bestCombo': 1,
    'score': -1,
    'elapsedMs': -1,
    'phase': 'completed',
    'selectedTiles': [-1],
    'eliminated': [puzzle.rounds.first.answers.single],
    'found': ['not-a-scene-answer'],
    'hintTile': -1,
    'hintObjectId': 'not-a-scene-answer',
  }.entries) {
    test('rejects inconsistent saved ${mutation.key}', () {
      final saved = deepJson(GameEngine(puzzle).toJson())
        ..[mutation.key] = mutation.value;
      expect(() => GameEngine.restore(saved), throwsFormatException);
    });
  }

  test(
    'a scene save cannot claim a non-answer or unsupported preview phase',
    () {
      final game = GameEngine(fixture(GameMode.hidden));
      for (final values in [
        {
          'found': ['not-an-answer'],
          'correctTaps': 1,
          'combo': 1,
          'bestCombo': 1,
        },
        {'phase': 'preview', 'previewRemainingMs': 1000},
      ]) {
        final saved = deepJson(game.toJson())..addAll(values);
        expect(() => GameEngine.restore(saved), throwsFormatException);
      }
    },
  );
}
