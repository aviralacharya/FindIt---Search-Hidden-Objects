import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../config/app_config.dart';

QueryExecutor openConnection({String name = AppConfig.storageNamespace}) =>
    LazyDatabase(() async {
      if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
        throw ArgumentError.value(name, 'name', 'Unsafe storage namespace.');
      }
      final directory = await getApplicationSupportDirectory();
      final temporary = await getTemporaryDirectory();
      sqlite3.tempDirectory = temporary.path;
      return NativeDatabase.createInBackground(
        File(p.join(directory.path, '$name.sqlite')),
      );
    });
