import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_services.dart';
import '../../app/theme.dart';
import '../../core/art/brand_art.dart';
import '../../core/art/object_art.dart';
import '../../core/config/app_config.dart';
import '../../core/domain/game_engine.dart';
import '../../core/domain/progress.dart';
import '../../core/domain/puzzle.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/game_clock.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/object_checklist.dart';
import '../../ui/widgets/scene_board.dart';
import '../../ui/widgets/tile_board.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({
    super.key,
    required this.puzzleId,
    this.dailyKey,
    this.resume = false,
  });
  final String puzzleId;
  final String? dailyKey;
  final bool resume;
  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with WidgetsBindingObserver {
  late final AppServices _services;
  GameEngine? _engine;
  String? _dailyKey;
  CompletionReceipt? _receipt;
  String? _invalid;
  String? _saveError;
  String _pauseMessage = 'A little breather. Your discovery can wait.';
  bool _ready = false;
  bool _paused = false;
  bool _busy = false;
  bool _menuShowing = false;
  bool _foreground = true;
  late final GameClock _clock;
  int _lastTick = 0;
  int _lastAutosave = 0;
  int _lastTap = -1000;
  int? _wrongTile;
  Offset? _wrongPoint;
  Timer? _ticker;
  Timer? _roundTimer;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _services = ref.read(servicesProvider);
    _clock = ref.read(gameClockFactoryProvider)();
    _open();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  Future<void> _open() async {
    final puzzle = _services.content.find(widget.puzzleId);
    if (puzzle == null) {
      setState(() => _invalid = 'This puzzle is not installed on your device.');
      return;
    }
    final saved = _services.progress.current.savedGame;
    _dailyKey = widget.dailyKey;
    try {
      final resuming = widget.resume && saved?.puzzleId == widget.puzzleId;
      if (resuming) _dailyKey = saved!.dailyKey;
      // Authorize daily membership before creating an engine. An invalid route
      // must not replace the active session through lifecycle/dispose autosaves.
      if ((puzzle.id.startsWith('daily-') || _dailyKey != null) &&
          (_dailyKey == null ||
              !(_services.progress.current.daily[_dailyKey]?.puzzles.any(
                    (p) => p.id == puzzle.id,
                  ) ??
                  false))) {
        setState(
          () => _invalid = 'Open this puzzle from its saved daily challenge.',
        );
        return;
      }
      if (resuming) {
        final restored = saved!.restore();
        if (restored.puzzle.mode != GameMode.hidden) {
          setState(
            () => _invalid =
                'Only hidden-object searches are available in this app.',
          );
          return;
        }
        _engine = restored;
      } else {
        if (!puzzle.id.startsWith('daily-') &&
            !_services.content.isUnlocked(puzzle)) {
          setState(
            () =>
                _invalid = 'Complete the previous level to unlock this puzzle.',
          );
          return;
        }
        _engine = GameEngine(
          puzzle,
          relaxed: _services.settings.current.relaxed,
        );
      }
      await _services.beginPlay();
      await _services.saveGame(_engine!, dailyKey: _dailyKey);
      if (!mounted) return;
      setState(() => _ready = true);
      if (_engine!.completed) {
        await _finish();
      } else {
        _resumeClock();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_engine == null) {
            _invalid = 'This saved puzzle couldn’t be read. Your completed levels and coins are still safe. Start a new puzzle from Play.';
          } else {
            _ready = true;
            _paused = true;
            _saveError = 'We couldn’t save your place. Free up a little device storage, then try again.';
          }
        });
      }
    }
  }

  void _advanceClock() {
    if (!_clock.isRunning || _engine == null) return;
    final now = _clock.elapsedMilliseconds;
    _engine!.tick(now - _lastTick);
    _lastTick = now;
  }

  void _resumeClock() {
    _lastTick = _clock.elapsedMilliseconds;
    if (_foreground && !_engine!.finished && _ready && !_paused && !_busy) {
      _clock.start();
    }
  }

  void _stopClock() {
    _advanceClock();
    _clock.stop();
  }

  void _tick() {
    if (!mounted ||
        !_ready ||
        _paused ||
        _busy ||
        _engine == null ||
        _engine!.finished) {
      return;
    }
    final oldPhase = _engine!.phase;
    _advanceClock();
    setState(() {});
    if (_engine!.phase != oldPhase) _save();
    if (_engine!.finished) _clock.stop();
    if (_clock.elapsedMilliseconds - _lastAutosave >= 5000) {
      _lastAutosave = _clock.elapsedMilliseconds;
      _save();
    }
  }

  Future<void> _save() async {
    if (_invalid != null || _engine == null || _engine!.completed) return;
    try {
      await _services.saveGame(_engine!, dailyKey: _dailyKey);
    } catch (_) {
      if (!mounted) return;
      _stopClock();
      setState(() {
        _paused = true;
        _saveError =
            'Your latest move couldn’t be saved. Please try saving again.';
      });
    }
  }

  Future<void> _retrySave() async {
    if (_engine == null) {
      await _open();
      return;
    }
    setState(() => _busy = true);
    try {
      await _services.saveGame(_engine!, dailyKey: _dailyKey);
      if (!mounted) return;
      setState(() {
        _saveError = null;
        _busy = false;
        _paused = !_foreground;
        // A failed round save may have canceled the transition timer. Its
        // durable snapshot reopens the next round; the live engine must do the
        // same when retrying in the foreground, or wait for explicit resume.
        if (!_paused && _engine!.phase == PlayPhase.betweenRounds) {
          _engine!.nextRound();
        }
      });
      if (_engine!.completed) {
        await _finish();
      } else {
        _resumeClock();
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _canTap() {
    if (!_ready ||
        _paused ||
        _busy ||
        _engine == null ||
        _engine!.phase != PlayPhase.answering) {
      return false;
    }
    _advanceClock();
    if (_engine!.finished) {
      setState(() {});
      _save();
      return false;
    }
    if (_clock.elapsedMilliseconds - _lastTap < 180) return false;
    _lastTap = _clock.elapsedMilliseconds;
    return true;
  }

  void _tapScene(double x, double y) {
    if (!_canTap()) return;
    final result = _engine!.tapScene(x, y);
    _answer(result, point: Offset(x, y));
  }

  void _tapTile(int index) {
    if (!_canTap()) return;
    final result = _engine!.tapTile(index);
    _answer(result, tile: index);
  }

  void _answer(AnswerResult result, {int? tile, Offset? point}) {
    if (result == AnswerResult.ignored || result == AnswerResult.alreadyFound) {
      return;
    }
    setState(() {
      _wrongTile = result == AnswerResult.incorrect ? tile : null;
      _wrongPoint = result == AnswerResult.incorrect ? point : null;
    });
    unawaited(
      _services.audio.play(
        result == AnswerResult.incorrect ? GameSound.wrong : GameSound.found,
      ),
    );
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        setState(() {
          _wrongTile = null;
          _wrongPoint = null;
        });
      }
    });
    if (result == AnswerResult.completed) {
      _finish();
      return;
    }
    _save();
    if (result == AnswerResult.roundComplete) {
      _roundTimer?.cancel();
      _roundTimer = Timer(const Duration(milliseconds: 550), () {
        if (!mounted || _engine == null || _paused) return;
        setState(() => _engine!.nextRound());
        _save();
      });
    }
  }

  Future<void> _finish() async {
    if (_busy || _receipt != null) return;
    _stopClock();
    setState(() => _busy = true);
    try {
      // If the process stops between these two writes, reopening the completed
      // saved engine retries the same idempotent completion receipt.
      await _services.saveGame(_engine!, dailyKey: _dailyKey);
      final receipt = await _services.completeGame(
        _engine!,
        dailyKey: _dailyKey,
      );
      if (!mounted) return;
      unawaited(_services.audio.play(GameSound.complete));
      setState(() {
        _receipt = receipt;
        _busy = false;
        _paused = false;
        _saveError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _paused = true;
          _saveError = 'You finished! Your reward is waiting for a successful local save. Try again; it won’t be awarded twice.';
        });
      }
    }
  }

  void _pause({bool background = false}) {
    if (_invalid != null || _engine == null || _engine!.finished) return;
    _stopClock();
    _roundTimer?.cancel();
    setState(() {
      _paused = true;
      _pauseMessage = background
          ? 'You stepped away. Your puzzle waited for you.'
          : 'A little breather. Your discovery can wait.';
    });
    // An in-flight hint/open/restart owns its durable snapshot. Saving the old
    // engine here could overwrite a paid hint after its transaction commits.
    if (!_busy) _save();
  }

  void _resume() {
    if (!_foreground ||
        !_ready ||
        _busy ||
        _saveError != null ||
        _engine == null) {
      return;
    }
    setState(() => _paused = false);
    if (_engine!.phase == PlayPhase.betweenRounds) _engine!.nextRound();
    _resumeClock();
    _save();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && mounted) _pause(background: true);
  }

  Future<void> _pauseMenu() async {
    if (_menuShowing || _busy || _engine == null) return;
    if (_engine!.finished) {
      await _leave();
      return;
    }
    _menuShowing = true;
    _pause();
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'A little breather',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your finds and timer are saved on this device. There’s no hurry.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: FindItColors.muted),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'resume'),
                  child: const Text('Keep discovering'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'leave'),
                  child: const Text('Save & leave'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'restart'),
                  child: const Text('Start this level again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _menuShowing = false;
    if (!mounted) return;
    if (choice == 'leave') {
      await _leave();
    } else if (choice == 'restart') {
      await _confirmRestart();
    } else if (_saveError == null) {
      _resume();
    }
  }

  Future<void> _confirmRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A fresh look?'),
        content: const Text(
          'This starts the level from the beginning. Coins already spent on hints are not refunded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my place'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start again'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      await _restart();
    } else {
      _resume();
    }
  }

  Future<void> _restart({bool? relaxed}) async {
    _roundTimer?.cancel();
    _feedbackTimer?.cancel();
    _clock.stop();
    _clock.reset();
    setState(() {
      _engine = GameEngine(
        _engine!.puzzle,
        relaxed: relaxed ?? _services.settings.current.relaxed,
      );
      _receipt = null;
      _saveError = null;
      _paused = false;
      _busy = true;
      _wrongPoint = null;
      _wrongTile = null;
      _lastTick = 0;
      _lastTap = -1000;
      _lastAutosave = 0;
    });
    await _save();
    if (!mounted) return;
    setState(() => _busy = false);
    _resumeClock();
  }

  Future<void> _leave() async {
    _stopClock();
    if (_engine != null && !_engine!.completed) await _save();
    if (!mounted || _saveError != null) return;
    context.go(
      _dailyKey != null
          ? '/daily'
          : _engine != null
          ? '/mode/${_engine!.puzzle.mode.slug}'
          : '/',
    );
  }

  Future<void> _next() async {
    if (_busy) return;
    setState(() => _busy = true);
    Puzzle? next;
    if (_dailyKey != null) {
      final daily = _services.progress.current.daily[_dailyKey];
      next = daily?.puzzles
          .where((p) => !daily.completedIds.contains(p.id))
          .firstOrNull;
    } else {
      next = _services.content.next(_engine!.puzzle);
    }
    if (next == null) {
      context.go(
        _dailyKey != null ? '/daily' : '/mode/${_engine!.puzzle.mode.slug}',
      );
      return;
    }
    context.pushReplacement(
      Uri(
        path: '/play/${next.id}',
        queryParameters: _dailyKey == null ? null : {'daily': _dailyKey!},
      ).toString(),
    );
  }

  Future<void> _hint() async {
    if (_busy || _paused || (!_engine!.canHint && !_engine!.canRevealHint)) {
      return;
    }
    _stopClock();
    if (_engine!.canRevealHint) {
      await _revealHint();
      return;
    }
    if (_services.progress.current.coins < AppConfig.hintCost) {
      _pause();
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 2, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const IconBadge(Icons.lightbulb_outline_rounded),
                  const SizedBox(height: 16),
                  Text(
                    'A little nudge',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Hints cost 20 coins. Earn coins by finishing levels or completing your daily adventure. No purchase or ad is required.',
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('I’ll keep looking'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (mounted && _saveError == null) _resume();
      return;
    }
    setState(() => _busy = true);
    try {
      final hinted = await _services.purchaseHint(
        _engine!,
        dailyKey: _dailyKey,
      );
      if (!mounted) return;
      if (hinted != null) {
        setState(() => _engine = hinted);
        unawaited(_services.audio.play(GameSound.hint));
      } else {
        showMessage(
          context,
          'This hint wasn’t charged. Try again after your next find.',
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'The hint could not be saved. No puzzle progress was lost.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_paused) {
          await _save();
        } else {
          _resumeClock();
        }
      }
    }
  }

  Future<void> _revealHint() async {
    setState(() => _busy = true);
    try {
      final precise = GameEngine.restore(_engine!.toJson());
      if (!precise.revealHint()) return;
      await _services.saveGame(precise, dailyKey: _dailyKey);
      if (!mounted) return;
      setState(() => _engine = precise);
      unawaited(_services.audio.play(GameSound.hint));
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'The reveal could not be saved. Your paid area hint is still available; no extra coins were charged.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_paused) {
          await _save();
        } else {
          _resumeClock();
        }
      }
    }
  }

  Future<void> _help() async {
    if (_engine == null || _busy) return;
    _pause();
    final mode = _engine!.puzzle.mode;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mode.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mode.instructions),
              const SizedBox(height: 16),
              Text(switch (mode) {
                GameMode.differences => 'There are exactly five differences. Found differences are marked in both pictures. Pinch to zoom; tap the zoom icon to reset.',
                GameMode.hidden => 'Find the objects pictured in the pinned checklist. Drag to explore the scene; pinch or use the zoom buttons for a closer look. Your first hint highlights a search area. Reveal that same object precisely for free if you still need help. You must tap the object yourself; found objects stay checked off.',
                GameMode.odd => 'There is exactly one different tile in each grid. It may differ in shape or color.',
                GameMode.memory => 'You may be asked what disappeared, what was added, which two positions moved, or which object appeared twice. A hint lets you look again.',
                GameMode.quick => 'Match the pictured target. Correct finds build a combo; a wrong tap breaks it and adds a 1.5-second penalty when the timer is on.',
                _ => '',
              }),
              const SizedBox(height: 16),
              const Text(
                'Earn up to three stars through accurate finds, fewer hints, and a good pace. A hint costs 20 coins. Pausing never uses your timer.',
              ),
              if (_engine!.relaxed) ...[
                const SizedBox(height: 12),
                const Text(
                  'Relaxed search is on. There is no countdown. You can choose timed searches for new sessions in Settings.',
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it. Let’s find!'),
          ),
        ],
      ),
    );
    if (mounted && !_engine!.finished && _saveError == null) _resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _roundTimer?.cancel();
    _feedbackTimer?.cancel();
    _clock.stop();
    if (_invalid == null && !_busy && _engine != null && !_engine!.completed) {
      unawaited(
        _services
            .saveGame(_engine!, dailyKey: _dailyKey)
            .catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final game = _engine;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_invalid != null) {
            context.go('/');
          } else {
            _pauseMenu();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Save and pause',
            onPressed: _invalid != null ? () => context.go('/') : _pauseMenu,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            game?.puzzle.mode.title ?? 'A little discovery',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          actions: [
            CoinPill(state.progress.coins, compact: true),
            if (game != null && !game.finished)
              IconButton(
                key: const ValueKey('pause-game'),
                tooltip: 'Pause puzzle',
                onPressed: _pauseMenu,
                icon: const Icon(Icons.pause_rounded),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: _invalid != null
            ? EmptyState(
                title: 'This discovery is waiting',
                message: _invalid!,
                action: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to play'),
                ),
              )
            : !_ready || game == null
            ? const Center(child: CircularProgressIndicator())
            : _paused
            ? _pausePanel()
            : game.completed
            ? _completionPanel()
            : game.phase == PlayPhase.timedOut
            ? _timeoutPanel()
            : _gameBody(game),
        bottomNavigationBar:
            game != null && _ready && !game.finished && !_paused
            ? _searchFooter(game)
            : null,
      ),
    );
  }

  Widget _searchFooter(GameEngine game) => SafeArea(
    top: false,
    child: Container(
      decoration: const BoxDecoration(
        color: FindItColors.paper,
        border: Border(top: BorderSide(color: FindItColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (game.puzzle.mode == GameMode.hidden &&
                  MediaQuery.sizeOf(context).width < 740) ...[
                ObjectChecklist(game: game),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('hint-button'),
                      onPressed: !_busy && (game.canHint || game.canRevealHint)
                          ? _hint
                          : null,
                      icon: const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 20,
                      ),
                      label: Text(
                        game.canRevealHint
                            ? 'Reveal object · free'
                            : 'Area hint · 20 coins',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    tooltip: 'How to play',
                    onPressed: _help,
                    icon: const Icon(Icons.question_mark_rounded, size: 21),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _pausePanel() => PageContent(
    maxWidth: 620,
    child: Padding(
      padding: const EdgeInsets.only(top: 40),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: IconBadge(Icons.pause_rounded, size: 66)),
            const SizedBox(height: 22),
            Text(
              _saveError == null
                  ? 'Right where you left it.'
                  : 'Let’s keep your progress safe.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            Text(
              _saveError ?? _pauseMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: FindItColors.muted),
            ),
            const SizedBox(height: 25),
            FilledButton(
              key: const ValueKey('resume-game'),
              onPressed: _busy
                  ? null
                  : _saveError != null
                  ? _retrySave
                  : _resume,
              child: Text(
                _busy
                    ? 'Saving…'
                    : _saveError != null
                    ? 'Try saving again'
                    : 'Keep discovering',
              ),
            ),
            if (_saveError == null) ...[
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _leave,
                child: const Text('Save & leave'),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _gameBody(GameEngine game) => game.puzzle.mode == GameMode.hidden
      ? _hiddenGameBody(game)
      : _legacyGameBody(game);

  Widget _hiddenGameBody(GameEngine game) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 740;
      final compact = constraints.maxHeight < 380;
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      // Keep the scene usable when the pinned, accessible checklist and hint
      // controls take most of a small phone's height. Progress remains visible
      // in the checklist, and full scene details stay available to semantics.
      final minimal = constraints.maxHeight < 180 * textScale;
      final board = SceneBoard(
        key: ValueKey('${game.sessionId}-search'),
        puzzle: game.puzzle,
        alternate: false,
        fillAvailable: true,
        found: game.found,
        hintId: game.hintObjectId,
        hintIsPrecise: game.hintRevealed,
        wrongPoint: _wrongPoint,
        onTap: !_busy ? _tapScene : null,
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 5, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                children: [
                  Expanded(
                    child: minimal
                        ? Semantics(
                            label:
                                '${game.puzzle.title}. ${game.answersFound} of ${game.puzzle.totalAnswers} found. ${game.mistakes} misses.',
                            excludeSemantics: true,
                            child: Text(
                              _dailyKey == null
                                  ? 'Level ${game.puzzle.level}'
                                  : 'Daily search',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Eyebrow(
                                '${_dailyKey == null ? 'LEVEL ${game.puzzle.level}' : 'DAILY SEARCH'} · ${game.puzzle.difficultyLabel.toUpperCase()}',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                game.puzzle.title.split(' · ').first,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 8),
                  _TimerChip(game: game),
                ],
              ),
            ),
            const SizedBox(height: 9),
            if (!minimal && compact)
              Text(
                '${game.answersFound} of ${game.puzzle.totalAnswers} found · ${game.mistakes} misses',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else if (!minimal)
              _StatusStrip(game: game),
            if (!minimal) const SizedBox(height: 8),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: board),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 244,
                          child: ObjectChecklist(game: game, vertical: true),
                        ),
                      ],
                    )
                  : board,
            ),
            if (!minimal) ...[
              const SizedBox(height: 6),
              Text(
                game.hintObjectId == null
                    ? 'Drag to explore · Pinch or use + to look closer'
                    : game.hintRevealed
                    ? 'Your object is circled in gold. Tap it to find it.'
                    : 'Search the golden area. Need more help? Reveal it for free.',
                textAlign: TextAlign.center,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: game.hintObjectId == null
                      ? FindItColors.muted
                      : const Color(0xFF9A7635),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _legacyGameBody(GameEngine game) => PageContent(
    maxWidth: game.puzzle.mode.isScene ? 1200 : 720,
    padding: const EdgeInsets.fromLTRB(18, 9, 18, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(
                    '${_dailyKey != null ? 'DAILY DISCOVERY' : 'LEVEL ${game.puzzle.level.toString().padLeft(2, '0')}'} · ${game.puzzle.difficultyLabel.toUpperCase()}',
                  ),
                  const SizedBox(height: 5),
                  Text(
                    game.puzzle.title,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _TimerChip(game: game),
          ],
        ),
        const SizedBox(height: 18),
        _StatusStrip(game: game),
        const SizedBox(height: 19),
        if (game.puzzle.mode.isScene) _sceneBody(game) else _tileBody(game),
        if (game.hintObjectId != null || game.hintTile != null) ...[
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Your little nudge is highlighted in gold.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9A7635), fontSize: 13),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _sceneBody(GameEngine game) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (game.puzzle.mode == GameMode.hidden) ...[
        Text(
          'On your little list',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in game.puzzle.answerIds)
              Builder(
                builder: (context) {
                  final object = game.puzzle.scene!.objects.firstWhere(
                    (o) => o.id == id,
                  );
                  final found = game.found.contains(id);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: found ? FindItColors.sage : FindItColors.paper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: FindItColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ObjectGlyph(
                          object.kind,
                          size: 28,
                          colorIndex: object.color,
                          variant: object.variant,
                          semanticLabel: false,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          objectLabel(object.kind),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: found
                                    ? FindItColors.forest
                                    : FindItColors.ink,
                                decoration: found
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                        if (found) ...[
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: FindItColors.forest,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
      ] else ...[
        Text(
          'Same little world. Five little changes.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
      ],
      Text(
        game.puzzle.mode == GameMode.hidden
            ? 'Tap an object to find it · Pinch to zoom'
            : 'Tap a difference in either picture · Pinch to zoom',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: FindItColors.muted),
      ),
      const SizedBox(height: 13),
      LayoutBuilder(
        builder: (context, constraints) {
          Widget image(bool alternate) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (game.puzzle.mode == GameMode.differences) ...[
                Eyebrow(alternate ? 'PICTURE B' : 'PICTURE A'),
                const SizedBox(height: 8),
              ],
              SceneBoard(
                key: ValueKey('${game.sessionId}-$alternate'),
                puzzle: game.puzzle,
                alternate: alternate,
                found: game.found,
                hintId: game.hintObjectId,
                wrongPoint: _wrongPoint,
                onTap: !_busy ? _tapScene : null,
              ),
            ],
          );
          if (game.puzzle.mode == GameMode.hidden) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: image(false),
              ),
            );
          }
          return constraints.maxWidth >= 740
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: image(false)),
                    const SizedBox(width: 18),
                    Expanded(child: image(true)),
                  ],
                )
              : Column(
                  children: [
                    image(false),
                    const SizedBox(height: 17),
                    image(true),
                  ],
                );
        },
      ),
    ],
  );

  Widget _tileBody(GameEngine game) {
    final round = game.currentRound;
    final memory = game.puzzle.mode == GameMode.memory;
    final preview = game.phase == PlayPhase.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview) ...[
          SoftCard(
            color: FindItColors.modeBackground(GameMode.memory),
            border: false,
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined, color: Color(0xFF726489)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Take a good look',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        game.relaxed
                            ? 'Take your time. Tap “I’m ready” when you are.'
                            : 'Remember the objects${round.rule == MemoryRule.moved ? ' and their positions' : ''}.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: FindItColors.muted),
                      ),
                    ],
                  ),
                ),
                if (!game.relaxed) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${(game.previewRemainingMs / 1000).ceil()}',
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(color: const Color(0xFF726489)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          TileBoard(
            tiles: round.preview,
            columns: round.rule == MemoryRule.moved ? round.columns : 3,
            numbered: round.rule == MemoryRule.moved,
            boardKey: 'preview',
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            key: const ValueKey('memory-ready'),
            onPressed: () {
              _advanceClock();
              setState(() => game.finishPreview());
              _save();
            },
            child: const Text('I’m ready'),
          ),
        ] else ...[
          if (game.puzzle.mode == GameMode.quick) ...[
            SoftCard(
              color: FindItColors.modeBackground(GameMode.quick),
              border: false,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  ObjectGlyph(
                    round.target!.kind,
                    colorIndex: round.target!.color,
                    variant: round.target!.variant,
                    size: 64,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow(
                          'FIND THIS LITTLE THING',
                          color: Color(0xFF497E8D),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          objectLabel(round.target!.kind),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ] else ...[
            Text(
              memory ? round.question : 'Which one is a little different?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              memory && round.rule == MemoryRule.moved
                  ? 'Tap both changed positions.'
                  : 'Look closely, then tap your answer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: FindItColors.muted),
            ),
            const SizedBox(height: 20),
          ],
          if (memory && round.rule == MemoryRule.disappeared) ...[
            SoftCard(
              color: FindItColors.modeBackground(GameMode.memory),
              border: false,
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  const Eyebrow('THESE OBJECTS ARE STILL HERE'),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final tile in round.preview.where(
                        (t) => t.kind != round.target!.kind,
                      ))
                        ObjectGlyph(
                          tile.kind,
                          colorIndex: tile.color,
                          variant: tile.variant,
                          size: 43,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          TileBoard(
            key: ValueKey('round-${game.sessionId}-${game.roundIndex}'),
            tiles: round.tiles,
            columns: round.columns,
            onTap: game.phase == PlayPhase.answering && !_busy
                ? _tapTile
                : null,
            selected: game.selectedTiles,
            eliminated: game.eliminated,
            wrong: _wrongTile,
            hint: game.hintTile,
            numbered: memory && round.rule == MemoryRule.moved,
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: game.phase == PlayPhase.betweenRounds
                ? const Text(
                    'Lovely find! Here’s the next little challenge.',
                    key: ValueKey('round-done'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FindItColors.forest),
                  )
                : _wrongTile != null
                ? const Text(
                    'Not quite. Take another little look.',
                    key: ValueKey('wrong'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FindItColors.coral),
                  )
                : const SizedBox(height: 20),
          ),
        ],
      ],
    );
  }

  Widget _completionPanel() {
    final game = _engine!;
    return PageContent(
      // Results are a new page state, not the scrolled puzzle board. Start at
      // the top so the artwork, title and saved reward are not clipped away.
      key: const ValueKey('completion-panel'),
      maxWidth: 690,
      child: Column(
        children: [
          const SizedBox(height: 16),
          ModeArtwork(game.puzzle.mode, width: 171, height: 125),
          const SizedBox(height: 8),
          const Eyebrow(
            'A LITTLE DISCOVERY. A LOVELY FEELING.',
            color: FindItColors.forest,
          ),
          const SizedBox(height: 12),
          Text(
            game.stars == 3
                ? 'Beautifully spotted!'
                : 'Look at you, discovering.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 14),
          Center(child: Stars(game.stars, size: 52)),
          const SizedBox(height: 12),
          Text(
            _receipt == null
                ? 'Saving your lovely achievement…'
                : _receipt!.firstCompletion
                ? 'One more little corner of the world, discovered.'
                : 'An old favorite, seen with fresh eyes.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: FindItColors.muted),
          ),
          const SizedBox(height: 28),
          SoftCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ResultStat(
                        'Score',
                        '${game.score}',
                        Icons.auto_awesome_outlined,
                      ),
                    ),
                    Expanded(
                      child: _ResultStat(
                        'Accuracy',
                        '${(game.accuracy * 100).round()}%',
                        Icons.gps_fixed_rounded,
                      ),
                    ),
                    Expanded(
                      child: _ResultStat(
                        'Time',
                        formatTime(game.elapsedMs),
                        Icons.schedule_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 17),
                if (_receipt != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: FindItColors.gold,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '+${_receipt!.coins + _receipt!.dailyBonus} coins safely saved',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: FindItColors.forest),
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_receipt != null && _receipt!.dailyBonus > 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Including your 60-coin daily adventure bonus!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: FindItColors.forest),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('next-puzzle'),
              onPressed: _receipt != null && !_busy ? _next : null,
              label: Text(
                _dailyKey != null
                    ? 'Continue daily adventure'
                    : _services.content.next(game.puzzle) == null
                    ? 'Back to your journey'
                    : 'The next little discovery',
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 19),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _receipt != null && !_busy ? _leave : null,
              child: Text(
                _dailyKey != null
                    ? 'Today’s discoveries'
                    : 'Choose another level',
              ),
            ),
          ),
          TextButton(
            onPressed: _receipt != null && !_busy ? _restart : null,
            child: const Text('Enjoy this one again'),
          ),
          if (game.relaxed)
            const Text(
              'Take-your-time mode · no countdown',
              style: TextStyle(color: FindItColors.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _timeoutPanel() => PageContent(
    maxWidth: 650,
    child: Column(
      children: [
        const SizedBox(height: 30),
        const ModeArtwork(GameMode.hidden, width: 174, height: 130),
        const SizedBox(height: 18),
        const Eyebrow('EVERY TRY IS A FRESH PERSPECTIVE'),
        const SizedBox(height: 12),
        Text(
          'A little more time? A little less rush.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 15),
        Text(
          'The timer ran out, but your curiosity hasn’t. Try again, or take your time with the countdown off.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: FindItColors.muted),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('retry-game'),
            onPressed: _busy ? null : _restart,
            child: const Text('Try a fresh look'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy ? null : () => _restart(relaxed: true),
            child: const Text('Try without the countdown'),
          ),
        ),
        TextButton(onPressed: _leave, child: const Text('Back to my journey')),
      ],
    ),
  );
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.game});
  final GameEngine game;
  @override
  Widget build(BuildContext context) {
    final urgent = game.timed && game.remainingMs <= 15000;
    final color = urgent ? FindItColors.coral : FindItColors.forest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFF4E2D9) : FindItColors.sage,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            game.relaxed ? Icons.spa_outlined : Icons.schedule_rounded,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            game.relaxed
                ? 'No rush'
                : formatTime(game.timed ? game.remainingMs : game.elapsedMs),
            style: TextStyle(
              color: color,
              fontFamily: 'Outfit',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.game});
  final GameEngine game;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
    decoration: BoxDecoration(
      color: FindItColors.paper,
      border: Border.all(color: FindItColors.line),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                game.puzzle.mode.isScene
                    ? '${game.answersFound} of ${game.puzzle.totalAnswers} found'
                    : 'Round ${game.roundIndex + 1} of ${game.puzzle.rounds.length}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              game.puzzle.mode == GameMode.quick
                  ? '${game.combo}× combo'
                  : '${game.mistakes} ${game.mistakes == 1 ? 'miss' : 'misses'}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: FindItColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: math.min(1, game.answersFound / game.puzzle.totalAnswers),
          minHeight: 4,
        ),
      ],
    ),
  );
}

class _ResultStat extends StatelessWidget {
  const _ResultStat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: FindItColors.muted, size: 20),
      const SizedBox(height: 9),
      Text(value, maxLines: 1, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: FindItColors.muted),
      ),
    ],
  );
}
