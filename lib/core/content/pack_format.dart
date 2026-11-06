import '../domain/puzzle.dart';
import 'puzzle_validator.dart';

/// Pure pack decoding shared by the offline publisher tool and the installer.
/// Downloaded artwork is declarative only; unknown fields and image paths are
/// never included in the canonical payload returned by [ValidatedPack.toJson].
abstract final class PackFormat {
  static ValidatedPack decode(
    Map<String, dynamic> json, {
    bool bundled = false,
    List<Puzzle> existingPuzzles = const [],
    Iterable<String> installedPackIds = const [],
  }) {
    if (json['schemaVersion'] != 1 ||
        json['contentVersion'] is! int ||
        (json['contentVersion'] as int) < 1 ||
        json['packId'] is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9_-]{2,79}$')
            .hasMatch(json['packId'] as String)) {
      throw const FormatException('Unsupported puzzle pack format.');
    }
    final raw = json['puzzles'];
    if (raw is! List ||
        raw.isEmpty ||
        raw.length > 1000 ||
        existingPuzzles.length + raw.length > 10000) {
      throw const FormatException('A pack must contain 1–1,000 puzzles.');
    }
    if (installedPackIds.contains(json['packId'])) {
      throw const FormatException('This pack is already installed.');
    }
    final items = raw.map((v) {
      final data = Map<String, dynamic>.of(v as Map<String, dynamic>);
      if (!bundled) {
        data.remove('imageA');
        data.remove('imageB');
      }
      return Puzzle.fromJson(data);
    }).toList();
    PuzzleValidator.validateCatalog(items);
    final existingIds = existingPuzzles.map((p) => p.id).toSet();
    if (items.any((p) => existingIds.contains(p.id))) {
      throw const FormatException('Pack contains an existing puzzle ID.');
    }
    if (!bundled && items.any((p) => p.id.startsWith('daily-'))) {
      throw const FormatException(
        'Daily puzzle IDs are reserved for local challenges.',
      );
    }
    final fingerprints = existingPuzzles
        .map(PuzzleValidator.fingerprint)
        .toSet();
    if (items.any(
      (p) => fingerprints.contains(PuzzleValidator.fingerprint(p)),
    )) {
      throw const FormatException(
        'Pack repeats a puzzle already in your collection.',
      );
    }
    if (!bundled &&
        (json['license'] is! String ||
            (json['license'] as String).trim().isEmpty ||
            (json['license'] as String).length > 2000)) {
      throw const FormatException(
        'A pack must include a bounded artwork-license declaration.',
      );
    }
    if (json['title'] != null &&
        (json['title'] is! String || (json['title'] as String).length > 120)) {
      throw const FormatException('Invalid pack title.');
    }
    return ValidatedPack(
      ContentPack(
        id: json['packId'] as String,
        title:
            json['title'] as String? ??
            (bundled ? 'The original collection' : json['packId'] as String),
        count: items.length,
        bundled: bundled,
        license:
            json['license'] as String? ??
            'Publisher must provide artwork rights before distribution.',
      ),
      List.unmodifiable(items),
      json['contentVersion'] as int,
    );
  }
}

class ValidatedPack {
  const ValidatedPack(this.pack, this.puzzles, this.contentVersion);
  final ContentPack pack;
  final List<Puzzle> puzzles;
  final int contentVersion;

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'contentVersion': contentVersion,
    'packId': pack.id,
    'title': pack.title,
    'license': pack.license,
    'puzzles': puzzles.map((p) => p.toJson()).toList(),
  };
}

class ContentPack {
  const ContentPack({
    required this.id,
    required this.title,
    required this.count,
    required this.bundled,
    required this.license,
  });
  final String id;
  final String title;
  final int count;
  final bool bundled;
  final String license;
}
