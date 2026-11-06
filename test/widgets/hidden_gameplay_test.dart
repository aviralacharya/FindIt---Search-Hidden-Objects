import 'package:findit/core/config/app_config.dart';
import 'package:findit/core/domain/game_engine.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:findit/core/storage/settings_repository.dart';
import 'package:findit/ui/widgets/object_checklist.dart';
import 'package:findit/ui/widgets/scene_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/puzzles.dart';
import '../support/write_gate.dart';

GameEngine saved(AppHarness app) =>
    app.services.progress.current.savedGame!.restore();

Future<void> failSessionWrites(WidgetTester tester, AppHarness app) async {
  await tester.runAsync(
    () => app.services.progress.db.customStatement('''
    CREATE TEMP TRIGGER fail_hidden_session BEFORE INSERT ON local_entries
    WHEN NEW.key = 'active-session'
    BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END
  '''),
  );
}

Future<void> allowSessionWrites(WidgetTester tester, AppHarness app) async {
  await tester.runAsync(
    () => app.services.progress.db.customStatement(
      'DROP TRIGGER fail_hidden_session',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFindItFonts);
  setUp(
    () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );

  testWidgets(
    'area hint and free precise reveal both survive save and resume',
    (tester) async {
      final app = await AppHarness.forTest(tester);
      try {
        await app.mount(tester);
        final puzzle = app.services.content.puzzles.first;
        await app.openPuzzle(tester, puzzle);
        expect(saved(app).relaxed, isTrue);
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(tester, () => saved(app).hints == 1);
        expect(app.services.progress.current.coins, 80);
        expect(saved(app).hintRevealed, isFalse);
        expect(saved(app).answersFound, 0);
        expect(find.text('Reveal object · free'), findsOneWidget);
        await app.tap(tester, find.byKey(const ValueKey('pause-game')));
        await app.tap(tester, find.text('Save & leave').last);
        await app.openPuzzle(tester, puzzle, resume: true);
        expect(saved(app).hintRevealed, isFalse);
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(tester, () => saved(app).hintRevealed);
        expect(app.services.progress.current.coins, 80);
        expect(saved(app).hints, 1);
        expect(saved(app).answersFound, 0);
        expect(
          tester.widget<SceneBoard>(find.byType(SceneBoard)).hintIsPrecise,
          isTrue,
        );
        await app.go(tester, '/');
        await app.openPuzzle(tester, puzzle, resume: true);
        expect(saved(app).hintRevealed, isTrue);
        expect(saved(app).hintObjectId, puzzle.answerIds.first);
        await app.tapSceneObject(tester, puzzle, puzzle.answerIds.first);
        await app.until(tester, () => saved(app).answersFound == 1);
        expect(saved(app).hintObjectId, isNull);
        expect(saved(app).hints, 1);
        expect(app.services.progress.current.coins, 80);
        expect(find.text('Area hint · 20 coins'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await app.close(tester);
      }
    },
  );

  testWidgets('real pan and pinch gestures do not count as object taps', (
    tester,
  ) async {
    final app = await AppHarness.forTest(tester);
    try {
      await app.mount(tester);
      final puzzle = app.services.content.puzzles.first;
      await app.openPuzzle(tester, puzzle);
      final checklist = tester.getRect(find.byType(ObjectChecklist));
      final point = await app.focusSceneObject(
        tester,
        puzzle,
        puzzle.answerIds.first,
      );
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final before = viewer.transformationController!.value.clone();
      await tester.dragFrom(point, const Offset(65, -35));
      await app.pump(tester);
      expect(viewer.transformationController!.value, isNot(before));
      expect(saved(app).answersFound, 0);
      expect(saved(app).mistakes, 0);
      expect(tester.getRect(find.byType(ObjectChecklist)), checklist);
      final center = tester.getRect(find.byType(InteractiveViewer)).center;
      final scaleBeforePinch = viewer.transformationController!.value
          .getMaxScaleOnAxis();
      final left = await tester.startGesture(
        center - const Offset(40, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        center + const Offset(40, 0),
        pointer: 2,
      );
      await left.moveBy(const Offset(-30, 0));
      await right.moveBy(const Offset(30, 0));
      await app.pump(tester);
      await left.up();
      await right.up();
      await app.pump(tester);
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(scaleBeforePinch),
      );
      expect(saved(app).answersFound, 0);
      expect(saved(app).mistakes, 0);
      await app.tap(tester, find.byKey(const ValueKey('scene-reset')));
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(), 1);
      await app.tap(tester, find.byKey(const ValueKey('scene-zoom-in')));
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(1.25, .001),
      );
      await app.tapSceneObject(tester, puzzle, puzzle.answerIds.first);
      await app.until(tester, () => saved(app).answersFound == 1);
      expect(saved(app).mistakes, 0);
    } finally {
      await app.close(tester);
    }
  });

  testWidgets(
    'featured and reused scenes complete with real taps and unlock sequentially',
    (tester) async {
      final app = await AppHarness.forTest(tester);
      try {
        await app.mount(tester);
        final puzzles = app.services.content.puzzles.take(4).toList();
        await app.openPuzzle(tester, puzzles.first);
        for (final (index, puzzle) in puzzles.indexed) {
          expect(app.services.content.isUnlocked(puzzle), isTrue);
          await app.solvePuzzle(tester, puzzle);
          expect(
            find.byKey(const ValueKey('completion-panel')),
            findsOneWidget,
          );
          final record = app.services.progress.current.records[puzzle.id]!;
          expect(record.stars, 3);
          expect(record.accuracy, 1);
          expect(record.plays, 1);
          if (index < puzzles.length - 1) {
            await app.tap(tester, find.byKey(const ValueKey('next-puzzle')));
            await app.until(
              tester,
              () =>
                  app.services.progress.current.savedGame?.puzzleId ==
                  puzzles[index + 1].id,
            );
          }
        }
        expect(app.services.progress.current.completedLevels, 4);
        expect(app.requests, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await app.close(tester);
      }
    },
  );

  testWidgets(
    'Daily Challenge searches all three scenes and grants one set bonus',
    (tester) async {
      final app = await AppHarness.forTest(tester);
      try {
        await app.mount(tester);
        final daily = app.services.progress.current.daily.values.single;
        expect(daily.puzzles.map((p) => p.mode).toSet(), {GameMode.hidden});
        await app.openPuzzle(
          tester,
          daily.puzzles.first,
          dailyKey: daily.dayKey,
        );
        for (final (index, puzzle) in daily.puzzles.indexed) {
          await app.solvePuzzle(tester, puzzle);
          if (index < 2) {
            await app.tap(tester, find.byKey(const ValueKey('next-puzzle')));
            await app.until(
              tester,
              () =>
                  app.services.progress.current.savedGame?.puzzleId ==
                  daily.puzzles[index + 1].id,
            );
          }
        }
        final completed = app.services.progress.current.daily[daily.dayKey]!;
        expect(completed.completed, isTrue);
        expect(completed.bonusClaimed, isTrue);
        final expectedCoins =
            AppConfig.initialCoins +
            AppConfig.dailyBonus +
            daily.puzzles.fold<int>(0, (coins, p) => coins + p.reward + 15);
        expect(app.services.progress.current.coins, expectedCoins);
        await app.go(tester, '/daily');
        expect(app.requests, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await app.close(tester);
      }
    },
  );

  testWidgets(
    'failed area-hint transaction rolls back coins and retries cleanly',
    (tester) async {
      final app = await AppHarness.forTest(tester);
      try {
        await app.mount(tester);
        await app.openPuzzle(tester, app.services.content.puzzles.first);
        await failSessionWrites(tester, app);
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(
          tester,
          () => find
              .text('The hint could not be saved. No puzzle progress was lost.')
              .evaluate()
              .isNotEmpty,
        );
        expect(app.services.progress.current.coins, 100);
        expect(saved(app).hints, 0);
        expect(saved(app).hintObjectId, isNull);
        await allowSessionWrites(tester, app);
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(tester, () => saved(app).hints == 1);
        expect(app.services.progress.current.coins, 80);
        expect(saved(app).hintRevealed, isFalse);
      } finally {
        await app.close(tester);
      }
    },
  );

  testWidgets(
    'failed free reveal preserves the paid hint without an extra charge',
    (tester) async {
      final app = await AppHarness.forTest(tester);
      try {
        await app.mount(tester);
        await app.openPuzzle(tester, app.services.content.puzzles.first);
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(tester, () => saved(app).hints == 1);
        await failSessionWrites(tester, app);
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(
          tester,
          () => find
              .textContaining('The reveal could not be saved.')
              .evaluate()
              .isNotEmpty,
        );
        expect(app.services.progress.current.coins, 80);
        expect(saved(app).hintRevealed, isFalse);
        expect(saved(app).hints, 1);
        expect(saved(app).answersFound, 0);
        await allowSessionWrites(tester, app);
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(tester, () => saved(app).hintRevealed);
        expect(app.services.progress.current.coins, 80);
        expect(saved(app).hints, 1);
        expect(saved(app).answersFound, 0);
      } finally {
        await app.close(tester);
      }
    },
  );

  testWidgets(
    'backgrounding during both hint writes cannot overwrite the committed stage',
    (tester) async {
      final gate = WriteGate();
      final app = await AppHarness.forTest(tester, interceptor: gate);
      try {
        await app.mount(tester);
        final puzzle = app.services.content.puzzles.first;
        await app.openPuzzle(tester, puzzle);
        gate.holdNextInsert(
          (sql, args) => sql.contains('wallet_entries') && args.contains(-20),
        );
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(tester, () => gate.waiting);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await app.pump(tester);
        gate.release();
        await app.until(tester, () => saved(app).hints == 1);
        expect(find.byKey(const ValueKey('resume-game')), findsOneWidget);
        expect(saved(app).hintRevealed, isFalse);
        expect(app.services.progress.current.coins, 80);
        final elapsed = saved(app).elapsedMs;
        await app.pump(tester, const Duration(minutes: 2));
        expect(saved(app).elapsedMs, elapsed);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await app.pump(tester);
        await app.tap(tester, find.byKey(const ValueKey('resume-game')));
        gate.holdNextInsert(
          (sql, args) =>
              sql.contains('local_entries') &&
              args.any(
                (a) =>
                    a is String &&
                    a.contains('"hintRevealed":true') &&
                    a.contains('"hintObjectId":"${puzzle.answerIds.first}"'),
              ),
        );
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(tester, () => gate.waiting);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await app.pump(tester);
        gate.release();
        await app.until(tester, () => saved(app).hintRevealed);
        expect(find.byKey(const ValueKey('resume-game')), findsOneWidget);
        expect(saved(app).hints, 1);
        expect(saved(app).answersFound, 0);
        expect(app.services.progress.current.coins, 80);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await app.pump(tester);
        await app.tap(tester, find.byKey(const ValueKey('resume-game')));
        expect(
          tester.widget<SceneBoard>(find.byType(SceneBoard)).hintIsPrecise,
          isTrue,
        );
      } finally {
        gate.release();
        await app.close(tester);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    },
  );

  testWidgets(
    'leaving during a paid hint keeps its durable save for reopening',
    (tester) async {
      final gate = WriteGate();
      final app = await AppHarness.forTest(tester, interceptor: gate);
      try {
        await app.mount(tester);
        final puzzle = app.services.content.puzzles.first;
        await app.openPuzzle(tester, puzzle);
        gate.holdNextInsert(
          (sql, args) => sql.contains('wallet_entries') && args.contains(-20),
        );
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(tester, () => gate.waiting);
        await app.go(tester, '/');
        gate.release();
        await app.until(tester, () => saved(app).hints == 1);
        await app.openPuzzle(tester, puzzle, resume: true);
        expect(app.services.progress.current.coins, 80);
        expect(saved(app).hintRevealed, isFalse);
        expect(saved(app).answersFound, 0);
        expect(find.text('Reveal object · free'), findsOneWidget);
      } finally {
        gate.release();
        await app.close(tester);
      }
    },
  );

  testWidgets(
    'insufficient funds offer only earned coins and leave an unpaid target hidden',
    (tester) async {
      final app = await AppHarness.forTest(tester);
      try {
        final puzzle = app.services.content.puzzles.first;
        await tester.runAsync(() async {
          for (var i = 0; i < 5; i++) {
            await app.services.purchaseHint(
              GameEngine(puzzle, sessionId: 'spend-$i'),
            );
          }
          await app.services.progress.clearSession();
        });
        await app.mount(tester);
        await app.openPuzzle(tester, puzzle);
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        expect(
          find.textContaining('No purchase or ad is required.'),
          findsOneWidget,
        );
        expect(app.services.progress.current.coins, 0);
        expect(saved(app).hints, 0);
        expect(saved(app).hintObjectId, isNull);
        await app.tap(tester, find.text('I’ll keep looking'));
        expect(find.byType(SceneBoard), findsOneWidget);
        expect(app.requests, isEmpty);
      } finally {
        await app.close(tester);
      }
    },
  );

  testWidgets(
    'non-hidden, locked, and unauthorized daily routes preserve the active save',
    (tester) async {
      final app = await AppHarness.forTest(tester);
      try {
        await app.mount(tester);
        final puzzle = app.services.content.puzzles.first;
        await app.openPuzzle(tester, puzzle);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await app.pump(tester);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await app.pump(tester);
        final before = deepJson(
          app.services.progress.current.savedGame!.toJson(),
        );
        for (final slug in [
          'spot',
          'odd',
          'memory',
          'quick',
          'daily',
          'unknown',
        ]) {
          await app.go(tester, '/mode/$slug');
          expect(find.text('A little off the beaten path.'), findsOneWidget);
          expect(find.byType(SceneBoard), findsNothing);
        }
        final daily = app.services.progress.current.daily.values.single;
        for (final route in [
          '/play/odd-001?resume=1',
          '/play/hidden-002',
          '/play/${daily.puzzles.first.id}',
          '/play/${daily.puzzles.first.id}?daily=2020-01-01',
        ]) {
          await app.go(tester, route);
          expect(find.text('This discovery is waiting'), findsOneWidget);
          expect(find.byKey(const ValueKey('hint-button')), findsNothing);
        }
        expect(app.services.progress.current.savedGame!.toJson(), before);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await app.openPuzzle(tester, puzzle, resume: true);
        expect(saved(app).sessionId, before['engine']['sessionId']);
        final unsupported = GameEngine(
          changePuzzle(fixture(GameMode.odd), {'id': puzzle.id}),
        );
        Future<void> writeUnsupportedFixture() async {
          // A live app's serialized writes can depend on callbacks in the
          // test's fake clock. Keep pumping them instead of entering runAsync
          // and waiting forever on a queue owned by the suspended test zone.
          var written = false;
          final writing = app.services.saveGame(unsupported).then((_) {
            written = true;
          });
          await app.until(
            tester,
            () => written,
            reason: 'The unsupported resume fixture was not saved.',
          );
          await writing;
        }

        await writeUnsupportedFixture();
        await app.go(tester, '/');
        // Re-save after disposal of the previous hidden scene so this collision
        // fixture exercises the resume boundary, not an earlier autosave.
        await writeUnsupportedFixture();
        await app.go(tester, '/play/${puzzle.id}?resume=1');
        expect(
          find.text('Only hidden-object searches are available in this app.'),
          findsOneWidget,
        );
        expect(find.byType(SceneBoard), findsNothing);
        expect(saved(app).puzzle.mode, GameMode.odd);
      } finally {
        await app.close(tester);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
    },
  );

  testWidgets(
    'timed search pauses in the background and can restart without a countdown',
    (tester) async {
      final app = await AppHarness.forTest(
        tester,
        settings: const GameSettings(relaxed: false),
      );
      try {
        await app.mount(tester);
        final puzzle = app.services.content.puzzles.first;
        await app.openPuzzle(tester, puzzle);
        expect(saved(app).timed, isTrue);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await app.pump(tester);
        final elapsed = saved(app).elapsedMs;
        await app.pump(tester, const Duration(hours: 1));
        expect(saved(app).elapsedMs, elapsed);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await app.pump(tester);
        await app.tap(tester, find.byKey(const ValueKey('resume-game')));
        await app.pump(tester, Duration(seconds: puzzle.timeLimitSeconds + 1));
        expect(find.byKey(const ValueKey('retry-game')), findsOneWidget);
        await app.tap(tester, find.text('Try without the countdown'));
        await app.until(tester, () => saved(app).relaxed);
        expect(saved(app).timed, isFalse);
        expect(find.byType(SceneBoard), findsOneWidget);
      } finally {
        await app.close(tester);
      }
    },
  );
}
