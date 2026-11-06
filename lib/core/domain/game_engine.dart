import 'dart:math' as math;

import 'puzzle.dart';

enum PlayPhase { preview, answering, betweenRounds, completed, timedOut }

enum AnswerResult {
  correct,
  incorrect,
  alreadyFound,
  ignored,
  roundComplete,
  completed,
}

/// All gameplay and scoring live here. No widgets, plugins, ads, or I/O.
class GameEngine {
  GameEngine(this.puzzle, {this.relaxed = false, String? sessionId})
    : sessionId =
          sessionId ?? '${puzzle.id}-${DateTime.now().microsecondsSinceEpoch}' {
    if (puzzle.mode == GameMode.memory) {
      phase = PlayPhase.preview;
      previewRemainingMs = currentRound.previewSeconds * 1000;
    }
  }

  final Puzzle puzzle;
  final String sessionId;
  final bool relaxed;
  PlayPhase phase = PlayPhase.answering;
  int roundIndex = 0;
  final Set<String> found = {};
  final Set<int> selectedTiles = {};
  final Set<int> eliminated = {};
  int mistakes = 0;
  int hints = 0;
  int correctTaps = 0;
  int combo = 0;
  int bestCombo = 0;
  int score = 0;
  int elapsedMs = 0;
  int previewRemainingMs = 0;
  String? hintObjectId;
  bool hintRevealed = true;
  int? hintTile;

  PuzzleRound get currentRound => puzzle.rounds[roundIndex];
  bool get finished =>
      phase == PlayPhase.completed || phase == PlayPhase.timedOut;
  bool get completed => phase == PlayPhase.completed;
  bool get timed => !relaxed && puzzle.timeLimitSeconds > 0;
  int get remainingMs =>
      math.max(0, puzzle.timeLimitSeconds * 1000 - elapsedMs);
  double get accuracy =>
      correctTaps + mistakes == 0 ? 1 : correctTaps / (correctTaps + mistakes);
  int get answersFound => puzzle.mode.isScene ? found.length : correctTaps;
  int get stars {
    if (!completed) return 0;
    if (mistakes <= 1 &&
        hints == 0 &&
        (relaxed || elapsedMs <= puzzle.parSeconds * 1000)) {
      return 3;
    }
    if (accuracy >= .65 && hints <= 2) return 2;
    return 1;
  }

  /// The caller supplies monotonic elapsed time; background time is excluded.
  void tick(int milliseconds) {
    if (finished || milliseconds <= 0 || phase == PlayPhase.betweenRounds) {
      return;
    }
    if (phase == PlayPhase.preview) {
      if (relaxed) return;
      previewRemainingMs = math.max(0, previewRemainingMs - milliseconds);
      if (previewRemainingMs == 0) phase = PlayPhase.answering;
      return;
    }
    elapsedMs += milliseconds;
    if (timed && remainingMs == 0) phase = PlayPhase.timedOut;
  }

  void finishPreview() {
    if (phase != PlayPhase.preview) return;
    previewRemainingMs = 0;
    phase = PlayPhase.answering;
  }

  AnswerResult tapScene(double x, double y) {
    if (!puzzle.mode.isScene ||
        phase != PlayPhase.answering ||
        !x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        x > 1 ||
        y < 0 ||
        y > 1) {
      return AnswerResult.ignored;
    }
    for (final item in puzzle.scene!.objects.reversed) {
      if (item.region.contains(x, y) && puzzle.answerIds.contains(item.id)) {
        if (found.contains(item.id)) return AnswerResult.alreadyFound;
        found.add(item.id);
        if (hintObjectId == item.id) {
          hintObjectId = null;
          hintRevealed = true;
        }
        _correct();
        if (found.length == puzzle.answerIds.length) return _complete();
        return AnswerResult.correct;
      }
    }
    return _incorrect();
  }

  AnswerResult tapTile(int index) {
    if (puzzle.mode.isScene ||
        phase != PlayPhase.answering ||
        index < 0 ||
        index >= currentRound.tiles.length ||
        eliminated.contains(index)) {
      return AnswerResult.ignored;
    }
    if (selectedTiles.contains(index)) return AnswerResult.alreadyFound;
    if (!currentRound.answers.contains(index)) return _incorrect();
    selectedTiles.add(index);
    hintTile = null;
    _correct();
    if (selectedTiles.length == currentRound.answers.length) {
      if (roundIndex == puzzle.rounds.length - 1) return _complete();
      phase = PlayPhase.betweenRounds;
      return AnswerResult.roundComplete;
    }
    return AnswerResult.correct;
  }

  void nextRound() {
    if (phase != PlayPhase.betweenRounds) return;
    roundIndex++;
    selectedTiles.clear();
    eliminated.clear();
    hintTile = null;
    if (puzzle.mode == GameMode.memory) {
      phase = PlayPhase.preview;
      previewRemainingMs = currentRound.previewSeconds * 1000;
    } else {
      phase = PlayPhase.answering;
    }
  }

  bool get canHint =>
      !finished &&
      phase != PlayPhase.betweenRounds &&
      (puzzle.mode.isScene
          ? hintObjectId == null
          : puzzle.mode == GameMode.memory
          ? phase == PlayPhase.answering
          : hintTile == null);

  /// Called only after a successful wallet transaction. Never completes a level.
  bool applyHint() {
    if (!canHint) return false;
    hints++;
    if (puzzle.mode.isScene) {
      hintObjectId = puzzle.answerIds.firstWhere((id) => !found.contains(id));
      hintRevealed = puzzle.mode != GameMode.hidden;
    } else if (puzzle.mode == GameMode.memory) {
      phase = PlayPhase.preview;
      previewRemainingMs = 2500;
    } else {
      final remaining = currentRound.answers.where(
        (i) => !selectedTiles.contains(i),
      );
      if (remaining.isEmpty) return false;
      hintTile = remaining.first;
      for (var i = 0; i < currentRound.tiles.length; i++) {
        if (!currentRound.answers.contains(i) && i % 2 == roundIndex % 2) {
          eliminated.add(i);
        }
      }
    }
    return true;
  }

  /// An already-paid hidden-object hint can be made precise for free.
  /// It does not complete the object, spend more coins or count a second hint.
  bool get canRevealHint =>
      !finished &&
      puzzle.mode == GameMode.hidden &&
      hintObjectId != null &&
      !hintRevealed;

  bool revealHint() {
    if (!canRevealHint) return false;
    hintRevealed = true;
    return true;
  }

  void _correct() {
    correctTaps++;
    combo++;
    bestCombo = math.max(bestCombo, combo);
    score +=
        100 + (puzzle.mode == GameMode.quick ? math.min(combo, 10) * 20 : 0);
  }

  AnswerResult _incorrect() {
    mistakes++;
    combo = 0;
    score = math.max(0, score - 20);
    if (puzzle.mode == GameMode.quick && timed) {
      elapsedMs += 1500;
      if (remainingMs == 0) phase = PlayPhase.timedOut;
    }
    return AnswerResult.incorrect;
  }

  AnswerResult _complete() {
    phase = PlayPhase.completed;
    score += math.max(0, puzzle.parSeconds - elapsedMs ~/ 1000) * 3;
    return AnswerResult.completed;
  }

  Map<String, dynamic> toJson() => {
    'puzzle': puzzle.toJson(),
    'sessionId': sessionId,
    'relaxed': relaxed,
    'phase': phase.name,
    'roundIndex': roundIndex,
    'found': found.toList(),
    'selectedTiles': selectedTiles.toList(),
    'eliminated': eliminated.toList(),
    'mistakes': mistakes,
    'hints': hints,
    'correctTaps': correctTaps,
    'combo': combo,
    'bestCombo': bestCombo,
    'score': score,
    'elapsedMs': elapsedMs,
    'previewRemainingMs': previewRemainingMs,
    'hintObjectId': hintObjectId,
    'hintRevealed': hintRevealed,
    'hintTile': hintTile,
  };

  factory GameEngine.restore(Map<String, dynamic> j) {
    final engine = GameEngine(
      Puzzle.fromJson(j['puzzle'] as Map<String, dynamic>),
      relaxed: j['relaxed'] as bool? ?? false,
      sessionId: j['sessionId'] as String,
    );
    engine.phase = PlayPhase.values.byName(j['phase'] as String);
    engine.roundIndex = j['roundIndex'] as int;
    engine.found.addAll((j['found'] as List).cast<String>());
    engine.selectedTiles.addAll((j['selectedTiles'] as List).cast<int>());
    engine.eliminated.addAll((j['eliminated'] as List? ?? []).cast<int>());
    engine.mistakes = j['mistakes'] as int;
    engine.hints = j['hints'] as int;
    engine.correctTaps = j['correctTaps'] as int;
    engine.combo = j['combo'] as int;
    engine.bestCombo = j['bestCombo'] as int;
    engine.score = j['score'] as int;
    engine.elapsedMs = j['elapsedMs'] as int;
    engine.previewRemainingMs = j['previewRemainingMs'] as int? ?? 0;
    engine.hintObjectId = j['hintObjectId'] as String?;
    engine.hintRevealed = j['hintRevealed'] as bool? ?? true;
    engine.hintTile = j['hintTile'] as int?;
    engine._validateRestoredState();
    // Reopen an interrupted transition deterministically, with no hidden timer.
    if (engine.phase == PlayPhase.betweenRounds) engine.nextRound();
    return engine;
  }

  void _validateRestoredState() {
    void check(bool valid) {
      if (!valid) {
        throw const FormatException('Inconsistent saved puzzle state.');
      }
    }

    check(sessionId.isNotEmpty);
    check(
      [
        roundIndex,
        mistakes,
        hints,
        correctTaps,
        combo,
        bestCombo,
        score,
        elapsedMs,
        previewRemainingMs,
      ].every((value) => value >= 0),
    );
    check(combo <= bestCombo && bestCombo <= correctTaps);
    check(correctTaps <= puzzle.totalAnswers);
    check(completed == (correctTaps == puzzle.totalAnswers));
    check(phase != PlayPhase.preview || puzzle.mode == GameMode.memory);
    check(phase != PlayPhase.preview || previewRemainingMs > 0);
    check(phase != PlayPhase.timedOut || (timed && remainingMs == 0));
    check(
      hintRevealed || (puzzle.mode == GameMode.hidden && hintObjectId != null),
    );

    if (puzzle.mode.isScene) {
      check(roundIndex == 0 && selectedTiles.isEmpty && eliminated.isEmpty);
      check(phase != PlayPhase.betweenRounds && phase != PlayPhase.preview);
      check(found.every(puzzle.answerIds.contains));
      check(correctTaps == found.length && hintTile == null);
      check(
        hintObjectId == null ||
            (hints > 0 &&
                puzzle.answerIds.contains(hintObjectId) &&
                !found.contains(hintObjectId)),
      );
    } else {
      check(roundIndex < puzzle.rounds.length);
      final round = currentRound;
      check(found.isEmpty && hintObjectId == null);
      check(selectedTiles.every(round.answers.contains));
      check(
        eliminated.every(
          (index) =>
              index < round.tiles.length &&
              index >= 0 &&
              !round.answers.contains(index),
        ),
      );
      check(eliminated.isEmpty || hints > 0);
      check(
        correctTaps ==
            puzzle.rounds
                    .take(roundIndex)
                    .fold<int>(0, (sum, round) => sum + round.answers.length) +
                selectedTiles.length,
      );
      check(
        hintTile == null ||
            (hints > 0 &&
                puzzle.mode != GameMode.memory &&
                round.answers.contains(hintTile) &&
                !selectedTiles.contains(hintTile)),
      );
      if (phase == PlayPhase.betweenRounds) {
        check(roundIndex < puzzle.rounds.length - 1);
        check(selectedTiles.length == round.answers.length);
      } else if (!completed) {
        check(selectedTiles.length < round.answers.length);
      }
    }
  }
}
