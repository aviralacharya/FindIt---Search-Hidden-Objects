import 'dart:async';

import 'package:findit/app/app.dart';
import 'package:findit/core/art/brand_art.dart';
import 'package:findit/core/config/app_config.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void _expectLauncherArtwork({Finder? within}) {
  final marks = within == null
      ? find.byType(FindItMark)
      : find.descendant(of: within, matching: find.byType(FindItMark));
  final images = find.descendant(of: marks, matching: find.byType(Image));
  expect(images, findsAtLeastNWidgets(1));
  for (final element in images.evaluate()) {
    final image = element.widget as Image;
    expect(image.image, const AssetImage(AppConfig.iconAsset));
    expect(image.fit, BoxFit.contain);
    expect(image.excludeFromSemantics, isTrue);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFindItFonts);

  testWidgets('the real startup screen uses FindIt and the launcher artwork', (
    tester,
  ) async {
    // Hold the preferences lookup before bootstrap can open any disk storage.
    const preferences = MethodChannel('plugins.flutter.io/shared_preferences');
    final pending = Completer<Object?>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      preferences,
      (_) => pending.future,
    );
    try {
      await tester.pumpWidget(const AppBootstrap());
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(AppConfig.iconAsset),
          tester.element(find.byType(FindItMark)),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'FindIt',
      );
      expect(find.text('FindIt'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      _expectLauncherArtwork();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        preferences,
        null,
      );
    }
  });

  for (final size in [33.0, 52.0, 76.0, 86.0]) {
    testWidgets('$size pixel brand mark renders the launcher icon asset', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: FindItMark(size: size)),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage(AppConfig.iconAsset),
          tester.element(find.byType(FindItMark)),
        ),
      );
      await tester.pumpAndSettle();
      _expectLauncherArtwork();
      expect(tester.getSize(find.byType(FindItMark)), Size.square(size));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('hidden-mode artwork uses the same icon, not an alternate logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ModeArtwork(GameMode.hidden))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FindItMark), findsOneWidget);
    _expectLauncherArtwork();
    expect(tester.takeException(), isNull);
  });

  testWidgets('home, about and licenses share FindIt naming and icon artwork', (
    tester,
  ) async {
    final app = await AppHarness.forTest(tester);
    try {
      await app.mount(tester);
      for (final route in ['/', '/about']) {
        await app.go(tester, route);
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
          'FindIt',
        );
        _expectLauncherArtwork();
        final text = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data ?? '')
            .join('\n');
        expect(text, isNot(contains('FindIt Hidden')));
        expect(text, isNot(contains('FindIt - Search Hidden Objects')));
        expect(tester.takeException(), isNull, reason: route);
      }
      await app.tap(tester, find.text('Open-source licenses'));
      await app.until(
        tester,
        () => find.text('Licenses').evaluate().isNotEmpty,
      );
      await app.pump(tester, const Duration(milliseconds: 600));
      expect(find.byType(LicensePage), findsOneWidget);
      _expectLauncherArtwork(within: find.byType(LicensePage));
      expect(find.text('FindIt'), findsAtLeastNWidgets(1));
      expect(app.requests, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await app.close(tester);
    }
  });

  testWidgets('About keeps player information, support and legal access only', (
    tester,
  ) async {
    final app = await AppHarness.forTest(tester);
    try {
      await app.mount(tester);
      await app.go(tester, '/about');
      expect(find.text('About FindIt'), findsOneWidget);
      expect(find.text('Version 1.0.0'), findsOneWidget);
      expect(find.text('Contact developer'), findsOneWidget);
      expect(find.text('Open-source licenses'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      _expectLauncherArtwork();
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .join('\n');
      expect(text, contains('60 offline levels'));
      expect(text, contains('Daily Challenge'));
      for (final internal in [
        'publisher',
        'provenance',
        'reused',
        'independent app',
        'vector',
        'synthesized',
        'Editable artwork',
        'SQLite',
        'Drift',
        'Flutter',
        'SDK',
        'development build',
        'Original little details',
        'Built with a little help',
      ]) {
        expect(text, isNot(contains(internal)), reason: internal);
      }
      await app.tap(tester, find.text('Privacy policy'));
      await app.until(
        tester,
        () => find.text('11. Contact the developer').evaluate().isNotEmpty,
      );
      expect(find.text('Privacy Policy'), findsAtLeastNWidgets(1));
      expect(app.requests, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await app.close(tester);
    }
  });

  testWidgets('the included collection hides internal publisher tooling', (
    tester,
  ) async {
    final app = await AppHarness.forTest(tester);
    try {
      await app.mount(tester);
      await app.go(tester, '/settings');
      expect(
        find.text('Game information, support, and licenses.'),
        findsOneWidget,
      );
      expect(find.text('60 levels included · play offline'), findsOneWidget);
      await app.go(tester, '/packs');
      expect(find.byType(TextFormField), findsNothing);
      expect(
        find.text(
          'All 60 levels are included and ready to play offline. Additional puzzle packs are not available right now.',
        ),
        findsOneWidget,
      );
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .join('\n');
      for (final internal in [
        'For publishers',
        'schema',
        'validator',
        'example pack',
        'configured',
        'development build',
        'vector artwork',
        'reused locally',
      ]) {
        expect(text, isNot(contains(internal)), reason: internal);
      }
      expect(app.requests, isEmpty);
      expect(tester.takeException(), isNull);
    } finally {
      await app.close(tester);
    }
  });
}
