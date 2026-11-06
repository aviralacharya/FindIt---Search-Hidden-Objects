import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../config/app_config.dart';
import '../content/puzzle_validator.dart';
import '../domain/daily_challenge.dart';
import '../domain/game_engine.dart';
import '../domain/progress.dart';
import '../domain/puzzle.dart';
import 'database.dart';

class ProgressRepository {
  ProgressRepository(this.db);
  final FindItDatabase db;
  PlayerProgress current = const PlayerProgress();
  Future<void> _tail = Future.value();

  Future<T> _serialize<T>(Future<T> Function() action) async {
    final previous = _tail;
    final next = Completer<void>();
    _tail = next.future;
    await previous;
    try {
      return await action();
    } finally {
      next.complete();
    }
  }

  Future<void> initialize() => _serialize(() async {
    await db
        .into(db.walletEntries)
        .insert(
          WalletEntriesCompanion.insert(
            eventId: 'initial-v1',
            amount: AppConfig.initialCoins,
            reason: 'welcome',
            createdAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await _reload();
  });

  Future<int> _balance() async {
    final sum = db.walletEntries.amount.sum();
    final row = await (db.selectOnly(
      db.walletEntries,
    )..addColumns([sum])).getSingle();
    return row.read(sum) ?? 0;
  }

  Future<String?> _get(String key) async => (await (db.select(
    db.localEntries,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.payload;

  Future<void> _put(String key, Object payload) => db
      .into(db.localEntries)
      .insertOnConflictUpdate(
        LocalEntriesCompanion.insert(key: key, payload: jsonEncode(payload)),
      );

  Future<void> _reload() async {
    final rows = await db.select(db.levelResults).get();
    final entries = await db.select(db.localEntries).get();
    final positive = db.walletEntries.amount.sum();
    final earned =
        await (db.selectOnly(db.walletEntries)
              ..where(
                db.walletEntries.amount.isBiggerThanValue(0) &
                    db.walletEntries.reason.isNotValue('welcome'),
              )
              ..addColumns([positive]))
            .getSingle();
    SavedGame? saved;
    String? savedGameError;
    final daily = <String, DailyChallenge>{};
    for (final entry in entries) {
      if (entry.key == 'active-session') {
        // A malformed optional session must not make the wallet and completed
        // levels inaccessible. Preserve its raw row until a deliberate new game
        // replaces it; never reset the database or silently use memory storage.
        const unreadable =
            'Your unfinished puzzle couldn’t be read. Completed levels and coins are safe. Starting a new discovery replaces only the unreadable puzzle save.';
        try {
          final candidate = SavedGame.fromJson(
            jsonDecode(entry.payload) as Map<String, dynamic>,
          );
          if (PuzzleValidator.validate(candidate.restore().puzzle).isNotEmpty) {
            throw const FormatException('Invalid saved puzzle content.');
          }
          saved = candidate;
        } on FormatException {
          savedGameError = unreadable;
        } on TypeError {
          savedGameError = unreadable;
        } on ArgumentError {
          savedGameError = unreadable;
        }
      } else if (entry.key.startsWith('daily:')) {
        final challenge = DailyChallenge.fromJson(
          jsonDecode(entry.payload) as Map<String, dynamic>,
        );
        daily[challenge.dayKey] = challenge;
      }
    }
    current = PlayerProgress(
      coins: await _balance(),
      earnedCoins: earned.read(positive) ?? 0,
      records: {
        for (final row in rows)
          row.puzzleId: LevelRecord(
            id: row.puzzleId,
            mode: GameMode.fromSlug(row.mode),
            stars: row.stars,
            bestScore: row.bestScore,
            bestElapsedMs: row.bestElapsedMs,
            accuracy: row.bestAccuracy,
            bestCombo: row.bestCombo,
            plays: row.plays,
          ),
      },
      daily: daily,
      savedGame: saved,
      savedGameError: savedGameError,
    );
  }

  Future<void> saveSession(GameEngine engine, {String? dailyKey}) {
    // Snapshot at invocation time, not after another asynchronous write.
    final saved = SavedGame(engine.toJson(), dailyKey).toJson();
    return _serialize(() async {
      await _put('active-session', saved);
      await _reload();
    });
  }

  Future<void> clearSession() => _serialize(() async {
    await (db.delete(
      db.localEntries,
    )..where((t) => t.key.equals('active-session'))).go();
    await _reload();
  });

  Future<DailyChallenge> ensureDaily(DateTime date) => _serialize(() async {
    final key = localDayKey(date);
    final existing = await _get('daily:$key');
    if (existing != null) {
      return DailyChallenge.fromJson(
        jsonDecode(existing) as Map<String, dynamic>,
      );
    }
    final challenge = DailyChallenge.forDate(date);
    PuzzleValidator.validateCatalog(challenge.puzzles);
    await db
        .into(db.localEntries)
        .insert(
          LocalEntriesCompanion.insert(
            key: 'daily:$key',
            payload: jsonEncode(challenge.toJson()),
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await _reload();
    return current.daily[key]!;
  });

  Future<GameEngine?> purchaseHint(GameEngine engine, {String? dailyKey}) {
    if (!engine.canHint) return Future.value();
    final copy = GameEngine.restore(engine.toJson());
    if (!copy.applyHint()) return Future.value();
    return _serialize(() async {
      final granted = await db.transaction(() async {
        if (await _balance() < AppConfig.hintCost) return false;
        final event = 'hint:${copy.sessionId}:${copy.hints}';
        final already = await (db.select(
          db.walletEntries,
        )..where((t) => t.eventId.equals(event))).getSingleOrNull();
        if (already != null) return false;
        await db
            .into(db.walletEntries)
            .insert(
              WalletEntriesCompanion.insert(
                eventId: event,
                amount: -AppConfig.hintCost,
                reason: 'hint',
                createdAt: DateTime.now(),
              ),
            );
        await _put(
          'active-session',
          SavedGame(copy.toJson(), dailyKey).toJson(),
        );
        return true;
      });
      await _reload();
      return granted ? copy : null;
    });
  }

  Future<CompletionReceipt> complete(GameEngine engine, {String? dailyKey}) {
    if (!engine.completed) {
      return Future.error(
        StateError('Only completed puzzles earn completion rewards.'),
      );
    }
    if (engine.puzzle.id.startsWith('daily-') && dailyKey == null) {
      return Future.error(
        StateError('A daily puzzle requires its persisted day key.'),
      );
    }
    final snapshot = GameEngine.restore(engine.toJson());
    return _serialize(() async {
      final receipt = await db.transaction(() async {
        final receiptKey = 'receipt:${snapshot.sessionId}';
        final prior = await _get(receiptKey);
        if (prior != null) {
          return CompletionReceipt.fromJson(
            jsonDecode(prior) as Map<String, dynamic>,
          );
        }
        final puzzle = snapshot.puzzle;
        final old = await (db.select(
          db.levelResults,
        )..where((t) => t.puzzleId.equals(puzzle.id))).getSingleOrNull();
        final first = old == null;
        var coins = first ? puzzle.reward + snapshot.stars * 5 : 10;
        var bonus = 0;
        // Daily puzzle replays are fun, but cannot mint another daily reward.
        if (dailyKey != null && !first) coins = 0;
        await db
            .into(db.levelResults)
            .insertOnConflictUpdate(
              LevelResultsCompanion.insert(
                puzzleId: puzzle.id,
                mode: puzzle.mode.slug,
                stars: math.max(old?.stars ?? 0, snapshot.stars),
                bestScore: math.max(old?.bestScore ?? 0, snapshot.score),
                bestElapsedMs: math.min(
                  old?.bestElapsedMs ?? snapshot.elapsedMs,
                  snapshot.elapsedMs,
                ),
                bestAccuracy: math.max(
                  old?.bestAccuracy ?? 0,
                  snapshot.accuracy,
                ),
                bestCombo: math.max(old?.bestCombo ?? 0, snapshot.bestCombo),
                plays: (old?.plays ?? 0) + 1,
                completedAt: DateTime.now(),
              ),
            );
        await db
            .into(db.walletEntries)
            .insert(
              WalletEntriesCompanion.insert(
                eventId: 'complete:${snapshot.sessionId}',
                amount: coins,
                reason: first ? 'level' : 'replay',
                createdAt: DateTime.now(),
              ),
            );
        if (dailyKey != null) {
          final raw = await _get('daily:$dailyKey');
          if (raw == null) throw StateError('Daily selection was not saved.');
          var daily = DailyChallenge.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );
          if (!daily.puzzles.any((p) => p.id == puzzle.id)) {
            throw StateError('Puzzle is not in this daily set.');
          }
          daily = daily.complete(puzzle.id);
          if (daily.completed && !daily.bonusClaimed) {
            bonus = AppConfig.dailyBonus;
            await db
                .into(db.walletEntries)
                .insert(
                  WalletEntriesCompanion.insert(
                    eventId: 'daily-bonus:$dailyKey',
                    amount: bonus,
                    reason: 'daily',
                    createdAt: DateTime.now(),
                  ),
                  mode: InsertMode.insertOrIgnore,
                );
            daily = daily.complete(puzzle.id, bonusClaimed: true);
          }
          await _put('daily:$dailyKey', daily.toJson());
        }
        final result = CompletionReceipt(
          coins: coins,
          dailyBonus: bonus,
          stars: snapshot.stars,
          firstCompletion: first,
          score: snapshot.score,
        );
        await _put(receiptKey, result.toJson());
        final saved = await _get('active-session');
        if (saved != null &&
            (SavedGame.fromJson(jsonDecode(saved) as Map<String, dynamic>)
                    .engineJson['sessionId'] ==
                snapshot.sessionId)) {
          await (db.delete(
            db.localEntries,
          )..where((t) => t.key.equals('active-session'))).go();
        }
        return result;
      });
      await _reload();
      return receipt;
    });
  }

  Future<List<String>> installedPacks() async => (await (db.select(
    db.localEntries,
  )..where((t) => t.key.like('pack:%'))).get()).map((r) => r.payload).toList();

  Future<void> savePack(String id, Map<String, dynamic> pack) =>
      _serialize(() async {
        // Never overwrite an installed pack during two concurrent downloads.
        await db
            .into(db.localEntries)
            .insert(
              LocalEntriesCompanion.insert(
                key: 'pack:$id',
                payload: jsonEncode(pack),
              ),
            );
      });

  Future<void> resetProgress() => _serialize(() async {
    await db.transaction(() async {
      await db.delete(db.levelResults).go();
      await db.delete(db.walletEntries).go();
      await (db.delete(
        db.localEntries,
      )..where((t) => t.key.like('pack:%').not())).go();
      await db
          .into(db.walletEntries)
          .insert(
            WalletEntriesCompanion.insert(
              eventId: 'initial-v1',
              amount: AppConfig.initialCoins,
              reason: 'welcome',
              createdAt: DateTime.now(),
            ),
          );
    });
    await _reload();
  });

  Future<void> close() async {
    await _tail;
    await db.close();
  }
}
