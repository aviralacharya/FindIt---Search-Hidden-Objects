import 'dart:ui' show SemanticsAction;

import 'package:findit/app/theme.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:findit/ui/widgets/tile_board.dart';
import 'package:findit/ui/widgets/scene_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/puzzles.dart';

void main() {
  testWidgets(
    'tile labels describe markings and expose working accessibility taps',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final taps = <int>[];
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildFindItTheme(),
            home: Scaffold(
              body: TileBoard(
                tiles: const [
                  TileData(kind: 'apple', variant: 1),
                  TileData(kind: 'apple', variant: 2),
                ],
                columns: 2,
                onTap: taps.add,
              ),
            ),
          ),
        );
        final first = tester.getSemantics(
          find.byKey(const ValueKey('tiles-0')),
        );
        expect(first.label, contains('white stripe'));
        expect(first.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        first.owner!.performAction(first.id, SemanticsAction.tap);
        expect(taps, [0]);
        expect(
          tester.getSemantics(find.byKey(const ValueKey('tiles-1'))).label,
          contains('white spots'),
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('grid tiles can be selected with the keyboard', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFindItTheme(),
        home: Scaffold(
          body: TileBoard(
            tiles: const [
              TileData(kind: 'apple'),
              TileData(kind: 'pear'),
            ],
            columns: 2,
            onTap: taps.add,
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, [0]);
  });

  testWidgets('found and eliminated tiles expose no accessibility tap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TileBoard(
              tiles: const [
                TileData(kind: 'apple'),
                TileData(kind: 'pear'),
              ],
              columns: 2,
              selected: const {0},
              eliminated: const {1},
              onTap: (_) => fail('Inactive tiles must not activate.'),
            ),
          ),
        ),
      );
      for (final index in [0, 1]) {
        final node = tester.getSemantics(find.byKey(ValueKey('tiles-$index')));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      }
    } finally {
      semantics.dispose();
    }
  });

  for (final alternate in [false, true]) {
    testWidgets(
      'picture ${alternate ? 'B' : 'A'} describes every visible object',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final puzzle = fixture(GameMode.differences);
        final taps = <(double, double)>[];
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildFindItTheme(),
              home: Scaffold(
                body: SceneBoard(
                  puzzle: puzzle,
                  alternate: alternate,
                  found: const {},
                  onTap: (x, y) => taps.add((x, y)),
                ),
              ),
            ),
          );
          for (final object in puzzle.scene!.objects) {
            final finder = find.byKey(
              ValueKey('scene-${alternate ? 'b' : 'a'}-object-${object.id}'),
            );
            if (alternate && object.alternateHidden) {
              expect(finder, findsNothing);
              continue;
            }
            final node = tester.getSemantics(finder);
            expect(
              node.label,
              contains(
                objectDescription(
                  alternate ? object.alternateKind ?? object.kind : object.kind,
                  color: alternate
                      ? object.alternateColor ?? object.color
                      : object.color,
                  variant: alternate
                      ? object.alternateVariant ?? object.variant
                      : object.variant,
                ),
              ),
            );
            expect(node.label, isNot(contains(object.id)));
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              isTrue,
            );
            node.owner!.performAction(node.id, SemanticsAction.tap);
            expect(taps.last, (object.region.centerX, object.region.centerY));
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final active in [false, true]) {
    testWidgets(
      '${active ? 'active' : 'inactive'} scenes never expose taps on found objects',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final puzzle = fixture(GameMode.hidden);
        final found = puzzle.answerIds.first;
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SceneBoard(
                  puzzle: puzzle,
                  alternate: false,
                  found: {found},
                  onTap: active ? (_, _) {} : null,
                ),
              ),
            ),
          );
          for (final object in puzzle.scene!.objects) {
            final node = tester.getSemantics(
              find.byKey(ValueKey('scene-a-object-${object.id}')),
            );
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              active && object.id != found,
            );
            if (object.id == found) expect(node.label, contains(', found'));
          }
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'scene keyboard activation and zoomed taps use original coordinates',
    (tester) async {
      final puzzle = fixture(GameMode.hidden);
      final object = puzzle.scene!.objects.first;
      final taps = <(double, double)>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildFindItTheme(),
          home: Scaffold(
            body: SceneBoard(
              puzzle: puzzle,
              alternate: false,
              found: const {},
              onTap: (x, y) => taps.add((x, y)),
            ),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(const ValueKey('scene-a')));
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      viewer.transformationController!.value = Matrix4.translationValues(
        rect.width * (.5 - 2 * object.region.centerX),
        rect.height * (.5 - 2 * object.region.centerY),
        0,
      )..scaleByDouble(2, 2, 1, 1);
      await tester.pump();
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(taps.last.$1, closeTo(object.region.centerX, .000001));
      expect(taps.last.$2, closeTo(object.region.centerY, .000001));
      final target = find.byKey(ValueKey('scene-a-object-${object.id}'));
      tester
          .widget<FocusableActionDetector>(
            find.descendant(
              of: target,
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .focusNode!
          .requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps.last, (object.region.centerX, object.region.centerY));
      expect(tester.takeException(), isNull);
    },
  );
}
