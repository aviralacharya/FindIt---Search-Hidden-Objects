/// Elapsed foreground time, independent of wall-clock changes and time zones.
/// Each game screen owns a clock; tests can supply controlled elapsed time.
abstract interface class GameClock {
  int get elapsedMilliseconds;
  bool get isRunning;
  void start();
  void stop();
  void reset();
}

final class StopwatchGameClock implements GameClock {
  final Stopwatch _stopwatch = Stopwatch();

  @override
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;
  @override
  bool get isRunning => _stopwatch.isRunning;
  @override
  void start() => _stopwatch.start();
  @override
  void stop() => _stopwatch.stop();
  @override
  void reset() => _stopwatch.reset();
}
