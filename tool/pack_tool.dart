import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:findit/core/content/pack_format.dart';
import 'package:findit/core/content/puzzle_generator.dart';
import 'package:findit/core/domain/puzzle.dart';

import 'pack_schema.dart';

const _encoder = JsonEncoder.withIndent('  ');

ValidatedPack _hiddenOnly(ValidatedPack pack) {
  if (pack.puzzles.any((p) => p.mode != GameMode.hidden)) {
    throw const FormatException('This app accepts hidden-object scenes only.');
  }
  return pack;
}

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (file.lengthSync() > 8 * 1024 * 1024) {
    throw const FormatException('Pack exceeds the 8 MB safety limit.');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void _writeJson(String path, Map<String, dynamic> json) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${_encoder.convert(json)}\n');
}

void main(List<String> arguments) {
  try {
    if (arguments.isEmpty ||
        !['example', 'validate', 'schema'].contains(arguments.first)) {
      stdout.writeln(
        '''FindIt Hidden Objects pack publisher tool (run from the project root)
  dart run tool/pack_tool.dart example [output.json]
  dart run tool/pack_tool.dart schema [output.schema.json]
  dart run tool/pack_tool.dart validate input.json [--against other.json] [--canonical output.json]

Validation always checks against the bundled catalog. Add --against for other
installed/published packs. SHA-256 is for the exact input bytes, not authenticity.
No downloads are performed. Artwork still needs independent human review.''',
      );
      exitCode = arguments.isEmpty ? 0 : 64;
      return;
    }
    final command = arguments.first;
    if (command == 'schema') {
      final output = arguments.length > 1
          ? arguments[1]
          : 'config/packs/pack-v1.schema.json';
      _writeJson(output, packSchema());
      stdout.writeln('Wrote $output');
      return;
    }
    final base = _hiddenOnly(
      PackFormat.decode(
        _readJson('assets/content/catalog.json'),
        bundled: true,
      ),
    );
    if (command == 'example') {
      final output = arguments.length > 1
          ? arguments[1]
          : 'config/packs/example-v1.json';
      final example = _hiddenOnly(
        PackFormat.decode({
          'schemaVersion': 1,
          'contentVersion': 1,
          'packId': 'findit-hidden-sample-expansion-v1',
          'title': 'Three more hidden-object discoveries',
          'license': 'Original FindIt vector compositions generated from this project’s editable source. Publisher rights review required before distribution.',
          'puzzles': [
            for (var scene = 0; scene < 3; scene++)
              PuzzleGenerator.generate(
                GameMode.hidden,
                seed: stableSeed('findit-hidden-example-v1-$scene'),
                level: 61 + scene,
                difficulty: 2,
                id: 'sample-hidden-0${61 + scene}',
              ).toJson(),
          ],
        }, existingPuzzles: base.puzzles),
      );
      _writeJson(output, example.toJson());
      _writeJson('config/packs/pack-v1.schema.json', packSchema());
      final checksum = sha256.convert(File(output).readAsBytesSync());
      File(
        '$output.sha256',
      ).writeAsStringSync('$checksum  ${File(output).uri.pathSegments.last}\n');
      stdout.writeln(
        'Wrote $output (${example.puzzles.length} unique puzzles). SHA-256: $checksum',
      );
      return;
    }
    if (arguments.length < 2) {
      throw const FormatException('Specify an input pack JSON file.');
    }
    final existing = [...base.puzzles];
    final installedIds = <String>{base.pack.id};
    String? canonicalPath;
    for (var i = 2; i < arguments.length; i += 2) {
      if (i + 1 >= arguments.length) {
        throw const FormatException('An option is missing its path.');
      }
      switch (arguments[i]) {
        case '--against':
          final other = _hiddenOnly(
            PackFormat.decode(
              _readJson(arguments[i + 1]),
              existingPuzzles: existing,
              installedPackIds: installedIds,
            ),
          );
          existing.addAll(other.puzzles);
          installedIds.add(other.pack.id);
        case '--canonical':
          canonicalPath = arguments[i + 1];
        default:
          throw FormatException('Unknown option: ${arguments[i]}');
      }
    }
    final input = arguments[1];
    final result = _hiddenOnly(
      PackFormat.decode(
        _readJson(input),
        existingPuzzles: existing,
        installedPackIds: installedIds,
      ),
    );
    if (canonicalPath != null) _writeJson(canonicalPath, result.toJson());
    stdout.writeln(
      'Valid: ${result.pack.id}; ${result.puzzles.length} unique puzzles; content v${result.contentVersion}.',
    );
    stdout.writeln(
      'SHA-256 (exact input bytes): ${sha256.convert(File(input).readAsBytesSync())}',
    );
    if (canonicalPath != null) {
      stdout.writeln('Canonical vector-only JSON: $canonicalPath');
    }
  } catch (error) {
    stderr.writeln('Pack validation failed: $error');
    exitCode = 1;
  }
}
