import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../storage/settings_repository.dart';

enum GameSound { found, wrong, hint, complete, tap }

class AudioService {
  AudioService(GameSettings settings, {this._enabled = true})
    : _settings = settings;
  final bool _enabled;
  GameSettings _settings;
  late final AudioPlayer _music = AudioPlayer();
  late final AudioPlayer _effects = AudioPlayer();
  bool _started = false;
  bool _foreground = true;
  bool _adShowing = false;
  bool _disposed = false;

  Future<void> configure(GameSettings settings) async {
    _settings = settings;
    await _safe(() async {
      await _music.setVolume(settings.musicVolume);
      await _effects.setVolume(settings.soundVolume);
      if (!settings.music) {
        await _music.pause();
      } else if (_started && _foreground && !_adShowing) {
        await _music.resume();
      }
    });
  }

  Future<void> startFromUserGesture() async {
    if (_disposed) return;
    await _safe(() async {
      if (!_started) {
        await _music.setReleaseMode(ReleaseMode.loop);
        await _music.setVolume(_settings.musicVolume);
        _started = true;
        if (_settings.music && _foreground && !_adShowing) {
          await _music.play(AssetSource('audio/garden_loop.wav'));
        } else {
          await _music.setSource(AssetSource('audio/garden_loop.wav'));
        }
      } else if (_settings.music && _foreground && !_adShowing) {
        await _music.resume();
      }
    });
  }

  Future<void> play(GameSound sound) async {
    if (!_enabled || _disposed || !_foreground || _adShowing) return;
    if (_settings.vibration && sound == GameSound.found) {
      unawaited(HapticFeedback.lightImpact());
    }
    if (!_settings.sound) return;
    await _safe(
      () => _effects.play(
        AssetSource('audio/${sound.name}.wav'),
        volume: _settings.soundVolume,
      ),
    );
  }

  Future<void> setForeground(bool value) async {
    _foreground = value;
    await _safe(() async {
      if (!value) {
        await _music.pause();
        await _effects.stop();
      } else if (_started && _settings.music && !_adShowing) {
        await _music.resume();
      }
    });
  }

  Future<void> setAdShowing(bool value) async {
    _adShowing = value;
    await _safe(() async {
      if (value) {
        await _music.pause();
        await _effects.stop();
      } else if (_started && _settings.music && _foreground) {
        await _music.resume();
      }
    });
  }

  Future<void> _safe(Future<void> Function() action) async {
    if (!_enabled || _disposed) return;
    try {
      await action();
    } catch (_) {
      // Unsupported/muted audio must never stop a puzzle or change progress.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    if (!_enabled) return;
    await _music.dispose();
    await _effects.dispose();
  }
}
