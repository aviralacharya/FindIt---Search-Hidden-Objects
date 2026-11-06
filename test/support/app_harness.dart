import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show QueryInterceptor, ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:findit/app/app.dart';
import 'package:findit/app/app_services.dart';
import 'package:findit/app/router.dart';
import 'package:findit/core/config/app_config.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:findit/core/services/game_clock.dart';
import 'package:findit/core/storage/database.dart';
import 'package:findit/core/storage/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadFindItFonts() async {
  for (final (family, asset) in [
    ('Outfit', 'assets/fonts/Outfit.ttf'),
    ('Nunito', 'assets/fonts/Nunito.ttf'),
    ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
  ]) {
    final loader = FontLoader(family)..addFont(rootBundle.load(asset));
    await loader.load();
  }
}

class FakeGameClock implements GameClock {
  int _elapsed = 0;
  bool _running = false;
  @override
  int get elapsedMilliseconds => _elapsed;
  @override
  bool get isRunning => _running;
  @override
  void start() => _running = true;
  @override
  void stop() => _running = false;
  @override
  void reset() => _elapsed = 0;
  void elapse(Duration duration) {
    if (_running) _elapsed += duration.inMilliseconds;
  }
}

/// The real app, repositories, routes, assets and rules, with only native audio,
/// networking and elapsed-time sources isolated from the test runner.
class AppHarness {
  AppHarness._(this.services, this.container, this.clocks, this.requests);
  final AppServices services;
  final ProviderContainer container;
  final List<FakeGameClock> clocks;
  final List<http.Request> requests;

  static Future<AppHarness> forTest(
    WidgetTester tester, {
    GameSettings settings = const GameSettings(),
    QueryInterceptor? interceptor,
    Map<String, Object> initialPreferences = const {},
    String? storageNamespace,
  }) async => (await tester.runAsync(
    () => create(
      settings: settings,
      interceptor: interceptor,
      initialPreferences: initialPreferences,
      storageNamespace: storageNamespace,
    ),
  ))!;

  static Future<AppHarness> create({
    GameSettings settings = const GameSettings(),
    QueryInterceptor? interceptor,
    Map<String, Object> initialPreferences = const {},
    String? storageNamespace,
  }) async {
    final namespace = storageNamespace ?? AppConfig.storageNamespace;
    SharedPreferences.setMockInitialValues({
      '$namespace-settings-v1': jsonEncode(settings.toJson()),
      ...initialPreferences,
    });
    final requests = <http.Request>[];
    final executor = NativeDatabase.memory();
    final services = await AppServices.create(
      database: FindItDatabase(
        interceptor == null ? executor : executor.interceptWith(interceptor),
      ),
      enablePlugins: false,
      storageNamespace: namespace,
      packClient: MockClient((request) async {
        requests.add(request);
        throw http.ClientException('Networking is disabled in UI tests.');
      }),
    );
    final clocks = <FakeGameClock>[];
    final container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(services),
        gameClockFactoryProvider.overrideWithValue(() {
          final clock = FakeGameClock();
          clocks.add(clock);
          return clock;
        }),
      ],
    );
    return AppHarness._(services, container, clocks, requests);
  }

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RepaintBoundary(
          key: ValueKey('app-capture'),
          child: FindItApp(),
        ),
      ),
    );
    await pump(tester, const Duration(milliseconds: 300));
  }

  Future<void> pump(
    WidgetTester tester, [
    Duration duration = const Duration(milliseconds: 220),
  ]) async {
    for (final clock in clocks) {
      clock.elapse(duration);
    }
    await tester.pump(duration);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    // Flush repository writes and notifications without waiting for periodic
    // gameplay ticks (pumpAndSettle would never settle an active puzzle).
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  Future<void> until(
    WidgetTester tester,
    bool Function() condition, {
    String reason = 'Expected UI state did not appear.',
  }) async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await pump(tester, const Duration(milliseconds: 20));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    expect(condition(), isTrue, reason: reason);
  }

  Future<void> go(WidgetTester tester, String location) async {
    container.read(routerProvider).go(location);
    await pump(tester, const Duration(milliseconds: 350));
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await pump(tester);
    await tester.tap(finder);
    await pump(tester);
  }

  Future<void> openPuzzle(
    WidgetTester tester,
    Puzzle puzzle, {
    String? dailyKey,
    bool resume = false,
  }) async {
    await go(
      tester,
      Uri(
        path: '/play/${puzzle.id}',
        queryParameters: {'daily': ?dailyKey, if (resume) 'resume': '1'},
      ).toString(),
    );
    await until(
      tester,
      () =>
          find.byKey(const ValueKey('hint-button')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('next-puzzle')).evaluate().isNotEmpty,
    );
  }

  Future<void> solvePuzzle(
    WidgetTester tester,
    Puzzle puzzle, {
    void Function(String)? trace,
  }) async {
    final playsBefore =
        services.progress.current.records[puzzle.id]?.plays ?? 0;
    await answerPuzzle(tester, puzzle, trace: trace);
    trace?.call('${puzzle.id}: wait for durable completion');
    await until(
      tester,
      () =>
          services.progress.current.records[puzzle.id]?.plays ==
          playsBefore + 1,
      reason: 'The app did not durably complete ${puzzle.id}.',
    );
  }

  Future<void> answerPuzzle(
    WidgetTester tester,
    Puzzle puzzle, {
    void Function(String)? trace,
  }) async {
    if (puzzle.mode.isScene) {
      for (final id in puzzle.answerIds) {
        trace?.call('${puzzle.id}: tap scene object $id');
        await tapSceneObject(tester, puzzle, id);
      }
    } else {
      var roundNumber = 0;
      for (final round in puzzle.rounds) {
        roundNumber++;
        if (puzzle.mode == GameMode.memory) {
          trace?.call('${puzzle.id}: round $roundNumber ready');
          await tap(tester, find.byKey(const ValueKey('memory-ready')));
        }
        for (final answer in round.answers) {
          trace?.call('${puzzle.id}: round $roundNumber tap tile $answer');
          await tap(tester, find.byKey(ValueKey('tiles-$answer')));
        }
        trace?.call('${puzzle.id}: round $roundNumber transition');
        await pump(tester, const Duration(milliseconds: 600));
      }
    }
  }

  /// Brings a scene point into the clipped pan/zoom viewport, then uses a real
  /// pointer tap. The pinned checklist is not an ancestor scrollable, and the
  /// scene's transformed bounding box may extend well beyond the phone screen.
  Future<void> tapSceneObject(
    WidgetTester tester,
    Puzzle puzzle,
    String objectId,
  ) async {
    final point = await focusSceneObject(tester, puzzle, objectId);
    await tester.tapAt(point);
    await pump(tester);
  }

  Future<Offset> focusSceneObject(
    WidgetTester tester,
    Puzzle puzzle,
    String objectId,
  ) async {
    final scene = find.byKey(const ValueKey('scene-a'));
    final object = puzzle.scene!.objects.firstWhere((o) => o.id == objectId);
    final viewerFinder = find.ancestor(
      of: scene,
      matching: find.byType(InteractiveViewer),
    );
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    final contentSize = tester.getSize(scene);
    final viewportSize = tester.getSize(viewerFinder);
    final scale = math.max(
      2.0,
      viewer.transformationController!.value.getMaxScaleOnAxis(),
    );
    final dx =
        (viewportSize.width / 2 -
                object.region.centerX * contentSize.width * scale)
            .clamp(
              math.min(0.0, viewportSize.width - contentSize.width * scale),
              0.0,
            )
            .toDouble();
    final dy =
        (viewportSize.height / 2 -
                object.region.centerY * contentSize.height * scale)
            .clamp(
              math.min(0.0, viewportSize.height - contentSize.height * scale),
              0.0,
            )
            .toDouble();
    viewer.transformationController!.value = Matrix4.diagonal3Values(
      scale,
      scale,
      1,
    )..setTranslationRaw(dx, dy, 0);
    await pump(tester);
    final target = find.byKey(ValueKey('scene-a-object-$objectId'));
    final point = tester.getCenter(target);
    expect(
      tester.getRect(viewerFinder).contains(point),
      isTrue,
      reason: '$objectId must be visible before the pointer tap.',
    );
    return point;
  }

  Future<void> close(WidgetTester tester) async {
    // A paused binding can suppress the unmount frame. Resume frame delivery
    // before disposal so no widget retains a disposed ProviderContainer.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    container.dispose();
    var closed = false;
    final closing = services.close().then((_) => closed = true);
    await until(tester, () => closed, reason: 'Local resources did not close.');
    await closing;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }
}
