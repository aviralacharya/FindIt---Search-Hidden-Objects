import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:findit/core/config/app_config.dart';
import 'package:findit/core/domain/game_engine.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:findit/core/storage/database.dart';
import 'package:findit/core/storage/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/puzzles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FindItDatabase db;
  late ProgressRepository repository;
  setUp(() async {
    db = FindItDatabase(NativeDatabase.memory());
    repository = ProgressRepository(db);
    await repository.initialize();
  });
  tearDown(() => repository.close());

  test('welcome balance is durable and initialization is idempotent', () async {
    expect(repository.current.coins, AppConfig.initialCoins);
    expect(repository.current.earnedCoins, 0);
    await repository.initialize();
    expect(repository.current.coins, AppConfig.initialCoins);
    expect(await db.select(db.walletEntries).get(), hasLength(1));
  });

  test(
    'concurrent completions have one receipt, one play, and one wallet grant',
    () async {
      final game = solve(
        fixture(GameMode.differences),
        sessionId: 'same-completion',
      );
      await repository.saveSession(game);
      final receipts = await Future.wait(
        List.generate(12, (_) => repository.complete(game)),
      );
      expect(receipts.every((r) => r.firstCompletion), isTrue);
      expect(receipts.map((r) => jsonEncode(r.toJson())).toSet(), hasLength(1));
      expect(repository.current.coins, 100 + game.puzzle.reward + 15);
      expect(repository.current.records[game.puzzle.id]!.plays, 1);
      expect(repository.current.savedGame, isNull);
      expect(await db.select(db.walletEntries).get(), hasLength(2));
      expect(repository.current.achievements.first.unlocked, isTrue);
    },
  );

  test(
    'ordinary replays earn 10 coins and independently preserve personal bests',
    () async {
      final puzzle = fixture(GameMode.odd);
      final slow = GameEngine(puzzle, sessionId: 'slow-try')
        ..tick(9000)
        ..applyHint();
      solveRemaining(slow);
      final first = await repository.complete(slow);
      expect(first.stars, 2);
      final better = solve(
        puzzle,
        sessionId: 'better-try',
        millisecondsPerAnswer: 100,
      );
      final second = await repository.complete(better);
      expect(second.firstCompletion, isFalse);
      expect(second.coins, 10);
      final record = repository.current.records[puzzle.id]!;
      expect(record.stars, 3);
      expect(record.bestScore, better.score);
      expect(record.bestElapsedMs, better.elapsedMs);
      expect(record.accuracy, 1);
      expect(record.plays, 2);
      final worse = GameEngine(puzzle, sessionId: 'worse-try')..tick(15000);
      final wrong = worse.currentRound.tiles.asMap().keys.firstWhere(
        (i) => !worse.currentRound.answers.contains(i),
      );
      for (var i = 0; i < 8; i++) {
        worse.tapTile(wrong);
      }
      solveRemaining(worse);
      await repository.complete(worse);
      final finalRecord = repository.current.records[puzzle.id]!;
      expect(finalRecord.stars, record.stars);
      expect(finalRecord.bestScore, record.bestScore);
      expect(finalRecord.bestElapsedMs, record.bestElapsedMs);
      expect(finalRecord.accuracy, record.accuracy);
      expect(finalRecord.plays, 3);
    },
  );

  test(
    'concurrent hint requests charge once and atomically save the hint',
    () async {
      final original = GameEngine(
        fixture(GameMode.hidden),
        sessionId: 'same-hint',
      );
      await repository.saveSession(original);
      final results = await Future.wait(
        List.generate(8, (_) => repository.purchaseHint(original)),
      );
      expect(results.whereType<GameEngine>(), hasLength(1));
      expect(repository.current.coins, 80);
      expect(original.hints, 0);
      final saved = repository.current.savedGame!.restore();
      expect(saved.hints, 1);
      expect(saved.hintObjectId, isNotNull);
      expect(saved.completed, isFalse);
      expect(saved.answersFound, 0);
      expect(await repository.purchaseHint(original), isNull);
      expect(await repository.purchaseHint(saved), isNull);
      expect(repository.current.coins, 80);
    },
  );

  test(
    'insufficient funds never go negative or expose an unpaid hint',
    () async {
      for (var i = 0; i < 5; i++) {
        final game = GameEngine(fixture(GameMode.odd), sessionId: 'spend-$i');
        expect(await repository.purchaseHint(game), isNotNull);
      }
      final previous = deepJson(repository.current.savedGame!.toJson());
      final game = GameEngine(
        fixture(GameMode.quick),
        sessionId: 'insufficient',
      );
      expect(await repository.purchaseHint(game), isNull);
      expect(repository.current.coins, 0);
      expect(repository.current.savedGame!.toJson(), previous);
      expect(game.hints, 0);
    },
  );

  test(
    'a failed hint save rolls back the charge and permits a clean retry',
    () async {
      final game = GameEngine(
        fixture(GameMode.hidden),
        sessionId: 'hint-rollback',
      );
      await repository.saveSession(game);
      await db.customStatement("""
      CREATE TEMP TRIGGER fail_session BEFORE INSERT ON local_entries
      WHEN NEW.key = 'active-session'
      BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END
    """);
      await expectLater(
        repository.purchaseHint(game),
        throwsA(isA<Exception>()),
      );
      expect(repository.current.coins, 100);
      expect(repository.current.savedGame!.restore().hints, 0);
      expect(await db.select(db.walletEntries).get(), hasLength(1));
      await db.customStatement('DROP TRIGGER fail_session');
      expect(await repository.purchaseHint(game), isNotNull);
      expect(repository.current.coins, 80);
    },
  );

  test(
    'invalid or incomplete completions never commit partial rewards',
    () async {
      final unfinished = GameEngine(fixture(GameMode.odd));
      await expectLater(repository.complete(unfinished), throwsStateError);
      final game = solve(fixture(GameMode.odd), sessionId: 'invalid-daily');
      await expectLater(
        repository.complete(game, dailyKey: '2026-11-04'),
        throwsStateError,
      );
      expect(repository.current.coins, 100);
      expect(await db.select(db.levelResults).get(), isEmpty);
      expect(await db.select(db.walletEntries).get(), hasLength(1));
      final receipt = await repository.complete(game);
      expect(receipt.firstCompletion, isTrue);
    },
  );

  test('a failed completion receipt rolls back results, coins, and session deletion', () async {
    final game = solve(
      fixture(GameMode.memory),
      sessionId: 'completion-rollback',
    );
    await repository.saveSession(game);
    await db.customStatement("""
      CREATE TEMP TRIGGER fail_receipt BEFORE INSERT ON local_entries
      WHEN NEW.key LIKE 'receipt:%'
      BEGIN SELECT RAISE(ABORT, 'simulated receipt failure'); END
    """);
    await expectLater(repository.complete(game), throwsA(isA<Exception>()));
    expect(await db.select(db.levelResults).get(), isEmpty);
    expect(await db.select(db.walletEntries).get(), hasLength(1));
    expect(repository.current.savedGame!.restore().completed, isTrue);
    await db.customStatement('DROP TRIGGER fail_receipt');
    await repository.complete(repository.current.savedGame!.restore());
    expect(repository.current.savedGame, isNull);
    expect(repository.current.coins, 100 + game.puzzle.reward + 15);
  });

  test(
    'saved engines snapshot at invocation rather than queued-write time',
    () async {
      final game = GameEngine(
        fixture(GameMode.quick),
        sessionId: 'snapshot-time',
      );
      final saving = repository.saveSession(game);
      game.tick(9000);
      game.applyHint();
      await saving;
      final saved = repository.current.savedGame!.restore();
      expect(saved.elapsedMs, 0);
      expect(saved.hints, 0);
      expect(saved.hintTile, isNull);
    },
  );

  test(
    'an unreadable active save never hides completed levels or resets coins',
    () async {
      final completed = solve(fixture(GameMode.odd), sessionId: 'kept-result');
      await repository.complete(completed);
      final coins = repository.current.coins;
      final inconsistent = GameEngine(fixture(GameMode.quick)).toJson()
        ..['roundIndex'] = 10000;
      final invalidContent = GameEngine(fixture(GameMode.hidden)).toJson();
      (invalidContent['puzzle'] as Map<String, dynamic>)['title'] = '';
      for (final raw in [
        '{broken json',
        '[]',
        '{"engine":null}',
        jsonEncode({'engine': inconsistent}),
        jsonEncode({'engine': invalidContent}),
      ]) {
        await db
            .into(db.localEntries)
            .insertOnConflictUpdate(
              LocalEntriesCompanion.insert(key: 'active-session', payload: raw),
            );
        await repository.initialize();
        expect(repository.current.savedGame, isNull);
        expect(repository.current.savedGameError, isNotNull);
        expect(repository.current.coins, coins);
        expect(repository.current.records[completed.puzzle.id]!.plays, 1);
        final row = await (db.select(
          db.localEntries,
        )..where((table) => table.key.equals('active-session'))).getSingle();
        expect(
          row.payload,
          raw,
          reason: 'Unreadable data must not be deleted.',
        );
      }
      final fresh = GameEngine(
        fixture(GameMode.hidden),
        sessionId: 'fresh-save',
      );
      await repository.saveSession(fresh);
      expect(repository.current.savedGameError, isNull);
      expect(repository.current.savedGame!.restore().sessionId, 'fresh-save');
      expect(repository.current.coins, coins);
    },
  );

  test(
    'finishing an older session does not clear a different active puzzle',
    () async {
      final completed = solve(
        fixture(GameMode.odd),
        sessionId: 'older-completion',
      );
      final newer = GameEngine(
        fixture(GameMode.hidden),
        sessionId: 'newer-session',
      );
      await repository.saveSession(newer);
      await repository.complete(completed);
      expect(
        repository.current.savedGame!.restore().sessionId,
        'newer-session',
      );
      await repository.clearSession();
      expect(repository.current.savedGame, isNull);
    },
  );

  test(
    'legacy wallet entries remain spendable without an ad reward service',
    () async {
      // Model data written by an older build, not a new ad grant API.
      await db
          .into(db.walletEntries)
          .insert(
            WalletEntriesCompanion.insert(
              eventId: 'ad:legacy-native-event',
              amount: 40,
              reason: 'optional-ad',
              createdAt: DateTime(2026, 11, 4),
            ),
          );
      await repository.initialize();
      expect(repository.current.coins, 140);
      expect(repository.current.earnedCoins, 40);
      final hinted = await repository.purchaseHint(
        GameEngine(fixture(GameMode.hidden), sessionId: 'spend-legacy-coins'),
      );
      expect(hinted!.hints, 1);
      expect(repository.current.coins, 120);
      await repository.initialize();
      expect(repository.current.coins, 120);
      final legacy = await (db.select(
        db.walletEntries,
      )..where((t) => t.eventId.equals('ad:legacy-native-event'))).getSingle();
      expect(legacy.amount, 40);
      expect(legacy.reason, 'optional-ad');
    },
  );

  test(
    'daily selection is persisted, not regenerated or overwritten',
    () async {
      final date = DateTime(2026, 11, 4);
      final results = await Future.wait(
        List.generate(8, (_) => repository.ensureDaily(date)),
      );
      expect(results.map((d) => jsonEncode(d.toJson())).toSet(), hasLength(1));
      final stored = deepJson(results.first.toJson());
      ((stored['puzzles'] as List).first as Map<String, dynamic>)['title'] =
          'Saved editorial title';
      await db
          .into(db.localEntries)
          .insertOnConflictUpdate(
            LocalEntriesCompanion.insert(
              key: 'daily:2026-11-04',
              payload: jsonEncode(stored),
            ),
          );
      final next = await repository.ensureDaily(date);
      expect(next.puzzles.first.title, 'Saved editorial title');
    },
  );

  test('daily puzzles require their persisted date and membership', () async {
    final daily = await repository.ensureDaily(DateTime(2026, 11, 4));
    final game = solve(daily.puzzles.first, sessionId: 'daily-missing-key');
    await expectLater(repository.complete(game), throwsStateError);
    final other = await repository.ensureDaily(DateTime(2026, 11, 5));
    await expectLater(
      repository.complete(game, dailyKey: other.dayKey),
      throwsStateError,
    );
    expect(repository.current.coins, 100);
    expect(repository.current.records, isEmpty);
    await repository.complete(game, dailyKey: daily.dayKey);
    expect(repository.current.daily[daily.dayKey]!.completedIds, {
      game.puzzle.id,
    });
    expect(repository.current.achievements.first.unlocked, isTrue);
    expect(repository.current.completedLevels, 0);
  });

  test(
    'daily completion and replays grant the set bonus exactly once',
    () async {
      final daily = await repository.ensureDaily(DateTime(2028, 2, 29));
      var expected = 100;
      for (var i = 0; i < daily.puzzles.length; i++) {
        final game = solve(daily.puzzles[i], sessionId: 'daily-first-$i');
        final receipt = await repository.complete(game, dailyKey: daily.dayKey);
        expected += game.puzzle.reward + 15;
        expect(receipt.dailyBonus, i == 2 ? 60 : 0);
      }
      expected += 60;
      expect(repository.current.coins, expected);
      expect(repository.current.daily[daily.dayKey]!.bonusClaimed, isTrue);
      for (var i = 0; i < daily.puzzles.length; i++) {
        final receipt = await repository.complete(
          solve(daily.puzzles[i], sessionId: 'daily-replay-$i'),
          dailyKey: daily.dayKey,
        );
        expect(receipt.coins, 0);
        expect(receipt.dailyBonus, 0);
        expect(receipt.firstCompletion, isFalse);
      }
      expect(repository.current.coins, expected);
      final bonusRows = await (db.select(
        db.walletEntries,
      )..where((t) => t.reason.equals('daily'))).get();
      expect(bonusRows, hasLength(1));
    },
  );

  test(
    'late completion rewards the original date, not the new daily set',
    () async {
      final old = await repository.ensureDaily(DateTime(2026, 12, 31));
      final game = solve(old.puzzles.first, sessionId: 'across-midnight');
      await repository.saveSession(game, dailyKey: old.dayKey);
      final today = await repository.ensureDaily(DateTime(2027, 1, 1));
      await repository.complete(
        repository.current.savedGame!.restore(),
        dailyKey: old.dayKey,
      );
      expect(repository.current.daily[old.dayKey]!.completedIds, {
        game.puzzle.id,
      });
      expect(repository.current.daily[today.dayKey]!.completedIds, isEmpty);
    },
  );

  test('concurrent pack writes cannot overwrite an installed pack', () async {
    final first = {'schemaVersion': 1, 'marker': 'first'};
    final second = {'schemaVersion': 1, 'marker': 'second'};
    final saved = repository.savePack('sample-pack', first);
    final duplicate = repository.savePack('sample-pack', second);
    await saved;
    await expectLater(duplicate, throwsA(isA<Exception>()));
    expect((await repository.installedPacks()).map(jsonDecode).single, first);
  });

  test(
    'reset preserves downloaded packs but deletes sessions and reward history',
    () async {
      await repository.savePack('kept-pack', {'marker': 'kept'});
      await repository.ensureDaily(DateTime(2026, 11, 4));
      await repository.complete(
        solve(fixture(GameMode.odd), sessionId: 'before-reset'),
      );
      await repository.saveSession(
        GameEngine(
          fixture(GameMode.hidden),
          sessionId: 'unfinished-before-reset',
        ),
      );
      await db
          .into(db.walletEntries)
          .insert(
            WalletEntriesCompanion.insert(
              eventId: 'ad:legacy-before-reset',
              amount: 40,
              reason: 'optional-ad',
              createdAt: DateTime(2026, 11, 4),
            ),
          );
      await repository.resetProgress();
      expect(repository.current.coins, 100);
      expect(repository.current.earnedCoins, 0);
      expect(repository.current.records, isEmpty);
      expect(repository.current.daily, isEmpty);
      expect(repository.current.savedGame, isNull);
      expect(await repository.installedPacks(), hasLength(1));
      expect(await db.select(db.walletEntries).get(), hasLength(1));
      expect(await db.select(db.localEntries).get(), hasLength(1));
    },
  );

  test('closing and reopening a real SQLite file retains rewards, hints, and daily dates', () async {
    // This test intentionally owns independent in-memory and on-disk executors.
    final warnBefore = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final parent = Directory(p.join(Directory.systemTemp.path, 'opencode'));
    await parent.create(recursive: true);
    final directory = await parent.createTemp('findit-persistence-');
    final file = File(p.join(directory.path, 'progress.sqlite'));
    ProgressRepository? disk;
    try {
      disk = ProgressRepository(FindItDatabase(NativeDatabase(file)));
      await disk.initialize();
      final daily = await disk.ensureDaily(DateTime(2028, 2, 29));
      await disk.complete(
        solve(daily.puzzles.first, sessionId: 'durable-daily'),
        dailyKey: daily.dayKey,
      );
      final hinted = await disk.purchaseHint(
        GameEngine(
          fixture(GameMode.hidden),
          sessionId: 'durable-hint',
          relaxed: true,
        ),
      );
      final coins = disk.current.coins;
      await disk.close();
      disk = ProgressRepository(FindItDatabase(NativeDatabase(file)));
      await disk.initialize();
      expect(disk.current.coins, coins);
      expect(disk.current.savedGame!.restore().toJson(), hinted!.toJson());
      expect(disk.current.daily[daily.dayKey]!.completedIds, {
        daily.puzzles.first.id,
      });
      expect(disk.current.records[daily.puzzles.first.id]!.plays, 1);
      await disk.complete(
        solve(daily.puzzles.first, sessionId: 'durable-daily'),
        dailyKey: daily.dayKey,
      );
      expect(disk.current.coins, coins);
      expect(disk.current.records[daily.puzzles.first.id]!.plays, 1);
    } finally {
      await disk?.close();
      await directory.delete(recursive: true);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = warnBefore;
    }
  });
}
