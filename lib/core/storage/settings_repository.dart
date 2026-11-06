import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

// Read and round-trip legacy fields without asking for age or enabling ads.
// They are inert migration data, not controls or runtime policy inputs.
enum AgeGroup { unknown, child, teen, adult }

class GameSettings {
  const GameSettings({
    this.sound = true,
    this.music = true,
    this.vibration = true,
    this.musicVolume = .20,
    this.soundVolume = .60,
    this.relaxed = true,
    this.adsEnabled = false,
    this.ageGroup = AgeGroup.unknown,
  });
  final bool sound;
  final bool music;
  final bool vibration;
  final double musicVolume;
  final double soundVolume;
  final bool relaxed;
  final bool adsEnabled;
  final AgeGroup ageGroup;

  GameSettings copyWith({
    bool? sound,
    bool? music,
    bool? vibration,
    double? musicVolume,
    double? soundVolume,
    bool? relaxed,
    bool? adsEnabled,
    AgeGroup? ageGroup,
  }) => GameSettings(
    sound: sound ?? this.sound,
    music: music ?? this.music,
    vibration: vibration ?? this.vibration,
    musicVolume: musicVolume ?? this.musicVolume,
    soundVolume: soundVolume ?? this.soundVolume,
    relaxed: relaxed ?? this.relaxed,
    adsEnabled: adsEnabled ?? this.adsEnabled,
    ageGroup: ageGroup ?? this.ageGroup,
  );

  Map<String, dynamic> toJson() => {
    'sound': sound,
    'music': music,
    'vibration': vibration,
    'musicVolume': musicVolume,
    'soundVolume': soundVolume,
    'relaxed': relaxed,
    'adsEnabled': adsEnabled,
    'ageGroup': ageGroup.name,
  };

  factory GameSettings.fromJson(Map<String, dynamic> j) => GameSettings(
    sound: j['sound'] as bool? ?? true,
    music: j['music'] as bool? ?? true,
    vibration: j['vibration'] as bool? ?? true,
    musicVolume: (j['musicVolume'] as num? ?? .20).toDouble().clamp(0, 1),
    soundVolume: (j['soundVolume'] as num? ?? .60).toDouble().clamp(0, 1),
    relaxed: j['relaxed'] as bool? ?? true,
    adsEnabled: j['adsEnabled'] as bool? ?? false,
    ageGroup:
        AgeGroup.values.where((a) => a.name == j['ageGroup']).firstOrNull ??
        AgeGroup.unknown,
  );
}

class SettingsRepository {
  SettingsRepository(
    this.preferences, {
    this.preferenceKey = '${AppConfig.storageNamespace}-settings-v1',
  });
  final SharedPreferences preferences;
  final String preferenceKey;
  GameSettings current = const GameSettings();
  String? recoveryNotice;
  void initialize() {
    current = const GameSettings();
    recoveryNotice = null;
    // Preserve unreadable preferences and independently stored puzzle progress.
    try {
      final raw = preferences.getString(preferenceKey);
      if (raw != null) {
        current = GameSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } on FormatException {
      _useSafeDefaults();
    } on TypeError {
      _useSafeDefaults();
    }
  }

  void _useSafeDefaults() {
    current = const GameSettings();
    recoveryNotice = 'Some settings couldn’t be read, so safe defaults are in use. Your puzzle progress is unchanged. Save a setting to replace the unreadable preferences.';
  }

  Future<void> save(GameSettings settings) async {
    final saved = await preferences.setString(
      preferenceKey,
      jsonEncode(settings.toJson()),
    );
    if (!saved) {
      throw StateError('Your settings could not be saved. Please try again.');
    }
    current = settings;
    recoveryNotice = null;
  }
}
