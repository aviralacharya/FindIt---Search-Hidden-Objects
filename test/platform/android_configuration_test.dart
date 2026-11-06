import 'dart:convert';
import 'dart:io';

import 'package:findit/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android permissions and backups match the ad-free family app', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    final permissions = RegExp(r'<uses-permission android:name="([^"]+)"')
        .allMatches(manifest)
        .map((match) => match.group(1))
        .toSet();
    expect(permissions, {
      'android.permission.INTERNET',
      'android.permission.VIBRATE',
    });
    expect(manifest, isNot(contains('com.google.android.gms.ads')));
    expect(manifest, isNot(contains('ACCESS_ADSERVICES_')));
    expect(manifest, isNot(contains('AD_ID')));
    final backup = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsStringSync();
    expect(backup, contains('<cloud-backup'));
    expect(backup, contains('<device-transfer>'));
    expect(backup, contains('<exclude domain="database" path="."'));
  });

  test(
    'production identity, isolated QA and explicit candidate/signing gates',
    () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('applicationId = "abiral.mobile.findit"'));
      expect(gradle, contains('namespace = "abiral.mobile.findit"'));
      expect(gradle, contains('FINDIT_HIDDEN_'));
      expect(
        File('android/app/src/main/kotlin/abiral/mobile/findit/MainActivity.kt')
            .readAsStringSync(),
        contains('package abiral.mobile.findit'),
      );
      expect(gradle, contains('minSdk = 24'));
      expect(gradle, contains('targetSdk = 36'));
      expect(gradle, contains('applicationIdSuffix = ".qa"'));
      expect(
        gradle,
        contains('manifestPlaceholders["appLabel"] = "FindIt QA"'),
      );
      expect(gradle, contains('manifestPlaceholders["appLabel"] = "FindIt"'));
      expect(gradle, contains('signingConfig = null'));
      expect(gradle, contains('if (unsignedProductionCandidate) null'));
      expect(gradle, contains('BUILD_STAGE'));
      expect(gradle, contains('unsigned-candidate'));
      expect(gradle, contains('dependsOn(validateProduction)'));
      expect(gradle, contains('dependsOn(validateQa)'));
      expect(gradle, contains('dependsOn(rejectAdvertisingInGame)'));
      expect(gradle, contains('dependsOn(validateSignedProductionBundle)'));
      expect(gradle, contains('Production requires an upload key'));
      final certificate = jsonDecode(
        File('verification/signing/production-upload-certificate.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(certificate['applicationId'], 'abiral.mobile.findit');
      expect(
        gradle,
        contains('certificateSha256 == productionUploadCertificateSha256'),
      );
      expect(gradle, contains('"${certificate['certificateSha256']}"'));
      expect(gradle, contains('PRIVACY_POLICY_URL'));
      expect(gradle, contains('An unsigned candidate is APK-only'));
      final productionManifest = File(
        'android/app/src/prod/AndroidManifest.xml',
      ).readAsStringSync();
      for (final key in [
        'APP_ENV',
        'BUILD_STAGE',
        'PRIVACY_POLICY_URL',
        'PACK_INDEX_URL',
      ]) {
        expect(productionManifest, contains('findit.hidden.$key'));
      }
      expect(productionManifest, isNot(contains('PASSWORD')));
      expect(gradle, isNot(contains('create("adpreview")')));
      expect(gradle, isNot(contains('ca-app-pub-')));
      expect(gradle, isNot(contains('manifestPlaceholders["admobAppId"]')));
    },
  );

  test('FindIt naming and one icon source agree across app and platforms', () {
    expect(AppConfig.name, 'FindIt');
    expect(AppConfig.launcherName, 'FindIt');
    expect(AppConfig.androidPackage, 'abiral.mobile.findit');
    expect(AppConfig.version, '1.0.0');
    expect(AppConfig.iconAsset, 'assets/branding/app_icon.png');
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('image_path: ${AppConfig.iconAsset}'),
    );
    final web = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
    expect(web['name'], AppConfig.name);
    expect(web['short_name'], AppConfig.launcherName);
    expect(
      File('web/index.html').readAsStringSync(),
      contains('<title>FindIt</title>'),
    );
    expect(
      File(
        'android/app/src/main/kotlin/abiral/mobile/findithiddenobjects/MainActivity.kt',
      ).existsSync(),
      isFalse,
    );
  });

  test(
    'private signing files, Python tooling and final config stay excluded',
    () {
      final ignored = File('.gitignore').readAsStringSync();
      for (final pattern in [
        '*.aab',
        '*.apk',
        '*.apks',
        '*.py',
        '**/key.properties',
        '**/keystore.properties',
        '**/signing.properties',
        '*.jks',
        '*.keystore',
        '*.p12',
        '*.pfx',
        '*.key',
        '*.pk8',
        '*.pem',
        '/.local-signing/',
        'config/production.json',
        '.env',
        '.env.*',
      ]) {
        expect(ignored, contains(pattern));
      }
      expect(
        ignored,
        contains('!/verification/signing/production-upload-certificate.pem'),
      );
    },
  );

  test('no advertising, WebView, or native test-plugin dependency remains', () {
    for (final path in [
      'pubspec.yaml',
      'pubspec.lock',
      '.flutter-plugins-dependencies',
    ]) {
      final value = File(path).readAsStringSync();
      for (final forbidden in [
        'google_mobile_ads',
        'webview_flutter',
        'integration_test',
      ]) {
        expect(value, isNot(contains(forbidden)), reason: path);
      }
    }
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final code = file.readAsStringSync();
      for (final forbidden in [
        'google_mobile_ads',
        'ad_preview/',
        'MobileAds',
        'ConsentInformation',
        'watchRewarded',
        'grantAdReward',
        'SafeAdBanner',
      ]) {
        expect(code, isNot(contains(forbidden)), reason: file.path);
      }
      expect(code, isNot(matches(RegExp(r'\bAdService\b'))), reason: file.path);
      if (!file.path.endsWith('settings_repository.dart')) {
        expect(code, isNot(contains('.ageGroup')), reason: file.path);
        expect(code, isNot(contains('.adsEnabled')), reason: file.path);
      }
    }
  });

  test(
    'no preview project, original history, or signing credentials were copied',
    () {
      expect(Directory('ad_preview').existsSync(), isFalse);
      expect(File('android/key.properties').existsSync(), isFalse);
      final reuse = jsonDecode(
        File('verification/source-reuse.json')
            .readAsStringSync()
            .replaceFirst('\ufeff', ''),
      ) as Map<String, dynamic>;
      expect(reuse['count'], greaterThan(200));
      expect(reuse['source'], isNot(reuse['destination']));
      // A new Git repository is valid. The original app's history must never
      // have been copied into it.
      expect(reuse['excludes'], contains('original .git history'));
      expect(
        (reuse['files'] as List).any((entry) {
          final path = (entry as Map)['path'] as String;
          return path == '.git' || path.startsWith('.git/');
        }),
        isFalse,
      );
    },
  );

  test(
    'optimization stays enabled and no advertising reflection keeps remain',
    () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
      final reflected = RegExp(
        r'-keep class androidx\.work\.impl\.WorkDatabase_Impl\s*\{\s*public <init>\(\);\s*\}',
      );
      expect(
        File('android/app/proguard-rules.pro').readAsStringSync(),
        isNot(matches(reflected)),
      );
      final rules = File('android/app/proguard-rules.pro').readAsStringSync();
      expect(rules, isNot(matches(reflected)));
      for (final forbidden in [
        '-dontshrink',
        '-dontoptimize',
        '-keep class androidx.work.**',
        '-keep class androidx.room.**',
      ]) {
        expect(rules, isNot(contains(forbidden)));
      }
    },
  );

  test(
    'reused schema has a new storage identity and a hidden-only catalog',
    () {
      final native = File('lib/core/storage/connection_native.dart')
          .readAsStringSync();
      final web = File('lib/core/storage/connection_web.dart')
          .readAsStringSync();
      expect(native, contains('String name = AppConfig.storageNamespace'));
      expect(native, contains("'\$name.sqlite'"));
      expect(web, contains('String name = AppConfig.storageNamespace'));
      expect(web, contains("databaseName: '\${name}_v1'"));
      expect(
        File('lib/app/app.dart').readAsStringSync(),
        contains('AppServices.create()'),
      );
      expect(
        File('lib/core/storage/database.dart').readAsStringSync(),
        contains('int get schemaVersion => 1'),
      );
      expect(
        File('lib/core/storage/settings_repository.dart').readAsStringSync(),
        contains(
          "this.preferenceKey = '\${AppConfig.storageNamespace}-settings-v1'",
        ),
      );
      final catalog = jsonDecode(
        File('assets/content/catalog.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final puzzles = catalog['puzzles'] as List;
      expect(puzzles, hasLength(60));
      expect(puzzles.every((p) => (p as Map)['mode'] == 'hidden'), isTrue);
    },
  );

  test('release configuration has no ad overrides or invented policy URL', () {
    for (final entry in {
      'unsigned-production': 'unsigned-candidate',
      'qa': 'qa',
      'production.example': 'final',
    }.entries) {
      final config = jsonDecode(
        File('config/${entry.key}.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(config['BUILD_STAGE'], entry.value);
      expect(config['PACK_INDEX_URL'], '');
      expect(config['PRIVACY_POLICY_URL'], '');
      expect(
        config.keys.any(
          (key) => key.startsWith('ADMOB_') || key == 'AD_PREVIEW',
        ),
        isFalse,
      );
    }
  });
}
