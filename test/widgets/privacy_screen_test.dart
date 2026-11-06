import 'dart:async';
import 'dart:io';

import 'package:findit/app/router.dart';
import 'package:findit/app/theme.dart';
import 'package:findit/core/config/privacy_policy.dart';
import 'package:findit/features/settings/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _PolicyBundle extends CachingAssetBundle {
  _PolicyBundle({this.failures = 0, this.pending});

  int failures;
  int loads = 0;
  final Completer<ByteData>? pending;

  @override
  Future<ByteData> load(String key) async {
    if (key != privacyPolicyAsset) return rootBundle.load(key);
    loads++;
    if (pending != null) return pending!.future;
    if (failures > 0) {
      failures--;
      throw FlutterError('Test-owned asset failure.');
    }
    return ByteData.sublistView(File(privacyPolicyAsset).readAsBytesSync());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFindItFonts);

  for (final (name, size, scale) in [
    ('phone', const Size(390, 844), 1.0),
    ('small phone with large text', const Size(320, 568), 2.0),
    ('wide', const Size(1440, 960), 1.0),
  ]) {
    testWidgets('$name shows the entire shared policy offline without links', (
      tester,
    ) async {
      final app = await AppHarness.forTest(tester);
      try {
        final document = (await tester.runAsync(PrivacyPolicyDocument.load))!;
        await app.mount(tester, size: size, textScale: scale);
        await app.go(tester, '/privacy');
        await app.until(
          tester,
          () => find.text(document.intro).evaluate().isNotEmpty,
        );
        expect(find.byType(SelectionArea), findsOneWidget);
        expect(find.text(document.appName), findsOneWidget);
        expect(find.text(document.revisionLabel), findsOneWidget);
        for (final section in document.sections) {
          expect(find.text(section.title), findsOneWidget);
          for (final paragraph in section.paragraphs) {
            expect(find.text(paragraph), findsOneWidget);
          }
          for (final bullet in section.bullets) {
            expect(find.text(bullet), findsOneWidget);
          }
          final heading = tester.widget<Semantics>(
            find
                .ancestor(
                  of: find.text(section.title),
                  matching: find.byType(Semantics),
                )
                .first,
          );
          expect(heading.properties.header, isTrue);
          await tester.ensureVisible(find.text(section.title));
          await app.pump(tester);
          expect(tester.takeException(), isNull, reason: section.id);
        }
        final text = tester
            .widgetList<Text>(find.byType(Text))
            .map(
              (widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '',
            )
            .join('\n');
        expect(text, isNot(matches(RegExp(r'https?://|mailto:|www\.'))));
        expect(text, isNot(contains('abiral.mobile.')));
        expect(text, isNot(contains('FindIt Hidden')));
        expect(text.toLowerCase(), isNot(contains('github')));
        expect(text.toLowerCase(), isNot(contains('policy source')));
        expect(text.toLowerCase(), isNot(contains('public policy')));
        expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
        expect(find.text('Public privacy policy'), findsNothing);
        expect(find.text('Email the developer'), findsNothing);
        expect(find.text('Email: abiralacharya80@gmail.com.'), findsOneWidget);
        expect(app.requests, isEmpty);
        await app.tap(tester, find.text('Open my settings'));
        expect(app.container.read(routerProvider).state.uri.path, '/settings');
      } finally {
        await app.close(tester);
      }
    });
  }

  testWidgets('an unavailable local asset shows a retry that really reloads', (
    tester,
  ) async {
    final bundle = _PolicyBundle(failures: 1);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFindItTheme(),
        home: DefaultAssetBundle(bundle: bundle, child: const PrivacyScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The bundled privacy policy could not be loaded.'),
      findsOneWidget,
    );
    expect(bundle.loads, 1);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(bundle.loads, 2);
    expect(find.text('11. Contact the developer'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending local policy loading stays safe if the screen closes', (
    tester,
  ) async {
    final pending = Completer<ByteData>();
    final bundle = _PolicyBundle(pending: pending);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFindItTheme(),
        home: DefaultAssetBundle(bundle: bundle, child: const PrivacyScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(
      ByteData.sublistView(File(privacyPolicyAsset).readAsBytesSync()),
    );
    await tester.pumpAndSettle();
    expect(bundle.loads, 1);
    expect(tester.takeException(), isNull);
  });
}
