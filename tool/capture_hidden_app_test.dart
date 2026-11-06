// Explicit, isolated screenshot review: flutter test --no-pub tool/capture_hidden_app_test.dart
// Uses a test-owned SQLite database and mocked preferences, never installed saves.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFindItFonts);

  testWidgets(
    'capture actual hidden-object app screens with no layout exceptions',
    (tester) async {
      final app = await AppHarness.forTest(tester);
      final captures = <Map<String, Object>>[];
      Future<void> capture(String name, {double pixelRatio = 2}) async {
        await app.pump(tester);
        expect(tester.takeException(), isNull, reason: name);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('app-capture')),
        );
        final image = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: pixelRatio),
        ))!;
        final data = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        ))!;
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final file = File('verification/screenshots/$name.png');
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
        await app.mount(tester);
        await capture('phone-home');
        await app.go(tester, '/mode/hidden');
        await capture('phone-levels');
        await app.go(tester, '/daily');
        await capture('phone-daily');
        final puzzles = app.services.content.puzzles.take(3).toList();
        await app.openPuzzle(tester, puzzles.first);
        await capture('phone-reading-room');
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(
          tester,
          () => app.services.progress.current.savedGame!.restore().hints == 1,
        );
        await capture('phone-area-hint');
        await app.tap(tester, find.byKey(const ValueKey('hint-button')));
        await app.until(
          tester,
          () => app.services.progress.current.savedGame!.restore().hintRevealed,
        );
        await capture('phone-precise-reveal');
        await app.tapSceneObject(
          tester,
          puzzles.first,
          puzzles.first.answerIds.first,
        );
        await app.go(tester, '/');
        await app.openPuzzle(tester, puzzles.first, resume: true);
        await capture('phone-resumed-search');
        await app.solvePuzzle(tester, puzzles.first);
        await capture('phone-completed');
        await app.tap(tester, find.byKey(const ValueKey('next-puzzle')));
        await app.until(
          tester,
          () =>
              app.services.progress.current.savedGame?.puzzleId ==
              puzzles[1].id,
        );
        await capture('phone-garden');
        await app.solvePuzzle(tester, puzzles[1]);
        await app.tap(tester, find.byKey(const ValueKey('next-puzzle')));
        await app.until(
          tester,
          () =>
              app.services.progress.current.savedGame?.puzzleId ==
              puzzles[2].id,
        );
        await capture('phone-cafe');

        for (final (name, size, textScale) in [
          ('wide', const Size(1440, 960), 1.0),
          ('landscape', const Size(844, 390), 1.0),
          ('large-text', const Size(390, 844), 2.0),
          ('wide-large-text', const Size(1440, 960), 2.0),
        ]) {
          await app.go(tester, '/');
          await app.mount(tester, size: size, textScale: textScale);
          await capture('$name-home', pixelRatio: 1);
          await app.openPuzzle(tester, puzzles.first);
          await capture('$name-search', pixelRatio: 1);
        }
        expect(app.requests, isEmpty);
        File('verification/screenshots/captures.json').writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert({'scope': 'Actual app widgets; isolated test-owned database/preferences; no installed or browser saves', 'captures': captures})}\n',
        );
      } finally {
        await app.close(tester);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
