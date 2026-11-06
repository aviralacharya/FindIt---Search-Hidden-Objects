// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $LevelResultsTable extends LevelResults
    with TableInfo<$LevelResultsTable, LevelResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LevelResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _puzzleIdMeta = const VerificationMeta(
    'puzzleId',
  );
  @override
  late final GeneratedColumn<String> puzzleId = GeneratedColumn<String>(
    'puzzle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _starsMeta = const VerificationMeta('stars');
  @override
  late final GeneratedColumn<int> stars = GeneratedColumn<int>(
    'stars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bestScoreMeta = const VerificationMeta(
    'bestScore',
  );
  @override
  late final GeneratedColumn<int> bestScore = GeneratedColumn<int>(
    'best_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bestElapsedMsMeta = const VerificationMeta(
    'bestElapsedMs',
  );
  @override
  late final GeneratedColumn<int> bestElapsedMs = GeneratedColumn<int>(
    'best_elapsed_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bestAccuracyMeta = const VerificationMeta(
    'bestAccuracy',
  );
  @override
  late final GeneratedColumn<double> bestAccuracy = GeneratedColumn<double>(
    'best_accuracy',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bestComboMeta = const VerificationMeta(
    'bestCombo',
  );
  @override
  late final GeneratedColumn<int> bestCombo = GeneratedColumn<int>(
    'best_combo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playsMeta = const VerificationMeta('plays');
  @override
  late final GeneratedColumn<int> plays = GeneratedColumn<int>(
    'plays',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    puzzleId,
    mode,
    stars,
    bestScore,
    bestElapsedMs,
    bestAccuracy,
    bestCombo,
    plays,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'level_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<LevelResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('puzzle_id')) {
      context.handle(
        _puzzleIdMeta,
        puzzleId.isAcceptableOrUnknown(data['puzzle_id']!, _puzzleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_puzzleIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('stars')) {
      context.handle(
        _starsMeta,
        stars.isAcceptableOrUnknown(data['stars']!, _starsMeta),
      );
    } else if (isInserting) {
      context.missing(_starsMeta);
    }
    if (data.containsKey('best_score')) {
      context.handle(
        _bestScoreMeta,
        bestScore.isAcceptableOrUnknown(data['best_score']!, _bestScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_bestScoreMeta);
    }
    if (data.containsKey('best_elapsed_ms')) {
      context.handle(
        _bestElapsedMsMeta,
        bestElapsedMs.isAcceptableOrUnknown(
          data['best_elapsed_ms']!,
          _bestElapsedMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bestElapsedMsMeta);
    }
    if (data.containsKey('best_accuracy')) {
      context.handle(
        _bestAccuracyMeta,
        bestAccuracy.isAcceptableOrUnknown(
          data['best_accuracy']!,
          _bestAccuracyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bestAccuracyMeta);
    }
    if (data.containsKey('best_combo')) {
      context.handle(
        _bestComboMeta,
        bestCombo.isAcceptableOrUnknown(data['best_combo']!, _bestComboMeta),
      );
    } else if (isInserting) {
      context.missing(_bestComboMeta);
    }
    if (data.containsKey('plays')) {
      context.handle(
        _playsMeta,
        plays.isAcceptableOrUnknown(data['plays']!, _playsMeta),
      );
    } else if (isInserting) {
      context.missing(_playsMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {puzzleId};
  @override
  LevelResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LevelResult(
      puzzleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}puzzle_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      stars: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stars'],
      )!,
      bestScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}best_score'],
      )!,
      bestElapsedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}best_elapsed_ms'],
      )!,
      bestAccuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}best_accuracy'],
      )!,
      bestCombo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}best_combo'],
      )!,
      plays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plays'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $LevelResultsTable createAlias(String alias) {
    return $LevelResultsTable(attachedDatabase, alias);
  }
}

class LevelResult extends DataClass implements Insertable<LevelResult> {
  final String puzzleId;
  final String mode;
  final int stars;
  final int bestScore;
  final int bestElapsedMs;
  final double bestAccuracy;
  final int bestCombo;
  final int plays;
  final DateTime completedAt;
  const LevelResult({
    required this.puzzleId,
    required this.mode,
    required this.stars,
    required this.bestScore,
    required this.bestElapsedMs,
    required this.bestAccuracy,
    required this.bestCombo,
    required this.plays,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['puzzle_id'] = Variable<String>(puzzleId);
    map['mode'] = Variable<String>(mode);
    map['stars'] = Variable<int>(stars);
    map['best_score'] = Variable<int>(bestScore);
    map['best_elapsed_ms'] = Variable<int>(bestElapsedMs);
    map['best_accuracy'] = Variable<double>(bestAccuracy);
    map['best_combo'] = Variable<int>(bestCombo);
    map['plays'] = Variable<int>(plays);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  LevelResultsCompanion toCompanion(bool nullToAbsent) {
    return LevelResultsCompanion(
      puzzleId: Value(puzzleId),
      mode: Value(mode),
      stars: Value(stars),
      bestScore: Value(bestScore),
      bestElapsedMs: Value(bestElapsedMs),
      bestAccuracy: Value(bestAccuracy),
      bestCombo: Value(bestCombo),
      plays: Value(plays),
      completedAt: Value(completedAt),
    );
  }

  factory LevelResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LevelResult(
      puzzleId: serializer.fromJson<String>(json['puzzleId']),
      mode: serializer.fromJson<String>(json['mode']),
      stars: serializer.fromJson<int>(json['stars']),
      bestScore: serializer.fromJson<int>(json['bestScore']),
      bestElapsedMs: serializer.fromJson<int>(json['bestElapsedMs']),
      bestAccuracy: serializer.fromJson<double>(json['bestAccuracy']),
      bestCombo: serializer.fromJson<int>(json['bestCombo']),
      plays: serializer.fromJson<int>(json['plays']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'puzzleId': serializer.toJson<String>(puzzleId),
      'mode': serializer.toJson<String>(mode),
      'stars': serializer.toJson<int>(stars),
      'bestScore': serializer.toJson<int>(bestScore),
      'bestElapsedMs': serializer.toJson<int>(bestElapsedMs),
      'bestAccuracy': serializer.toJson<double>(bestAccuracy),
      'bestCombo': serializer.toJson<int>(bestCombo),
      'plays': serializer.toJson<int>(plays),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  LevelResult copyWith({
    String? puzzleId,
    String? mode,
    int? stars,
    int? bestScore,
    int? bestElapsedMs,
    double? bestAccuracy,
    int? bestCombo,
    int? plays,
    DateTime? completedAt,
  }) => LevelResult(
    puzzleId: puzzleId ?? this.puzzleId,
    mode: mode ?? this.mode,
    stars: stars ?? this.stars,
    bestScore: bestScore ?? this.bestScore,
    bestElapsedMs: bestElapsedMs ?? this.bestElapsedMs,
    bestAccuracy: bestAccuracy ?? this.bestAccuracy,
    bestCombo: bestCombo ?? this.bestCombo,
    plays: plays ?? this.plays,
    completedAt: completedAt ?? this.completedAt,
  );
  LevelResult copyWithCompanion(LevelResultsCompanion data) {
    return LevelResult(
      puzzleId: data.puzzleId.present ? data.puzzleId.value : this.puzzleId,
      mode: data.mode.present ? data.mode.value : this.mode,
      stars: data.stars.present ? data.stars.value : this.stars,
      bestScore: data.bestScore.present ? data.bestScore.value : this.bestScore,
      bestElapsedMs: data.bestElapsedMs.present
          ? data.bestElapsedMs.value
          : this.bestElapsedMs,
      bestAccuracy: data.bestAccuracy.present
          ? data.bestAccuracy.value
          : this.bestAccuracy,
      bestCombo: data.bestCombo.present ? data.bestCombo.value : this.bestCombo,
      plays: data.plays.present ? data.plays.value : this.plays,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LevelResult(')
          ..write('puzzleId: $puzzleId, ')
          ..write('mode: $mode, ')
          ..write('stars: $stars, ')
          ..write('bestScore: $bestScore, ')
          ..write('bestElapsedMs: $bestElapsedMs, ')
          ..write('bestAccuracy: $bestAccuracy, ')
          ..write('bestCombo: $bestCombo, ')
          ..write('plays: $plays, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    puzzleId,
    mode,
    stars,
    bestScore,
    bestElapsedMs,
    bestAccuracy,
    bestCombo,
    plays,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LevelResult &&
          other.puzzleId == this.puzzleId &&
          other.mode == this.mode &&
          other.stars == this.stars &&
          other.bestScore == this.bestScore &&
          other.bestElapsedMs == this.bestElapsedMs &&
          other.bestAccuracy == this.bestAccuracy &&
          other.bestCombo == this.bestCombo &&
          other.plays == this.plays &&
          other.completedAt == this.completedAt);
}

class LevelResultsCompanion extends UpdateCompanion<LevelResult> {
  final Value<String> puzzleId;
  final Value<String> mode;
  final Value<int> stars;
  final Value<int> bestScore;
  final Value<int> bestElapsedMs;
  final Value<double> bestAccuracy;
  final Value<int> bestCombo;
  final Value<int> plays;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const LevelResultsCompanion({
    this.puzzleId = const Value.absent(),
    this.mode = const Value.absent(),
    this.stars = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.bestElapsedMs = const Value.absent(),
    this.bestAccuracy = const Value.absent(),
    this.bestCombo = const Value.absent(),
    this.plays = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LevelResultsCompanion.insert({
    required String puzzleId,
    required String mode,
    required int stars,
    required int bestScore,
    required int bestElapsedMs,
    required double bestAccuracy,
    required int bestCombo,
    required int plays,
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  }) : puzzleId = Value(puzzleId),
       mode = Value(mode),
       stars = Value(stars),
       bestScore = Value(bestScore),
       bestElapsedMs = Value(bestElapsedMs),
       bestAccuracy = Value(bestAccuracy),
       bestCombo = Value(bestCombo),
       plays = Value(plays),
       completedAt = Value(completedAt);
  static Insertable<LevelResult> custom({
    Expression<String>? puzzleId,
    Expression<String>? mode,
    Expression<int>? stars,
    Expression<int>? bestScore,
    Expression<int>? bestElapsedMs,
    Expression<double>? bestAccuracy,
    Expression<int>? bestCombo,
    Expression<int>? plays,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (puzzleId != null) 'puzzle_id': puzzleId,
      if (mode != null) 'mode': mode,
      if (stars != null) 'stars': stars,
      if (bestScore != null) 'best_score': bestScore,
      if (bestElapsedMs != null) 'best_elapsed_ms': bestElapsedMs,
      if (bestAccuracy != null) 'best_accuracy': bestAccuracy,
      if (bestCombo != null) 'best_combo': bestCombo,
      if (plays != null) 'plays': plays,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LevelResultsCompanion copyWith({
    Value<String>? puzzleId,
    Value<String>? mode,
    Value<int>? stars,
    Value<int>? bestScore,
    Value<int>? bestElapsedMs,
    Value<double>? bestAccuracy,
    Value<int>? bestCombo,
    Value<int>? plays,
    Value<DateTime>? completedAt,
    Value<int>? rowid,
  }) {
    return LevelResultsCompanion(
      puzzleId: puzzleId ?? this.puzzleId,
      mode: mode ?? this.mode,
      stars: stars ?? this.stars,
      bestScore: bestScore ?? this.bestScore,
      bestElapsedMs: bestElapsedMs ?? this.bestElapsedMs,
      bestAccuracy: bestAccuracy ?? this.bestAccuracy,
      bestCombo: bestCombo ?? this.bestCombo,
      plays: plays ?? this.plays,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (puzzleId.present) {
      map['puzzle_id'] = Variable<String>(puzzleId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (stars.present) {
      map['stars'] = Variable<int>(stars.value);
    }
    if (bestScore.present) {
      map['best_score'] = Variable<int>(bestScore.value);
    }
    if (bestElapsedMs.present) {
      map['best_elapsed_ms'] = Variable<int>(bestElapsedMs.value);
    }
    if (bestAccuracy.present) {
      map['best_accuracy'] = Variable<double>(bestAccuracy.value);
    }
    if (bestCombo.present) {
      map['best_combo'] = Variable<int>(bestCombo.value);
    }
    if (plays.present) {
      map['plays'] = Variable<int>(plays.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LevelResultsCompanion(')
          ..write('puzzleId: $puzzleId, ')
          ..write('mode: $mode, ')
          ..write('stars: $stars, ')
          ..write('bestScore: $bestScore, ')
          ..write('bestElapsedMs: $bestElapsedMs, ')
          ..write('bestAccuracy: $bestAccuracy, ')
          ..write('bestCombo: $bestCombo, ')
          ..write('plays: $plays, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletEntriesTable extends WalletEntries
    with TableInfo<$WalletEntriesTable, WalletEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [eventId, amount, reason, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  WalletEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletEntry(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WalletEntriesTable createAlias(String alias) {
    return $WalletEntriesTable(attachedDatabase, alias);
  }
}

class WalletEntry extends DataClass implements Insertable<WalletEntry> {
  final String eventId;
  final int amount;
  final String reason;
  final DateTime createdAt;
  const WalletEntry({
    required this.eventId,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['amount'] = Variable<int>(amount);
    map['reason'] = Variable<String>(reason);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WalletEntriesCompanion toCompanion(bool nullToAbsent) {
    return WalletEntriesCompanion(
      eventId: Value(eventId),
      amount: Value(amount),
      reason: Value(reason),
      createdAt: Value(createdAt),
    );
  }

  factory WalletEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletEntry(
      eventId: serializer.fromJson<String>(json['eventId']),
      amount: serializer.fromJson<int>(json['amount']),
      reason: serializer.fromJson<String>(json['reason']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'amount': serializer.toJson<int>(amount),
      'reason': serializer.toJson<String>(reason),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WalletEntry copyWith({
    String? eventId,
    int? amount,
    String? reason,
    DateTime? createdAt,
  }) => WalletEntry(
    eventId: eventId ?? this.eventId,
    amount: amount ?? this.amount,
    reason: reason ?? this.reason,
    createdAt: createdAt ?? this.createdAt,
  );
  WalletEntry copyWithCompanion(WalletEntriesCompanion data) {
    return WalletEntry(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      amount: data.amount.present ? data.amount.value : this.amount,
      reason: data.reason.present ? data.reason.value : this.reason,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletEntry(')
          ..write('eventId: $eventId, ')
          ..write('amount: $amount, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, amount, reason, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletEntry &&
          other.eventId == this.eventId &&
          other.amount == this.amount &&
          other.reason == this.reason &&
          other.createdAt == this.createdAt);
}

class WalletEntriesCompanion extends UpdateCompanion<WalletEntry> {
  final Value<String> eventId;
  final Value<int> amount;
  final Value<String> reason;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WalletEntriesCompanion({
    this.eventId = const Value.absent(),
    this.amount = const Value.absent(),
    this.reason = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletEntriesCompanion.insert({
    required String eventId,
    required int amount,
    required String reason,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       amount = Value(amount),
       reason = Value(reason),
       createdAt = Value(createdAt);
  static Insertable<WalletEntry> custom({
    Expression<String>? eventId,
    Expression<int>? amount,
    Expression<String>? reason,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (amount != null) 'amount': amount,
      if (reason != null) 'reason': reason,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletEntriesCompanion copyWith({
    Value<String>? eventId,
    Value<int>? amount,
    Value<String>? reason,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WalletEntriesCompanion(
      eventId: eventId ?? this.eventId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletEntriesCompanion(')
          ..write('eventId: $eventId, ')
          ..write('amount: $amount, ')
          ..write('reason: $reason, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEntriesTable extends LocalEntries
    with TableInfo<$LocalEntriesTable, LocalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $LocalEntriesTable createAlias(String alias) {
    return $LocalEntriesTable(attachedDatabase, alias);
  }
}

class LocalEntry extends DataClass implements Insertable<LocalEntry> {
  final String key;
  final String payload;
  const LocalEntry({required this.key, required this.payload});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  LocalEntriesCompanion toCompanion(bool nullToAbsent) {
    return LocalEntriesCompanion(key: Value(key), payload: Value(payload));
  }

  factory LocalEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEntry(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
    };
  }

  LocalEntry copyWith({String? key, String? payload}) =>
      LocalEntry(key: key ?? this.key, payload: payload ?? this.payload);
  LocalEntry copyWithCompanion(LocalEntriesCompanion data) {
    return LocalEntry(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEntry(')
          ..write('key: $key, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEntry &&
          other.key == this.key &&
          other.payload == this.payload);
}

class LocalEntriesCompanion extends UpdateCompanion<LocalEntry> {
  final Value<String> key;
  final Value<String> payload;
  final Value<int> rowid;
  const LocalEntriesCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEntriesCompanion.insert({
    required String key,
    required String payload,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       payload = Value(payload);
  static Insertable<LocalEntry> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return LocalEntriesCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEntriesCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FindItDatabase extends GeneratedDatabase {
  _$FindItDatabase(QueryExecutor e) : super(e);
  $FindItDatabaseManager get managers => $FindItDatabaseManager(this);
  late final $LevelResultsTable levelResults = $LevelResultsTable(this);
  late final $WalletEntriesTable walletEntries = $WalletEntriesTable(this);
  late final $LocalEntriesTable localEntries = $LocalEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    levelResults,
    walletEntries,
    localEntries,
  ];
}

typedef $$LevelResultsTableCreateCompanionBuilder =
    LevelResultsCompanion Function({
      required String puzzleId,
      required String mode,
      required int stars,
      required int bestScore,
      required int bestElapsedMs,
      required double bestAccuracy,
      required int bestCombo,
      required int plays,
      required DateTime completedAt,
      Value<int> rowid,
    });
typedef $$LevelResultsTableUpdateCompanionBuilder =
    LevelResultsCompanion Function({
      Value<String> puzzleId,
      Value<String> mode,
      Value<int> stars,
      Value<int> bestScore,
      Value<int> bestElapsedMs,
      Value<double> bestAccuracy,
      Value<int> bestCombo,
      Value<int> plays,
      Value<DateTime> completedAt,
      Value<int> rowid,
    });

class $$LevelResultsTableFilterComposer
    extends Composer<_$FindItDatabase, $LevelResultsTable> {
  $$LevelResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get puzzleId => $composableBuilder(
    column: $table.puzzleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stars => $composableBuilder(
    column: $table.stars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bestElapsedMs => $composableBuilder(
    column: $table.bestElapsedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bestAccuracy => $composableBuilder(
    column: $table.bestAccuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bestCombo => $composableBuilder(
    column: $table.bestCombo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plays => $composableBuilder(
    column: $table.plays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LevelResultsTableOrderingComposer
    extends Composer<_$FindItDatabase, $LevelResultsTable> {
  $$LevelResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get puzzleId => $composableBuilder(
    column: $table.puzzleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stars => $composableBuilder(
    column: $table.stars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestElapsedMs => $composableBuilder(
    column: $table.bestElapsedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bestAccuracy => $composableBuilder(
    column: $table.bestAccuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestCombo => $composableBuilder(
    column: $table.bestCombo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plays => $composableBuilder(
    column: $table.plays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LevelResultsTableAnnotationComposer
    extends Composer<_$FindItDatabase, $LevelResultsTable> {
  $$LevelResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get puzzleId =>
      $composableBuilder(column: $table.puzzleId, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get stars =>
      $composableBuilder(column: $table.stars, builder: (column) => column);

  GeneratedColumn<int> get bestScore =>
      $composableBuilder(column: $table.bestScore, builder: (column) => column);

  GeneratedColumn<int> get bestElapsedMs => $composableBuilder(
    column: $table.bestElapsedMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get bestAccuracy => $composableBuilder(
    column: $table.bestAccuracy,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bestCombo =>
      $composableBuilder(column: $table.bestCombo, builder: (column) => column);

  GeneratedColumn<int> get plays =>
      $composableBuilder(column: $table.plays, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$LevelResultsTableTableManager
    extends
        RootTableManager<
          _$FindItDatabase,
          $LevelResultsTable,
          LevelResult,
          $$LevelResultsTableFilterComposer,
          $$LevelResultsTableOrderingComposer,
          $$LevelResultsTableAnnotationComposer,
          $$LevelResultsTableCreateCompanionBuilder,
          $$LevelResultsTableUpdateCompanionBuilder,
          (
            LevelResult,
            BaseReferences<_$FindItDatabase, $LevelResultsTable, LevelResult>,
          ),
          LevelResult,
          PrefetchHooks Function()
        > {
  $$LevelResultsTableTableManager(_$FindItDatabase db, $LevelResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LevelResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LevelResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LevelResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> puzzleId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int> stars = const Value.absent(),
                Value<int> bestScore = const Value.absent(),
                Value<int> bestElapsedMs = const Value.absent(),
                Value<double> bestAccuracy = const Value.absent(),
                Value<int> bestCombo = const Value.absent(),
                Value<int> plays = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LevelResultsCompanion(
                puzzleId: puzzleId,
                mode: mode,
                stars: stars,
                bestScore: bestScore,
                bestElapsedMs: bestElapsedMs,
                bestAccuracy: bestAccuracy,
                bestCombo: bestCombo,
                plays: plays,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String puzzleId,
                required String mode,
                required int stars,
                required int bestScore,
                required int bestElapsedMs,
                required double bestAccuracy,
                required int bestCombo,
                required int plays,
                required DateTime completedAt,
                Value<int> rowid = const Value.absent(),
              }) => LevelResultsCompanion.insert(
                puzzleId: puzzleId,
                mode: mode,
                stars: stars,
                bestScore: bestScore,
                bestElapsedMs: bestElapsedMs,
                bestAccuracy: bestAccuracy,
                bestCombo: bestCombo,
                plays: plays,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LevelResultsTable, LevelResult>(table),
                  BaseReferences<
                    _$FindItDatabase,
                    $LevelResultsTable,
                    LevelResult
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LevelResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$FindItDatabase,
      $LevelResultsTable,
      LevelResult,
      $$LevelResultsTableFilterComposer,
      $$LevelResultsTableOrderingComposer,
      $$LevelResultsTableAnnotationComposer,
      $$LevelResultsTableCreateCompanionBuilder,
      $$LevelResultsTableUpdateCompanionBuilder,
      (
        LevelResult,
        BaseReferences<_$FindItDatabase, $LevelResultsTable, LevelResult>,
      ),
      LevelResult,
      PrefetchHooks Function()
    >;
typedef $$WalletEntriesTableCreateCompanionBuilder =
    WalletEntriesCompanion Function({
      required String eventId,
      required int amount,
      required String reason,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WalletEntriesTableUpdateCompanionBuilder =
    WalletEntriesCompanion Function({
      Value<String> eventId,
      Value<int> amount,
      Value<String> reason,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$WalletEntriesTableFilterComposer
    extends Composer<_$FindItDatabase, $WalletEntriesTable> {
  $$WalletEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletEntriesTableOrderingComposer
    extends Composer<_$FindItDatabase, $WalletEntriesTable> {
  $$WalletEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletEntriesTableAnnotationComposer
    extends Composer<_$FindItDatabase, $WalletEntriesTable> {
  $$WalletEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WalletEntriesTableTableManager
    extends
        RootTableManager<
          _$FindItDatabase,
          $WalletEntriesTable,
          WalletEntry,
          $$WalletEntriesTableFilterComposer,
          $$WalletEntriesTableOrderingComposer,
          $$WalletEntriesTableAnnotationComposer,
          $$WalletEntriesTableCreateCompanionBuilder,
          $$WalletEntriesTableUpdateCompanionBuilder,
          (
            WalletEntry,
            BaseReferences<_$FindItDatabase, $WalletEntriesTable, WalletEntry>,
          ),
          WalletEntry,
          PrefetchHooks Function()
        > {
  $$WalletEntriesTableTableManager(
    _$FindItDatabase db,
    $WalletEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletEntriesCompanion(
                eventId: eventId,
                amount: amount,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required int amount,
                required String reason,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WalletEntriesCompanion.insert(
                eventId: eventId,
                amount: amount,
                reason: reason,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WalletEntriesTable, WalletEntry>(table),
                  BaseReferences<
                    _$FindItDatabase,
                    $WalletEntriesTable,
                    WalletEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FindItDatabase,
      $WalletEntriesTable,
      WalletEntry,
      $$WalletEntriesTableFilterComposer,
      $$WalletEntriesTableOrderingComposer,
      $$WalletEntriesTableAnnotationComposer,
      $$WalletEntriesTableCreateCompanionBuilder,
      $$WalletEntriesTableUpdateCompanionBuilder,
      (
        WalletEntry,
        BaseReferences<_$FindItDatabase, $WalletEntriesTable, WalletEntry>,
      ),
      WalletEntry,
      PrefetchHooks Function()
    >;
typedef $$LocalEntriesTableCreateCompanionBuilder =
    LocalEntriesCompanion Function({
      required String key,
      required String payload,
      Value<int> rowid,
    });
typedef $$LocalEntriesTableUpdateCompanionBuilder =
    LocalEntriesCompanion Function({
      Value<String> key,
      Value<String> payload,
      Value<int> rowid,
    });

class $$LocalEntriesTableFilterComposer
    extends Composer<_$FindItDatabase, $LocalEntriesTable> {
  $$LocalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEntriesTableOrderingComposer
    extends Composer<_$FindItDatabase, $LocalEntriesTable> {
  $$LocalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEntriesTableAnnotationComposer
    extends Composer<_$FindItDatabase, $LocalEntriesTable> {
  $$LocalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$LocalEntriesTableTableManager
    extends
        RootTableManager<
          _$FindItDatabase,
          $LocalEntriesTable,
          LocalEntry,
          $$LocalEntriesTableFilterComposer,
          $$LocalEntriesTableOrderingComposer,
          $$LocalEntriesTableAnnotationComposer,
          $$LocalEntriesTableCreateCompanionBuilder,
          $$LocalEntriesTableUpdateCompanionBuilder,
          (
            LocalEntry,
            BaseReferences<_$FindItDatabase, $LocalEntriesTable, LocalEntry>,
          ),
          LocalEntry,
          PrefetchHooks Function()
        > {
  $$LocalEntriesTableTableManager(_$FindItDatabase db, $LocalEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalEntriesCompanion(key: key, payload: payload, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => LocalEntriesCompanion.insert(
                key: key,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalEntriesTable, LocalEntry>(table),
                  BaseReferences<
                    _$FindItDatabase,
                    $LocalEntriesTable,
                    LocalEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FindItDatabase,
      $LocalEntriesTable,
      LocalEntry,
      $$LocalEntriesTableFilterComposer,
      $$LocalEntriesTableOrderingComposer,
      $$LocalEntriesTableAnnotationComposer,
      $$LocalEntriesTableCreateCompanionBuilder,
      $$LocalEntriesTableUpdateCompanionBuilder,
      (
        LocalEntry,
        BaseReferences<_$FindItDatabase, $LocalEntriesTable, LocalEntry>,
      ),
      LocalEntry,
      PrefetchHooks Function()
    >;

class $FindItDatabaseManager {
  final _$FindItDatabase _db;
  $FindItDatabaseManager(this._db);
  $$LevelResultsTableTableManager get levelResults =>
      $$LevelResultsTableTableManager(_db, _db.levelResults);
  $$WalletEntriesTableTableManager get walletEntries =>
      $$WalletEntriesTableTableManager(_db, _db.walletEntries);
  $$LocalEntriesTableTableManager get localEntries =>
      $$LocalEntriesTableTableManager(_db, _db.localEntries);
}
