import 'package:drift/drift.dart';

import 'connection.dart';

part 'database.g.dart';

class LevelResults extends Table {
  TextColumn get puzzleId => text()();
  TextColumn get mode => text()();
  IntColumn get stars => integer()();
  IntColumn get bestScore => integer()();
  IntColumn get bestElapsedMs => integer()();
  RealColumn get bestAccuracy => real()();
  IntColumn get bestCombo => integer()();
  IntColumn get plays => integer()();
  DateTimeColumn get completedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {puzzleId};
}

class WalletEntries extends Table {
  TextColumn get eventId => text()();
  IntColumn get amount => integer()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {eventId};
}

class LocalEntries extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [LevelResults, WalletEntries, LocalEntries])
class FindItDatabase extends _$FindItDatabase {
  FindItDatabase([QueryExecutor? executor])
    : super(executor ?? openConnection());
  @override
  int get schemaVersion => 1;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
