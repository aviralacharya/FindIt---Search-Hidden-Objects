import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/puzzle.dart';
import 'object_art.dart';

class FindItMark extends StatelessWidget {
  const FindItMark({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: const BrandMarkPainter()),
  );
}

class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({this.onTeal = false, this.monochrome = false});
  final bool onTeal;
  final bool monochrome;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final g = ArtBrush(canvas);
    final ink = monochrome
        ? Colors.white
        : onTeal
        ? artPaper
        : const Color(0xFF237A68);
    g.line(63, 65, 88, 90, ink, 15);
    g.circle(43, 43, 31, null);
    canvas.drawCircle(
      const Offset(43, 43),
      31,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    g.poly(
      [
        41,
        25,
        46,
        36,
        58,
        38,
        49,
        46,
        52,
        58,
        41,
        52,
        31,
        58,
        33,
        46,
        25,
        38,
        37,
        36,
      ],
      monochrome ? Colors.white : const Color(0xFFEABD66),
      stroke: false,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter old) =>
      old.onTeal != onTeal || old.monochrome != monochrome;
}

class ModeArtwork extends StatelessWidget {
  const ModeArtwork(
    this.mode, {
    super.key,
    this.width = 128,
    this.height = 100,
  });
  final GameMode mode;
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: ModeArtPainter(mode)),
    ),
  );
}

class ModeArtPainter extends CustomPainter {
  const ModeArtPainter(this.mode);
  final GameMode mode;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 120);
    final g = ArtBrush(canvas);
    void icon(String kind, double x, double y, double s, int color) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(s / 100);
      drawObject(canvas, kind, colorIndex: color);
      canvas.restore();
    }

    switch (mode) {
      case GameMode.differences:
        g.rr(6, 19, 72, 87, 8, artPaper);
        g.rr(82, 8, 72, 87, 8, artPaper);
        g.rr(12, 25, 60, 74, 5, const Color(0xFFDCE8D2), stroke: false);
        g.rr(88, 14, 60, 74, 5, const Color(0xFFDCE8D2), stroke: false);
        icon('plant', 16, 37, 55, 0);
        icon('plant', 92, 26, 55, 3);
        canvas.drawCircle(
          const Offset(120, 58),
          23,
          Paint()
            ..color = const Color(0xFF237A68)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        g.line(65, 107, 84, 104, const Color(0xFFD7B061), 3);
      case GameMode.hidden:
        g.rr(13, 31, 99, 77, 10, const Color(0xFFDCE8D2), stroke: false);
        icon('plant', 4, 11, 64, 2);
        icon('cat', 55, 40, 57, 0);
        icon('key', 28, 61, 43, 3);
        canvas.save();
        canvas.translate(86, 24);
        canvas.scale(.66);
        const BrandMarkPainter().paint(canvas, const Size(100, 100));
        canvas.restore();
      case GameMode.odd:
        for (var i = 0; i < 6; i++) {
          final x = 13 + i % 3 * 46.0;
          final y = 12 + i ~/ 3 * 51.0;
          g.rr(x, y, 42, 46, 9, artPaper, stroke: false);
          icon(i == 4 ? 'pear' : 'apple', x + 2, y + 3, 38, i == 4 ? 2 : 0);
          if (i == 4) g.rr(x - 2, y - 2, 46, 50, 10, null);
        }
      case GameMode.memory:
        for (var i = 0; i < 3; i++) {
          canvas.save();
          canvas.translate(19 + i * 39.0, 20 + (i == 1 ? -7 : 7));
          canvas.rotate((i - 1) * .13);
          g.rr(0, 0, 53, 75, 9, i == 1 ? const Color(0xFFCFDDD0) : artPaper);
          if (i == 1) {
            g.circle(26, 36, 17, const Color(0xFFA3B99F), stroke: false);
            g.line(20, 36, 26, 43, artPaper, 4);
            g.line(26, 43, 37, 28, artPaper, 4);
          } else {
            icon(i == 0 ? 'flower' : 'butterfly', 3, 12, 47, i + 2);
          }
          canvas.restore();
        }
      case GameMode.quick:
        icon('clock', 35, 3, 93, 1);
        g.poly([
          133,
          30,
          111,
          68,
          129,
          66,
          108,
          106,
          148,
          54,
          130,
          56,
        ], const Color(0xFFEABD66));
        for (var i = 0; i < 3; i++) {
          g.line(
            9 + i * 4.0,
            43 + i * 19.0,
            33,
            43 + i * 19.0,
            const Color(0xFFA5BDC0),
            4,
          );
        }
      case GameMode.daily:
        g.rr(24, 25, 97, 82, 12, artPaper);
        g.rr(24, 25, 97, 22, 9, const Color(0xFF83A67A));
        g.line(45, 16, 45, 36, artInk, 4);
        g.line(101, 16, 101, 36, artInk, 4);
        icon('star', 44, 45, 56, 3);
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5;
          g.circle(
            133 + math.cos(a) * 15,
            23 + math.sin(a) * 15,
            2.5,
            const Color(0xFFEABD66),
            stroke: false,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ModeArtPainter old) => old.mode != mode;
}
