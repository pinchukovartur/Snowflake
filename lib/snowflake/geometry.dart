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
  // Halloween: six-fold only (built for a 15° half-wedge).
  'web': _web(),
  'pumpkins': _pumpkins(),
  'spiders': _spiders(),
  'bats': _bats(),
  'ghosts': _ghosts(),
  'hats': _hats(),
  // Classic paper flakes, six-fold: an arm with side branches on every
  // other fold.
  'fern': _branched(hole: .27, ring: .40, branches: [.50, .64, .78], lean: .7, reach: .17),
  'starburst': _branched(ring: .30, branches: [.44, .66], lean: 1.0, reach: .21, branch: .075),
  'leafy': _branched(ring: .26, branches: [.38, .56, .74], lean: .45, reach: .23, branch: .08, spine: .08),
  'forked': _forked(),
  'chevrons': _chevrons(),
  // New Year pack (not offered yet), four-fold.
  'snowmen': _snowmen(),
  'spiky': _branched(hole: .1, ring: .34, branches: [.50, .72], lean: 1.4, reach: .19, branch: .055),
};

/// Half-angle of a six-fold wedge, which the Halloween presets are drawn for.
const _h6 = math.pi / 12;

/// A point [r] out from the centre, [phi] clockwise from the wedge's middle.
Offset _polar(double r, double phi) => Offset(r * math.sin(phi), -r * math.cos(phi));

/// A classic flake's arm along the wedge's right fold (so six arms unfold),
/// [spine] wide each side, from the solid middle out to the rim: side
/// branches leave it at [branches] (along the arm), [branch] wide, leaning
/// out towards the tip by [lean] (along the arm per unit out), cut off
/// [reach] from the spine. The middle is solid out to [ring], with a [hole]
/// in it if not 0.
List<Cut> _branched({double hole = 0, required double ring, required List<double> branches, required double lean, required double reach, double branch = .065, double spine = .07}) {
  // Along the arm (u) and out from it into the wedge (v).
  final d = _polar(1, _h6), n = Offset(-math.cos(_h6), -math.sin(_h6));
  Offset at(double u, double v) => d * u + n * v;
  final dir = Offset(lean, 1) / Offset(lean, 1).distance;
  Offset out(double u, double v, double t) => at(u + dir.dx * t, v + dir.dy * t);
  const far = 2.0;
  final cuts = <Cut>[];
  // Beyond the branches' ends, all the way along the arm.
  cuts.add([at(ring, spine + reach), at(1.4, spine + reach), at(1.4, far), at(ring * .6, far), at(ring * .6, ring * .6 * .577)]);
  // Between the branches, and between the last one and the tip.
  final starts = [ring + .02, for (final b in branches) b + branch / dir.dy];
  final ends = [...branches, 1.4];
  for (var i = 0; i < starts.length; i++) {
    final u0 = starts[i], u1 = ends[i];
    if (u1 <= u0) continue;
    cuts.add([at(u0, spine), at(u1, spine), out(u1, spine, far), out(u0, spine, far)]);
  }
  if (hole > 0) cuts.add(_circle(Offset.zero, hole, 24));
  return cuts;
}

/// Everything but [keep] (a closed outline, in wedge units) cut away: one
/// contour round the board, joined to [keep] run the other way, so the
/// non-zero fill leaves it standing.
Cut _keepOnly(List<Offset> keep) {
  double area(List<Offset> p) {
    var a = 0.0;
    for (var i = 0; i < p.length; i++) {
      final q = p[i], r = p[(i + 1) % p.length];
      a += q.dx * r.dy - r.dx * q.dy;
    }
    return a;
  }

  // Joined below the apex, where the bridge out to it is off the paper.
  const outer = [Offset(0, .5), Offset(2, .5), Offset(2, -2), Offset(-2, -2), Offset(-2, .5)];
  final k = area(keep).sign == area(outer).sign ? keep.reversed.toList() : keep;
  return [outer.first, ...k, k.first, ...outer];
}

/// A classic flake with forked, swallow-tailed arms on every other fold, a
/// small branched arm on the folds between, and a frame joining them.
Cut _forkedKeep() {
  // Along the big arm (u) and out from it into the wedge (v); along the small
  // arm on the left fold (r) and out from it into the wedge (t).
  final d = _polar(1, _h6), n = Offset(-math.cos(_h6), -math.sin(_h6));
  final d2 = _polar(1, -_h6), n2 = Offset(math.cos(_h6), -math.sin(_h6));
  Offset a(double u, double v) => d * u + n * v;
  Offset b(double r, double t) => d2 * r + n2 * t;
  const w = .055, w2 = .035;
  return [
    Offset.zero,
    // Up the big arm's fold to the notch between its prongs, out to a prong.
    a(.84, 0), a(.99, .12), a(.9, w + .03),
    // Down its edge, past a side branch.
    a(.82, w), a(.88, .15), a(.84, .17), a(.74, w),
    // The frame across to the small arm.
    a(.62, w), b(.64, w2),
    // Up the small arm, past its branch, to its tip on the fold.
    b(.68, w2), b(.74, .11), b(.71, .125), b(.75, w2 + .01), b(.8, 0),
    // Back down the fold, the frame's other edge, and the big arm to the hub.
    b(.56, 0), a(.54, w), a(.3, w), b(.26, 0),
  ];
}

List<Cut> _forked() => [_keepOnly(_forkedKeep())];

/// Eight snowmen round a hub, four-fold: on every other fold one waving its
/// arms, on the folds between one with a ring cut through its body.
List<Cut> _snowmen() {
  const h = math.pi / 8;
  // Along the right fold (u) and out from it (v); along the left fold (r)
  // and out from it (t).
  final d = _polar(1, h), n = Offset(-math.cos(h), -math.sin(h));
  final d2 = _polar(1, -h), n2 = Offset(math.cos(h), -math.sin(h));
  Offset a(double u, double v) => d * u + n * v;
  Offset b(double r, double t) => d2 * r + n2 * t;
  // Half a circle on a fold, centred [c] along it, from [from] to [to]
  // degrees off the fold's outward direction.
  Iterable<Offset> arc(Offset Function(double, double) at, double c, double rad, double from, double to) sync* {
    const steps = 10;
    for (var i = 0; i <= steps; i++) {
      final th = (from + (to - from) * i / steps) * math.pi / 180;
      yield at(c + rad * math.cos(th), rad * math.sin(th));
    }
  }

  const hub = .16, spoke = .04;
  final keep = <Offset>[
    Offset.zero,
    // Up the right fold to the top of the waving snowman's hat, then down
    // its side: hat, head, body with a raised arm.
    a(.99, 0), a(.99, .07), a(.91, .07), a(.91, .14), a(.875, .14), a(.865, .085),
    ...arc(a, .76, .115, 30, 150),
    ...arc(a, .52, .165, 22, 55),
    a(.66, .2), a(.71, .215), a(.705, .24), a(.675, .232), a(.69, .265), a(.665, .272), a(.648, .232), a(.6, .21),
    ...arc(a, .52, .165, 80, 165),
    // Its spoke into the hub, round to the other spoke, and up the snowman
    // with the ring: body, head, hat, to its top on the left fold.
    a(.36, spoke), a(hub, spoke), b(hub, spoke), b(.37, spoke),
    ...arc(b, .52, .155, 165, 22),
    ...arc(b, .745, .105, 150, 30),
    b(.845, .13), b(.875, .13), b(.875, .065), b(.95, .065), b(.95, 0),
  ];
  return [_keepOnly(keep), _circle(b(.52, 0), .07, 20)];
}

/// A twelve-pointed star of nested chevrons, six-fold: star outlines one
/// inside another, a point in the middle of every wedge, held together by a
/// spine down each point and a solid star in the middle.
List<Cut> _chevrons() {
  // A star outline scaled by [s]: its point on the wedge's middle, its
  // valleys on the folds (side −1 left, 1 right).
  const tip = .99, valley = .64, spine = .03, band = .075;
  Offset point(double s) => _polar(tip * s, 0);
  Offset valleyAt(double s, int side) => _polar(valley * s, side * _h6);
  // Along the outline from the point towards a valley: where it leaves the
  // spine, and on past the fold (so a cut there runs off the paper).
  Offset offSpine(double s, int side) {
    final p = point(s), v = valleyAt(s, side);
    return p + (v - p) * (spine / v.dx.abs());
  }

  Offset pastFold(double s, int side) {
    final p = point(s), v = valleyAt(s, side);
    return v + (v - p) * .4;
  }

  // Outer edges of the rings, outside in; the last runs into the solid middle.
  const rings = [1.0, .8, .6, .42];
  final cuts = <Cut>[
    // Off the paper beyond the outermost outline.
    [_polar(1.6, -.6), pastFold(1, -1), point(1), pastFold(1, 1), _polar(1.6, .6)],
  ];
  for (var i = 0; i + 1 < rings.length; i++) {
    final a = rings[i] - band, b = rings[i + 1];
    for (final side in const [-1, 1]) {
      cuts.add([offSpine(a, side), pastFold(a, side), pastFold(b, side), offSpine(b, side)]);
    }
  }
  return cuts;
}

Cut _circle(Offset c, double r, [int n = 14]) => [for (var i = 0; i < n; i++) c + Offset(math.cos(i * 2 * math.pi / n), math.sin(i * 2 * math.pi / n)) * r];

// ---- Halloween figures ---------------------------------------------------
//
// Six figures round a ring, six-fold: each stands on the wedge's right fold
// (half of it drawn, the fold mirroring the rest), joined to its neighbours
// by a band round the middle, which is cut out.

/// Along the wedge's right fold (u) and out from it towards the left (v).
Offset _a(double u, double v) => _polar(1, _h6) * u + Offset(-math.cos(_h6), -math.sin(_h6)) * v;

/// [r] out from the middle, [phi] round from the right fold towards the left.
Offset _round(double r, double phi) => _polar(r, _h6 - phi);

/// Half a circle on the right fold, centred [c] along it, from [from] to
/// [to] degrees off the fold's outward direction.
List<Offset> _arc(double c, double rad, double from, double to, [int steps = 12]) => [
      for (var i = 0; i <= steps; i++) _a(c + rad * math.cos((from + (to - from) * i / steps) * math.pi / 180), rad * math.sin((from + (to - from) * i / steps) * math.pi / 180)),
    ];

/// A limb [w] wide along [path] (in wedge units), out on one side and back
/// on the other, to splice into an outline; [out] picks the side to go out on.
List<Offset> _limb(List<Offset> path, double w, {bool out = true}) {
  Offset side(int i) {
    final d = path[math.min(i + 1, path.length - 1)] - path[math.max(i - 1, 0)];
    final n = Offset(-d.dy, d.dx) / d.distance * (w / 2);
    return out ? n : -n;
  }

  return [
    for (var i = 0; i < path.length; i++) path[i] + side(i),
    for (var i = path.length - 1; i >= 0; i--) path[i] - side(i),
  ];
}

/// A figure on the right fold joined into a ring: [half] runs from the top of
/// the figure on the fold down its left side; it is cut short where it first
/// comes inside the ring's outer edge [outer], which carries on round to the
/// left fold, back along the inner edge [inner], and in to the fold.
Cut _onRing(List<Offset> half, {double inner = .25, double outer = .42}) {
  final keep = <Offset>[];
  for (final p in half) {
    if (p.distance < outer && keep.isNotEmpty) break;
    keep.add(p);
  }
  // Where it met the ring, as an angle round from the right fold.
  final last = keep.last;
  final phi = (_h6 - math.atan2(last.dx, -last.dy)).clamp(0.0, 2 * _h6);
  const steps = 8;
  return _keepOnly([
    _round(inner, 0),
    ...keep,
    for (var i = 0; i <= steps; i++) _round(outer, phi + (2 * _h6 - phi) * i / steps),
    for (var i = steps; i >= 0; i--) _round(inner, 2 * _h6 * i / steps),
  ]);
}

/// Jack-o'-lanterns with a stem, triangle eyes and a toothy grin.
List<Cut> _pumpkins() => [
      _onRing([_a(1, 0), _a(1, .05), _a(.955, .055), ..._arc(.64, .32, 12, 178)]),
      [_a(.82, .06), _a(.71, .18), _a(.71, .04)],
      [_a(.6, -.01), _a(.62, .08), _a(.58, .11), _a(.61, .17), _a(.53, .16), _a(.51, .08), _a(.53, -.01)],
    ];

/// Spiders on their legs, three a side, reaching out to their neighbours.
List<Cut> _spiders() => [
      _onRing([
        ..._arc(.76, .15, 0, 105, 8),
        ..._limb([_a(.72, .145), _a(.86, .27), _a(1, .24)], .034),
        ..._limb([_a(.68, .125), _a(.74, .31), _a(.82, .37)], .034),
        ..._limb([_a(.64, .11), _a(.6, .3), _a(.66, .37)], .034),
        ..._arc(.58, .1, 55, 150, 8),
        // A thread down into the ring.
        _a(.46, .04), _a(.36, .04),
      ]),
    ];

/// Bats with pointed ears and scalloped wings.
List<Cut> _bats() => [
      _onRing([
        _a(.9, 0), _a(.98, .06), _a(.88, .09), _a(.82, .07),
        _a(.88, .18), _a(.92, .3), _a(.86, .4),
        _a(.78, .34), _a(.77, .27), _a(.7, .29), _a(.69, .21), _a(.62, .21), _a(.62, .13), _a(.55, .1), _a(.45, .07),
      ]),
    ];

/// Little ghosts, arms out, with round eyes and an "o" of a mouth.
List<Cut> _ghosts() => [
      _onRing([
        ..._arc(.74, .2, 0, 95, 10),
        _a(.68, .25), _a(.7, .36), _a(.63, .37), _a(.62, .22),
        _a(.56, .21), _a(.52, .15), _a(.48, .18), _a(.45, .1), _a(.4, .1),
      ]),
      _circle(_a(.8, .07), .035, 12),
      _circle(_a(.68, 0), .045, 14),
    ];

/// Witches' hats, broad brims round the ring, a band round each.
List<Cut> _hats() => [
      _onRing([_a(.99, 0), _a(.88, .04), _a(.76, .1), _a(.66, .14), _a(.65, .33), _a(.58, .34), _a(.56, .26), _a(.55, .14), _a(.45, .12)]),
      [_a(.69, -.01), _a(.69, .08), _a(.64, .085), _a(.64, -.01)],
    ];

/// A cobweb: threads sagging between spokes on every fold and down the
/// middle of each wedge, with a solid hub and rim.
List<Cut> _web() {
  const rings = [.12, .27, .42, .57, .72, .86, .97];
  const thread = .012, spoke = 1.3 * math.pi / 180;
  final cuts = <Cut>[];
  for (var i = 0; i + 1 < rings.length; i++) {
    final r0 = rings[i] + thread, r1 = rings[i + 1] - thread;
    for (final (a0, a1) in [(-_h6 + spoke, -spoke), (spoke, _h6 - spoke)]) {
      // Threads sag in towards the hub halfway between the spokes.
      double sag(double r, double t) => r * (1 - .06 * math.sin(math.pi * t));
      const steps = 6;
      cuts.add([
        for (var k = 0; k <= steps; k++) _polar(sag(r1, k / steps), a0 + (a1 - a0) * k / steps),
        for (var k = steps; k >= 0; k--) _polar(sag(r0, k / steps), a0 + (a1 - a0) * k / steps),
      ]);
    }
  }
  return cuts;
}

class PaperColor {
  const PaperColor(this.id, this.name, this.color);
  final String id, name;
  final Color color;
}

/// Shown six to a row: pale shades on top, their bold match below, columns
/// in hue order.
const paperColors = [
  PaperColor('white', 'Белая', Color(0xFFFFFFFF)),
  PaperColor('pink', 'Розовая', Color(0xFFFFC7D0)),
  PaperColor('sun', 'Жёлтая', Color(0xFFFFE08A)),
  PaperColor('mint', 'Мятная', Color(0xFFBFF0DC)),
  PaperColor('ice', 'Голубая', Color(0xFFC4ECFF)),
  PaperColor('lilac', 'Сиреневая', Color(0xFFDCD2FF)),
  PaperColor('black', 'Чёрная', Color(0xFF1E1F26)),
  PaperColor('red', 'Красная', Color(0xFFE0405E)),
  PaperColor('orange', 'Оранжевая', Color(0xFFFF9A3C)),
  PaperColor('green', 'Зелёная', Color(0xFF2FB37E)),
  PaperColor('blue', 'Синяя', Color(0xFF3E61B8)),
  PaperColor('violet', 'Фиолетовая', Color(0xFF8A5CD6)),
];

const paperPatterns = [
  ('plain', 'Гладкая'),
  ('dots', 'Горошек'),
  ('stripes', 'Полоски'),
  ('checks', 'Клетка'),
  ('sparkle', 'Блёстки'),
];

double wedgeHalfAngle(int folds) => math.pi / (2 * folds);

/// Stencil polygon in wedge units, for the stencil named [tool]; the names
/// are the cases below.
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
    case 'diamond':
      for (final (a, rr) in const [(-90, 1.0), (0, 0.62), (90, 1.0), (180, 0.62)]) {
        p(a * math.pi / 180, r * rr);
      }
    case 'hexagon':
      for (var i = 0; i < 6; i++) {
        p(-math.pi / 2 + i * math.pi / 3, r);
      }
  }
  return pts;
}

/// Whether a scissors stroke closes on itself, cutting out what it encloses,
/// rather than slitting the paper along an open line.
bool isLoop(List<Offset> stroke) {
  var length = 0.0;
  for (var k = 1; k < stroke.length; k++) {
    length += (stroke[k] - stroke[k - 1]).distance;
  }
  final gap = (stroke.last - stroke.first).distance;
  return gap < 0.08 && gap < length * 0.3;
}

/// A scissors slit along the open [line]: a band [width] wide, its ends
/// stretched by [overshoot] so a slit stopping right at an edge still cuts through.
Cut slit(List<Offset> line, {double width = 0.006, double overshoot = 0.015}) {
  Offset dir(Offset from, Offset to) {
    final d = to - from;
    return d.distance == 0 ? Offset.zero : d / d.distance;
  }

  final n = line.length;
  final pts = [
    line.first - dir(line.first, line[1]) * overshoot,
    ...line,
    line.last + dir(line[n - 2], line.last) * overshoot,
  ];
  final left = <Offset>[], right = <Offset>[];
  for (var k = 0; k < pts.length; k++) {
    // Normal of the chord through the neighbours: smooth along a hand-drawn line.
    final d = dir(pts[math.max(0, k - 1)], pts[math.min(pts.length - 1, k + 1)]);
    final off = Offset(-d.dy, d.dx) * (width / 2);
    left.add(pts[k] + off);
    right.add(pts[k] - off);
  }
  final cut = [...left, ...right.reversed];
  _slitLines[cut] = pts;
  return cut;
}

final _slitLines = Expando<List<Offset>>('slit line');

/// The line a cut made by [slit] runs along, or null for any other cut.
List<Offset>? slitLine(Cut c) => _slitLines[c];

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
  // Navy on light paper, white on dark paper, where navy would vanish.
  final dark = color.computeLuminance() < 0.2;
  final ink = dark ? const Color(0x38FFFFFF) : const Color(0x292E4A94); // rgba(46,74,148,.16)
  final inkLight = dark ? const Color(0x24FFFFFF) : const Color(0x1A2E4A94);
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
      final p = Paint()..color = inkLight;
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
/// [pad] widens the wedge by about s·pad past each fold edge, right down to
/// the apex, so mirrored copies overlap without seams.
void drawWedge(Canvas canvas, double s, List<Cut> cuts, double half, Paint fill, {double pad = 0}) {
  final bounds = Rect.fromCircle(center: Offset.zero, radius: s * 1.3);
  canvas.saveLayer(bounds, Paint());
  final wedge = Path()
    ..moveTo(0, s * pad / math.sin(half))
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
