import 'package:flutter/material.dart';

import '../domain/puzzle.dart';
import 'object_art.dart';

const _wood = Color(0xFFCE9364);
const _cream = Color(0xFFFFF1D5);
const _coral = Color(0xFFECA083);
const _teal = Color(0xFF61A799);
const _green = Color(0xFF87AF71);

/// New layered backgrounds use the existing vector brushes and glyphs.
/// No external artwork, remote image requests, or extra rendering dependency.
void paintIllustratedBackground(Canvas canvas, SceneData scene) {
  final g = ArtBrush(canvas);
  switch (scene.template) {
    case 'illustrated-home':
      _home(g);
    case 'illustrated-garden':
      _garden(g);
    case 'illustrated-cafe':
      _cafe(g);
  }
}

void paintIllustratedForeground(Canvas canvas, SceneData scene) {
  final g = ArtBrush(canvas);
  if (scene.template == 'illustrated-home') {
    for (final y in [116.0, 192.0, 268.0]) {
      g.rr(28, y, 182, 5, 2, _wood);
    }
  } else if (scene.template == 'illustrated-cafe') {
    g.line(35, 233, 247, 233, const Color(0xFF88B4AE), 3);
    g.line(39, 183, 53, 221, Colors.white.withValues(alpha: .55), 3);
  } else {
    for (var i = 0; i < 26; i++) {
      final x = 6 + i * 23.0;
      g.line(x, 448, x + 3, 440, _green, 1.5);
    }
  }
}

void _floor(ArtBrush g, {bool tiles = false}) {
  g.rr(0, 318, 600, 132, 0, const Color(0xFFE5BE8D), stroke: false);
  for (var i = 0; i < 9; i++) {
    g.line(i * 78.0 - 60, 318, i * 78.0, 450, _wood, 1);
  }
  for (final y in [355.0, 397.0, 439.0]) {
    g.line(0, y, 600, y, const Color(0xFFD5A777), tiles ? 2 : 1);
  }
  g.line(0, 318, 600, 318, _wood, 5);
}

void _window(ArtBrush g, double x, double y, double w, double h) {
  g.rr(x, y, w, h, 12, _wood);
  g.rr(x + 7, y + 7, w - 14, h - 14, 7, const Color(0xFFB9E0DF));
  g.circle(x + w - 33, y + 32, 15, const Color(0xFFFFDA85), stroke: false);
  g.ellipse(x + 17, y + 26, 51, 13, artPaper, stroke: false);
  g.ellipse(x + 69, y + 49, 49, 12, artPaper, stroke: false);
  g.path(
    Path()
      ..moveTo(x + 7, y + h - 37)
      ..quadraticBezierTo(x + w * .35, y + h - 78, x + w - 7, y + h - 28)
      ..lineTo(x + w - 7, y + h - 7)
      ..lineTo(x + 7, y + h - 7)
      ..close(),
    const Color(0xFF99B88A),
    stroke: false,
  );
  g.line(x + w / 2, y + 7, x + w / 2, y + h - 7, _cream, 5);
  g.line(x + 7, y + h / 2, x + w - 7, y + h / 2, _cream, 5);
  g.rr(x - 6, y + h - 2, w + 12, 9, 3, _wood);
}

void _home(ArtBrush g) {
  g.rr(0, 0, 600, 450, 0, _cream, stroke: false);
  // Wallpaper, timber grain, textiles and furniture create natural clutter.
  for (var row = 0; row < 10; row++) {
    for (var col = 0; col < 18; col++) {
      final x = 12 + col * 35.0 + (row.isOdd ? 12 : 0);
      final y = 18 + row * 31.0;
      g.ellipse(x, y, 3, 7, const Color(0xFFECD7AD), stroke: false);
    }
  }
  _floor(g);
  g.rr(23, 22, 193, 260, 8, const Color(0xFFB57F59));
  g.rr(31, 29, 177, 244, 3, const Color(0xFFF2CC9B));
  for (final y in [119.0, 195.0, 271.0]) {
    g.rr(28, y, 182, 8, 2, _wood);
  }
  for (var i = 0; i < 5; i++) {
    g.line(34 + i * 36.0, 32, 34 + i * 36.0, 269, const Color(0xFFE4B383), 1);
  }
  _window(g, 347, 28, 183, 153);
  g.path(
    Path()
      ..moveTo(330, 25)
      ..lineTo(353, 25)
      ..lineTo(353, 184)
      ..quadraticBezierTo(335, 167, 330, 187)
      ..close(),
    _coral,
  );
  g.path(
    Path()
      ..moveTo(529, 25)
      ..lineTo(552, 25)
      ..lineTo(552, 187)
      ..quadraticBezierTo(535, 168, 529, 184)
      ..close(),
    _coral,
  );
  for (var i = 0; i < 4; i++) {
    g.line(335 + i * 5.0, 30, 335 + i * 5.0, 173, const Color(0xFFD58773), 1);
    g.line(533 + i * 5.0, 30, 533 + i * 5.0, 174, const Color(0xFFD58773), 1);
  }
  g.rr(235, 198, 257, 126, 25, _teal);
  g.rr(224, 256, 32, 79, 12, const Color(0xFF438C83));
  g.rr(471, 256, 32, 79, 12, const Color(0xFF438C83));
  g.rr(254, 265, 216, 62, 11, const Color(0xFF91C6B1));
  g.rr(257, 212, 75, 50, 12, const Color(0xFFF0C677));
  g.rr(355, 210, 70, 53, 13, const Color(0xFFEFA992));
  for (var i = 0; i < 5; i++) {
    g.line(362 + i * 12.0, 216, 362 + i * 12.0, 257, _cream, 1.5);
  }
  g.line(272, 327, 266, 348, _wood, 6);
  g.line(453, 327, 461, 349, _wood, 6);
  g.ellipse(133, 374, 333, 62, const Color(0xFFC8D5AC), stroke: false);
  for (var i = 0; i < 6; i++) {
    g.line(157, 390 + i * 5.0, 437, 390 + i * 5.0, const Color(0xFFADC391), 1);
  }
  g.ellipse(248, 342, 156, 35, _wood);
  g.ellipse(254, 339, 144, 25, const Color(0xFFEBC89A));
  g.line(269, 370, 260, 399, _wood, 6);
  g.line(384, 371, 395, 401, _wood, 6);
  g.rr(47, 321, 72, 11, 4, _wood);
  g.line(59, 332, 55, 361, _wood, 5);
  g.line(108, 332, 113, 360, _wood, 5);
  _foliage(g, 558, 353, .8);
  g.rr(546, 354, 35, 42, 5, _coral);
  g.rr(298, 25, 31, 58, 5, _coral);
  g.rr(304, 31, 19, 43, 2, artPaper);
  g.line(308, 59, 318, 41, _green, 2);
}

void _garden(ArtBrush g) {
  g.rr(0, 0, 600, 450, 0, const Color(0xFFD5EEEA), stroke: false);
  g.circle(80, 49, 28, const Color(0xFFFFD27A), stroke: false);
  for (var i = 0; i < 4; i++) {
    g.ellipse(
      130 + i * 125.0,
      22 + i % 2 * 23,
      68,
      16,
      artPaper,
      stroke: false,
    );
  }
  g.rr(0, 153, 600, 297, 0, const Color(0xFFBBD29A), stroke: false);
  g.path(
    Path()
      ..moveTo(267, 221)
      ..quadraticBezierTo(236, 313, 344, 450)
      ..lineTo(210, 450)
      ..quadraticBezierTo(148, 307, 267, 221)
      ..close(),
    const Color(0xFFF0D4A7),
    stroke: false,
  );
  g.rr(386, 87, 162, 145, 7, const Color(0xFFF7DDAC));
  g.poly([365, 88, 466, 28, 568, 88], _coral);
  g.line(381, 83, 466, 38, const Color(0xFFC98165), 4);
  g.line(466, 38, 553, 82, const Color(0xFFC98165), 4);
  g.rr(402, 111, 48, 54, 4, _teal);
  g.rr(408, 117, 36, 41, 2, const Color(0xFFC4E6DB));
  g.line(426, 117, 426, 159, _cream, 3);
  g.rr(494, 108, 38, 101, 4, _teal);
  g.circle(502, 157, 2, _cream, stroke: false);
  for (var i = 0; i < 12; i++) {
    final x = 6 + i * 30.0;
    g.poly([x, 175, x + 11, 166, x + 22, 175, x + 22, 245, x, 245], _cream);
  }
  g.line(0, 194, 363, 194, _wood, 6);
  g.line(0, 230, 363, 230, _wood, 6);
  _foliage(g, 58, 159, 1.4);
  _foliage(g, 192, 160, 1.1);
  g.line(59, 157, 56, 259, _wood, 8);
  g.line(195, 142, 190, 261, _wood, 7);
  g.rr(40, 255, 207, 54, 8, const Color(0xFF779A85));
  for (var i = 0; i < 4; i++) {
    g.line(46, 266 + i * 10.0, 241, 266 + i * 10.0, _cream, 2);
  }
  g.rr(35, 304, 219, 13, 4, _wood);
  g.line(54, 317, 46, 343, _wood, 6);
  g.line(235, 317, 245, 343, _wood, 6);
  g.rr(330, 292, 207, 14, 4, _wood);
  g.line(347, 306, 339, 370, _wood, 8);
  g.line(520, 306, 532, 370, _wood, 8);
  g.rr(340, 352, 189, 9, 2, const Color(0xFFAB865C));
  for (var i = 0; i < 9; i++) {
    final x = 13 + i * 65.0;
    final y = 388 + i % 3 * 18.0;
    g.ellipse(x, y, 23, 9, const Color(0xFFA4BF80), stroke: false);
    if (i.isEven) _smallFlowers(g, x + 9, y - 7);
  }
  _foliage(g, 565, 265, .8);
  _smallFlowers(g, 559, 233);
  _smallFlowers(g, 30, 233);
  g.rr(11, 414, 78, 20, 6, _coral);
  g.rr(483, 417, 98, 20, 6, _coral);
  for (var i = 0; i < 6; i++) {
    g.ellipse(
      205 + i * 22.0,
      425 - i % 2 * 18.0,
      14,
      6,
      const Color(0xFFD9BC90),
    );
  }
}

void _cafe(ArtBrush g) {
  g.rr(0, 0, 600, 450, 0, const Color(0xFFF9DFC1), stroke: false);
  for (var i = 0; i < 10; i++) {
    g.line(0, 30 + i * 30.0, 600, 30 + i * 30.0, const Color(0xFFEFD0AC), 1);
  }
  _floor(g, tiles: true);
  _window(g, 334, 33, 210, 145);
  g.rr(329, 24, 219, 20, 3, _coral);
  for (var i = 0; i < 10; i++) {
    g.rr(330 + i * 22.0, 24, 10, 25, 3, _cream, stroke: false);
  }
  g.rr(34, 64, 195, 109, 5, const Color(0xFFF0C894));
  g.rr(29, 124, 206, 8, 3, _wood);
  g.rr(29, 174, 206, 8, 3, _wood);
  g.rr(29, 240, 236, 105, 7, _teal);
  for (var i = 0; i < 4; i++) {
    g.rr(40 + i * 55.0, 254, 43, 79, 4, const Color(0xFF91C5B1));
    g.circle(61 + i * 55.0, 270, 2.4, _cream, stroke: false);
  }
  g.rr(23, 236, 248, 12, 4, _wood);
  g.rr(34, 181, 213, 53, 7, const Color(0xFFDCEEE5));
  g.rr(41, 188, 199, 42, 4, const Color(0xFFECF4DB), stroke: false);
  g.rr(256, 106, 71, 71, 6, _teal);
  g.rr(262, 112, 59, 59, 3, const Color(0xFF36645D));
  for (var i = 0; i < 4; i++) {
    g.line(269, 124 + i * 11.0, 310 - i % 2 * 12.0, 124 + i * 11.0, _cream, 2);
  }
  g.line(291, 106, 291, 93, _wood, 2);
  g.rr(321, 227, 155, 76, 11, _coral);
  for (var i = 0; i < 5; i++) {
    g.line(
      332 + i * 29.0,
      235,
      332 + i * 29.0,
      295,
      const Color(0xFFDE8973),
      2,
    );
  }
  g.ellipse(304, 337, 189, 36, _wood);
  g.ellipse(309, 331, 179, 29, _cream);
  g.line(332, 367, 322, 405, _wood, 7);
  g.line(466, 367, 476, 405, _wood, 7);
  g.rr(454, 292, 51, 77, 8, _teal);
  g.rr(451, 363, 62, 10, 3, _wood);
  g.line(464, 373, 460, 410, _wood, 5);
  g.line(501, 373, 508, 410, _wood, 5);
  g.rr(75, 345, 53, 14, 6, _coral);
  g.line(88, 359, 79, 391, _wood, 6);
  g.line(116, 359, 123, 390, _wood, 6);
  _foliage(g, 561, 329, .8);
  g.rr(548, 331, 38, 52, 6, _wood);
  g.ellipse(154, 394, 151, 39, const Color(0xFFDBC59E), stroke: false);
  for (var i = 0; i < 6; i++) {
    g.line(170, 400 + i * 4.0, 289, 400 + i * 4.0, _cream, 1);
  }
}

void _foliage(ArtBrush g, double x, double y, double scale) {
  for (var i = 0; i < 7; i++) {
    final dx = (i % 3 - 1) * 22 * scale;
    final dy = (i ~/ 3) * 18 * scale;
    g.ellipse(
      x + dx - 25 * scale,
      y - 73 * scale + dy,
      50 * scale,
      35 * scale,
      i.isEven ? _green : const Color(0xFF6D9C6A),
      stroke: false,
    );
  }
}

void _smallFlowers(ArtBrush g, double x, double y) {
  for (var i = 0; i < 3; i++) {
    g.line(x + i * 10.0, y + 12, x + i * 10.0, y - i % 2 * 9, _green, 2);
    g.circle(
      x + i * 10.0,
      y - i % 2 * 9,
      5,
      i.isEven ? _coral : _cream,
      stroke: false,
    );
    g.circle(
      x + i * 10.0,
      y - i % 2 * 9,
      2,
      const Color(0xFFE7B451),
      stroke: false,
    );
  }
}
