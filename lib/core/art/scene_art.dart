import 'package:flutter/material.dart';

import '../domain/puzzle.dart';
import 'object_art.dart';
import 'illustrated_scene_art.dart';

class ScenePainter extends CustomPainter {
  const ScenePainter(this.scene, {this.alternate = false});
  final SceneData scene;
  final bool alternate;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / 600, size.height / 450);
    final illustrated = scene.template.startsWith('illustrated-');
    if (illustrated) {
      paintIllustratedBackground(canvas, scene);
    } else {
      _background(canvas);
    }
    for (final object in scene.objects) {
      if (alternate && object.alternateHidden) continue;
      final r = object.region;
      final bounds = Rect.fromLTWH(
        r.x * 600,
        r.y * 450,
        r.width * 600,
        r.height * 450,
      );
      canvas.save();
      canvas.clipRect(bounds);
      canvas.translate(bounds.center.dx, bounds.center.dy);
      canvas.rotate(object.rotation);
      canvas.translate(-bounds.width / 2, -bounds.height / 2);
      canvas.scale(bounds.width / 100, bounds.height / 100);
      drawObject(
        canvas,
        alternate ? object.alternateKind ?? object.kind : object.kind,
        colorIndex: alternate
            ? object.alternateColor ?? object.color
            : object.color,
        variant: alternate
            ? object.alternateVariant ?? object.variant
            : object.variant,
      );
      canvas.restore();
    }
    if (illustrated) paintIllustratedForeground(canvas, scene);
    canvas.restore();
  }

  void _background(Canvas canvas) {
    final g = ArtBrush(canvas);
    final tint = objectColors[scene.palette % 6];
    final wall = Color.lerp(tint, artPaper, .87)!;
    final soft = Color.lerp(tint, artPaper, .66)!;
    final rng = SeededRandom(scene.seed);
    final outdoors = [
      'animals',
      'nature',
      'beach',
      'city',
      'transport',
      'garden',
      'forest',
      'travel',
      'adventure',
    ].contains(scene.template);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 600, 450), Paint()..color = wall);
    if (outdoors) {
      _outdoor(g, tint, soft, rng);
    } else {
      _indoor(g, tint, soft, rng);
    }
    // Grounding details vary by composition, and are identical in each pair.
    for (var i = 0; i < 10; i++) {
      final x = 14 + rng.nextDouble() * 570;
      final y = 408 + rng.nextDouble() * 30;
      g.line(
        x,
        y,
        x + 8 + rng.nextDouble() * 10,
        y,
        Color.lerp(tint, artPaper, .65)!,
        1.5,
      );
    }
  }

  void _indoor(ArtBrush g, Color tint, Color soft, SeededRandom rng) {
    final mirror = scene.layout.isOdd;
    g.canvas.save();
    if (mirror) {
      g.canvas.translate(600, 0);
      g.canvas.scale(-1, 1);
    }
    g.rr(-5, 310, 610, 145, 0, const Color(0xFFECE3D2), stroke: false);
    g.line(0, 311, 600, 311, const Color(0xFFBDB8A9), 3);
    for (var i = 0; i < 8; i++) {
      g.line(i * 85.0, 314, i * 85.0 + 45, 450, const Color(0xFFD9CEBC), 1.3);
    }
    _window(g, 350, 29, 179, 170, soft);
    g.rr(15, 100, 230, 10, 2, const Color(0xFFC7B194));
    g.rr(15, 190, 230, 10, 2, const Color(0xFFC7B194));
    g.line(27, 111, 27, 124, const Color(0xFFC7B194), 5);
    g.line(224, 111, 224, 124, const Color(0xFFC7B194), 5);
    switch (scene.template) {
      case 'kitchen':
        g.rr(12, 253, 576, 137, 6, soft);
        g.rr(7, 247, 586, 15, 4, const Color(0xFFC9B297));
        for (var i = 0; i < 5; i++) {
          g.rr(23 + i * 112.0, 274, 100, 102, 5, artPaper);
          g.line(61 + i * 112.0, 288, 83 + i * 112.0, 288, tint, 4);
        }
        g.rr(272, 264, 111, 102, 5, const Color(0xFFA9B6AF));
        g.rr(284, 280, 87, 64, 6, const Color(0xFF677C76));
        for (final x in [285.0, 320.0, 355.0]) {
          g.circle(x, 272, 3, artPaper, stroke: false);
        }
      case 'bedroom':
        g.rr(95, 238, 329, 119, 13, const Color(0xFFD4BD9F));
        g.rr(91, 272, 336, 124, 10, soft);
        g.rr(100, 253, 125, 55, 13, artPaper);
        g.rr(244, 253, 125, 55, 13, artPaper);
        g.rr(91, 305, 336, 83, 8, tint);
        for (var i = 0; i < 6; i++) {
          g.line(103 + i * 53.0, 316, 103 + i * 53.0, 379, soft, 2);
        }
        g.rr(456, 263, 105, 109, 6, const Color(0xFFCDBA9F));
        g.rr(466, 283, 85, 36, 4, artPaper);
        g.rr(466, 325, 85, 36, 4, artPaper);
        g.circle(509, 300, 3, tint);
        g.circle(509, 342, 3, tint);
      case 'food':
        g.ellipse(45, 210, 517, 199, const Color(0xFFD1B799));
        g.ellipse(74, 227, 457, 158, artPaper);
        for (var i = 0; i < 3; i++) {
          g.circle(158 + i * 144.0, 312, 38, soft);
          g.circle(158 + i * 144.0, 312, 29, artPaper);
        }
        g.rr(105, 130, 285, 8, 2, const Color(0xFFC7B194));
      case 'restaurant':
        g.rr(12, 247, 180, 100, 10, tint);
        g.rr(408, 247, 180, 100, 10, tint);
        g.ellipse(116, 253, 367, 140, const Color(0xFFCAB08F));
        g.ellipse(132, 261, 335, 119, artPaper);
        g.line(201, 374, 181, 438, const Color(0xFFB69777), 8);
        g.line(399, 374, 419, 438, const Color(0xFFB69777), 8);
        g.rr(218, 18, 104, 91, 5, tint);
        g.rr(229, 29, 82, 69, 2, artPaper);
        g.ellipse(242, 45, 55, 34, soft, stroke: false);
      case 'school':
        g.rr(19, 23, 301, 138, 6, const Color(0xFFADB59C));
        g.rr(27, 30, 285, 120, 3, const Color(0xFF6F9080));
        g.line(49, 61, 145, 61, artPaper, 4);
        g.line(49, 81, 195, 81, artPaper, 4);
        g.line(49, 101, 113, 101, artPaper, 4);
        for (var i = 0; i < 3; i++) {
          g.rr(24 + i * 198.0, 287, 177, 27, 5, const Color(0xFFCBB295));
          g.line(
            44 + i * 198.0,
            314,
            44 + i * 198.0,
            391,
            const Color(0xFFB7A38B),
            7,
          );
          g.line(
            181 + i * 198.0,
            314,
            181 + i * 198.0,
            391,
            const Color(0xFFB7A38B),
            7,
          );
          g.rr(60 + i * 198.0, 362, 110, 23, 5, soft);
        }
      case 'mall':
        g.rr(23, 23, 244, 226, 6, artPaper);
        g.rr(325, 23, 252, 226, 6, artPaper);
        g.rr(23, 23, 244, 38, 4, tint);
        g.rr(325, 23, 252, 38, 4, soft);
        for (var i = 0; i < 4; i++) {
          g.rr(30 + i * 60.0, 224, 49, 32, 4, soft);
        }
        g.rr(74, 298, 447, 27, 7, const Color(0xFFCDB99C));
        g.line(105, 323, 105, 382, const Color(0xFFCDB99C), 9);
        g.line(495, 323, 495, 382, const Color(0xFFCDB99C), 9);
      case 'studio':
        g.rr(12, 21, 273, 180, 6, const Color(0xFFDECDB9));
        for (var i = 0; i < 5; i++) {
          g.line(20, 56 + i * 29.0, 277, 56 + i * 29.0, artPaper, 2);
        }
        g.poly([390, 126, 482, 126, 501, 262, 371, 262], artPaper);
        g.line(412, 262, 375, 399, const Color(0xFFB9A184), 7);
        g.line(462, 262, 499, 399, const Color(0xFFB9A184), 7);
        g.rr(15, 282, 329, 26, 4, const Color(0xFFBEA487));
        g.line(42, 308, 42, 411, const Color(0xFFBEA487), 8);
        g.line(317, 308, 317, 411, const Color(0xFFBEA487), 8);
      default:
        g.rr(107, 239, 367, 126, 24, tint);
        g.rr(92, 286, 40, 93, 13, soft);
        g.rr(452, 286, 40, 93, 13, soft);
        g.rr(132, 307, 321, 64, 15, soft);
        g.rr(133, 249, 89, 59, 15, artPaper);
        g.rr(362, 250, 75, 60, 15, wallColor(tint));
        g.ellipse(177, 366, 221, 52, const Color(0xFFD5BC9B));
        g.line(200, 396, 196, 440, const Color(0xFFBCA386), 6);
        g.line(371, 396, 378, 440, const Color(0xFFBCA386), 6);
        g.rr(249, 30, 72, 96, 4, tint);
        g.rr(257, 38, 56, 80, 1, artPaper);
        g.ellipse(265, 66, 41, 29, soft, stroke: false);
    }
    // Hand-drawn textile rug and a tall plant help the interior feel inhabited.
    g.ellipse(72, 408, 452, 44, wallColor(tint), stroke: false);
    for (var i = 0; i < 5; i++) {
      g.line(120, 420 + i * 5.0, 480, 420 + i * 5.0, soft, 1);
    }
    g.canvas.restore();
  }

  static Color wallColor(Color tint) => Color.lerp(tint, artPaper, .80)!;

  void _window(ArtBrush g, double x, double y, double w, double h, Color soft) {
    g.rr(x, y, w, h, 9, artPaper);
    g.rr(x + 9, y + 9, w - 18, h - 18, 4, const Color(0xFFD1E5E4));
    g.ellipse(x + 23, y + 24, 49, 16, artPaper, stroke: false);
    g.ellipse(x + w - 76, y + 54, 49, 14, artPaper, stroke: false);
    g.path(
      Path()
        ..moveTo(x + 9, y + h - 41)
        ..quadraticBezierTo(x + w / 2, y + h - 70, x + w - 9, y + h - 30)
        ..lineTo(x + w - 9, y + h - 9)
        ..lineTo(x + 9, y + h - 9)
        ..close(),
      soft,
      stroke: false,
    );
    g.line(x + w / 2, y + 7, x + w / 2, y + h - 7, artPaper, 5);
    g.line(x + 7, y + h / 2, x + w - 7, y + h / 2, artPaper, 5);
    g.rr(x - 6, y + h, w + 12, 10, 2, const Color(0xFFC7B194));
  }

  void _outdoor(ArtBrush g, Color tint, Color soft, SeededRandom rng) {
    final beach = scene.template == 'beach' || scene.template == 'travel';
    final urban = scene.template == 'city' || scene.template == 'transport';
    g.circle(
      scene.layout.isOdd ? 101 : 497,
      45,
      26,
      const Color(0xFFF0D494),
      stroke: false,
    );
    for (var i = 0; i < 4; i++) {
      final x = 31 + i * 146.0 + rng.nextDouble() * 20;
      g.ellipse(x, 22 + i % 2 * 17, 62, 19, artPaper, stroke: false);
      g.ellipse(x + 17, 13 + i % 2 * 17, 35, 25, artPaper, stroke: false);
    }
    if (beach) {
      g.rr(-5, 151, 610, 302, 0, const Color(0xFFD1E5E2), stroke: false);
      g.path(
        Path()
          ..moveTo(0, 253)
          ..quadraticBezierTo(170, 189, 316, 269)
          ..quadraticBezierTo(470, 321, 600, 244)
          ..lineTo(600, 450)
          ..lineTo(0, 450)
          ..close(),
        const Color(0xFFF0DDB6),
        stroke: false,
      );
      for (var i = 0; i < 5; i++) {
        g.line(
          25 + i * 117.0,
          174 + (i % 2) * 15,
          84 + i * 117.0,
          174 + (i % 2) * 15,
          artPaper,
          3,
        );
      }
      g.line(510, 97, 510, 287, const Color(0xFFB79C7A), 7);
      g.path(
        Path()
          ..moveTo(425, 145)
          ..quadraticBezierTo(430, 58, 510, 57)
          ..quadraticBezierTo(590, 58, 596, 145)
          ..close(),
        tint,
      );
      g.path(
        Path()
          ..moveTo(510, 57)
          ..quadraticBezierTo(483, 99, 480, 145),
        null,
        lineWidth: 3,
        lineColor: artPaper,
      );
      g.path(
        Path()
          ..moveTo(510, 57)
          ..quadraticBezierTo(540, 99, 544, 145),
        null,
        lineWidth: 3,
        lineColor: artPaper,
      );
      _palm(g, 77, 293, 1.0);
    } else if (urban) {
      g.rr(0, 284, 600, 166, 0, const Color(0xFFD4DCD5), stroke: false);
      for (var i = 0; i < 5; i++) {
        final h = 123 + rng.nextInt(65).toDouble();
        final x = 6 + i * 120.0;
        g.rr(x, 260 - h, 104, h, 4, i.isEven ? soft : wallColor(tint));
        for (var row = 0; row < 3; row++) {
          for (var col = 0; col < 3; col++) {
            g.rr(
              x + 12 + col * 28.0,
              275 - h + row * 35.0,
              18,
              24,
              3,
              artPaper,
            );
          }
        }
        g.rr(x + 40, 216, 26, 44, 3, tint);
      }
      g.rr(-5, 326, 610, 100, 0, const Color(0xFFAFBDB6), stroke: false);
      for (var i = 0; i < 6; i++) {
        g.line(i * 106.0 + 10, 376, i * 106.0 + 61, 376, artPaper, 4);
      }
      g.rr(427, 267, 132, 17, 5, const Color(0xFFBBA68C));
      g.line(442, 284, 442, 315, const Color(0xFFBBA68C), 5);
      g.line(544, 284, 544, 315, const Color(0xFFBBA68C), 5);
    } else {
      g.path(
        Path()
          ..moveTo(0, 195)
          ..quadraticBezierTo(128, 68, 305, 184)
          ..quadraticBezierTo(440, 83, 600, 191)
          ..lineTo(600, 450)
          ..lineTo(0, 450)
          ..close(),
        const Color(0xFFCEDBC0),
        stroke: false,
      );
      g.path(
        Path()
          ..moveTo(0, 287)
          ..quadraticBezierTo(247, 197, 600, 291)
          ..lineTo(600, 450)
          ..lineTo(0, 450)
          ..close(),
        const Color(0xFFDBE3C8),
        stroke: false,
      );
      g.path(
        Path()
          ..moveTo(265, 238)
          ..quadraticBezierTo(240, 319, 386, 450)
          ..lineTo(228, 450)
          ..quadraticBezierTo(152, 335, 265, 238)
          ..close(),
        const Color(0xFFE7D7B8),
        stroke: false,
      );
      _tree(g, 68, 294, .95, tint);
      _tree(g, 522, 278, 1.16, soft);
      if (scene.template == 'animals') {
        g.poly([
          345,
          242,
          345,
          130,
          406,
          91,
          469,
          130,
          469,
          242,
        ], const Color(0xFFDAB6A1));
        g.poly([332, 132, 406, 83, 482, 132], tint);
        g.rr(381, 168, 54, 74, 3, artPaper);
        g.line(354, 150, 463, 150, artPaper, 3);
      } else if (scene.template == 'adventure') {
        g.poly([340, 277, 402, 133, 481, 277], tint);
        g.poly([366, 277, 402, 188, 447, 277], artPaper);
        g.line(340, 277, 328, 285, artInk, 3);
        g.line(481, 277, 493, 285, artInk, 3);
      } else if (scene.template == 'garden') {
        for (var i = 0; i < 6; i++) {
          g.rr(170 + i * 53.0, 165, 26, 95, 9, artPaper);
        }
        g.line(169, 197, 457, 197, const Color(0xFFCDBDA4), 8);
        g.line(169, 238, 457, 238, const Color(0xFFCDBDA4), 8);
      } else if (scene.template == 'forest') {
        _tree(g, 181, 231, .62, const Color(0xFFBCD0AF));
        _tree(g, 422, 209, .65, const Color(0xFFB2C8A6));
      } else {
        g.ellipse(305, 260, 175, 56, const Color(0xFFB6D5CF), stroke: false);
        g.ellipse(330, 270, 125, 24, const Color(0xFFD6E6DF), stroke: false);
      }
      for (var i = 0; i < 12; i++) {
        final x = 16 + rng.nextDouble() * 570;
        final y = 369 + rng.nextDouble() * 66;
        g.line(x, y, x + 3, y - 9, const Color(0xFFA5B68F), 2);
        g.line(x + 3, y, x + 7, y - 8, const Color(0xFFA5B68F), 2);
      }
    }
  }

  void _tree(ArtBrush g, double x, double bottom, double scale, Color color) {
    g.canvas.save();
    g.canvas.translate(x, bottom);
    g.canvas.scale(scale);
    g.rr(-9, -130, 18, 130, 5, const Color(0xFFB9A07D));
    g.circle(-32, -131, 47, color, stroke: false);
    g.circle(23, -139, 48, color, stroke: false);
    g.circle(0, -180, 46, color, stroke: false);
    g.line(-5, -67, -24, -104, const Color(0xFFB9A07D), 5);
    g.line(4, -95, 29, -127, const Color(0xFFB9A07D), 4);
    g.canvas.restore();
  }

  void _palm(ArtBrush g, double x, double bottom, double scale) {
    g.canvas.save();
    g.canvas.translate(x, bottom);
    g.canvas.scale(scale);
    g.path(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(19, -84, 4, -161),
      null,
      lineWidth: 11,
      lineColor: const Color(0xFFBEA17C),
    );
    for (var i = -2; i <= 2; i++) {
      g.path(
        Path()
          ..moveTo(5, -160)
          ..quadraticBezierTo(i * 31.0, -205, i * 42.0, -132)
          ..quadraticBezierTo(i * 27.0, -161, 5, -160)
          ..close(),
        const Color(0xFF94B38B),
        stroke: false,
      );
    }
    g.canvas.restore();
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.scene != scene || old.alternate != alternate;
}
