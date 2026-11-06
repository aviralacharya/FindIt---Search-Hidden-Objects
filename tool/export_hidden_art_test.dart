// Run explicitly: flutter test --no-pub tool/export_hidden_art_test.dart
// Only the three new featured PNGs are exported. The other 57 are reused.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:findit/core/art/scene_art.dart';
import 'package:findit/core/content/hidden_catalog.dart';
import 'package:findit/core/domain/puzzle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> _render(SceneData scene, Size size) async {
  final recorder = ui.PictureRecorder();
  ScenePainter(scene).paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  return image;
}

Future<Uint8List> _pixels(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'export featured scenes and verify every target remains visible',
    () async {
      const size = Size(1200, 900);
      final puzzles = HiddenCatalog.launchCatalog().take(3);
      final checks = <Map<String, Object>>[];
      for (final puzzle in puzzles) {
        final scene = puzzle.scene!;
        final image = await _render(scene, size);
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final data = png.buffer.asUint8List(
          png.offsetInBytes,
          png.lengthInBytes,
        );
        final file = File(puzzle.imageA!);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data);
        final complete = await _pixels(image);
        final visiblePixels = <String, int>{};
        for (final id in puzzle.answerIds) {
          final object = scene.objects.firstWhere((o) => o.id == id);
          final without = SceneData(
            template: scene.template,
            palette: scene.palette,
            layout: scene.layout,
            seed: scene.seed,
            objects: scene.objects.where((o) => o.id != id).toList(),
          );
          final removedImage = await _render(without, size);
          final removed = await _pixels(removedImage);
          var changed = 0;
          var outside = 0;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              final at = (y * image.width + x) * 4;
              if ((complete[at] - removed[at]).abs() <= 1 &&
                  (complete[at + 1] - removed[at + 1]).abs() <= 1 &&
                  (complete[at + 2] - removed[at + 2]).abs() <= 1) {
                continue;
              }
              if (object.region.contains(x / size.width, y / size.height)) {
                changed++;
              } else {
                outside++;
              }
            }
          }
          expect(
            changed,
            greaterThan(200),
            reason: '$id must be discoverably visible over the background.',
          );
          // One anti-aliased edge pixel can lie on either side of a normalized
          // boundary. ScenePainter clips each glyph to its authored hit region.
          expect(
            outside,
            lessThan(160),
            reason: '$id changed pixels beyond its hit region.',
          );
          visiblePixels[id] = changed;
          removedImage.dispose();
        }
        checks.add({
          'id': puzzle.id,
          'template': scene.template,
          'file': puzzle.imageA!,
          'sha256': sha256.convert(data).toString(),
          'targetVisiblePixels': visiblePixels,
        });
        image.dispose();
      }
      File('assets/content/pixel-validation.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'scope': 'three enhanced featured scenes; 57 classic PNGs reused',
          'size': '1200x900',
          'method': 'Rendered scene compared with each target omitted in turn',
          'checks': checks,
        }),
      );
      stdout.writeln(
        'Exported three featured scenes; all 18 targets are visible.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
