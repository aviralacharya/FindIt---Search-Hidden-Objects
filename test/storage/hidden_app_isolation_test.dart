import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:findit/app/app_services.dart';
import 'package:findit/core/config/app_config.dart';
import 'package:findit/core/content/hidden_catalog.dart';
import 'package:findit/core/domain/game_engine.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:findit/core/storage/database.dart';
import 'package:findit/core/storage/progress_repository.dart';
import 'package:findit/core/storage/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/puzzles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'default app preferences ignore original and Ads Preview namespaces',
    () async {
      const originalSettings = '{"relaxed":false,"music":false}';
      const previewSettings = '{"relaxed":false,"sound":false}';
      SharedPreferences.setMockInitialValues({
        'findit-settings-v1': originalSettings,
        'findit-has-played': false,
        'findit_ad_preview-settings-v1': previewSettings,
        'findit_ad_preview-has-played': false,
      });
      final preferences = await SharedPreferences.getInstance();
      final services = await AppServices.create(
        database: FindItDatabase(NativeDatabase.memory()),
        preferences: preferences,
        enablePlugins: false,
      );
      try {
        expect(services.storageNamespace, 'findit_hidden_objects');
        expect(services.settings.current.relaxed, isTrue);
        expect(services.settings.current.music, isTrue);
        await services.beginPlay();
        await services.updateSettings(
          services.settings.current.copyWith(sound: false),
        );
        await services.resetProgress();
        expect(preferences.getString('findit-settings-v1'), originalSettings);
        expect(preferences.getBool('findit-has-played'), isFalse);
        expect(
          preferences.getString('findit_ad_preview-settings-v1'),
          previewSettings,
        );
        expect(preferences.getBool('findit_ad_preview-has-played'), isFalse);
        expect(
          preferences.getBool('${AppConfig.storageNamespace}-has-played'),
          isTrue,
        );
        expect(
          (jsonDecode(
            preferences.getString('${AppConfig.storageNamespace}-settings-v1')!,
          ) as Map)['sound'],
          isFalse,
        );
      } finally {
        await services.close();
      }
    },
  );

  test('independent SQLite files preserve original wallet and save through hidden reset', () async {
    final parent = Directory('build/verification-tests')
      ..createSync(recursive: true);
    final directory = parent.createTempSync('hidden-isolation-');
    final originalFile = File('${directory.path}/findit.sqlite');
    final hiddenFile = File(
      '${directory.path}/${AppConfig.storageNamespace}.sqlite',
    );
    final previousWarning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    ProgressRepository? original;
    ProgressRepository? hidden;
    try {
      original = ProgressRepository(
        FindItDatabase(NativeDatabase(originalFile)),
      );
      hidden = ProgressRepository(FindItDatabase(NativeDatabase(hiddenFile)));
      await original.initialize();
      await hidden.initialize();
      await original.complete(
        solve(fixture(GameMode.odd), sessionId: 'original-kept'),
      );
      await original.saveSession(
        GameEngine(fixture(GameMode.memory), sessionId: 'original-save'),
      );
      final originalBytes = originalFile.readAsBytesSync();
      final originalCoins = original.current.coins;
      final originalSave = deepJson(original.current.savedGame!.toJson());
      final puzzle = HiddenCatalog.launchCatalog().first;
      final area = (await hidden.purchaseHint(
        GameEngine(puzzle, sessionId: 'hidden-save'),
      ))!;
      expect(hidden.current.coins, 80);
      expect(area.revealHint(), isTrue);
      await hidden.saveSession(area);
      await hidden.close();
      hidden = ProgressRepository(FindItDatabase(NativeDatabase(hiddenFile)));
      await hidden.initialize();
      expect(hidden.current.savedGame!.restore().hintRevealed, isTrue);
      expect(hidden.current.savedGame!.restore().hints, 1);
      expect(hidden.current.savedGame!.restore().answersFound, 0);
      expect(hidden.current.coins, 80);
      await hidden.resetProgress();
      await original.initialize();
      expect(original.current.coins, originalCoins);
      expect(original.current.savedGame!.toJson(), originalSave);
      expect(original.current.records['odd-001']!.plays, 1);
      expect(originalFile.readAsBytesSync(), originalBytes);
      expect(hidden.current.coins, 100);
      expect(hidden.current.savedGame, isNull);
      expect(hidden.current.records, isEmpty);
    } finally {
      await hidden?.close();
      await original?.close();
      directory.deleteSync(recursive: true);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = previousWarning;
    }
  });

  test('unsafe namespaces are refused before opening local storage', () async {
    for (final namespace in [
      'findit/../original',
      '..',
      '',
      'hidden objects',
    ]) {
      await expectLater(
        AppServices.create(storageNamespace: namespace, enablePlugins: false),
        throwsArgumentError,
      );
    }
    expect(const GameSettings().relaxed, isTrue);
  });
}
