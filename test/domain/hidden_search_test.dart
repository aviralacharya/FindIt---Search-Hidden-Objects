import 'package:findit/core/content/featured_scenes.dart';
import 'package:findit/core/content/hidden_catalog.dart';
import 'package:findit/core/content/puzzle_validator.dart';
import 'package:findit/core/domain/game_engine.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/puzzles.dart';

void main() {
  final catalog = HiddenCatalog.launchCatalog();

  for (final puzzle in catalog) {
    test('${puzzle.id} supports durable two-stage hints and manual finds', () {
      expect(PuzzleValidator.validate(puzzle), isEmpty);
      var game = GameEngine(
        puzzle,
        relaxed: true,
        sessionId: 'search-${puzzle.id}',
      );
      for (final (index, id) in puzzle.answerIds.indexed) {
        expect(game.applyHint(), isTrue);
        expect(game.hintObjectId, id);
        expect(game.hintRevealed, isFalse);
        expect(game.hints, index + 1);
        expect(game.answersFound, index);
        expect(game.completed, isFalse);
        expect(game.applyHint(), isFalse);
        game = GameEngine.restore(deepJson(game.toJson()));
        expect(game.canRevealHint, isTrue);
        final before = game.toJson();
        expect(game.revealHint(), isTrue);
        expect(game.hints, before['hints']);
        expect(game.found, (before['found'] as List).toSet());
        expect(game.score, before['score']);
        expect(game.revealHint(), isFalse);
        expect(game.canHint, isFalse);
        game = GameEngine.restore(deepJson(game.toJson()));
        expect(game.hintRevealed, isTrue);
        final object = puzzle.scene!.objects.firstWhere((o) => o.id == id);
        game.tick(250);
        expect(
          game.tapScene(object.region.centerX, object.region.centerY),
          index == puzzle.answerIds.length - 1
              ? AnswerResult.completed
              : AnswerResult.correct,
        );
        expect(game.hintObjectId, isNull);
        expect(game.hintRevealed, isTrue);
        expect(game.answersFound, index + 1);
        game = GameEngine.restore(deepJson(game.toJson()));
      }
      expect(game.completed, isTrue);
      final frozen = deepJson(game.toJson());
      game.tick(1000000);
      expect(game.applyHint(), isFalse);
      expect(game.revealHint(), isFalse);
      expect(game.tapScene(.5, .5), AnswerResult.ignored);
      expect(game.toJson(), frozen);
    });
  }

  test(
    'featured scenes are authored compositions with classic levels retained',
    () {
      expect(
        catalog.take(3).map((p) => p.scene!.template),
        FeaturedScenes.templates,
      );
      expect(catalog.take(3).map((p) => p.category), FeaturedScenes.categories);
      expect(catalog.take(3).map((p) => p.totalAnswers), [6, 6, 6]);
      for (final puzzle in catalog.skip(3)) {
        expect(
          puzzle.toJson(),
          fixture(GameMode.hidden, level: puzzle.level).toJson(),
        );
      }
      for (final puzzle in catalog) {
        final completed = solve(puzzle, relaxed: true);
        expect(completed.stars, 3);
        expect(completed.mistakes, 0);
        expect(completed.hints, 0);
      }
    },
  );

  test(
    'a miss retains the paid area hint and neither stage auto-finds a target',
    () {
      final game = GameEngine(catalog.first)..applyHint();
      final target = game.hintObjectId;
      expect(game.tapScene(0, 0), AnswerResult.incorrect);
      expect(game.hintObjectId, target);
      expect(game.hintRevealed, isFalse);
      expect(game.revealHint(), isTrue);
      expect(game.answersFound, 0);
      expect(game.mistakes, 1);
      expect(game.hints, 1);
      final object = game.puzzle.scene!.objects.firstWhere(
        (o) => o.id == target,
      );
      expect(
        game.tapScene(object.region.centerX, object.region.centerY),
        AnswerResult.correct,
      );
      expect(
        game.tapScene(object.region.centerX, object.region.centerY),
        AnswerResult.alreadyFound,
      );
      expect(game.answersFound, 1);
      expect(game.canHint, isTrue);
    },
  );

  test(
    'legacy precise saves remain precise without inventing a new charge',
    () {
      final game = GameEngine(catalog.first)..applyHint();
      final legacy = deepJson(game.toJson())..remove('hintRevealed');
      final restored = GameEngine.restore(legacy);
      expect(restored.hintObjectId, game.hintObjectId);
      expect(restored.hintRevealed, isTrue);
      expect(restored.canRevealHint, isFalse);
      expect(restored.hints, 1);
      expect(restored.answersFound, 0);
    },
  );

  test('invalid hint stages and timed-out reveals are rejected', () {
    final fresh = GameEngine(catalog.first);
    expect(fresh.revealHint(), isFalse);
    expect(
      () => GameEngine.restore(
        deepJson(fresh.toJson())..['hintRevealed'] = false,
      ),
      throwsFormatException,
    );
    final other = GameEngine(fixture(GameMode.differences))..applyHint();
    expect(other.canRevealHint, isFalse);
    expect(
      () => GameEngine.restore(
        deepJson(other.toJson())..['hintRevealed'] = false,
      ),
      throwsFormatException,
    );
    fresh.applyHint();
    fresh.tick(fresh.puzzle.timeLimitSeconds * 1000);
    expect(fresh.phase, PlayPhase.timedOut);
    expect(fresh.revealHint(), isFalse);
    expect(fresh.hints, 1);
    expect(fresh.answersFound, 0);
  });
}
