import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

import '../config/app_config.dart';

QueryExecutor openConnection({String name = AppConfig.storageNamespace}) =>
    DatabaseConnection.delayed(
      Future(() async {
        if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
          throw ArgumentError.value(name, 'name', 'Unsafe storage namespace.');
        }
        final result = await WasmDatabase.open(
          databaseName: '${name}_v1',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.js'),
        );
        if (result.chosenImplementation == WasmStorageImplementation.inMemory ||
            result.chosenImplementation ==
                WasmStorageImplementation.unsafeIndexedDb) {
          throw StateError(
            'Reliable local storage is unavailable in this browser. '
            'Please use a normal browser window or the Android app.',
          );
        }
        return result.resolvedExecutor;
      }),
    );
