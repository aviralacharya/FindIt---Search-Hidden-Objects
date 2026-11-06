import 'dart:convert';

import 'package:findit/core/content/puzzle_generator.dart';
import 'package:findit/core/domain/game_engine.dart';
import 'package:findit/core/domain/puzzle.dart';

Puzzle fixture(GameMode mode, {int level = 1}) => PuzzleGenerator.generate(
  mode,
  seed: stableSeed('findit-v1-${mode.slug}-$level'),
  level: level,
);

Map<String, dynamic> deepJson(Map<String, dynamic> value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

Puzzle changePuzzle(Puzzle puzzle, Map<String, dynamic> changes) =>
    Puzzle.fromJson(deepJson(puzzle.toJson())..addAll(changes));

GameEngine solve(
  Puzzle puzzle, {
  String? sessionId,
  bool relaxed = false,
  int millisecondsPerAnswer = 400,
}) {
  final game = GameEngine(puzzle, sessionId: sessionId, relaxed: relaxed);
  solveRemaining(game, millisecondsPerAnswer: millisecondsPerAnswer);
  return game;
}

void solveRemaining(GameEngine game, {int millisecondsPerAnswer = 400}) {
  var transitions = 0;
  while (!game.finished && transitions++ < 100) {
    if (game.phase == PlayPhase.preview) game.finishPreview();
    if (game.phase == PlayPhase.betweenRounds) game.nextRound();
    if (game.puzzle.mode.isScene) {
      for (final id in game.puzzle.answerIds.where(
        (id) => !game.found.contains(id),
      )) {
        final object = game.puzzle.scene!.objects.firstWhere((o) => o.id == id);
        game.tick(millisecondsPerAnswer);
        game.tapScene(object.region.centerX, object.region.centerY);
      }
    } else {
      for (final index in game.currentRound.answers) {
        if (game.selectedTiles.contains(index)) continue;
        game.tick(millisecondsPerAnswer);
        game.tapTile(index);
      }
    }
  }
  if (!game.completed) {
    throw StateError('Failed to solve ${game.puzzle.id}: ${game.phase}');
  }
}
