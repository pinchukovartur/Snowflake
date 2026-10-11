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
    this.spin = 0,
    this.shading = true,
    this.twinkle,
  });

  final List<Cut>? cuts;
  final String preset;
  final int folds;
  final double size, unfold, spin;
  final Color? color;
  final String pattern;
  final bool shading;

  /// Seconds the paper has shimmered for (see [shimmers]): glitter's glints
  /// flash on the unfolded flake, a hologram's sheen drifts. Redrawn each
  /// frame rather than baked, so kept to a flake on show.
  final double? twinkle;

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
        twinkle: shimmers(pattern) ? twinkle : null,
        dpr: MediaQuery.devicePixelRatioOf(context),
      ),
    );
  }
}

class _WedgeKey {
  _WedgeKey(this.cuts, this.folds, this.color, this.pattern, this.px, [this.pos = 0]);
  final List<Cut> cuts;
  final int folds, px;
  final Color color;
  final String pattern;

  /// The segment this wedge is cut from (see [toSheet]): each shows its own
  /// part of the sheet's pattern. Plain paper looks the same in every one.
  final int pos;

  _WedgeKey at(int p) {
    final segs = folds * 2;
    return _WedgeKey(cuts, folds, color, pattern, px, pattern == 'plain' ? 0 : ((p % segs) + segs) % segs);
  }

  @override
  bool operator ==(Object o) =>
      o is _WedgeKey && identical(o.cuts, cuts) && o.folds == folds && o.color == color && o.pattern == pattern && o.px == px && o.pos == pos;

  @override
  int get hashCode => Object.hash(identityHashCode(cuts), folds, color, pattern, px, pos);
}

// Each segment's wedge is rendered once and re-drawn as needed.
final _wedgeCache = <_WedgeKey, ui.Image>{};

ui.Image _wedgeImage(_WedgeKey k) {
  final hit = _wedgeCache.remove(k);
  if (hit != null) return _wedgeCache[k] = hit;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  final px = k.px.toDouble();
  final u = px / 2 * 0.96;
  c.translate(px / 2, px / 2);
  drawWedge(c, u, k.cuts, wedgeHalfAngle(k.folds), makePaperFill(k.color, k.pattern, u), pad: 0.006, pattern: k.pattern, pos: k.pos, folds: k.folds, sheen: false);
  final img = rec.endRecording().toImageSync(k.px, k.px);
  _wedgeCache[k] = img;
  while (_wedgeCache.length > 240) {
    _wedgeCache.remove(_wedgeCache.keys.first)?.dispose();
  }
  return img;
}

class _FlakeKey {
  _FlakeKey(this.wedge, this.size, this.shading);
  final _WedgeKey wedge;
  final double size;
  final bool shading;

  @override
  bool operator ==(Object o) => o is _FlakeKey && o.wedge == wedge && o.size == size && o.shading == shading;

  @override
  int get hashCode => Object.hash(wedge, size, shading);
}

// Fully unfolded, unrotated, still (not shimmering) flakes are baked once:
// the home screen, gallery and falling flakes then cost a single drawImage
// per frame.
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

final _stacks = <int, List<List<int>>>{};

/// The segment on top of a [folds]-fold flake still folded: what the cut
/// board shows of its paper, so the flake opens from just that.
int foldedTop(int folds) {
  final plan = _unfoldPlan(folds), depth = _stackDepths(folds)[0];
  return plan.layers[depth.indexOf(0)].pos;
}

/// How deep each layer of a [folds]-fold flake lies in its pile before
/// unfolding stage k (0 = on top; k = stages: the flat sheet). Found by
/// folding the sheet up again, last stage first: each fold lays its flap
/// over the pile it lands on, turned over (so the flap's own order
/// reverses), the clockwise flaps of a two-sided stage last, as they open
/// first. The flaps about to open thus always lie on top, and lift off it.
List<List<int>> _stackDepths(int folds) => _stacks.putIfAbsent(folds, () {
      final plan = _unfoldPlan(folds), n = plan.layers.length;
      // Piles by position, top first.
      final piles = <int, List<int>>{for (var i = 0; i < n; i++) plan.layers[i].pos: [i]};
      List<int> depths() {
        final d = List.filled(n, 0);
        for (final pile in piles.values) {
          for (var k = 0; k < pile.length; k++) {
            d[pile[k]] = k;
          }
        }
        return d;
      }

      final out = List<List<int>>.filled(plan.stages + 1, const []);
      out[plan.stages] = depths();
      for (var st = plan.stages - 1; st >= 0; st--) {
        for (final side in const [-1, 1]) {
          // Every flap of this pass is lifted off first, then laid down, so
          // none is moved twice.
          final lifted = <int, List<int>>{};
          for (final p in [...piles.keys]) {
            final pile = piles[p]!;
            final moving = [
              for (final i in pile)
                if (plan.layers[i].flips.any((f) => f.stage == st && f.side == side)) i,
            ];
            if (moving.isEmpty) continue;
            final c = plan.layers[moving.first].flips.firstWhere((f) => f.stage == st).crease;
            piles[p] = [for (final i in pile) if (!moving.contains(i)) i];
            lifted[2 * c + 1 - p] = [...moving.reversed, ...?lifted[2 * c + 1 - p]];
          }
          lifted.forEach((q, flap) => piles[q] = [...flap, ...?piles[q]]);
          piles.removeWhere((_, pile) => pile.isEmpty);
        }
        out[st] = depths();
      }
      return out;
    });

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

/// How long each stage of [plan] takes, in turns of one flap: two for a stage
/// opening flaps to both sides, as they go one after the other.
List<int> _stageWeights(_UnfoldPlan plan) => [
      for (var st = 0; st < plan.stages; st++) {for (final l in plan.layers) for (final f in l.flips) if (f.stage == st) f.side}.length > 1 ? 2 : 1,
    ];

/// How much longer unfolding a [folds]-fold flake takes than one stage per
/// fold factor would: stretch an animation by this to keep each flap's pace.
double unfoldSpan(int folds) {
  final plan = _unfoldPlan(folds);
  return _stageWeights(plan).fold(0, (a, b) => a + b) / plan.stages;
}

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

/// A point of a segment's frame (already mirrored if need be) on the sheet,
/// for the segment turned by [angle].
Offset _sheetPoint(Offset q, double angle) {
  final c = math.cos(angle), s = math.sin(angle);
  return Offset(q.dx * c - q.dy * s, q.dx * s + q.dy * c);
}

final _paperPaths = <_WedgeKey, Path>{};

/// The paper left of a wedge [r] px in radius (as [_wedgeImage] draws it):
/// what the glints are clipped to.
Path _paperPath(_WedgeKey k, double r) {
  final key = k.at(0);
  final hit = _paperPaths[key];
  if (hit != null) return hit;
  while (_paperPaths.length >= 40) {
    _paperPaths.remove(_paperPaths.keys.first);
  }
  return _paperPaths[key] = () {
    final half = wedgeHalfAngle(k.folds), pad = .006;
    var paper = Path()
      ..moveTo(0, r * pad / math.sin(half))
      ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r), -math.pi / 2 - half - pad, 2 * (half + pad), false)
      ..close();
    for (final c in k.cuts) {
      if (c.length < 3) continue;
      paper = Path.combine(PathOperation.difference, paper, cutPath(c, r)..fillType = PathFillType.nonZero);
    }
    return paper;
  }();
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
    this.twinkle,
    required this.dpr,
  });

  final List<Cut> cuts;
  final int folds;
  final Color color;
  final String pattern;
  final double unfold, spin, dpr;
  final bool shading;
  final double? twinkle;

  _WedgeKey _wedgeKey(double s) => _WedgeKey(cuts, folds, color, pattern, (s * dpr).round());

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Nothing to draw under a pixel across (an image can't be 0 wide), as when
    // laid out in no room.
    if ((s * dpr).round() < 1) return;
    if (unfold < 1 || spin != 0 || twinkle != null) {
      _paintFlake(canvas, s);
      return;
    }
    final key = _FlakeKey(_wedgeKey(s), s, shading);
    var img = _flakeCache.remove(key);
    if (img == null) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(dpr);
      _paintFlake(c, s);
      final px = (s * dpr).ceil();
      img = rec.endRecording().toImageSync(px, px);
      while (_flakeCache.length >= 60) {
        _flakeCache.remove(_flakeCache.keys.first)?.dispose();
      }
    }
    _flakeCache[key] = img;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, 0, s, s),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// Paper darkened towards black by [a]: mirrored segments face the light
  /// at a slightly different angle, flaps turning over darken edge-on.
  static Paint _shade(double a) {
    final p = Paint()..filterQuality = FilterQuality.medium;
    if (a > 0) p.colorFilter = ColorFilter.mode(Color.fromRGBO(0, 0, 0, math.min(a, 1)), BlendMode.srcATop);
    return p;
  }

  void _paintFlake(Canvas canvas, double s) {
    final key = _wedgeKey(s);
    final img = _wedgeImage(key);
    final segs = folds * 2;
    final step = math.pi * 2 / segs;
    final t = unfold.clamp(0.0, 1.0);
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final dst = Rect.fromCenter(center: Offset.zero, width: s, height: s);
    final flat = t >= 1;

    // Flaps lifted towards the viewer grow past the flake's box.
    canvas.saveLayer(Rect.fromLTWH(0, 0, s, s).inflate(flat ? 0 : s * .3), Paint());
    canvas.translate(s / 2, s / 2);
    // Unfolded, a flake rests with a crease upright, half a segment round from
    // the folded wedge's upright middle; it turns there as it opens.
    canvas.rotate(spin + t * wedgeHalfAngle(folds));
    if (flat) {
      final front = _shade(0), back = _shade(shading ? _sideShade : 0);
      for (var i = 0; i < segs; i++) {
        canvas.save();
        canvas.rotate(i * step);
        if (i.isOdd) canvas.scale(-1, 1);
        canvas.drawImageRect(_wedgeImage(key.at(i)), src, dst, i.isOdd ? back : front);
        canvas.restore();
      }
      final tw = twinkle;
      if (tw != null && pattern == 'sparkle') {
        // The glints, drawn straight on (no image per frame): each segment
        // clipped to its paper and showing its own part of the sheet's.
        final r = s / 2 * .96;
        final clip = _paperPath(key, r);
        final h = wedgeHalfAngle(folds);
        for (var i = 0; i < segs; i++) {
          canvas.save();
          canvas.rotate(i * step);
          if (i.isOdd) canvas.scale(-1, 1);
          canvas.clipPath(clip);
          toSheet(canvas, i, folds);
          // Only where this segment lies on the sheet.
          final corners = [Offset.zero, Offset(-r * math.sin(h), -r * math.cos(h)), Offset(r * math.sin(h), -r * math.cos(h)), Offset(0, -r)];
          final onSheet = [
            for (final q in corners) _sheetPoint(i.isOdd ? Offset(-q.dx, q.dy) : q, i * step),
          ];
          var area = Rect.fromPoints(onSheet.first, onSheet.first);
          for (final q in onSheet) {
            area = area.expandToInclude(Rect.fromPoints(q, q));
          }
          drawGlints(canvas, area.inflate(r * .05), color, r, tw);
          canvas.restore();
        }
      }
    } else {
      _paintFolded(canvas, key, src, dst, s, t);
    }
    if (pattern == 'holo') {
      // The hologram's sheen stays put on the screen, as light on foil does,
      // however the flake turns: laid over the paper drawn so far.
      canvas.rotate(-(spin + t * wedgeHalfAngle(folds)));
      drawHoloSheen(canvas, Rect.fromCircle(center: Offset.zero, radius: s * .8), s * .48, blend: BlendMode.srcATop, time: twinkle ?? 0);
    }
    canvas.restore();
  }

  /// The paper while it unfolds: each layer is the flat segment at its final
  /// position, turned back over the creases it still has to open.
  void _paintFolded(Canvas canvas, _WedgeKey key, Rect src, Rect dst, double s, double t) {
    final plan = _unfoldPlan(folds);
    final half = wedgeHalfAngle(folds), step = 2 * half;
    // A stage opening flaps to both sides takes twice as long (see [_stageWeights]).
    final weights = _stageWeights(plan);
    var at = t * weights.fold(0, (a, b) => a + b), stage = 0;
    while (stage < plan.stages - 1 && at >= weights[stage]) {
      at -= weights[stage];
      stage++;
    }
    final p = (at / weights[stage]).clamp(0.0, 1.0);
    // Flaps opening to both sides in one stage can't pass through each other:
    // the clockwise ones (on top of the stack) go first, the others after.
    final both = weights[stage] > 1;
    double progress(_Flip f) => Curves.easeInOut.transform(!both ? p : ((f.side > 0 ? p : p - .5) * 2).clamp(0.0, 1.0));
    final persp = Matrix4.identity()..setEntry(3, 2, -1 / (s * 2.5));
    final side = shading ? _sideShade : 0.0;

    bool moving(_Layer l) => l.flips.any((f) => f.stage == stage && progress(f) > 0 && progress(f) < 1);
    // As the paper lies stacked (see [_stackDepths]), deepest first: before
    // this stage's turn, or after it for a flap that has landed. A flap turning
    // over lies on top, its layers in the order they lay before (while its
    // face is still up) or will lie after (once it has turned past upright).
    final depth = _stackDepths(folds);
    double turned(_Layer l) => l.flips.where((f) => f.stage == stage).map(progress).fold(0.0, math.max);
    int deep(int i) => depth[turned(plan.layers[i]) >= .5 ? stage + 1 : stage][i];
    final all = [for (var i = 0; i < plan.layers.length; i++) i];
    final still = [for (final i in all) if (!moving(plan.layers[i])) i]..sort((a, b) => deep(b).compareTo(deep(a)));
    final turning = [for (final i in all) if (moving(plan.layers[i])) i]..sort((a, b) => deep(b).compareTo(deep(a)));
    for (final l in [for (final i in [...still, ...turning]) plan.layers[i]]) {
      var m = Matrix4.rotationZ(l.pos * step);
      if (l.pos.isOdd) m.multiply(Matrix4.diagonal3Values(-1, 1, 1));
      // Each turn still to come mirrors the layer once more.
      var pending = 0, active = 0;
      var e = 0.0;
      for (final f in l.flips) {
        if (f.stage < stage) continue;
        if (f.stage == stage) {
          active++;
          e = progress(f);
        } else {
          pending++;
        }
        m = _turn(-math.pi / 2 + half + f.crease * step, f.side, f.stage == stage ? math.pi * (1 - e) : math.pi)..multiply(m);
      }
      final phi = math.pi * (1 - e);
      final after = l.pos.isOdd != pending.isOdd, before = after != active.isOdd;
      final a = side * ((before ? 1 - e : 0) + (after ? e : 0)) + (active > 0 ? _turnShade * math.sin(phi) : 0);
      canvas.save();
      canvas.transform((persp.clone()..multiply(m)).storage);
      canvas.drawImageRect(_wedgeImage(key.at(l.pos)), src, dst, _shade(a));
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
      o.twinkle != twinkle ||
      o.shading != shading ||
      o.dpr != dpr;
}
