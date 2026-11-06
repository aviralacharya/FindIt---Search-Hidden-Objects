import 'package:findit/core/content/puzzle_generator.dart';
import 'package:findit/core/content/puzzle_validator.dart';
import 'package:findit/core/domain/game_engine.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/puzzles.dart';

void main() {
  group('all 300 launch puzzles', () {
    for (final puzzle in PuzzleGenerator.launchCatalog()) {
      test('${puzzle.id} is valid and solvable, with a frozen completion', () {
        expect(PuzzleValidator.validate(puzzle), isEmpty);
        final game = solve(puzzle, sessionId: 'verify-${puzzle.id}');
        expect(game.completed, isTrue);
        expect(game.correctTaps, puzzle.totalAnswers);
        expect(game.answersFound, puzzle.totalAnswers);
        expect(game.mistakes, 0);
        expect(game.accuracy, 1);
        expect(game.stars, 3);
        expect(game.bestCombo, puzzle.totalAnswers);
        final result = deepJson(game.toJson());
        game.tick(1000000);
        expect(game.tapTile(0), AnswerResult.ignored);
        expect(game.tapScene(.5, .5), AnswerResult.ignored);
        expect(game.applyHint(), isFalse);
        game.nextRound();
        expect(game.toJson(), result);
      });
    }
  });

  group('scene answers', () {
    test('normalized bounds, duplicate finds, and non-target taps', () {
      final game = GameEngine(fixture(GameMode.differences));
      final target = game.puzzle.scene!.objects.firstWhere(
        (o) => game.puzzle.answerIds.contains(o.id),
      );
      for (final point in [
        (double.nan, .5),
        (double.infinity, .5),
        (-.01, .5),
        (1.01, .5),
        (.5, -.01),
        (.5, 1.01),
      ]) {
        expect(game.tapScene(point.$1, point.$2), AnswerResult.ignored);
      }
      expect(game.mistakes, 0);
      expect(
        game.tapScene(target.region.centerX, target.region.centerY),
        AnswerResult.correct,
      );
      expect(
        game.tapScene(target.region.centerX, target.region.centerY),
        AnswerResult.alreadyFound,
      );
      final other = game.puzzle.scene!.objects.firstWhere(
        (o) => !game.puzzle.answerIds.contains(o.id),
      );
      expect(
        game.tapScene(other.region.centerX, other.region.centerY),
        AnswerResult.incorrect,
      );
      expect(game.correctTaps, 1);
      expect(game.mistakes, 1);
      expect(game.combo, 0);
      expect(game.score, 80);
    });

    test('a hint highlights but never finds an answer', () {
      final game = GameEngine(fixture(GameMode.hidden));
      expect(game.applyHint(), isTrue);
      expect(game.hints, 1);
      expect(game.answersFound, 0);
      expect(game.completed, isFalse);
      expect(game.canHint, isFalse);
      expect(game.applyHint(), isFalse);
      final target = game.puzzle.scene!.objects.firstWhere(
        (o) => o.id == game.hintObjectId,
      );
      game.tapScene(target.region.centerX, target.region.centerY);
      expect(game.hintObjectId, isNull);
      expect(game.canHint, isTrue);
      expect(game.applyHint(), isTrue);
      expect(game.hints, 2);
    });
  });

  group('grid rounds and hints', () {
    test('invalid and eliminated tiles cannot spend accuracy or finish', () {
      final game = GameEngine(fixture(GameMode.odd));
      expect(game.tapTile(-1), AnswerResult.ignored);
      expect(game.tapTile(1000), AnswerResult.ignored);
      expect(game.applyHint(), isTrue);
      expect(game.hintTile, game.currentRound.answers.single);
      expect(game.eliminated, isNotEmpty);
      expect(game.eliminated.any(game.currentRound.answers.contains), isFalse);
      expect(game.tapTile(game.eliminated.first), AnswerResult.ignored);
      expect(game.mistakes, 0);
      expect(game.applyHint(), isFalse);
      expect(
        game.tapTile(game.currentRound.answers.single),
        AnswerResult.roundComplete,
      );
      final snapshot = deepJson(game.toJson());
      game.tick(10000);
      expect(game.toJson(), snapshot);
      expect(game.tapTile(0), AnswerResult.ignored);
      expect(game.applyHint(), isFalse);
      game.nextRound();
      expect(game.roundIndex, 1);
      expect(game.selectedTiles, isEmpty);
      expect(game.eliminated, isEmpty);
      expect(game.hintTile, isNull);
      expect(game.phase, PlayPhase.answering);
    });

    test('quick combos, wrong-tap penalty, and exact timeout', () {
      final game = GameEngine(fixture(GameMode.quick));
      game.tapTile(game.currentRound.answers.single);
      expect(game.score, 120);
      game.nextRound();
      game.tapTile(game.currentRound.answers.single);
      expect(game.score, 260);
      expect(game.bestCombo, 2);
      game.nextRound();
      final wrong = game.currentRound.tiles.asMap().keys.firstWhere(
        (i) => !game.currentRound.answers.contains(i),
      );
      expect(game.tapTile(wrong), AnswerResult.incorrect);
      expect(game.score, 240);
      expect(game.elapsedMs, 1500);
      expect(game.combo, 0);
      expect(game.bestCombo, 2);
      game.tick(game.remainingMs - 1);
      expect(game.phase, PlayPhase.answering);
      game.tick(1);
      expect(game.phase, PlayPhase.timedOut);
      expect(game.stars, 0);
      expect(
        game.tapTile(game.currentRound.answers.single),
        AnswerResult.ignored,
      );
    });

    test('relaxed play has no deadline or wrong-tap time penalty', () {
      final game = GameEngine(fixture(GameMode.quick), relaxed: true);
      final wrong = game.currentRound.tiles.asMap().keys.firstWhere(
        (i) => !game.currentRound.answers.contains(i),
      );
      game.tapTile(wrong);
      expect(game.elapsedMs, 0);
      game.tick(10000000);
      expect(game.timed, isFalse);
      expect(game.phase, PlayPhase.answering);
      solveRemaining(game);
      expect(game.stars, 3);
    });
  });

  group('memory rules', () {
    for (final rule in MemoryRule.values) {
      test(
        '${rule.name} supports preview, answers, re-preview, and restoration',
        () {
          final puzzle = PuzzleGenerator.launchCatalog().firstWhere(
            (p) => p.mode == GameMode.memory && p.rounds.first.rule == rule,
          );
          final game = GameEngine(puzzle);
          expect(game.phase, PlayPhase.preview);
          expect(game.canHint, isFalse);
          expect(
            game.tapTile(game.currentRound.answers.first),
            AnswerResult.ignored,
          );
          game.tick(game.previewRemainingMs - 1);
          expect(game.phase, PlayPhase.preview);
          expect(game.elapsedMs, 0);
          game.tick(1);
          expect(game.phase, PlayPhase.answering);
          game.tick(700);
          if (rule == MemoryRule.moved) {
            expect(
              game.tapTile(game.currentRound.answers.first),
              AnswerResult.correct,
            );
            expect(
              game.tapTile(game.currentRound.answers.first),
              AnswerResult.alreadyFound,
            );
          }
          final selected = Set<int>.of(game.selectedTiles);
          expect(game.applyHint(), isTrue);
          expect(game.previewRemainingMs, 2500);
          expect(game.phase, PlayPhase.preview);
          expect(game.elapsedMs, 700);
          expect(game.selectedTiles, selected);
          final restored = GameEngine.restore(deepJson(game.toJson()));
          expect(restored.toJson(), game.toJson());
          restored.finishPreview();
          solveRemaining(restored);
          expect(restored.completed, isTrue);
          expect(restored.hints, 1);
          expect(restored.correctTaps, puzzle.totalAnswers);
          expect(restored.stars, 2);
        },
      );
    }

    test('relaxed preview waits for readiness, even after a hint', () {
      final game = GameEngine(fixture(GameMode.memory), relaxed: true);
      final remaining = game.previewRemainingMs;
      game.tick(10000000);
      expect(game.phase, PlayPhase.preview);
      expect(game.previewRemainingMs, remaining);
      game.finishPreview();
      expect(game.phase, PlayPhase.answering);
      expect(game.applyHint(), isTrue);
      game.tick(10000000);
      expect(game.phase, PlayPhase.preview);
      game.finishPreview();
      solveRemaining(game);
      expect(game.completed, isTrue);
    });

    test('an interrupted transition reopens the next round exactly once', () {
      final game = GameEngine(fixture(GameMode.memory));
      game.finishPreview();
      for (final index in game.currentRound.answers) {
        game.tapTile(index);
      }
      expect(game.phase, PlayPhase.betweenRounds);
      final restored = GameEngine.restore(deepJson(game.toJson()));
      expect(restored.roundIndex, 1);
      expect(restored.phase, PlayPhase.preview);
      expect(restored.selectedTiles, isEmpty);
      final reopened = GameEngine.restore(deepJson(restored.toJson()));
      expect(reopened.toJson(), restored.toJson());
    });
  });

  group('scoring and restoration', () {
    test('three, two, and one-star results use accuracy, hints, and pace', () {
      final puzzle = fixture(GameMode.differences);
      expect(solve(puzzle).stars, 3);
      final slower = GameEngine(puzzle)..tick((puzzle.parSeconds + 1) * 1000);
      solveRemaining(slower, millisecondsPerAnswer: 0);
      expect(slower.stars, 2);
      final hinted = GameEngine(puzzle)..applyHint();
      solveRemaining(hinted);
      expect(hinted.stars, 2);
      final inaccurate = GameEngine(puzzle);
      for (var i = 0; i < 10; i++) {
        inaccurate.tapScene(0, 0);
      }
      expect(inaccurate.score, 0);
      solveRemaining(inaccurate);
      expect(inaccurate.accuracy, closeTo(1 / 3, .00001));
      expect(inaccurate.stars, 1);
    });

    test('partial scene snapshots retain all counters, hint, and pace', () {
      final game = GameEngine(
        fixture(GameMode.differences),
        relaxed: true,
        sessionId: 'restore-scene',
      );
      game.tick(1234);
      game.applyHint();
      final target = game.puzzle.scene!.objects.firstWhere(
        (o) => o.id == game.hintObjectId,
      );
      game.tapScene(target.region.centerX, target.region.centerY);
      game.tapScene(0, 0);
      game.applyHint();
      final restored = GameEngine.restore(deepJson(game.toJson()));
      expect(restored.toJson(), game.toJson());
      expect(restored.sessionId, 'restore-scene');
      expect(restored.relaxed, isTrue);
      solveRemaining(restored);
      expect(restored.completed, isTrue);
    });

    test('non-positive ticks and a non-memory preview finish are no-ops', () {
      final game = GameEngine(fixture(GameMode.odd));
      final snapshot = deepJson(game.toJson());
      game.tick(0);
      game.tick(-100);
      game.finishPreview();
      expect(game.toJson(), snapshot);
    });
  });
}
