import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A cut is a polygon in wedge units: apex (0,0) = flake centre,
/// y negative upward, radius 1.
typedef Cut = List<Offset>;

List<Cut> _p(List<List<List<double>>> raw) => [for (final c in raw) [for (final p in c) Offset(p[0], p[1])]];

final Map<String, List<Cut>> snowflakePresets = {
  'classic': _p([
    [[0.3, -0.42], [0.06, -0.52], [0.3, -0.64]],
    [[-0.34, -0.66], [-0.07, -0.76], [-0.34, -0.88]],
    [[-0.1, -1.06], [0, -0.84], [0.1, -1.06]],
    [[0, -0.28], [0.05, -0.35], [0, -0.42], [-0.05, -0.35]],
    [[-0.22, -0.16], [-0.03, -0.22], [-0.22, -0.3]],
  ]),
  'star': _p([
    [[0.3, -0.2], [0.02, -0.6], [0.3, -0.9]],
    [[-0.3, -0.35], [-0.1, -0.45], [-0.3, -0.55]],
    [[-0.3, -0.8], [-0.14, -0.9], [-0.3, -1.1]],
    [[0.05, -1.1], [0.02, -0.95], [0.2, -1.1]],
  ]),
  'lace': _p([
    [[0.3, -0.25], [0.1, -0.3], [0.3, -0.35]],
    [[0.3, -0.55], [0.08, -0.6], [0.3, -0.65]],
    [[0.3, -0.82], [0.1, -0.86], [0.3, -0.9]],
    [[-0.3, -0.4], [-0.09, -0.46], [-0.3, -0.52]],
    [[-0.3, -0.7], [-0.1, -0.75], [-0.3, -0.8]],
    [[-0.06, -0.62], [0, -0.54], [0.05, -0.62], [0, -0.7]],
    [[0, -0.15], [0.03, -0.19], [0, -0.23], [-0.03, -0.19]],
    [[-0.12, -1.1], [-0.05, -0.93], [0.02, -1.1]],
  ]),
};

class PaperColor {
  const PaperColor(this.id, this.name, this.color);
  final String id, name;
  final Color color;
}

const paperColors = [
  PaperColor('white', 'Белая', Color(0xFFFFFFFF)),
  PaperColor('ice', 'Голубая', Color(0xFFC4ECFF)),
  PaperColor('pink', 'Розовая', Color(0xFFFFC7D0)),
  PaperColor('sun', 'Жёлтая', Color(0xFFFFE08A)),
  PaperColor('mint', 'Мятная', Color(0xFFBFF0DC)),
  PaperColor('lilac', 'Сиреневая', Color(0xFFDCD2FF)),
];

const paperPatterns = [
  ('plain', 'Гладкая'),
  ('dots', 'Горошек'),
  ('stripes', 'Полоски'),
  ('checks', 'Клетка'),
  ('sparkle', 'Блёстки'),
];

double wedgeHalfAngle(int folds) => math.pi / (2 * folds);

/// Stencil polygon in wedge units. tool: circle | square | triangle | star | heart | drop
Cut stencilShape(String tool, double cx, double cy, double r) {
  final pts = <Offset>[];
  void p(double a, double rr) => pts.add(Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr));
  switch (tool) {
    case 'circle':
      for (var i = 0; i < 28; i++) {
        p(i / 28 * math.pi * 2, r);
      }
    case 'square':
      for (final (a, b) in const [(-1, -1), (1, -1), (1, 1), (-1, 1)]) {
        pts.add(Offset(cx + a * r * 0.82, cy + b * r * 0.82));
      }
    case 'triangle':
      for (final d in const [-90, 30, 150]) {
        p(d * math.pi / 180, r);
      }
    case 'star':
      for (var i = 0; i < 10; i++) {
        p(-math.pi / 2 + i * math.pi / 5, i.isOdd ? r * 0.45 : r);
      }
    case 'heart':
      for (var i = 0; i < 32; i++) {
        final t = i / 32 * math.pi * 2;
        pts.add(Offset(
          cx + 16 * math.pow(math.sin(t), 3) * r / 17,
          cy - (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) * r / 17 - r * 0.1,
        ));
      }
    case 'drop':
      for (var i = 0; i < 28; i++) {
        final t = i / 28 * math.pi * 2;
        pts.add(Offset(cx + math.sin(t) * math.sin(t / 2) * r * 0.9, cy - math.cos(t) * r));
      }
  }
  return pts;
}

Path cutPath(Cut c, double s, {bool close = true}) {
  final path = Path()..moveTo(c.first.dx * s, c.first.dy * s);
  for (var i = 1; i < c.length; i++) {
    path.lineTo(c[i].dx * s, c[i].dy * s);
  }
  if (close) path.close();
  return path;
}

// ---- Paper fill ----------------------------------------------------------

final _tileCache = <(Color, String, int), ui.Image>{};

/// Paint for the paper: plain colour or a repeating pattern tile. unitPx = paper radius in px.
Paint makePaperFill(Color color, String pattern, double unitPx) {
  final paint = Paint()..color = color;
  if (pattern == 'plain') return paint;
  final t = math.max(8, (unitPx * 0.075).round());
  final img = _tileCache.putIfAbsent((color, pattern, t), () => _tile(color, pattern, t.toDouble()));
  return paint..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, _identity);
}

final _identity = Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

ui.Image _tile(Color color, String pattern, double t) {
  final rec = ui.PictureRecorder();
  final x = Canvas(rec);
  x.drawRect(Rect.fromLTWH(0, 0, t, t), Paint()..color = color);
  const ink = Color(0x292E4A94); // rgba(46,74,148,.16)
  switch (pattern) {
    case 'dots':
      x.drawCircle(Offset(t / 2, t / 2), t * 0.16, Paint()..color = ink);
    case 'stripes':
      final p = Paint()
        ..color = ink
        ..strokeWidth = t * 0.22
        ..style = PaintingStyle.stroke;
      for (final o in [-t, 0.0, t]) {
        x.drawLine(Offset(o, t), Offset(o + t, 0), p);
      }
    case 'checks':
      final p = Paint()..color = const Color(0x1A2E4A94);
      x.drawRect(Rect.fromLTWH(0, 0, t / 2, t / 2), p);
      x.drawRect(Rect.fromLTWH(t / 2, t / 2, t / 2, t / 2), p);
    case 'sparkle':
      var seed = 7;
      double rnd() => (seed = (seed * 16807) % 2147483647) / 2147483647;
      for (var i = 0; i < 6; i++) {
        final p = Paint()..color = i.isOdd ? const Color(0xF2FFFFFF) : const Color(0x734FB3F5);
        final cx = rnd() * t, cy = rnd() * t, rr = t * (0.04 + rnd() * 0.05);
        x.drawCircle(Offset(cx, cy), rr, p);
      }
  }
  return rec.endRecording().toImageSync(t.toInt(), t.toInt());
}

/// Draws the paper wedge (apex at current origin, pointing up) and erases cuts. s = unit radius in px.
void drawWedge(Canvas canvas, double s, List<Cut> cuts, double half, Paint fill, {double pad = 0}) {
  final bounds = Rect.fromCircle(center: Offset.zero, radius: s * 1.3);
  canvas.saveLayer(bounds, Paint());
  final wedge = Path()
    ..moveTo(0, 0)
    ..arcTo(Rect.fromCircle(center: Offset.zero, radius: s), -math.pi / 2 - half - pad, 2 * (half + pad), false)
    ..close();
  canvas.drawPath(wedge, fill);
  final clear = Paint()..blendMode = BlendMode.clear;
  for (final c in cuts) {
    if (c.length < 3) continue;
    canvas.drawPath(cutPath(c, s)..fillType = PathFillType.nonZero, clear);
  }
  canvas.restore();
}

/// Draws a dashed version of [path].
void drawDashed(Canvas canvas, Path path, Paint paint, double dash, double gap) {
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), paint);
      d += dash + gap;
    }
  }
}
