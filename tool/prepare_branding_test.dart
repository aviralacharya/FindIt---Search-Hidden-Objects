// Run explicitly, after placing the publisher's original PNG at _sourcePath:
// flutter test --no-pub tool/prepare_branding_test.dart
// No packages or online image services are needed; Flutter does the raster work.
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _cream = Color(0xFFFBF7EE);
const _sourcePath = 'assets/branding/icon_source.png';

Rect _foregroundBounds(Uint8List pixels, int width, int height) {
  var left = width;
  var top = height;
  var right = 0;
  var bottom = 0;
  for (var at = 0; at < width * height; at++) {
    if (pixels[at * 4 + 3] == 0) continue;
    final x = at % width;
    final y = at ~/ width;
    left = math.min(left, x);
    top = math.min(top, y);
    right = math.max(right, x + 1);
    bottom = math.max(bottom, y + 1);
  }
  if (right <= left || bottom <= top) return Rect.zero;
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}

double _foregroundRadius(Uint8List pixels, int width, Rect bounds) {
  final side = math.max(bounds.width, bounds.height);
  var radius = 0.0;
  for (var at = 0; at < pixels.length ~/ 4; at++) {
    if (pixels[at * 4 + 3] == 0) continue;
    final x = (at % width + .5 - bounds.center.dx) / side;
    final y = (at ~/ width + .5 - bounds.center.dy) / side;
    radius = math.max(radius, math.sqrt(x * x + y * y));
  }
  return radius;
}

Uint8List _monochromePixels(Uint8List pixels) {
  // Derive the themed icon from the supplied art, not a separately drawn logo.
  // Remove the light lens fill so the rim, handle, leaf and hills remain legible.
  final monochrome = Uint8List(pixels.length);
  for (var at = 0; at < pixels.length; at += 4) {
    final luminance =
        pixels[at] * .299 + pixels[at + 1] * .587 + pixels[at + 2] * .114;
    final coverage = ((225 - luminance) / 20).clamp(0.0, 1.0);
    final alpha = (pixels[at + 3] * coverage).round();
    // ImageDescriptor.raw expects premultiplied RGBA: white channels equal alpha.
    monochrome.fillRange(at, at + 4, alpha);
  }
  return monochrome;
}

Uint8List _retainLargestComponent(Uint8List pixels, int width, int height) {
  // Thresholding can expose tiny disconnected background speckles in the PNG.
  // Keep the connected logo, including its anti-aliased edges, for themed icons.
  final visited = Uint8List(width * height);
  final queue = ListQueue<int>();
  var largest = <int>[];
  void add(int at) {
    if (visited[at] == 0 && pixels[at * 4 + 3] != 0) {
      visited[at] = 1;
      queue.addLast(at);
    }
  }

  for (var start = 0; start < visited.length; start++) {
    if (visited[start] != 0 || pixels[start * 4 + 3] == 0) continue;
    final component = <int>[];
    add(start);
    while (queue.isNotEmpty) {
      final at = queue.removeFirst();
      component.add(at);
      final x = at % width;
      final y = at ~/ width;
      if (x > 0) add(at - 1);
      if (x + 1 < width) add(at + 1);
      if (y > 0) add(at - width);
      if (y + 1 < height) add(at + width);
    }
    if (component.length > largest.length) largest = component;
  }
  final cleaned = Uint8List(pixels.length);
  for (final at in largest) {
    cleaned.setRange(at * 4, at * 4 + 4, pixels, at * 4);
  }
  return cleaned;
}

Future<ui.Image> _imageFromPixels(
  Uint8List pixels,
  int width,
  int height,
) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
  return image;
}

Future<ui.Image> _render(
  int width,
  int height,
  void Function(Canvas, Size) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  return image;
}

Rect _destinationRect(Size source, Size target, double fraction) {
  final side = math.min(target.width, target.height) * fraction;
  final scale = side / math.max(source.width, source.height);
  return Rect.fromCenter(
    center: target.center(Offset.zero),
    width: source.width * scale,
    height: source.height * scale,
  );
}

void _drawImage(
  Canvas canvas,
  Size size,
  ui.Image image,
  double fraction, {
  required Rect bounds,
}) {
  canvas.drawImageRect(
    image,
    bounds,
    _destinationRect(bounds.size, size, fraction),
    Paint()..filterQuality = FilterQuality.high,
  );
}

Future<Map<String, Object>> _save(String path, ui.Image image) async {
  final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  final data = png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
  final file = File(path);
  String? previous;
  if (file.existsSync()) {
    previous = sha256.convert(file.readAsBytesSync()).toString();
  }
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(data);
  return {
    'file': path,
    'width': image.width,
    'height': image.height,
    'bytes': data.length,
    'sha256': sha256.convert(data).toString(),
    'previousSha256': ?previous,
  };
}

(int, int) _existingDimensions(String path) {
  final data = File(path).readAsBytesSync();
  expect(data.take(8), [137, 80, 78, 71, 13, 10, 26, 10], reason: path);
  final view = ByteData.sublistView(data);
  return (view.getUint32(16), view.getUint32(20));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only fully transparent margins are excluded from the artwork', () {
    const width = 7;
    const height = 6;
    final pixels = Uint8List(width * height * 4);
    pixels[(width + 2) * 4 + 3] = 1;
    pixels[(3 * width + 4) * 4 + 3] = 255;
    expect(
      _foregroundBounds(pixels, width, height),
      const Rect.fromLTRB(2, 1, 5, 4),
    );
    expect(_foregroundBounds(Uint8List(16), 2, 2), Rect.zero);
  });

  test('non-square artwork is centered without changing its proportions', () {
    final rect = _destinationRect(
      const Size(200, 100),
      const Size(100, 100),
      .5,
    );
    expect(rect, const Rect.fromLTWH(25, 37.5, 50, 25));
    expect(rect.size.aspectRatio, 2);
  });

  test('themed pixels retain the supplied rim and leaf, not the lens fill', () {
    final pixels = Uint8List.fromList([
      0,
      0,
      0,
      0,
      3,
      81,
      69,
      254,
      255,
      188,
      0,
      254,
      250,
      234,
      212,
      254,
    ]);
    final original = Uint8List.fromList(pixels);
    expect(_monochromePixels(pixels), [
      0,
      0,
      0,
      0,
      254,
      254,
      254,
      254,
      254,
      254,
      254,
      254,
      0,
      0,
      0,
      0,
    ]);
    expect(pixels, original);
  });

  test(
    'themed masks remove disconnected speckles without changing the logo',
    () {
      final pixels = Uint8List(4 * 4 * 4);
      for (final at in [5, 6]) {
        pixels.fillRange(at * 4, at * 4 + 4, 254);
      }
      pixels.fillRange(15 * 4, 16 * 4, 64);
      final original = Uint8List.fromList(pixels);
      final cleaned = _retainLargestComponent(pixels, 4, 4);
      expect(cleaned.sublist(5 * 4, 7 * 4), List.filled(8, 254));
      expect(cleaned.sublist(15 * 4, 16 * 4), List.filled(4, 0));
      expect(pixels, original);
    },
  );

  test('prepare publisher icon, Android safe zones, web and Play graphics', () async {
    final file = File(_sourcePath);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Place the publisher original at assets/branding/icon_source.png first.',
    );
    final original = file.readAsBytesSync();
    final codec = await ui.instantiateImageCodec(original);
    final source = (await codec.getNextFrame()).image;
    codec.dispose();
    expect(source.width, inInclusiveRange(512, 4096));
    expect(source.height, inInclusiveRange(512, 4096));
    final raw = (await source.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    final pixels = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    final bounds = _foregroundBounds(pixels, source.width, source.height);
    expect(
      bounds.isEmpty,
      isFalse,
      reason: 'The supplied PNG must contain art.',
    );
    final radius = _foregroundRadius(pixels, source.width, bounds);
    final adaptiveFraction = math.min(.68, .29 / radius);
    expect(radius * adaptiveFraction, lessThan(33 / 108));
    final monochrome = await _imageFromPixels(
      _retainLargestComponent(
        _monochromePixels(pixels),
        source.width,
        source.height,
      ),
      source.width,
      source.height,
    );
    final outputs = <Map<String, Object>>[];

    Future<void> full(String path, int side, {bool opaque = true}) async {
      final image = await _render(side, side, (canvas, size) {
        if (opaque) canvas.drawColor(_cream, BlendMode.src);
        _drawImage(canvas, size, source, .88, bounds: bounds);
      });
      if (side == 512 && opaque) {
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (var i = 3; i < rgba.lengthInBytes; i += 4) {
          expect(
            rgba.getUint8(i),
            255,
            reason: 'The Play icon must be fully opaque.',
          );
        }
      }
      outputs.add(await _save(path, image));
      image.dispose();
    }

    Future<void> padded(
      String path,
      int width,
      int height, {
      bool opaque = false,
      bool mono = false,
    }) async {
      final image = await _render(width, height, (canvas, size) {
        if (opaque) canvas.drawColor(_cream, BlendMode.src);
        _drawImage(
          canvas,
          size,
          mono ? monochrome : source,
          adaptiveFraction,
          bounds: bounds,
        );
      });
      outputs.add(await _save(path, image));
      image.dispose();
    }

    await full('assets/branding/app_icon.png', 1024, opaque: false);
    await full('assets/branding/play_store_icon.png', 512);
    await full('release/play-store/graphics/icon-512.png', 512);
    expect(outputs.last['bytes'] as int, lessThanOrEqualTo(1024 * 1024));
    await padded('assets/branding/icon_foreground.png', 1024, 1024);
    await padded('assets/branding/icon_monochrome.png', 1024, 1024, mono: true);
    await padded('assets/branding/splash_mark.png', 512, 512);

    const densities = {
      'mdpi': 1.0,
      'hdpi': 1.5,
      'xhdpi': 2.0,
      'xxhdpi': 3.0,
      'xxxhdpi': 4.0,
    };
    for (final entry in densities.entries) {
      final drawable = 'android/app/src/main/res/drawable-${entry.key}';
      await full(
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        (48 * entry.value).round(),
      );
      final adaptiveSide = (108 * entry.value).round();
      await padded(
        '$drawable/ic_launcher_foreground.png',
        adaptiveSide,
        adaptiveSide,
      );
      await padded(
        '$drawable/ic_launcher_monochrome.png',
        adaptiveSide,
        adaptiveSide,
        mono: true,
      );
      for (final path in [
        '$drawable/splash.png',
        '$drawable/android12splash.png',
        'android/app/src/main/res/drawable-night-${entry.key}/android12splash.png',
      ]) {
        final (width, height) = _existingDimensions(path);
        await padded(path, width, height);
      }
    }
    for (final side in [192, 512]) {
      await full('web/icons/Icon-$side.png', side);
      await padded(
        'web/icons/Icon-maskable-$side.png',
        side,
        side,
        opaque: true,
      );
    }
    await full('web/favicon.png', 32);
    for (final theme in ['light', 'dark']) {
      for (var scale = 1; scale <= 4; scale++) {
        final path = 'web/splash/img/$theme-${scale}x.png';
        final (width, height) = _existingDimensions(path);
        await padded(path, width, height);
      }
    }
    for (final shape in ['circle', 'squircle', 'square']) {
      final image = await _render(384, 384, (canvas, size) {
        // Android masks the middle 72 dp of a 108 dp layer. Model that actual
        // viewport, rather than incorrectly masking the complete 108 dp layer.
        if (shape == 'circle') {
          canvas.clipPath(Path()..addOval(Offset.zero & size));
        } else if (shape == 'squircle') {
          canvas.clipRRect(
            RRect.fromRectAndRadius(
              Offset.zero & size,
              const Radius.circular(92),
            ),
          );
        }
        canvas.drawColor(_cream, BlendMode.src);
        _drawImage(
          canvas,
          size,
          source,
          adaptiveFraction * 108 / 72,
          bounds: bounds,
        );
      });
      outputs.add(
        await _save('verification/branding/launcher-$shape.png', image),
      );
      image.dispose();
    }
    await padded(
      'verification/branding/launcher-monochrome.png',
      384,
      384,
      mono: true,
    );
    File('verification/branding/icon-source.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'file': _sourcePath, 'sha256': sha256.convert(original).toString(), 'bytes': original.length, 'width': source.width, 'height': source.height, 'provenance': 'Original PNG supplied and selected by the publisher; distribution rights require publisher review.'})}\n',
    );
    final report = {
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'generator': 'tool/prepare_branding_test.dart',
      'source': _sourcePath,
      'sourceSha256': sha256.convert(original).toString(),
      'sourceWidth': source.width,
      'sourceHeight': source.height,
      'foregroundBounds': {
        'left': bounds.left,
        'top': bounds.top,
        'width': bounds.width,
        'height': bounds.height,
      },
      'appIcon': '1024x1024 transparent PNG; original proportions preserved',
      'adaptiveForegroundFraction': adaptiveFraction,
      'adaptiveMaxRadiusDp': radius * adaptiveFraction * 108,
      'adaptiveSafeRadiusDp': 33,
      'playIcon': '512x512, opaque 32-bit PNG, at most 1 MiB; no added corner mask or shadow',
      'method': 'Preserve original PNG bytes and all artwork colors. Exclude only fully transparent outer margins, center with uniform scaling, and retain transparency in app/adaptive/splash art. Composite legacy, web and Play icons onto cream. Derive themed pixels from the original rim, handle, leaf and hills by removing the light lens fill and disconnected speckles; no alternate logo drawing.',
      'scope': 'Generated asset and mask checks, not Android launcher/runtime QA or a legal rights determination.',
      'outputs': outputs,
    };
    File('verification/branding/manifest.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    expect(
      file.readAsBytesSync(),
      original,
      reason: 'Never modify the publisher original.',
    );
    monochrome.dispose();
    source.dispose();
    stdout.writeln(
      'Prepared ${outputs.length} icon/splash/web assets and launcher-mask previews.',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
