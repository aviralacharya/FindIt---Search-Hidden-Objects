import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/content/content_repository.dart';
import '../core/config/app_config.dart';
import '../core/domain/daily_challenge.dart';
import '../core/domain/game_engine.dart';
import '../core/domain/progress.dart';
import '../core/services/audio_service.dart';
import '../core/services/game_clock.dart';
import '../core/storage/connection.dart';
import '../core/storage/database.dart';
import '../core/storage/progress_repository.dart';
import '../core/storage/settings_repository.dart';

/// One owner for local resources. UI changes are published only after durable
/// repository writes; the game engine itself remains independent of the app.
class AppServices extends ChangeNotifier {
  AppServices._({
    required this.preferences,
    required this.progress,
    required this.settings,
    required this.content,
    required this.audio,
    required this.storageNamespace,
  });

  final SharedPreferences preferences;
  final ProgressRepository progress;
  final SettingsRepository settings;
  final ContentRepository content;
  final AudioService audio;
  final String storageNamespace;
  bool _closed = false;

  static Future<AppServices> create({
    FindItDatabase? database,
    SharedPreferences? preferences,
    http.Client? packClient,
    bool enablePlugins = true,
    String storageNamespace = AppConfig.storageNamespace,
  }) async {
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(storageNamespace)) {
      throw ArgumentError.value(storageNamespace, 'storageNamespace');
    }
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final settings = SettingsRepository(
      prefs,
      preferenceKey: '$storageNamespace-settings-v1',
    )..initialize();
    final progress = ProgressRepository(
      database ?? FindItDatabase(openConnection(name: storageNamespace)),
    );
    try {
      await progress.initialize();
      final content = ContentRepository(progress, client: packClient);
      await content.initialize();
      await progress.ensureDaily(DateTime.now());
      final audio = AudioService(settings.current, enabled: enablePlugins);
      await audio.configure(settings.current);
      final services = AppServices._(
        preferences: prefs,
        progress: progress,
        settings: settings,
        content: content,
        audio: audio,
        storageNamespace: storageNamespace,
      );
      return services;
    } catch (_) {
      await progress.close();
      rethrow;
    }
  }

  void changed() {
    if (!_closed) notifyListeners();
  }

  Future<void> beginPlay() async {
    unawaited(audio.startFromUserGesture());
    await preferences.setBool('$storageNamespace-has-played', true);
  }

  Future<void> updateSettings(GameSettings value) async {
    await settings.save(value);
    changed();
    await audio.configure(value);
  }

  Future<DailyChallenge> ensureDaily(DateTime date) async {
    final result = await progress.ensureDaily(date);
    changed();
    return result;
  }

  Future<void> saveGame(GameEngine engine, {String? dailyKey}) async {
    await progress.saveSession(engine, dailyKey: dailyKey);
    changed();
  }

  Future<CompletionReceipt> completeGame(
    GameEngine engine, {
    String? dailyKey,
  }) async {
    final receipt = await progress.complete(engine, dailyKey: dailyKey);
    changed();
    return receipt;
  }

  Future<GameEngine?> purchaseHint(
    GameEngine engine, {
    String? dailyKey,
  }) async {
    final result = await progress.purchaseHint(engine, dailyKey: dailyKey);
    changed();
    return result;
  }

  Future<void> resetProgress() async {
    await progress.resetProgress();
    await progress.ensureDaily(DateTime.now());
    changed();
  }

  Future<void> setForeground(bool value) async {
    await audio.setForeground(value);
    if (value) {
      try {
        await ensureDaily(DateTime.now());
      } catch (_) {
        // Screens report write errors when an action requires a save.
      }
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    content.close();
    await audio.dispose();
    await progress.close();
    super.dispose();
  }
}

final servicesProvider = Provider<AppServices>(
  (ref) => throw StateError(
    'AppServices must be initialized before the app is opened.',
  ),
);

final gameClockFactoryProvider = Provider<GameClock Function()>(
  (ref) => StopwatchGameClock.new,
);

class AppSnapshot {
  AppSnapshot(AppServices services)
    : progress = services.progress.current,
      settings = services.settings.current,
      settingsRecoveryNotice = services.settings.recoveryNotice,
      puzzleCount = services.content.length;
  final PlayerProgress progress;
  final GameSettings settings;
  final String? settingsRecoveryNotice;
  final int puzzleCount;
}

class AppController extends Notifier<AppSnapshot> {
  @override
  AppSnapshot build() {
    final services = ref.watch(servicesProvider);
    void update() => state = AppSnapshot(services);
    services.addListener(update);
    ref.onDispose(() => services.removeListener(update));
    return AppSnapshot(services);
  }
}

final appStateProvider = NotifierProvider<AppController, AppSnapshot>(
  AppController.new,
);
