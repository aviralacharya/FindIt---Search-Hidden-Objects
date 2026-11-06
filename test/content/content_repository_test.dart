import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:findit/core/content/content_repository.dart';
import 'package:findit/core/content/puzzle_generator.dart';
import 'package:findit/core/domain/game_engine.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:findit/core/storage/database.dart';
import 'package:findit/core/storage/progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/puzzles.dart';

Map<String, dynamic> pack({
  String id = 'test-expansion',
  String puzzleId = 'expansion-hidden-one',
  int seed = 987654321,
}) => {
  'schemaVersion': 1,
  'contentVersion': 1,
  'packId': id,
  'title': 'A few more little discoveries',
  'license': 'Original test fixtures for FindIt; no external artwork.',
  'puzzles': [
    PuzzleGenerator.generate(
      GameMode.hidden,
      seed: seed,
      level: 61,
      id: puzzleId,
    ).toJson(),
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProgressRepository progress;
  late ContentRepository content;
  late Map<String, dynamic> response;
  late int requests;
  setUp(() async {
    progress = ProgressRepository(FindItDatabase(NativeDatabase.memory()));
    await progress.initialize();
    response = pack();
    requests = 0;
    content = ContentRepository(
      progress,
      client: MockClient((request) async {
        requests++;
        return http.Response(
          jsonEncode(response),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await content.initialize();
  });
  tearDown(() async {
    content.close();
    await progress.close();
  });

  test(
    'initialization is local and mode progression unlocks only on completion',
    () async {
      expect(requests, 0);
      expect(content.length, 60);
      for (final mode in [GameMode.hidden]) {
        final levels = content.forMode(mode);
        expect(content.isUnlocked(levels.first), isTrue);
        expect(content.isUnlocked(levels[1]), isFalse);
        expect(content.next(levels.first)!.id, levels[1].id);
        expect(content.next(levels.last), isNull);
        await progress.complete(
          solve(levels.first, sessionId: 'unlock-${mode.slug}'),
        );
        expect(content.isUnlocked(levels[1]), isTrue);
        expect(content.isUnlocked(levels[2]), isFalse);
      }
      expect(content.find('missing-puzzle'), isNull);
    },
  );

  test(
    'find resolves persisted daily puzzles and the active session',
    () async {
      final daily = await progress.ensureDaily(DateTime(2026, 11, 4));
      expect(
        content.find(daily.puzzles.first.id)!.toJson(),
        daily.puzzles.first.toJson(),
      );
      final outside = PuzzleGenerator.generate(
        GameMode.hidden,
        seed: 10,
        level: 1,
        id: 'saved-fixture',
      );
      await progress.saveSession(GameEngine(outside));
      expect(content.find(outside.id)!.toJson(), outside.toJson());
    },
  );

  test(
    'valid packs commit before exposure, work offline, and match a checksum',
    () async {
      final digest = sha256
          .convert(utf8.encode(jsonEncode(response)))
          .toString();
      final installed = await content.downloadPack(
        Uri.parse('https://publisher.example/pack.json'),
        expectedSha256: digest.toUpperCase(),
      );
      expect(installed.count, 1);
      expect(content.length, 61);
      expect(content.find('expansion-hidden-one'), isNotNull);
      expect(await progress.installedPacks(), hasLength(1));
      final offline = ContentRepository(
        progress,
        client: MockClient((_) async => throw StateError('offline')),
      );
      await offline.initialize();
      expect(offline.length, 61);
      expect(offline.find('expansion-hidden-one'), isNotNull);
      offline.close();
    },
  );

  test(
    'non-hidden packs and saved engines are never exposed by this app',
    () async {
      for (final mode in GameMode.values.where(
        (m) => m != GameMode.hidden && m != GameMode.daily,
      )) {
        final outside = PuzzleGenerator.generate(
          mode,
          seed: stableSeed('unsupported-${mode.slug}'),
          level: 61,
          id: 'unsupported-${mode.slug}',
        );
        response = pack()..['puzzles'] = [outside.toJson()];
        await expectLater(
          content.downloadPack(
            Uri.parse('https://publisher.example/pack.json'),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('hidden-object scenes only'),
            ),
          ),
        );
        await progress.saveSession(GameEngine(outside));
        expect(content.find(outside.id), isNull);
        expect(content.forMode(mode), isEmpty);
        expect(content.length, 60);
        expect(await progress.installedPacks(), isEmpty);
      }
    },
  );

  test(
    'an unsupported stored pack is refused without deleting its durable data',
    () async {
      final unsupported = pack()
        ..['puzzles'] = [
          PuzzleGenerator.generate(
            GameMode.odd,
            seed: stableSeed('stored-unsupported'),
            level: 61,
            id: 'stored-unsupported',
          ).toJson(),
        ];
      await progress.savePack('test-expansion', unsupported);
      final offline = ContentRepository(
        progress,
        client: MockClient((_) async => throw StateError('offline')),
      );
      try {
        await expectLater(offline.initialize(), throwsFormatException);
        expect(offline.length, 60);
        expect(offline.forMode(GameMode.odd), isEmpty);
        expect(
          jsonDecode((await progress.installedPacks()).single),
          unsupported,
        );
      } finally {
        offline.close();
      }
    },
  );

  test(
    'unsafe URLs and mismatched checksums leave the collection unchanged',
    () async {
      for (final uri in [
        'http://publisher.example/pack.json',
        'https://user:password@publisher.example/pack.json',
        'https://publisher.example/pack.json#fragment',
      ]) {
        await expectLater(
          content.downloadPack(Uri.parse(uri)),
          throwsFormatException,
        );
      }
      expect(requests, 0);
      await expectLater(
        content.downloadPack(
          Uri.parse('https://publisher.example/pack.json'),
          expectedSha256: '0' * 64,
        ),
        throwsFormatException,
      );
      expect(content.length, 60);
      expect(await progress.installedPacks(), isEmpty);
    },
  );

  test(
    'duplicate IDs, padded repeats, and reserved daily IDs are rejected',
    () async {
      final url = Uri.parse('https://publisher.example/pack.json');
      response['puzzles'] = [fixture(GameMode.hidden, level: 4).toJson()];
      await expectLater(content.downloadPack(url), throwsA(isA<Exception>()));
      final repeated = fixture(GameMode.hidden, level: 4).toJson()
        ..['id'] = 'different-label-same-puzzle';
      response['puzzles'] = [repeated];
      await expectLater(content.downloadPack(url), throwsFormatException);
      response = pack(puzzleId: 'daily-not-allowed');
      await expectLater(content.downloadPack(url), throwsFormatException);
      expect(await progress.installedPacks(), isEmpty);
      expect(content.length, 60);
    },
  );

  test(
    'unlicensed or malformed content is never partially installed',
    () async {
      final url = Uri.parse('https://publisher.example/pack.json');
      response.remove('license');
      await expectLater(content.downloadPack(url), throwsFormatException);
      response = pack()..['schemaVersion'] = 2;
      await expectLater(content.downloadPack(url), throwsFormatException);
      response = pack();
      ((response['puzzles'] as List).first as Map<String, dynamic>)['scene'] =
          null;
      await expectLater(content.downloadPack(url), throwsA(isA<Exception>()));
      expect(content.packs, hasLength(1));
      expect(content.length, 60);
      expect(await progress.installedPacks(), isEmpty);
    },
  );

  test('remote asset references are removed; only declarative vector data is rendered', () async {
    final scene = PuzzleGenerator.generate(
      GameMode.hidden,
      seed: 123456,
      level: 61,
      id: 'expansion-scene',
    ).toJson();
    scene['imageA'] = 'https://publisher.example/tracking.png';
    scene['imageB'] = '../../unsafe.png';
    response['puzzles'] = [scene];
    await content.downloadPack(
      Uri.parse('https://publisher.example/pack.json'),
    );
    expect(content.find('expansion-scene')!.imageA, isNull);
    expect(content.find('expansion-scene')!.imageB, isNull);
    expect(content.find('expansion-scene')!.scene, isNotNull);
    expect(requests, 1);
    final stored = (await progress.installedPacks()).single;
    expect(stored, isNot(contains('tracking.png')));
    expect(stored, isNot(contains('unsafe.png')));
  });

  test('HTTP failures, redirect responses, and declared oversized bodies install nothing', () async {
    for (final status in [302, 404, 500]) {
      final failed = ContentRepository(
        progress,
        client: MockClient((_) async => http.Response('error', status)),
      );
      await failed.initialize();
      await expectLater(
        failed.downloadPack(Uri.parse('https://publisher.example/pack.json')),
        throwsStateError,
      );
      expect(failed.length, 60);
      failed.close();
    }
    final oversized = ContentRepository(
      progress,
      client: MockClient.streaming(
        (request, _) async => http.StreamedResponse(
          const Stream<List<int>>.empty(),
          200,
          contentLength: 8 * 1024 * 1024 + 1,
        ),
      ),
    );
    await oversized.initialize();
    await expectLater(
      oversized.downloadPack(Uri.parse('https://publisher.example/pack.json')),
      throwsFormatException,
    );
    expect(await progress.installedPacks(), isEmpty);
    oversized.close();
  });

  test('streamed size limit and broken connections are fail-safe', () async {
    final oversized = ContentRepository(
      progress,
      client: MockClient.streaming(
        (request, _) async => http.StreamedResponse(
          Stream.value(List<int>.filled(8 * 1024 * 1024 + 1, 32)),
          200,
        ),
      ),
    );
    await oversized.initialize();
    await expectLater(
      oversized.downloadPack(Uri.parse('https://publisher.example/pack.json')),
      throwsFormatException,
    );
    oversized.close();
    final offline = ContentRepository(
      progress,
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await offline.initialize();
    await expectLater(
      offline.downloadPack(Uri.parse('https://publisher.example/pack.json')),
      throwsA(isA<http.ClientException>()),
    );
    expect(await progress.installedPacks(), isEmpty);
    offline.close();
  });

  test(
    'two concurrent downloads of the same pack can install only once',
    () async {
      final results = await Future.wait([
        content
            .downloadPack(Uri.parse('https://publisher.example/pack.json'))
            .then<Object>((v) => v, onError: (Object e) => e),
        content
            .downloadPack(Uri.parse('https://publisher.example/pack.json'))
            .then<Object>((v) => v, onError: (Object e) => e),
      ]);
      expect(results.whereType<ContentPack>(), hasLength(1));
      expect(content.length, 61);
      expect(await progress.installedPacks(), hasLength(1));
    },
  );

  test(
    'concurrent different pack IDs cannot persist conflicting puzzle content',
    () async {
      final gated = Completer<void>();
      var started = 0;
      final racing = ContentRepository(
        progress,
        client: MockClient((request) async {
          if (++started == 2) gated.complete();
          await gated.future;
          return http.Response(
            jsonEncode(
              pack(
                id: request.url.path.contains('one') ? 'pack-one' : 'pack-two',
              ),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await racing.initialize();
      final results = await Future.wait([
        racing
            .downloadPack(Uri.parse('https://publisher.example/one.json'))
            .then<Object>((v) => v, onError: (Object e) => e),
        racing
            .downloadPack(Uri.parse('https://publisher.example/two.json'))
            .then<Object>((v) => v, onError: (Object e) => e),
      ]);
      expect(results.whereType<ContentPack>(), hasLength(1));
      expect(racing.length, 61);
      expect(await progress.installedPacks(), hasLength(1));
      final reopened = ContentRepository(progress);
      await reopened.initialize();
      expect(reopened.length, 61);
      reopened.close();
      racing.close();
    },
  );

  test(
    'concurrent relabeled repeats are rejected before their durable save',
    () async {
      final racing = ContentRepository(
        progress,
        client: MockClient((request) async {
          final one = request.url.path.contains('one');
          return http.Response(
            jsonEncode(
              pack(
                id: one ? 'pack-one' : 'pack-two',
                puzzleId: one ? 'unique-id-one' : 'unique-id-two',
              ),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await racing.initialize();
      try {
        final results = await Future.wait([
          racing
              .downloadPack(Uri.parse('https://publisher.example/one.json'))
              .then<Object>((v) => v, onError: (Object e) => e),
          racing
              .downloadPack(Uri.parse('https://publisher.example/two.json'))
              .then<Object>((v) => v, onError: (Object e) => e),
        ]);
        expect(results.whereType<ContentPack>(), hasLength(1));
        expect(racing.length, 61);
        expect(await progress.installedPacks(), hasLength(1));
      } finally {
        racing.close();
      }
    },
  );

  test(
    'distinct concurrent packs both install and reopen successfully',
    () async {
      final racing = ContentRepository(
        progress,
        client: MockClient((request) async {
          final one = request.url.path.contains('one');
          return http.Response(
            jsonEncode(
              pack(
                id: one ? 'pack-one' : 'pack-two',
                puzzleId: one ? 'unique-id-one' : 'unique-id-two',
                seed: one ? 111222333 : 444555666,
              ),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await racing.initialize();
      try {
        await Future.wait([
          racing.downloadPack(Uri.parse('https://publisher.example/one.json')),
          racing.downloadPack(Uri.parse('https://publisher.example/two.json')),
        ]);
        expect(racing.length, 62);
        expect(await progress.installedPacks(), hasLength(2));
        final reopened = ContentRepository(progress);
        try {
          await reopened.initialize();
          expect(reopened.length, 62);
        } finally {
          reopened.close();
        }
      } finally {
        racing.close();
      }
    },
  );

  test(
    'a failed pack save exposes nothing and does not poison the install queue',
    () async {
      await progress.db.customStatement("""
      CREATE TEMP TRIGGER fail_pack BEFORE INSERT ON local_entries
      WHEN NEW.key LIKE 'pack:%'
      BEGIN SELECT RAISE(ABORT, 'simulated full disk'); END
    """);
      final uri = Uri.parse('https://publisher.example/pack.json');
      await expectLater(content.downloadPack(uri), throwsA(isA<Exception>()));
      expect(content.length, 60);
      expect(content.packs, hasLength(1));
      expect(await progress.installedPacks(), isEmpty);
      await progress.db.customStatement('DROP TRIGGER fail_pack');
      await content.downloadPack(uri);
      expect(content.length, 61);
      expect(await progress.installedPacks(), hasLength(1));
    },
  );
}
