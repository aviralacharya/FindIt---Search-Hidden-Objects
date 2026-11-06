// Run explicitly, after selecting the original PNG:
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

Uint8List _backgroundFlood(
  Uint8List pixels,
  int width,
  int height, {
  required bool whiteOnly,
}) {
  final visited = Uint8List(width * height);
  final queue = ListQueue<int>();
  bool isBackground(int at) {
    final r = pixels[at * 4];
    final g = pixels[at * 4 + 1];
    final b = pixels[at * 4 + 2];
    final a = pixels[at * 4 + 3];
    if (a < 20) return true;
    if (whiteOnly) {
      return math.min(r, math.min(g, b)) >= 245 &&
          math.max(r, math.max(g, b)) - math.min(r, math.min(g, b)) < 8;
    }
    // Only flood from the outer image edge. White highlights inside the closed
    // green magnifying-glass rim are preserved, as are gold/green art pixels.
    return r >= g - 2 && g >= b - 2 && r - b < 100 && r - g < 55;
  }

  void add(int at) {
    if (visited[at] == 0 && isBackground(at)) {
      visited[at] = 1;
      queue.addLast(at);
    }
  }

  for (var x = 0; x < width; x++) {
    add(x);
    add((height - 1) * width + x);
  }
  for (var y = 0; y < height; y++) {
    add(y * width);
    add(y * width + width - 1);
  }
  while (queue.isNotEmpty) {
    final at = queue.removeFirst();
    final x = at % width;
    final y = at ~/ width;
    if (x > 0) add(at - 1);
    if (x + 1 < width) add(at + 1);
    if (y > 0) add(at - width);
    if (y + 1 < height) add(at + width);
  }
  return visited;
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

void _drawImage(Canvas canvas, Size size, ui.Image image, double fraction) {
  final side = math.min(size.width, size.height) * fraction;
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    ),
    Paint()..filterQuality = FilterQuality.high,
  );
}

void _drawMonochrome(Canvas canvas, Size size, double fraction) {
  // An intentionally simplified search/star/leaf silhouette for Android themed
  // icons. Full-color launcher, splash, web and Play assets use the supplied PNG.
  final side = math.min(size.width, size.height) * fraction;
  canvas.save();
  canvas.translate((size.width - side) / 2, (size.height - side) / 2);
  canvas.scale(side);
  final stroke = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = .08
    ..strokeCap = StrokeCap.round;
  canvas.drawCircle(const Offset(.435, .435), .315, stroke);
  canvas.drawLine(
    const Offset(.665, .67),
    const Offset(.83, .835),
    stroke..strokeWidth = .15,
  );
  final star = Path();
  for (var i = 0; i < 10; i++) {
    final angle = -math.pi / 2 + i * math.pi / 5;
    final radius = i.isEven ? .175 : .082;
    final x = .45 + math.cos(angle) * radius;
    final y = .43 + math.sin(angle) * radius;
    if (i == 0) {
      star.moveTo(x, y);
    } else {
      star.lineTo(x, y);
    }
  }
  star.close();
  final fill = Paint()..color = Colors.white;
  canvas.drawPath(star, fill);
  canvas.drawPath(
    Path()
      ..moveTo(.23, .52)
      ..cubicTo(.4, .51, .45, .63, .41, .7)
      ..cubicTo(.3, .7, .25, .63, .23, .52)
      ..close(),
    fill,
  );
  canvas.restore();
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

  test('background removal never floods enclosed white highlights', () {
    const width = 7;
    final pixels = Uint8List(width * width * 4);
    for (var y = 0; y < width; y++) {
      for (var x = 0; x < width; x++) {
        final at = (y * width + x) * 4;
        final rim =
            x >= 1 &&
            x <= 5 &&
            y >= 1 &&
            y <= 5 &&
            (x == 1 || x == 5 || y == 1 || y == 5);
        pixels.setRange(
          at,
          at + 4,
          rim ? [10, 100, 60, 255] : [255, 255, 255, 255],
        );
      }
    }
    for (final whiteOnly in [true, false]) {
      final mask = _backgroundFlood(pixels, width, width, whiteOnly: whiteOnly);
      expect(mask[0], 1);
      expect(mask[3 * width + 3], 0);
      expect(mask[width + 1], 0);
    }
  });

  test('prepare publisher icon, Android safe zones, web and Play graphics', () async {
    final file = File(_sourcePath);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Select the original PNG in tool/prepare_release_inputs.py --dialog first.',
    );
    final original = file.readAsBytesSync();
    final codec = await ui.instantiateImageCodec(original);
    final source = (await codec.getNextFrame()).image;
    codec.dispose();
    expect(source.width, source.height);
    expect(source.width, inInclusiveRange(512, 4096));
    final raw = (await source.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final pixels = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    final outsideWhite = _backgroundFlood(
      pixels,
      source.width,
      source.height,
      whiteOnly: true,
    );
    final outsideCream = _backgroundFlood(
      pixels,
      source.width,
      source.height,
      whiteOnly: false,
    );
    final fullBleedPixels = Uint8List.fromList(pixels);
    final cutoutPixels = Uint8List.fromList(pixels);
    var retained = 0;
    var radius = 0.0;
    for (var at = 0; at < outsideWhite.length; at++) {
      if (outsideWhite[at] == 1) {
        fullBleedPixels.setRange(at * 4, at * 4 + 4, [251, 247, 238, 255]);
      }
      if (outsideCream[at] == 1) {
        cutoutPixels.setRange(at * 4, at * 4 + 4, [0, 0, 0, 0]);
      } else if (pixels[at * 4 + 3] >= 200) {
        retained++;
        final x = (at % source.width + .5) / source.width - .5;
        final y = (at ~/ source.width + .5) / source.height - .5;
        radius = math.max(radius, math.sqrt(x * x + y * y));
      }
    }
    final retainedFraction = retained / (source.width * source.height);
    expect(
      retainedFraction,
      inInclusiveRange(.12, .85),
      reason: 'Review the supplied PNG if its background cannot be separated safely.',
    );
    final adaptiveFraction = math.min(.68, .29 / radius);
    expect(radius * adaptiveFraction, lessThan(33 / 108));
    final fullBleed = await _imageFromPixels(
      fullBleedPixels,
      source.width,
      source.height,
    );
    final cutout = await _imageFromPixels(
      cutoutPixels,
      source.width,
      source.height,
    );
    final outputs = <Map<String, Object>>[];

    Future<void> full(String path, int side) async {
      final image = await _render(side, side, (canvas, size) {
        canvas.drawColor(_cream, BlendMode.src);
        _drawImage(canvas, size, fullBleed, 1);
      });
      if (side == 512) {
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
        if (mono) {
          _drawMonochrome(canvas, size, adaptiveFraction);
        } else {
          _drawImage(canvas, size, cutout, adaptiveFraction);
        }
      });
      outputs.add(await _save(path, image));
      image.dispose();
    }

    await full('assets/branding/app_icon.png', 1024);
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
        _drawImage(canvas, size, cutout, adaptiveFraction * 108 / 72);
      });
      outputs.add(
        await _save('verification/branding/launcher-$shape.png', image),
      );
      image.dispose();
    }
    final report = {
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'generator': 'tool/prepare_branding_test.dart',
      'source': _sourcePath,
      'sourceSha256': sha256.convert(original).toString(),
      'sourceWidth': source.width,
      'sourceHeight': source.height,
      'adaptiveForegroundFraction': adaptiveFraction,
      'adaptiveMaxRadiusDp': radius * adaptiveFraction * 108,
      'adaptiveSafeRadiusDp': 33,
      'retainedForegroundFraction': retainedFraction,
      'playIcon': '512x512, opaque 32-bit PNG, at most 1 MiB; no added corner mask or shadow',
      'method': 'Preserve original PNG bytes. Extend white outer corners with cream for full-bleed icons. Flood only edge-connected cream/white background for padded adaptive and splash art. Preserve enclosed lens highlights. Use a simplified magnifier/star/leaf silhouette for themed icons.',
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
    cutout.dispose();
    fullBleed.dispose();
    source.dispose();
    stdout.writeln(
      'Prepared ${outputs.length} icon/splash/web assets and launcher-mask previews.',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
