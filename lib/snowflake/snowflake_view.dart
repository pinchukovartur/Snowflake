import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'geometry.dart';

/// Mirrors a cut wedge into the full flake. `unfold` 0→1 fans the segments out
/// for the reveal; creases fade in over the last 15%.
class SnowflakeView extends StatelessWidget {
  const SnowflakeView({
    super.key,
    this.cuts,
    this.preset = 'classic',
    this.folds = 6,
    this.size = 240,
    this.unfold = 1,
    this.color,
    this.pattern = 'plain',
    this.glow = true,
    this.spin = 0,
    this.creases = true,
  });

  final List<Cut>? cuts;
  final String preset;
  final int folds;
  final double size, unfold, spin;
  final Color? color;
  final String pattern;
  final bool glow, creases;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: SnowflakePainter(
        cuts: cuts ?? snowflakePresets[preset] ?? const [],
        folds: folds,
        color: color ?? Colors.white,
        pattern: pattern,
        unfold: unfold,
        spin: spin,
        creases: creases,
        glow: glow,
        dpr: MediaQuery.devicePixelRatioOf(context),
      ),
    );
  }
}

class _WedgeKey {
  _WedgeKey(this.cuts, this.folds, this.color, this.pattern, this.px);
  final List<Cut> cuts;
  final int folds, px;
  final Color color;
  final String pattern;

  @override
  bool operator ==(Object o) =>
      o is _WedgeKey && identical(o.cuts, cuts) && o.folds == folds && o.color == color && o.pattern == pattern && o.px == px;

  @override
  int get hashCode => Object.hash(identityHashCode(cuts), folds, color, pattern, px);
}

// The wedge is rendered once and re-drawn per segment.
final _wedgeCache = <_WedgeKey, ui.Image>{};

ui.Image _wedgeImage(_WedgeKey k) {
  final hit = _wedgeCache.remove(k);
  if (hit != null) return _wedgeCache[k] = hit;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final px = k.px.toDouble();
  final u = px / 2 * 0.96;
  c.translate(px / 2, px / 2);
  drawWedge(c, u, k.cuts, wedgeHalfAngle(k.folds), makePaperFill(k.color, k.pattern, u), pad: 0.006);
  final img = rec.endRecording().toImageSync(k.px, k.px);
  _wedgeCache[k] = img;
  while (_wedgeCache.length > 80) {
    _wedgeCache.remove(_wedgeCache.keys.first)?.dispose();
  }
  return img;
}

/// Room around the flake for the glow to spill into.
const _glowMargin = 24.0;

class _FlakeKey {
  _FlakeKey(this.wedge, this.size, this.glow, this.creases);
  final _WedgeKey wedge;
  final double size;
  final bool glow, creases;

  @override
  bool operator ==(Object o) => o is _FlakeKey && o.wedge == wedge && o.size == size && o.glow == glow && o.creases == creases;

  @override
  int get hashCode => Object.hash(wedge, size, glow, creases);
}

// Fully unfolded, unrotated flakes (glow included) are baked once: the home
// screen, gallery and falling flakes then cost a single drawImage per frame.
final _flakeCache = <_FlakeKey, ui.Image>{};

class SnowflakePainter extends CustomPainter {
  SnowflakePainter({
    required this.cuts,
    required this.folds,
    required this.color,
    required this.pattern,
    required this.unfold,
    required this.spin,
    required this.creases,
    required this.glow,
    required this.dpr,
  });

  final List<Cut> cuts;
  final int folds;
  final Color color;
  final String pattern;
  final double unfold, spin, dpr;
  final bool creases, glow;

  _WedgeKey _wedgeKey(double s) => _WedgeKey(cuts, folds, color, pattern, (s * dpr).round());

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    if (unfold < 1 || spin != 0) {
      _paintGlowing(canvas, s);
      return;
    }
    final m = glow ? _glowMargin : 0.0;
    final key = _FlakeKey(_wedgeKey(s), s, glow, creases);
    var img = _flakeCache.remove(key);
    if (img == null) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)
        ..scale(dpr)
        ..translate(m, m);
      _paintGlowing(c, s);
      final px = ((s + 2 * m) * dpr).ceil();
      img = rec.endRecording().toImageSync(px, px);
      while (_flakeCache.length >= 60) {
        _flakeCache.remove(_flakeCache.keys.first)?.dispose();
      }
    }
    _flakeCache[key] = img;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(-m, -m, s + 2 * m, s + 2 * m),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// drop-shadow(0 0 14px ice/.65) drop-shadow(0 4px 0 night/.18), then the flake.
  void _paintGlowing(Canvas canvas, double s) {
    if (glow) {
      final bounds = Rect.fromLTWH(-_glowMargin, -_glowMargin, s + 2 * _glowMargin, s + 2 * _glowMargin);
      canvas.saveLayer(bounds, Paint()..colorFilter = const ColorFilter.mode(Color(0x2E101A3F), BlendMode.srcIn));
      canvas.translate(0, 4);
      _paintFlake(canvas, s);
      canvas.restore();
      canvas.saveLayer(
        bounds,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7, tileMode: TileMode.decal)
          ..colorFilter = const ColorFilter.mode(Color(0xA6C4ECFF), BlendMode.srcIn),
      );
      _paintFlake(canvas, s);
      canvas.restore();
    }
    _paintFlake(canvas, s);
  }

  void _paintFlake(Canvas canvas, double s) {
    final img = _wedgeImage(_wedgeKey(s));
    final half = wedgeHalfAngle(folds);
    final segs = folds * 2;
    final step = math.pi * 2 / segs;
    final u = s / 2 * 0.96;
    final t = unfold.clamp(0.0, 1.0);
    final count = t >= 1 ? segs : math.max(1, (segs * math.min(1, t * 1.2)).ceil());
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final dst = Rect.fromCenter(center: Offset.zero, width: s, height: s);
    final imgPaint = Paint()..filterQuality = FilterQuality.medium;

    canvas.saveLayer(Rect.fromLTWH(0, 0, s, s), Paint());
    canvas.translate(s / 2, s / 2);
    canvas.rotate(spin);
    for (var i = 0; i < count; i++) {
      canvas.save();
      canvas.rotate(i * step * t);
      if (i.isOdd) canvas.scale(-1, 1);
      canvas.drawImageRect(img, src, dst, imgPaint);
      canvas.restore();
    }
    if (creases && t > 0.85) {
      final a = math.min(1.0, (t - 0.85) / 0.15);
      final lw = math.max(1.0, s * dpr / 240) / dpr;
      for (var i = 0; i < segs; i++) {
        final ang = -math.pi / 2 + half + i * step;
        final dx = math.cos(ang), dy = math.sin(ang), nx = -dy, ny = dx;
        final valley = i.isEven;
        final l = u * 1.02;
        canvas.drawLine(
          Offset.zero,
          Offset(dx * l, dy * l),
          Paint()
            ..blendMode = BlendMode.srcATop
            ..strokeCap = StrokeCap.round
            ..strokeWidth = lw * 1.6
            ..color = Color.fromRGBO(46, 74, 148, (valley ? 0.22 : 0.12) * a),
        );
        final o = (valley ? 1 : -1) * lw * 1.3;
        canvas.drawLine(
          Offset(nx * o, ny * o),
          Offset(dx * l + nx * o, dy * l + ny * o),
          Paint()
            ..blendMode = BlendMode.srcATop
            ..strokeCap = StrokeCap.round
            ..strokeWidth = lw
            ..color = Color.fromRGBO(255, 255, 255, 0.85 * a),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SnowflakePainter o) =>
      !identical(o.cuts, cuts) ||
      o.folds != folds ||
      o.color != color ||
      o.pattern != pattern ||
      o.unfold != unfold ||
      o.spin != spin ||
      o.creases != creases ||
      o.glow != glow ||
      o.dpr != dpr;
}
