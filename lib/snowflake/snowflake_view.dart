import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'geometry.dart';

/// Mirrors a cut wedge into the full flake. `unfold` 0→1 opens the folded
/// paper fold by fold for the reveal; mirrored segments are lightly shaded.
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
    this.shading = true,
  });

  final List<Cut>? cuts;
  final String preset;
  final int folds;
  final double size, unfold, spin;
  final Color? color;
  final String pattern;
  final bool glow, shading;

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
        shading: shading,
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
  _FlakeKey(this.wedge, this.size, this.glow, this.shading);
  final _WedgeKey wedge;
  final double size;
  final bool glow, shading;

  @override
  bool operator ==(Object o) => o is _FlakeKey && o.wedge == wedge && o.size == size && o.glow == glow && o.shading == shading;

  @override
  int get hashCode => Object.hash(wedge, size, glow, shading);
}

// Fully unfolded, unrotated flakes (glow included) are baked once: the home
// screen, gallery and falling flakes then cost a single drawImage per frame.
final _flakeCache = <_FlakeKey, ui.Image>{};

// ---- Unfolding ------------------------------------------------------------
//
// Segment positions are integers: position p is the wedge turned by p·step,
// mirrored when p is odd; crease c lies between positions c and c+1. The folds
// open last-first, each multiplying the visible run of segments: the final
// half fold (×2), then folds' thirds (×3, a flap each side), then halves (×2).
// For 6 folds that is 1 → 2 → 6 → 12 segments.

/// Tint of mirrored segments, and the extra tint of a flap seen edge-on.
const _sideShade = 0.14, _turnShade = 0.3;

/// One turn of a layer over crease [crease] during [stage], landing on [side]
/// of it (+1 = clockwise).
class _Flip {
  const _Flip(this.stage, this.crease, this.side);
  final int stage, crease, side;
}

class _Layer {
  const _Layer(this.pos, this.flips);
  final int pos;

  /// Innermost first: the order they apply to the flat segment.
  final List<_Flip> flips;
}

class _UnfoldPlan {
  const _UnfoldPlan(this.stages, this.layers);
  final int stages;
  final List<_Layer> layers;
}

final _plans = <int, _UnfoldPlan>{};

_UnfoldPlan _unfoldPlan(int folds) => _plans.putIfAbsent(folds, () {
      final factors = [2];
      var f = folds;
      for (final k in const [3, 2]) {
        while (f % k == 0) {
          factors.add(k);
          f ~/= k;
        }
      }
      if (f > 1) factors.add(f); // opens like an accordion
      final runs = [(0, 0)];
      for (final k in factors) {
        final (lo, hi) = runs.last;
        final m = hi - lo + 1;
        runs.add((lo - (k - 1) ~/ 2 * m, hi + k ~/ 2 * m));
      }
      final (lo, hi) = runs.last;
      return _UnfoldPlan(factors.length, [for (var p = lo; p <= hi; p++) _Layer(p, _flipsFor(p, runs))]);
    });

/// Folds position [pos] back to 0 stage by stage, reflecting it over the crease
/// next to the run it came from.
List<_Flip> _flipsFor(int pos, List<(int, int)> runs) {
  final flips = <_Flip>[];
  var p = pos;
  for (var s = runs.length - 2; s >= 0; s--) {
    final (lo, hi) = runs[s];
    final m = hi - lo + 1;
    while (p > hi) {
      final c = hi + (p - hi - 1) ~/ m * m;
      flips.add(_Flip(s, c, 1));
      p = 2 * c + 1 - p;
    }
    while (p < lo) {
      final c = lo - 1 - (lo - 1 - p) ~/ m * m;
      flips.add(_Flip(s, c, -1));
      p = 2 * c + 1 - p;
    }
  }
  return flips;
}

/// Turns the paper on [side] of the line through the centre at angle [a] up
/// towards the viewer by [phi]: 0 = flat in place, π = folded over the line.
Matrix4 _turn(double a, int side, double phi) {
  final dx = math.cos(a), dy = math.sin(a);
  final nx = -dy * side, ny = dx * side;
  final c = math.cos(phi), s = math.sin(phi);
  // Basis (d, n, z): d stays, n → c·n + s·z, z → −s·n + c·z. Column-major.
  return Matrix4(
    dx * dx + c * nx * nx, dy * dx + c * ny * nx, s * nx, 0,
    dx * dy + c * nx * ny, dy * dy + c * ny * ny, s * ny, 0,
    -s * nx, -s * ny, c, 0,
    0, 0, 0, 1,
  );
}

class SnowflakePainter extends CustomPainter {
  SnowflakePainter({
    required this.cuts,
    required this.folds,
    required this.color,
    required this.pattern,
    required this.unfold,
    required this.spin,
    required this.shading,
    required this.glow,
    required this.dpr,
  });

  final List<Cut> cuts;
  final int folds;
  final Color color;
  final String pattern;
  final double unfold, spin, dpr;
  final bool shading, glow;

  _WedgeKey _wedgeKey(double s) => _WedgeKey(cuts, folds, color, pattern, (s * dpr).round());

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    if (unfold < 1 || spin != 0) {
      _paintGlowing(canvas, s);
      return;
    }
    final m = glow ? _glowMargin : 0.0;
    final key = _FlakeKey(_wedgeKey(s), s, glow, shading);
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

  /// Paper tinted towards night blue by [a]: mirrored segments face the light
  /// at a slightly different angle, flaps turning over darken edge-on.
  static Paint _shade(double a) {
    final p = Paint()..filterQuality = FilterQuality.medium;
    if (a > 0) p.colorFilter = ColorFilter.mode(Color.fromRGBO(46, 74, 148, math.min(a, 1)), BlendMode.srcATop);
    return p;
  }

  void _paintFlake(Canvas canvas, double s) {
    final img = _wedgeImage(_wedgeKey(s));
    final segs = folds * 2;
    final step = math.pi * 2 / segs;
    final t = unfold.clamp(0.0, 1.0);
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final dst = Rect.fromCenter(center: Offset.zero, width: s, height: s);
    final flat = t >= 1;

    // Flaps lifted towards the viewer grow past the flake's box.
    canvas.saveLayer(Rect.fromLTWH(0, 0, s, s).inflate(flat ? 0 : s * .3), Paint());
    canvas.translate(s / 2, s / 2);
    canvas.rotate(spin);
    if (flat) {
      final front = _shade(0), back = _shade(shading ? _sideShade : 0);
      for (var i = 0; i < segs; i++) {
        canvas.save();
        canvas.rotate(i * step);
        if (i.isOdd) canvas.scale(-1, 1);
        canvas.drawImageRect(img, src, dst, i.isOdd ? back : front);
        canvas.restore();
      }
    } else {
      _paintFolded(canvas, img, src, dst, s, t);
    }
    canvas.restore();
  }

  /// The paper while it unfolds: each layer is the flat segment at its final
  /// position, turned back over the creases it still has to open.
  void _paintFolded(Canvas canvas, ui.Image img, Rect src, Rect dst, double s, double t) {
    final plan = _unfoldPlan(folds);
    final half = wedgeHalfAngle(folds), step = 2 * half;
    final len = 1 / plan.stages;
    final stage = math.min(plan.stages - 1, t ~/ len);
    final e = Curves.easeInOut.transform(((t - stage * len) / len).clamp(0.0, 1.0));
    final phi = math.pi * (1 - e);
    final persp = Matrix4.identity()..setEntry(3, 2, -1 / (s * 2.5));
    final side = shading ? _sideShade : 0.0;

    bool moving(_Layer l) => l.flips.any((f) => f.stage == stage);
    // Layers turning over now lie on top of the stack.
    for (final l in [...plan.layers.where((l) => !moving(l)), ...plan.layers.where(moving)]) {
      var m = Matrix4.rotationZ(l.pos * step);
      if (l.pos.isOdd) m.multiply(Matrix4.diagonal3Values(-1, 1, 1));
      // Each turn still to come mirrors the layer once more.
      var pending = 0, active = 0;
      for (final f in l.flips) {
        if (f.stage < stage) continue;
        f.stage == stage ? active++ : pending++;
        m = _turn(-math.pi / 2 + half + f.crease * step, f.side, f.stage == stage ? phi : math.pi)..multiply(m);
      }
      final after = l.pos.isOdd != pending.isOdd, before = after != active.isOdd;
      final a = side * ((before ? 1 - e : 0) + (after ? e : 0)) + (active > 0 ? _turnShade * math.sin(phi) : 0);
      canvas.save();
      canvas.transform((persp.clone()..multiply(m)).storage);
      canvas.drawImageRect(img, src, dst, _shade(a));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(SnowflakePainter o) =>
      !identical(o.cuts, cuts) ||
      o.folds != folds ||
      o.color != color ||
      o.pattern != pattern ||
      o.unfold != unfold ||
      o.spin != spin ||
      o.shading != shading ||
      o.glow != glow ||
      o.dpr != dpr;
}
