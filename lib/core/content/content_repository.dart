import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../domain/puzzle.dart';
import '../storage/progress_repository.dart';
import 'pack_format.dart';

export 'pack_format.dart' show ContentPack;

class ContentRepository {
  ContentRepository(this.progress, {http.Client? client})
    : _client = client ?? http.Client();
  final ProgressRepository progress;
  final http.Client _client;
  final List<Puzzle> _puzzles = [];
  final List<ContentPack> packs = [];
  Future<void> _installTail = Future.value();
  bool _closed = false;
  List<Puzzle> get puzzles => List.unmodifiable(_puzzles);
  int get length => _puzzles.length;

  Future<void> initialize() async {
    final bundled = jsonDecode(
      await rootBundle.loadString('assets/content/catalog.json'),
    ) as Map<String, dynamic>;
    _install(bundled, bundled: true);
    for (final raw in await progress.installedPacks()) {
      _install(jsonDecode(raw) as Map<String, dynamic>, bundled: false);
    }
  }

  Puzzle? find(String id) {
    for (final puzzle in _puzzles) {
      if (puzzle.id == id && puzzle.mode == GameMode.hidden) return puzzle;
    }
    for (final daily in progress.current.daily.values) {
      for (final puzzle in daily.puzzles) {
        if (puzzle.id == id && puzzle.mode == GameMode.hidden) return puzzle;
      }
    }
    final saved = progress.current.savedGame;
    if (saved?.puzzleId == id) {
      final puzzle = Puzzle.fromJson(
        saved!.engineJson['puzzle'] as Map<String, dynamic>,
      );
      return puzzle.mode == GameMode.hidden ? puzzle : null;
    }
    return null;
  }

  List<Puzzle> forMode(GameMode mode) =>
      _puzzles.where((p) => p.mode == mode).toList();

  bool isUnlocked(Puzzle puzzle) {
    final levels = forMode(puzzle.mode);
    final index = levels.indexWhere((p) => p.id == puzzle.id);
    return index == 0 ||
        puzzle.level == 1 ||
        progress.current.records.containsKey(puzzle.id) ||
        (index > 0 &&
            progress.current.records.containsKey(levels[index - 1].id));
  }

  Puzzle? next(Puzzle puzzle) {
    final levels = forMode(puzzle.mode);
    final index = levels.indexWhere((p) => p.id == puzzle.id);
    return index >= 0 && index + 1 < levels.length ? levels[index + 1] : null;
  }

  void _install(Map<String, dynamic> json, {required bool bundled}) =>
      _publish(_prepare(json, bundled: bundled));

  ValidatedPack _prepare(Map<String, dynamic> json, {required bool bundled}) {
    final prepared = PackFormat.decode(
      json,
      bundled: bundled,
      existingPuzzles: _puzzles,
      installedPackIds: packs.map((p) => p.id),
    );
    if (prepared.puzzles.any((p) => p.mode != GameMode.hidden)) {
      throw const FormatException(
        'This app accepts hidden-object scenes only.',
      );
    }
    return prepared;
  }

  void _publish(ValidatedPack prepared) {
    packs.add(prepared.pack);
    _puzzles.addAll(prepared.puzzles);
  }

  Future<ContentPack> _commitPack(Map<String, dynamic> json) async {
    final previous = _installTail;
    final next = Completer<void>();
    _installTail = next.future;
    await previous;
    try {
      if (_closed) throw StateError('The puzzle collection is closed.');
      // Downloads may run concurrently, but validate against the latest
      // collection and hold this lock through the durable save and publication.
      // Otherwise two different pack IDs could persist conflicting puzzles.
      final prepared = _prepare(json, bundled: false);
      await progress.savePack(prepared.pack.id, prepared.toJson());
      _publish(prepared);
      return prepared.pack;
    } finally {
      next.complete();
    }
  }

  Future<ContentPack> downloadPack(Uri uri, {String? expectedSha256}) async {
    if (_closed) throw StateError('The puzzle collection is closed.');
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FormatException('Use a public HTTPS puzzle-pack URL.');
    }
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('The pack server returned ${response.statusCode}.');
    }
    const limit = 8 * 1024 * 1024;
    if ((response.contentLength ?? 0) > limit) {
      throw const FormatException('Pack exceeds the 8 MB safety limit.');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 15),
    )) {
      if (bytes.length + chunk.length > limit) {
        throw const FormatException('Pack exceeds the 8 MB safety limit.');
      }
      bytes.addAll(chunk);
    }
    final digest = sha256.convert(bytes).toString();
    if (expectedSha256 != null && digest != expectedSha256.toLowerCase()) {
      throw const FormatException(
        'Pack checksum mismatch. Nothing was installed.',
      );
    }
    final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return _commitPack(json);
  }

  void close() {
    _closed = true;
    _client.close();
  }
}
