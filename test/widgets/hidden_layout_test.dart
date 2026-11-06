import 'package:findit/ui/widgets/object_checklist.dart';
import 'package:findit/ui/widgets/scene_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFindItFonts);

  for (final (name, size, scale) in [
    ('phone', const Size(390, 844), 1.0),
    ('small phone', const Size(320, 568), 1.0),
    ('landscape', const Size(844, 390), 1.0),
    ('wide', const Size(1440, 960), 1.0),
    ('large text', const Size(390, 844), 2.0),
    ('small phone large text', const Size(320, 568), 2.0),
    ('wide large text', const Size(1440, 960), 2.0),
  ]) {
    testWidgets(
      '$name keeps pages, pinned checklist, and search controls usable',
      (tester) async {
        final app = await AppHarness.forTest(tester);
        try {
          await app.mount(tester, size: size, textScale: scale);
          for (final route in [
            '/',
            '/mode/hidden',
            '/daily',
            '/progress',
            '/settings',
            '/about',
            '/privacy',
            '/packs',
          ]) {
            await app.go(tester, route);
            expect(
              tester.takeException(),
              isNull,
              reason: '$name: $route at top',
            );
            final pages = find.byType(SingleChildScrollView);
            if (pages.evaluate().isNotEmpty) {
              final scrollable = find
                  .descendant(
                    of: pages.first,
                    matching: find.byType(Scrollable),
                  )
                  .first;
              final position = tester
                  .state<ScrollableState>(scrollable)
                  .position;
              position.jumpTo(position.maxScrollExtent);
              await app.pump(tester);
              expect(
                tester.takeException(),
                isNull,
                reason: '$name: $route at bottom',
              );
            }
          }
          await app.openPuzzle(tester, app.services.content.puzzles.first);
          expect(find.byType(SceneBoard), findsOneWidget);
          expect(find.byType(ObjectChecklist), findsOneWidget);
          final scene = tester.getSize(
            find.byKey(const ValueKey('scene-viewport')),
          );
          expect(scene.width, greaterThan(100));
          expect(scene.height, greaterThan(96));
          expect(
            find.byKey(const ValueKey('hint-button')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('scene-zoom-in')).hitTestable(),
            findsOneWidget,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$name: search layout',
          );
          await app.tap(tester, find.byKey(const ValueKey('hint-button')));
          await app.until(
            tester,
            () => app.services.progress.current.savedGame!.restore().hints == 1,
          );
          await app.tap(tester, find.byKey(const ValueKey('hint-button')));
          await app.until(
            tester,
            () =>
                app.services.progress.current.savedGame!.restore().hintRevealed,
          );
          expect(tester.takeException(), isNull, reason: '$name: hint layout');
        } finally {
          await app.close(tester);
        }
      },
    );
  }
}
