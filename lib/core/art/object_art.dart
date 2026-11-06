import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/puzzle.dart';

const objectColors = [
  Color(0xFFD88970),
  Color(0xFF6595A5),
  Color(0xFF83A67A),
  Color(0xFFD8B259),
  Color(0xFFA08CAF),
  Color(0xFF7C9DB9),
];
const artInk = Color(0xFF3D5650);
const artPaper = Color(0xFFFFFBF2);

class ObjectGlyph extends StatelessWidget {
  const ObjectGlyph(
    this.kind, {
    super.key,
    this.colorIndex = 0,
    this.variant = 0,
    this.size = 52,
    this.semanticLabel = true,
  });
  final String kind;
  final int colorIndex;
  final int variant;
  final double size;
  final bool semanticLabel;
  @override
  Widget build(BuildContext context) {
    final image = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: ObjectPainter(kind, colorIndex, variant)),
    );
    return semanticLabel
        ? Semantics(
            label: objectDescription(kind, color: colorIndex, variant: variant),
            image: true,
            child: image,
          )
        : image;
  }
}

class ObjectPainter extends CustomPainter {
  const ObjectPainter(this.kind, this.colorIndex, this.variant);
  final String kind;
  final int colorIndex;
  final int variant;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    drawObject(canvas, kind, colorIndex: colorIndex, variant: variant);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ObjectPainter old) =>
      kind != old.kind ||
      colorIndex != old.colorIndex ||
      variant != old.variant;
}

/// Original, editable vector silhouettes. No platform emoji or remote assets.
void drawObject(
  Canvas canvas,
  String kind, {
  int colorIndex = 0,
  int variant = 0,
}) {
  final g = ArtBrush(canvas);
  final color = objectColors[colorIndex % objectColors.length];
  const green = Color(0xFF759C70);
  const gold = Color(0xFFE9BE62);
  const pink = Color(0xFFDD8B80);
  final light = Color.lerp(color, artPaper, .57)!;
  switch (kind) {
    case 'plant':
      g.line(50, 68, 50, 24, green, 4);
      g.path(
        Path()
          ..moveTo(50, 47)
          ..cubicTo(20, 45, 21, 19, 47, 36)
          ..close(),
        green,
      );
      g.path(
        Path()
          ..moveTo(51, 40)
          ..cubicTo(78, 36, 79, 14, 52, 27)
          ..close(),
        green,
      );
      g.path(
        Path()
          ..moveTo(50, 58)
          ..cubicTo(79, 58, 80, 36, 53, 46)
          ..close(),
        green,
      );
      g.poly([27, 62, 73, 62, 66, 88, 34, 88], color);
      g.rr(24, 59, 52, 9, 4, light);
      g.line(37, 72, 40, 83, artPaper, 3);
    case 'vase':
      g.path(
        Path()
          ..moveTo(39, 19)
          ..lineTo(61, 19)
          ..lineTo(60, 34)
          ..cubicTo(80, 52, 85, 80, 62, 87)
          ..lineTo(38, 87)
          ..cubicTo(15, 80, 20, 52, 40, 34)
          ..close(),
        color,
      );
      g.rr(37, 15, 26, 8, 3, light);
      g.line(31, 62, 69, 62, artPaper, 4);
      g.line(35, 71, 65, 71, artPaper, 3);
    case 'clock':
      g.circle(50, 49, 36, color);
      g.circle(50, 49, 29, artPaper);
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi / 6;
        g.line(
          50 + math.sin(a) * 23,
          49 - math.cos(a) * 23,
          50 + math.sin(a) * 26,
          49 - math.cos(a) * 26,
          artInk,
          1.8,
        );
      }
      g.line(50, 49, 50, 32, artInk, 3);
      g.line(50, 49, 64, 56, artInk, 3);
      g.circle(50, 49, 3, color, stroke: false);
      g.line(27, 83, 32, 78, artInk, 3);
      g.line(73, 83, 68, 78, artInk, 3);
    case 'book':
      g.rr(24, 15, 56, 72, 6, color);
      g.rr(20, 78, 60, 10, 4, artPaper);
      g.line(28, 20, 28, 76, light, 4);
      g.rr(39, 30, 29, 27, 3, light, stroke: false);
      g.line(44, 38, 61, 38, artInk, 2);
      g.line(44, 45, 57, 45, artInk, 2);
      g.line(29, 83, 76, 83, color, 1.4);
    case 'mug':
      g.circle(73, 54, 16, light);
      g.circle(73, 54, 9, artPaper);
      g.rr(21, 32, 51, 49, 9, color);
      g.ellipse(21, 26, 51, 15, light);
      g.ellipse(28, 29, 36, 7, artInk, stroke: false);
      g.path(
        Path()
          ..moveTo(38, 23)
          ..quadraticBezierTo(30, 16, 38, 9),
        null,
        lineWidth: 2,
      );
      g.path(
        Path()
          ..moveTo(54, 22)
          ..quadraticBezierTo(46, 16, 54, 10),
        null,
        lineWidth: 2,
      );
      g.line(30, 46, 30, 65, artPaper, 3);
    case 'cat':
      g.path(
        Path()
          ..moveTo(72, 81)
          ..cubicTo(94, 82, 86, 53, 78, 63),
        null,
        lineWidth: 8,
        lineColor: color,
      );
      g.ellipse(27, 46, 47, 43, color);
      g.poly([24, 29, 22, 10, 42, 23, 62, 23, 80, 10, 77, 42], color);
      g.ellipse(22, 22, 57, 41, color);
      g.ellipse(37, 39, 29, 19, light, stroke: false);
      g.circle(36, 35, 2.6, artInk, stroke: false);
      g.circle(65, 35, 2.6, artInk, stroke: false);
      g.poly([47, 43, 54, 43, 50, 47], pink, stroke: false);
      g.line(24, 44, 38, 46, artInk, 1.4);
      g.line(63, 46, 78, 44, artInk, 1.4);
      g.line(41, 78, 41, 87, artInk, 2);
      g.line(61, 78, 61, 87, artInk, 2);
    case 'cake':
      g.rr(18, 53, 64, 31, 7, color);
      g.ellipse(18, 43, 64, 24, artPaper);
      g.line(17, 84, 83, 84, artInk, 3);
      g.line(22, 71, 78, 71, light, 4);
      for (final x in [35.0, 50.0, 65.0]) {
        g.rr(x - 3, 27, 6, 23, 1, color);
        g.path(
          Path()
            ..moveTo(x, 12)
            ..quadraticBezierTo(x - 8, 23, x, 26)
            ..quadraticBezierTo(x + 8, 23, x, 12)
            ..close(),
          gold,
          stroke: false,
        );
      }
    case 'apple':
      g.path(
        Path()
          ..moveTo(50, 30)
          ..cubicTo(17, 13, 9, 55, 24, 76)
          ..cubicTo(36, 95, 45, 82, 50, 86)
          ..cubicTo(57, 82, 69, 95, 82, 72)
          ..cubicTo(96, 44, 79, 14, 50, 30)
          ..close(),
        color,
      );
      g.line(50, 30, 54, 15, artInk, 4);
      g.path(
        Path()
          ..moveTo(54, 22)
          ..quadraticBezierTo(67, 7, 77, 18)
          ..quadraticBezierTo(65, 30, 54, 22)
          ..close(),
        green,
      );
      g.path(
        Path()
          ..moveTo(28, 42)
          ..quadraticBezierTo(22, 52, 28, 62),
        null,
        lineWidth: 4,
        lineColor: light,
      );
    case 'pear':
      g.path(
        Path()
          ..moveTo(50, 24)
          ..cubicTo(33, 23, 37, 45, 24, 59)
          ..cubicTo(8, 89, 87, 100, 79, 65)
          ..cubicTo(76, 50, 63, 45, 61, 29)
          ..quadraticBezierTo(56, 23, 50, 24)
          ..close(),
        color,
      );
      g.line(51, 25, 55, 11, artInk, 4);
      g.path(
        Path()
          ..moveTo(54, 17)
          ..quadraticBezierTo(68, 7, 77, 20)
          ..quadraticBezierTo(64, 28, 54, 17)
          ..close(),
        green,
      );
      g.line(29, 68, 33, 79, light, 4);
    case 'lemon':
      g.path(
        Path()
          ..moveTo(12, 50)
          ..cubicTo(30, 14, 71, 13, 89, 48)
          ..cubicTo(75, 86, 30, 89, 12, 50)
          ..close(),
        color,
      );
      g.path(
        Path()
          ..moveTo(27, 42)
          ..quadraticBezierTo(49, 23, 66, 35),
        null,
        lineWidth: 4,
        lineColor: light,
      );
      g.line(77, 50, 84, 50, artInk, 2);
    case 'camera':
      g.rr(13, 31, 74, 51, 9, color);
      g.poly([29, 31, 34, 21, 56, 21, 62, 31], color);
      g.rr(18, 26, 13, 7, 2, artInk);
      g.circle(52, 57, 24, light);
      g.circle(52, 57, 17, artInk);
      g.circle(47, 51, 6, artPaper, stroke: false);
      g.rr(70, 38, 10, 6, 2, artPaper);
    case 'umbrella':
      g.line(50, 28, 50, 80, artInk, 3);
      g.path(
        Path()
          ..moveTo(50, 80)
          ..quadraticBezierTo(50, 93, 36, 88),
        null,
        lineWidth: 4,
      );
      g.path(
        Path()
          ..moveTo(10, 53)
          ..quadraticBezierTo(15, 16, 50, 15)
          ..quadraticBezierTo(85, 16, 90, 53)
          ..quadraticBezierTo(77, 43, 63, 53)
          ..quadraticBezierTo(50, 44, 37, 53)
          ..quadraticBezierTo(23, 43, 10, 53)
          ..close(),
        color,
      );
      g.path(
        Path()
          ..moveTo(50, 15)
          ..quadraticBezierTo(34, 31, 37, 53),
        null,
        lineWidth: 2,
        lineColor: artPaper,
      );
      g.path(
        Path()
          ..moveTo(50, 15)
          ..quadraticBezierTo(66, 31, 63, 53),
        null,
        lineWidth: 2,
        lineColor: artPaper,
      );
    case 'bird':
      g.ellipse(23, 33, 57, 43, color);
      g.circle(64, 31, 18, color);
      g.poly([80, 28, 94, 34, 80, 39], gold);
      g.poly([27, 49, 10, 31, 13, 63, 28, 64], color);
      g.ellipse(33, 43, 29, 24, light);
      g.circle(68, 27, 3, artInk, stroke: false);
      g.line(44, 75, 42, 86, artInk, 2);
      g.line(57, 75, 59, 86, artInk, 2);
    case 'fish':
      g.poly([73, 48, 94, 26, 94, 76, 72, 56], color);
      g.ellipse(10, 29, 68, 44, color);
      g.path(
        Path()
          ..moveTo(43, 53)
          ..lineTo(62, 40)
          ..quadraticBezierTo(68, 68, 43, 53)
          ..close(),
        light,
      );
      g.circle(25, 44, 4, artInk, stroke: false);
      g.path(
        Path()
          ..moveTo(33, 33)
          ..quadraticBezierTo(42, 51, 33, 68),
        null,
        lineWidth: 2,
      );
      g.circle(11, 19, 4, light);
      g.circle(23, 11, 2, light);
    case 'boat':
      g.poly([10, 66, 89, 66, 76, 84, 24, 84], color);
      g.line(49, 66, 49, 14, artInk, 3);
      g.poly([45, 20, 45, 60, 17, 60], artPaper);
      g.poly([54, 26, 80, 59, 54, 59], light);
      g.line(15, 91, 36, 91, Color(0xFF83B6BF), 2);
      g.line(50, 91, 85, 91, Color(0xFF83B6BF), 2);
    case 'car':
      g.path(
        Path()
          ..moveTo(12, 50)
          ..lineTo(24, 46)
          ..lineTo(35, 27)
          ..lineTo(64, 27)
          ..lineTo(77, 46)
          ..lineTo(88, 50)
          ..lineTo(89, 75)
          ..lineTo(11, 75)
          ..close(),
        color,
      );
      g.poly([36, 33, 48, 33, 48, 46, 29, 46], artPaper);
      g.poly([54, 33, 62, 33, 71, 46, 54, 46], artPaper);
      g.circle(29, 75, 12, artInk);
      g.circle(72, 75, 12, artInk);
      g.circle(29, 75, 6, artPaper);
      g.circle(72, 75, 6, artPaper);
      g.rr(12, 56, 9, 7, 2, gold);
      g.rr(79, 56, 8, 7, 2, artPaper);
    case 'scooter':
      g.circle(21, 77, 12, artInk);
      g.circle(78, 77, 12, artInk);
      g.circle(21, 77, 6, artPaper);
      g.circle(78, 77, 6, artPaper);
      g.path(
        Path()
          ..moveTo(19, 65)
          ..lineTo(48, 65)
          ..lineTo(62, 42)
          ..lineTo(76, 42)
          ..lineTo(82, 66)
          ..lineTo(20, 70)
          ..close(),
        color,
      );
      g.line(68, 44, 64, 24, color, 7);
      g.line(58, 23, 76, 23, artInk, 4);
      g.rr(27, 52, 25, 7, 3, artInk);
      g.circle(76, 40, 7, artPaper);
    case 'train':
      g.rr(12, 46, 74, 33, 4, color);
      g.rr(50, 24, 30, 40, 4, color);
      g.rr(45, 20, 40, 7, 2, light);
      g.rr(57, 33, 16, 17, 2, artPaper);
      g.rr(21, 29, 11, 22, 2, color);
      g.rr(17, 27, 19, 6, 2, light);
      for (final x in [24.0, 46.0, 69.0]) {
        g.circle(x, 78, 10, artInk);
        g.circle(x, 78, 4, artPaper);
      }
      g.ellipse(15, 13, 14, 8, light, stroke: false);
      g.ellipse(28, 7, 17, 9, light, stroke: false);
    case 'hat':
      g.ellipse(9, 61, 82, 23, color);
      g.path(
        Path()
          ..moveTo(25, 66)
          ..lineTo(31, 32)
          ..quadraticBezierTo(50, 13, 69, 32)
          ..lineTo(76, 66)
          ..close(),
        color,
      );
      g.poly([28, 51, 73, 51, 75, 63, 26, 63], light);
      g.rr(57, 48, 13, 15, 2, artPaper);
    case 'key':
      g.circle(34, 32, 22, color);
      g.circle(34, 32, 12, artPaper);
      g.line(48, 48, 78, 79, color, 12);
      g.line(63, 66, 55, 76, color, 9);
      g.line(74, 77, 65, 86, color, 9);
      g.line(48, 48, 77, 77, artInk, 2);
    case 'shoe':
      g.path(
        Path()
          ..moveTo(18, 28)
          ..lineTo(37, 39)
          ..lineTo(50, 29)
          ..lineTo(60, 54)
          ..lineTo(82, 61)
          ..quadraticBezierTo(93, 65, 87, 80)
          ..lineTo(14, 80)
          ..close(),
        color,
      );
      g.rr(13, 75, 76, 11, 3, artPaper);
      g.line(44, 43, 57, 40, artPaper, 3);
      g.line(47, 51, 61, 47, artPaper, 3);
      g.line(51, 59, 66, 54, artPaper, 3);
    case 'ball':
      g.circle(50, 50, 36, artPaper);
      canvas.save();
      canvas.clipPath(Path()..addOval(const Rect.fromLTWH(14, 14, 72, 72)));
      g.path(
        Path()
          ..moveTo(50, 50)
          ..lineTo(10, 18)
          ..lineTo(90, 14)
          ..close(),
        color,
        stroke: false,
      );
      g.path(
        Path()
          ..moveTo(50, 50)
          ..lineTo(93, 80)
          ..lineTo(21, 93)
          ..close(),
        light,
        stroke: false,
      );
      canvas.restore();
      g.circle(50, 50, 36, null);
      g.circle(50, 50, 8, color);
    case 'star':
      final points = <double>[];
      for (var i = 0; i < 10; i++) {
        final angle = -math.pi / 2 + i * math.pi / 5;
        final radius = i.isEven ? 40.0 : 18.0;
        points.addAll([
          50 + math.cos(angle) * radius,
          51 + math.sin(angle) * radius,
        ]);
      }
      g.poly(points, color);
      g.line(47, 20, 40, 39, light, 3);
    case 'shell':
      g.path(
        Path()
          ..moveTo(50, 84)
          ..lineTo(10, 54)
          ..cubicTo(10, 14, 88, 10, 90, 54)
          ..close(),
        light,
      );
      for (final x in [22.0, 36.0, 50.0, 64.0, 78.0]) {
        g.path(
          Path()
            ..moveTo(50, 80)
            ..quadraticBezierTo(x, 58, x, 33),
          null,
          lineWidth: 3,
          lineColor: color,
        );
      }
      g.rr(38, 80, 24, 8, 3, color);
    case 'feather':
      g.path(
        Path()
          ..moveTo(19, 83)
          ..cubicTo(14, 39, 42, 11, 80, 15)
          ..cubicTo(81, 52, 49, 81, 19, 83)
          ..close(),
        color,
      );
      g.line(15, 91, 73, 24, artInk, 2.5);
      g.line(31, 69, 25, 47, light, 2);
      g.line(43, 54, 38, 31, light, 2);
      g.line(37, 63, 60, 59, light, 2);
      g.line(51, 48, 70, 43, light, 2);
    case 'leaf':
      g.path(
        Path()
          ..moveTo(18, 81)
          ..cubicTo(2, 26, 40, 11, 83, 15)
          ..cubicTo(89, 65, 59, 86, 18, 81)
          ..close(),
        color,
      );
      g.line(12, 88, 74, 24, artInk, 2.5);
      g.line(30, 70, 26, 44, artInk, 1.5);
      g.line(45, 55, 41, 30, artInk, 1.5);
      g.line(37, 62, 67, 57, artInk, 1.5);
      g.line(54, 45, 78, 40, artInk, 1.5);
    case 'butterfly':
      g.ellipse(9, 16, 37, 44, color);
      g.ellipse(54, 16, 37, 44, color);
      g.ellipse(16, 51, 31, 33, light);
      g.ellipse(53, 51, 31, 33, light);
      g.rr(45, 27, 10, 58, 5, artInk);
      g.circle(50, 26, 7, artInk);
      g.line(47, 22, 39, 10, artInk, 2);
      g.line(53, 22, 61, 10, artInk, 2);
      g.circle(27, 36, 8, light, stroke: false);
      g.circle(73, 36, 8, light, stroke: false);
    case 'flower':
      g.line(50, 48, 50, 90, green, 4);
      g.path(
        Path()
          ..moveTo(50, 75)
          ..quadraticBezierTo(25, 57, 26, 78)
          ..quadraticBezierTo(40, 90, 50, 75)
          ..close(),
        green,
      );
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3;
        g.circle(50 + math.cos(a) * 19, 35 + math.sin(a) * 19, 14, color);
      }
      g.circle(50, 35, 13, gold);
    case 'gift':
      g.rr(18, 36, 64, 52, 4, color);
      g.rr(13, 30, 74, 13, 3, light);
      g.rr(43, 30, 14, 58, 1, artPaper);
      g.path(
        Path()
          ..moveTo(50, 31)
          ..cubicTo(15, 27, 28, 4, 50, 31)
          ..cubicTo(72, 4, 86, 27, 50, 31),
        null,
        lineWidth: 5,
        lineColor: color,
      );
    case 'basket':
      g.path(
        Path()
          ..moveTo(24, 44)
          ..cubicTo(21, 3, 80, 3, 76, 44),
        null,
        lineWidth: 6,
        lineColor: color,
      );
      g.poly([15, 43, 85, 43, 76, 86, 24, 86], color);
      g.rr(12, 40, 76, 9, 3, light);
      for (final x in [30.0, 43.0, 56.0, 69.0]) {
        g.line(x, 53, x + (50 - x) / 5, 82, light, 2);
      }
      g.line(20, 60, 80, 60, light, 2);
      g.line(23, 74, 77, 74, light, 2);
    case 'lantern':
      g.path(
        Path()
          ..moveTo(38, 24)
          ..cubicTo(29, 4, 71, 4, 62, 24),
        null,
        lineWidth: 3,
      );
      g.poly([30, 26, 70, 26, 78, 36, 22, 36], color);
      g.rr(27, 36, 46, 43, 3, light);
      g.rr(34, 41, 32, 31, 2, artPaper);
      g.rr(44, 56, 12, 18, 2, gold);
      g.path(
        Path()
          ..moveTo(50, 43)
          ..quadraticBezierTo(39, 55, 50, 57)
          ..quadraticBezierTo(59, 54, 50, 43)
          ..close(),
        pink,
        stroke: false,
      );
      g.rr(22, 78, 56, 9, 3, color);
    case 'teapot':
      g.circle(75, 53, 16, color);
      g.circle(75, 53, 10, artPaper);
      g.poly([29, 47, 12, 31, 8, 37, 18, 65, 31, 68], color);
      g.ellipse(24, 32, 51, 49, color);
      g.ellipse(27, 26, 45, 14, light);
      g.circle(50, 24, 6, color);
      g.path(
        Path()
          ..moveTo(34, 45)
          ..quadraticBezierTo(27, 60, 35, 68),
        null,
        lineWidth: 3,
        lineColor: artPaper,
      );
    case 'binoculars':
      g.poly([21, 18, 41, 18, 44, 70, 12, 70], color);
      g.poly([59, 18, 79, 18, 88, 70, 56, 70], color);
      g.rr(35, 32, 31, 15, 4, color);
      g.ellipse(11, 61, 35, 22, light);
      g.ellipse(54, 61, 35, 22, light);
      g.ellipse(17, 66, 23, 12, artInk);
      g.ellipse(60, 66, 23, 12, artInk);
      g.line(28, 25, 25, 53, artPaper, 3);
      g.line(71, 25, 74, 53, artPaper, 3);
    case 'map':
      g.poly([
        10,
        20,
        36,
        13,
        62,
        22,
        89,
        13,
        89,
        79,
        62,
        88,
        36,
        79,
        10,
        88,
      ], artPaper);
      g.poly([36, 14, 61, 23, 61, 87, 36, 78], light, stroke: false);
      g.line(36, 14, 36, 78, color, 1.5);
      g.line(62, 23, 62, 86, color, 1.5);
      g.path(
        Path()
          ..moveTo(18, 66)
          ..cubicTo(36, 39, 52, 70, 75, 39),
        null,
        lineWidth: 3,
        lineColor: color,
      );
      g.line(68, 30, 82, 44, pink, 4);
      g.line(82, 30, 68, 44, pink, 4);
    case 'compass':
      g.circle(50, 51, 37, color);
      g.circle(50, 51, 29, artPaper);
      g.poly([50, 23, 60, 50, 50, 78, 40, 50], color);
      g.poly([50, 23, 50, 51, 40, 50], pink);
      g.line(22, 51, 29, 51, artInk, 2);
      g.line(71, 51, 78, 51, artInk, 2);
      g.circle(50, 51, 4, artInk, stroke: false);
      g.rr(41, 6, 18, 9, 4, color);
    case 'bottle':
      g.path(
        Path()
          ..moveTo(39, 22)
          ..lineTo(61, 22)
          ..lineTo(61, 35)
          ..quadraticBezierTo(76, 42, 75, 57)
          ..lineTo(75, 85)
          ..quadraticBezierTo(50, 94, 25, 85)
          ..lineTo(25, 57)
          ..quadraticBezierTo(24, 42, 39, 35)
          ..close(),
        light,
      );
      g.rr(36, 12, 28, 12, 3, color);
      g.rr(26, 57, 48, 20, 2, color);
      g.line(34, 46, 34, 53, artPaper, 3);
    case 'watermelon':
      g.path(
        Path()
          ..moveTo(10, 66)
          ..lineTo(53, 17)
          ..lineTo(91, 72)
          ..quadraticBezierTo(49, 96, 10, 66)
          ..close(),
        green,
      );
      g.path(
        Path()
          ..moveTo(16, 63)
          ..lineTo(52, 22)
          ..lineTo(83, 66)
          ..quadraticBezierTo(51, 86, 16, 63)
          ..close(),
        color,
      );
      for (final pair in [
        [43.0, 45.0],
        [62.0, 48.0],
        [34.0, 63.0],
        [55.0, 66.0],
        [71.0, 64.0],
      ]) {
        g.ellipse(pair[0], pair[1], 3, 5, artInk, stroke: false);
      }
    case 'strawberry':
      g.path(
        Path()
          ..moveTo(50, 29)
          ..cubicTo(7, 10, 9, 58, 50, 88)
          ..cubicTo(91, 58, 93, 10, 50, 29)
          ..close(),
        color,
      );
      g.poly([
        26,
        24,
        40,
        28,
        44,
        13,
        52,
        26,
        66,
        16,
        63,
        30,
        78,
        29,
        57,
        42,
        37,
        37,
      ], green);
      for (final pair in [
        [31.0, 48.0],
        [48.0, 51.0],
        [65.0, 45.0],
        [41.0, 66.0],
        [58.0, 65.0],
      ]) {
        g.line(pair[0], pair[1], pair[0] - 1, pair[1] + 4, artPaper, 2.5);
      }
    case 'donut':
      g.circle(50, 51, 36, color);
      g.circle(50, 51, 15, artPaper);
      for (final p in [
        [30.0, 33.0],
        [61.0, 28.0],
        [73.0, 52.0],
        [55.0, 77.0],
        [25.0, 62.0],
      ]) {
        g.line(p[0], p[1], p[0] + 6, p[1] + 2, artPaper, 3);
      }
      g.line(28, 48, 31, 40, light, 4);
    case 'pizza':
      g.poly([15, 23, 87, 25, 49, 89], gold);
      g.path(
        Path()
          ..moveTo(14, 23)
          ..quadraticBezierTo(50, 9, 87, 25),
        null,
        lineWidth: 12,
        lineColor: color,
      );
      g.circle(39, 39, 8, color);
      g.circle(65, 40, 8, color);
      g.circle(51, 62, 8, color);
      g.line(26, 35, 23, 42, green, 3);
      g.line(70, 54, 65, 60, green, 3);
    case 'bread':
      g.path(
        Path()
          ..moveTo(12, 63)
          ..cubicTo(8, 22, 82, 10, 89, 49)
          ..lineTo(88, 79)
          ..quadraticBezierTo(50, 94, 12, 79)
          ..close(),
        color,
      );
      g.path(
        Path()
          ..moveTo(12, 66)
          ..quadraticBezierTo(51, 83, 88, 67),
        null,
        lineWidth: 3,
        lineColor: light,
      );
      g.line(34, 30, 27, 49, light, 5);
      g.line(53, 25, 46, 46, light, 5);
      g.line(73, 31, 66, 50, light, 5);
    case 'pineapple':
      g.poly([35, 34, 23, 14, 43, 22, 47, 5, 58, 23, 77, 13, 67, 38], green);
      g.ellipse(25, 28, 50, 64, color);
      for (var i = 0; i < 4; i++) {
        g.line(30, 42 + i * 11, 64, 67 + i * 5, light, 2);
        g.line(68, 42 + i * 11, 36, 68 + i * 5, light, 2);
      }
    case 'backpack':
      g.path(
        Path()
          ..moveTo(37, 20)
          ..quadraticBezierTo(49, 4, 62, 20),
        null,
        lineWidth: 4,
      );
      g.rr(22, 18, 58, 72, 15, color);
      g.rr(30, 57, 42, 25, 7, light);
      g.line(33, 64, 69, 64, artInk, 2);
      g.line(71, 37, 72, 52, artPaper, 3);
      g.rr(35, 30, 28, 14, 4, artPaper);
    case 'pencil':
      g.poly([17, 72, 67, 14, 84, 29, 34, 87], color);
      g.poly([17, 72, 34, 87, 9, 94], artPaper);
      g.poly([9, 94, 13, 83, 21, 89], artInk);
      g.poly([67, 14, 75, 6, 91, 21, 84, 29], pink);
      g.line(26, 75, 75, 20, light, 3);
    case 'notebook':
      g.rr(23, 13, 59, 77, 6, color);
      g.rr(33, 23, 38, 33, 3, artPaper);
      g.line(40, 33, 64, 33, light, 2);
      g.line(40, 42, 60, 42, light, 2);
      for (var i = 0; i < 6; i++) {
        g.rr(16, 21 + i * 11, 16, 5, 2, light);
      }
    case 'ruler':
      g.poly([12, 61, 74, 10, 92, 34, 30, 87], color);
      for (var i = 0; i < 7; i++) {
        final x = 24 + i * 8.0;
        final y = 57 - i * 6.5;
        g.line(
          x,
          y,
          x + (i.isEven ? 8 : 5),
          y + (i.isEven ? 10 : 6),
          artInk,
          2,
        );
      }
    case 'globe':
      g.line(50, 78, 50, 89, artInk, 4);
      g.rr(31, 86, 40, 7, 3, color);
      g.circle(50, 44, 31, light);
      canvas.save();
      canvas.clipPath(Path()..addOval(const Rect.fromLTWH(19, 13, 62, 62)));
      g.poly(
        [23, 25, 42, 15, 50, 24, 40, 36, 45, 51, 32, 50, 24, 39],
        color,
        stroke: false,
      );
      g.poly([62, 36, 78, 32, 87, 52, 65, 69, 58, 58], color, stroke: false);
      canvas.restore();
      g.path(
        Path()
          ..moveTo(69, 10)
          ..cubicTo(100, 46, 69, 88, 29, 76),
        null,
        lineWidth: 3,
      );
    case 'flag':
      g.line(28, 10, 28, 90, artInk, 4);
      g.path(
        Path()
          ..moveTo(30, 15)
          ..cubicTo(52, 6, 64, 30, 85, 16)
          ..lineTo(85, 56)
          ..cubicTo(65, 71, 52, 47, 30, 56)
          ..close(),
        color,
      );
      g.line(38, 85, 18, 85, color, 4);
      g.circle(28, 10, 4, gold);
    case 'telescope':
      g.line(51, 56, 29, 89, artInk, 3);
      g.line(51, 56, 72, 89, artInk, 3);
      g.line(51, 56, 51, 90, artInk, 3);
      g.poly([16, 41, 78, 14, 89, 40, 27, 67], color);
      g.poly([73, 15, 80, 12, 92, 40, 85, 43], light);
      g.poly([17, 41, 26, 37, 37, 61, 27, 66], light);
      g.line(36, 39, 67, 25, artPaper, 3);
    case 'rocket':
      g.poly([32, 54, 17, 73, 17, 87, 37, 76], color);
      g.poly([68, 54, 83, 73, 83, 87, 63, 76], color);
      g.path(
        Path()
          ..moveTo(50, 8)
          ..cubicTo(27, 30, 29, 58, 33, 78)
          ..lineTo(67, 78)
          ..cubicTo(71, 58, 73, 30, 50, 8)
          ..close(),
        light,
      );
      g.path(
        Path()
          ..moveTo(50, 8)
          ..quadraticBezierTo(34, 26, 34, 34)
          ..lineTo(66, 34)
          ..quadraticBezierTo(66, 26, 50, 8)
          ..close(),
        color,
      );
      g.circle(50, 48, 13, color);
      g.circle(50, 48, 8, artPaper);
      g.poly([39, 81, 61, 81, 50, 97], gold, stroke: false);
    case 'dog':
      g.ellipse(24, 47, 52, 40, color);
      g.path(
        Path()
          ..moveTo(74, 64)
          ..quadraticBezierTo(95, 41, 84, 36),
        null,
        lineWidth: 7,
        lineColor: color,
      );
      g.rr(25, 16, 51, 47, 18, color);
      g.ellipse(17, 18, 19, 37, light);
      g.ellipse(65, 18, 19, 37, light);
      g.ellipse(35, 38, 31, 21, light, stroke: false);
      g.circle(38, 31, 3, artInk, stroke: false);
      g.circle(63, 31, 3, artInk, stroke: false);
      g.ellipse(45, 40, 12, 8, artInk, stroke: false);
      g.line(50, 48, 50, 55, artInk, 2);
      g.line(36, 76, 35, 87, artInk, 2);
      g.line(64, 76, 65, 87, artInk, 2);
    case 'cherry':
      g.path(
        Path()
          ..moveTo(31, 63)
          ..quadraticBezierTo(47, 29, 64, 15)
          ..quadraticBezierTo(64, 41, 70, 61),
        null,
        lineWidth: 3,
        lineColor: green,
      );
      g.circle(30, 67, 20, color);
      g.circle(70, 69, 20, color);
      g.path(
        Path()
          ..moveTo(61, 20)
          ..quadraticBezierTo(38, 8, 33, 25)
          ..quadraticBezierTo(50, 31, 61, 20)
          ..close(),
        green,
      );
      g.line(20, 58, 17, 67, light, 3);
      g.line(60, 60, 57, 69, light, 3);
    default:
      throw ArgumentError.value(kind, 'kind', 'Unknown original artwork');
  }
  if (variant == 1) {
    g.line(31, 61, 66, 37, artPaper, 5);
  } else if (variant == 2) {
    g.circle(38, 60, 7, artPaper);
    g.circle(63, 43, 7, artPaper);
  }
}

class ArtBrush {
  const ArtBrush(this.canvas);
  final Canvas canvas;
  void path(
    Path path,
    Color? color, {
    bool stroke = true,
    double lineWidth = 2,
    Color lineColor = artInk,
  }) {
    if (color != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
    if (stroke) {
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void rr(
    double x,
    double y,
    double w,
    double h,
    double r,
    Color? color, {
    bool stroke = true,
  }) => path(
    Path()..addRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
    ),
    color,
    stroke: stroke,
  );
  void ellipse(
    double x,
    double y,
    double w,
    double h,
    Color? color, {
    bool stroke = true,
  }) => path(Path()..addOval(Rect.fromLTWH(x, y, w, h)), color, stroke: stroke);
  void circle(
    double x,
    double y,
    double radius,
    Color? color, {
    bool stroke = true,
  }) => ellipse(
    x - radius,
    y - radius,
    radius * 2,
    radius * 2,
    color,
    stroke: stroke,
  );
  void line(
    double x1,
    double y1,
    double x2,
    double y2,
    Color color,
    double width,
  ) => canvas.drawLine(
    Offset(x1, y1),
    Offset(x2, y2),
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  void poly(List<double> points, Color? color, {bool stroke = true}) {
    final p = Path()..moveTo(points[0], points[1]);
    for (var i = 2; i < points.length; i += 2) {
      p.lineTo(points[i], points[i + 1]);
    }
    p.close();
    path(p, color, stroke: stroke);
  }
}
