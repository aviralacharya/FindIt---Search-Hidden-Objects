import 'dart:convert';

import 'package:findit/core/storage/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'default preferences allow immediate play and keep advertising off',
    () async {
      final settings = SettingsRepository(await SharedPreferences.getInstance())
        ..initialize();
      expect(settings.current.adsEnabled, isFalse);
      expect(settings.current.ageGroup, AgeGroup.unknown);
      expect(settings.current.relaxed, isTrue);
      expect(settings.current.sound, isTrue);
    },
  );

  test(
    'settings persist and round-trip inactive legacy preference fields',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsRepository(prefs)..initialize();
      final value = settings.current.copyWith(
        music: false,
        sound: false,
        vibration: false,
        musicVolume: .35,
        soundVolume: .75,
        relaxed: true,
        ageGroup: AgeGroup.adult,
        adsEnabled: true,
      );
      await settings.save(value);
      final reopened = SettingsRepository(prefs)..initialize();
      expect(reopened.current.toJson(), value.toJson());
      final stored = jsonDecode(
        prefs.getString('findit_hidden_objects-settings-v1')!,
      ) as Map<String, dynamic>;
      expect(stored.keys, isNot(contains('age')));
      expect(stored.keys, isNot(contains('birthday')));
      expect(stored['ageGroup'], 'adult');
    },
  );

  test('unknown age values fail closed and stored volume is bounded', () {
    final settings = GameSettings.fromJson({
      'ageGroup': 'not-a-real-group',
      'musicVolume': -100,
      'soundVolume': 100,
    });
    expect(settings.ageGroup, AgeGroup.unknown);
    expect(settings.adsEnabled, isFalse);
    expect(settings.musicVolume, 0);
    expect(settings.soundVolume, 1);
  });

  test(
    'hidden-object settings do not read or overwrite the original game',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final normal = SettingsRepository(
        prefs,
        preferenceKey: 'findit-settings-v1',
      )..initialize();
      await normal.save(
        const GameSettings(
          relaxed: false,
          ageGroup: AgeGroup.adult,
          adsEnabled: true,
        ),
      );
      final raw = prefs.getString('findit-settings-v1');
      final preview = SettingsRepository(prefs)..initialize();
      expect(preview.current.toJson(), const GameSettings().toJson());
      await preview.save(preview.current.copyWith(music: false));
      expect(prefs.getString('findit-settings-v1'), raw);
      expect(
        (SettingsRepository(
          prefs,
          preferenceKey: 'findit-settings-v1',
        )..initialize()).current.relaxed,
        isFalse,
      );
      expect(preview.current.ageGroup, AgeGroup.unknown);
      expect(preview.current.adsEnabled, isFalse);
    },
  );

  for (final raw in <Object>[
    '{broken json',
    '[]',
    '{"sound":"not a boolean","adsEnabled":true,"ageGroup":"adult"}',
    '{"soundVolume":"loud"}',
    123,
  ]) {
    test(
      'unreadable preferences use ad-free defaults and preserve raw data: $raw',
      () async {
        SharedPreferences.setMockInitialValues({
          'findit_hidden_objects-settings-v1': raw,
        });
        final prefs = await SharedPreferences.getInstance();
        final settings = SettingsRepository(prefs)..initialize();
        expect(settings.current.toJson(), const GameSettings().toJson());
        expect(settings.recoveryNotice, isNotNull);
        expect(prefs.get('findit_hidden_objects-settings-v1'), raw);
        await settings.save(settings.current.copyWith(relaxed: true));
        expect(settings.recoveryNotice, isNull);
        expect(settings.current.relaxed, isTrue);
        expect(settings.current.adsEnabled, isFalse);
        expect(settings.current.ageGroup, AgeGroup.unknown);
      },
    );
  }
}
