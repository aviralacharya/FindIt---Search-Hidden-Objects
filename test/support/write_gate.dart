import 'dart:async';

import 'package:drift/drift.dart';

/// Holds one real SQLite write so lifecycle races are deterministic, not timed.
class WriteGate extends QueryInterceptor {
  bool Function(String, List<Object?>)? _predicate;
  Completer<void>? _release;
  bool waiting = false;

  void holdNextInsert(bool Function(String, List<Object?>) predicate) {
    if (waiting) throw StateError('Release the held write first.');
    _predicate = predicate;
    _release = Completer<void>();
  }

  void release() {
    _predicate = null;
    final release = _release;
    if (release != null && !release.isCompleted) release.complete();
    waiting = false;
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    if (_predicate?.call(statement, args) ?? false) {
      _predicate = null;
      waiting = true;
      await _release!.future;
      waiting = false;
    }
    return executor.runInsert(statement, args);
  }
}
