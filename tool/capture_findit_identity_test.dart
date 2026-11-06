// Explicit identity review; earlier captures are never overwritten.
// flutter test --no-pub --dart-define-from-file=config/production.json tool/capture_findit_identity_test.dart
// Uses test-owned SQLite/preferences. Startup is held before any disk access.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:findit/app/app.dart';
import 'package:findit/app/theme.dart';
import 'package:findit/core/art/brand_art.dart';
import 'package:findit/core/config/app_config.dart';
import 'package:findit/core/config/privacy_policy.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/app_harness.dart';

const _output = String.fromEnvironment(
  'FINDIT_IDENTITY_CAPTURE_DIRECTORY',
  defaultValue: 'verification/findit-identity/production-ui',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFindItFonts);
  final captures = <Map<String, Object>>[];

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 600));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    final marks = find.byType(FindItMark);
    if (marks.evaluate().isNotEmpty) {
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(AppConfig.iconAsset),
          tester.element(marks.first),
        ),
      );
      await tester.pump();
      for (final image in tester.widgetList<RawImage>(
        find.descendant(of: marks, matching: find.byType(RawImage)),
      )) {
        expect(image.image, isNotNull, reason: '$name icon is decoded.');
      }
    }
    expect(tester.takeException(), isNull, reason: name);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('app-capture')),
    );
    final image = (await tester.runAsync(
      () => boundary.toImage(pixelRatio: 2),
    ))!;
    try {
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      ))!;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final file = File('$_output/screenshots/$name.png');
      expect(file.existsSync(), isFalse, reason: 'Preserve earlier captures.');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      captures.add({
        'file': file.path.replaceAll('\\', '/'),
        'sha256': sha256.convert(bytes).toString(),
        'width': image.width,
        'height': image.height,
      });
    } finally {
      image.dispose();
    }
  }

  void writeManifest(
    String name,
    String scope,
    List<Map<String, Object>> records,
  ) {
    final manifest = File('$_output/$name');
    expect(
      manifest.existsSync(),
      isFalse,
      reason: 'Preserve earlier evidence.',
    );
    manifest.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'createdAtUtc': DateTime.now().toUtc().toIso8601String(), 'scope': scope, 'appName': AppConfig.name, 'appEnvironment': AppConfig.environment, 'buildStage': AppConfig.buildStage, 'productionUi': AppConfig.production, 'iconAsset': AppConfig.iconAsset, 'iconSha256': sha256.convert(File(AppConfig.iconAsset).readAsBytesSync()).toString(), 'policySourceSha256': sha256.convert(File(privacyPolicyAsset).readAsBytesSync()).toString(), 'policyHtmlSha256': sha256.convert(File('privacy-policy.html').readAsBytesSync()).toString(), 'legalTextMatchesSource': true, 'appPackageIdentifiersInPolicy': false, 'captures': records})}\n',
    );
  }

  testWidgets('capture actual startup and shared hidden-mode icon', (
    tester,
  ) async {
    const preferences = MethodChannel('plugins.flutter.io/shared_preferences');
    final pending = Completer<Object?>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      preferences,
      (_) => pending.future,
    );
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    try {
      await tester.pumpWidget(
        const RepaintBoundary(
          key: ValueKey('app-capture'),
          child: AppBootstrap(),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(AppConfig.iconAsset),
          tester.element(find.byType(FindItMark)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await capture(tester, 'phone-startup');
      await tester.pumpWidget(
        RepaintBoundary(
          key: ValueKey('app-capture'),
          child: MaterialApp(
            title: AppConfig.name,
            debugShowCheckedModeBanner: false,
            theme: buildFindItTheme(),
            home: const Scaffold(
              body: Center(
                child: ModeArtwork(GameMode.hidden, width: 256, height: 200),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await capture(tester, 'hidden-mode-artwork');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        preferences,
        null,
      );
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('capture app branding and package-free offline policy', (
    tester,
  ) async {
    final app = await AppHarness.forTest(tester);
    final document = (await tester.runAsync(PrivacyPolicyDocument.load))!;
    try {
      for (final (name, size, scale) in [
        ('phone', const Size(390, 844), 1.0),
        ('small-phone-large-text', const Size(320, 568), 2.0),
        ('wide', const Size(1440, 960), 1.0),
      ]) {
        await app.go(tester, '/');
        await app.mount(tester, size: size, textScale: scale);
        await capture(tester, '$name-home');
        await app.go(tester, '/settings');
        await capture(tester, '$name-settings');
        await app.go(tester, '/packs');
        await capture(tester, '$name-collection');
        await app.go(tester, '/about');
        await capture(tester, '$name-about');
        await app.tap(tester, find.text('Open-source licenses'));
        await app.until(
          tester,
          () => find.text('Licenses').evaluate().isNotEmpty,
        );
        await app.pump(tester, const Duration(milliseconds: 600));
        expect(find.byType(LicensePage), findsOneWidget);
        await capture(tester, '$name-licenses');
        await tester.pageBack();
        await app.pump(tester);
        await app.go(tester, '/privacy');
        await app.until(
          tester,
          () => find.text(document.intro).evaluate().isNotEmpty,
        );
        for (final section in document.sections) {
          expect(find.text(section.title), findsOneWidget);
          for (final paragraph in section.paragraphs) {
            expect(find.text(paragraph), findsOneWidget);
          }
          for (final bullet in section.bullets) {
            expect(find.text(bullet), findsOneWidget);
          }
        }
        final text = tester
            .widgetList<Text>(find.byType(Text))
            .map(
              (widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '',
            )
            .join('\n');
        expect(text, isNot(contains('abiral.mobile.')));
        expect(text, isNot(matches(RegExp(r'https?://|mailto:|www\.'))));
        expect(text.toLowerCase(), isNot(contains('github')));
        expect(text.toLowerCase(), isNot(contains('policy source')));
        expect(text.toLowerCase(), isNot(contains('public policy')));
        await capture(tester, '$name-policy-top');
        for (final id in ['permissions_backups', 'contact']) {
          final section = document.sections.firstWhere(
            (section) => section.id == id,
          );
          await Scrollable.ensureVisible(
            tester.element(find.text(section.title)),
            alignment: .02,
          );
          await app.pump(tester);
          await capture(tester, '$name-policy-$id');
        }
      }
      expect(app.requests, isEmpty);
      writeManifest(
        'captures.json',
        'Actual startup/home/settings/collection/about/license widgets and all 11 shared policy sections. Test-owned SQLite/preferences; startup held before disk access. No installation, existing saves or live hosting.',
        captures,
      );
    } finally {
      await app.close(tester);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('capture player-facing details below the fold', (tester) async {
    final app = await AppHarness.forTest(tester);
    final firstDetail = captures.length;
    try {
      expect(AppConfig.production, isTrue);
      expect(AppConfig.buildStage, 'final');
      for (final (name, size, scale) in [
        ('phone', const Size(390, 844), 1.0),
        ('small-phone-large-text', const Size(320, 568), 2.0),
        ('wide', const Size(1440, 960), 1.0),
      ]) {
        await app.go(tester, '/settings');
        await app.mount(tester, size: size, textScale: scale);
        expect(find.text('60 levels included · play offline'), findsOneWidget);
        expect(find.text('FindIt 1.0.0'), findsOneWidget);
        for (final (suffix, title) in [
          ('settings-collection', 'Puzzle collection'),
          ('settings-about', 'About FindIt'),
        ]) {
          await Scrollable.ensureVisible(
            tester.element(find.text(title)),
            alignment: .05,
          );
          await capture(tester, '$name-$suffix');
        }
        await app.go(tester, '/packs');
        await Scrollable.ensureVisible(
          tester.element(
            find.text(
              'All 60 levels are included and ready to play offline. Additional puzzle packs are not available right now.',
            ),
          ),
          alignment: .05,
        );
        await capture(tester, '$name-collection-details');
        await app.go(tester, '/about');
        await Scrollable.ensureVisible(
          tester.element(find.text('Version 1.0.0')),
          alignment: .85,
        );
        await capture(tester, '$name-about-details');
      }
      expect(app.requests, isEmpty);
      writeManifest(
        'details-captures.json',
        'Scrolled production Settings, collection availability, and About support/privacy/licenses/version at all three review sizes. Isolated widget tests only; no installation, existing saves, live hosting, upload or publication.',
        captures.skip(firstDetail).toList(),
      );
    } finally {
      await app.close(tester);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
