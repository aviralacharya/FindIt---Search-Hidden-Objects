// Explicit capture of the same offline policy used to generate privacy-policy.html.
// Uses test-owned SQLite/preferences, never installed or browser saves.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:findit/core/config/privacy_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFindItFonts);

  testWidgets('capture the complete link-free policy on phone and wide layouts', (
    tester,
  ) async {
    final app = await AppHarness.forTest(tester);
    final captures = <Map<String, Object>>[];
    final document = (await tester.runAsync(PrivacyPolicyDocument.load))!;
    Future<void> capture(String name) async {
      await app.pump(tester);
      expect(tester.takeException(), isNull, reason: name);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('app-capture')),
      );
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 2),
      ))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      ))!;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final file = File('verification/privacy-policy/screenshots/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      captures.add({
        'file': file.path.replaceAll('\\', '/'),
        'sha256': sha256.convert(bytes).toString(),
        'width': image.width,
        'height': image.height,
      });
      image.dispose();
    }

    try {
      for (final (name, size, scale) in [
        ('phone', const Size(390, 844), 1.0),
        ('phone-large-text', const Size(390, 844), 2.0),
        ('wide', const Size(1440, 960), 1.0),
      ]) {
        await app.go(tester, '/');
        await app.mount(tester, size: size, textScale: scale);
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
        await capture('$name-top');
        for (final id in ['security', 'contact']) {
          final section = document.sections.firstWhere(
            (section) => section.id == id,
          );
          await Scrollable.ensureVisible(
            tester.element(find.text(section.title)),
            alignment: .02,
          );
          await capture('$name-$id');
        }
      }
      expect(app.requests, isEmpty);
      File('verification/privacy-policy/captures.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({'createdAt': DateTime.now().toUtc().toIso8601String(), 'scope': 'Actual app widgets and all 11 shared legal sections; offline test-owned database/preferences. No installation, browser saves or live hosting.', 'policySourceSha256': sha256.convert(File(privacyPolicyAsset).readAsBytesSync()).toString(), 'policyHtmlSha256': sha256.convert(File('privacy-policy.html').readAsBytesSync()).toString(), 'legalTextMatchesSource': true, 'captures': captures})}\n',
      );
    } finally {
      await app.close(tester);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
