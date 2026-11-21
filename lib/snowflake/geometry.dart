import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../l10n.dart';

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
  'spiders': _spiders(),
  'bats': _bats(),
  'ghosts': _ghosts(),
  'hats': _hats(),
  'cats': _cats(),
  'zombies': _zombies(),
  // Classic paper flakes, six-fold: arms with side branches on every other
  // fold, a forked one, and nested chevrons.
  'fern': _branched(hole: .27, ring: .40, branches: [.50, .64, .78], lean: .7, reach: .17),
  'starburst': _branched(ring: .30, branches: [.44, .66], lean: 1.0, reach: .21, branch: .075),
  'leafy': _branched(ring: .26, branches: [.38, .56, .74], lean: .45, reach: .23, branch: .08, spine: .08),
  'spiky': _branched(hole: .1, ring: .34, branches: [.50, .72], lean: 1.4, reach: .19, branch: .055),
  'forked': _forked(),
  'chevrons': _chevrons(),
  // Six-fold too, from a paper pattern: a ring of rhombus and square outlines.
  'rhombi': _rhombi(),
  // Christmas pack, four-fold.
  'snowmen': _snowmen(),
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
Cut _keepOnly(List<Offset> keep) => _keepAll([keep]);

/// Everything but the [islands] (closed outlines apart from one another, in
/// wedge units) cut away: one contour round the board, joined to each island
/// in turn, run the other way, by a bridge out from its first corner and back
/// (no width, so it cuts nothing).
Cut _keepAll(List<List<Offset>> islands) {
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
  return [
    for (final keep in islands) ...[
      outer.first,
      ...(area(keep).sign == area(outer).sign ? keep.reversed : keep),
      area(keep).sign == area(outer).sign ? keep.last : keep.first,
    ],
    ...outer,
  ];
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

// ---- Flakes drawn whole, then cut down to a wedge ------------------------

/// Points in a frame [r] out along the direction [phi] (clockwise from the
/// wedge's middle): [u] further out along it, [v] across it clockwise.
Offset Function(double u, double v) _frame(double phi, [double r = 0]) {
  final d = _polar(1, phi), n = Offset(math.cos(phi), math.sin(phi));
  return (u, v) => d * (r + u) + n * v;
}

/// The six directions of the flake's arms (`side` 1, on the wedge's right
/// fold and every 60° on) or of the valleys between them (`side` −1).
Iterable<double> _sixWays(int side) => [for (var k = 0; k < 6; k++) side * _h6 + k * math.pi / 3];

Path _poly(List<Offset> p) => Path()..addPolygon(p, true);

/// A rhombus [r] out along [phi], [along] to its corners out and in, [across]
/// to those at the sides.
List<Offset> _rhombus(double phi, double r, double along, double across) {
  final at = _frame(phi, r);
  return [at(along, 0), at(0, across), at(-along, 0), at(0, -across)];
}

/// [p] shrunk by [w] all round: each edge moved in, the corners where the
/// moved edges meet.
List<Offset> _inset(List<Offset> p, double w) {
  final shape = _poly(p);
  final lines = <(Offset, Offset)>[];
  for (var i = 0; i < p.length; i++) {
    final a = p[i], d = p[(i + 1) % p.length] - a;
    var n = Offset(-d.dy, d.dx) / d.distance;
    if (!shape.contains(a + d / 2 + n * 1e-3)) n = -n;
    lines.add((a + n * w, d));
  }
  return [
    for (var i = 0; i < lines.length; i++)
      () {
        final (a, d) = lines[(i - 1 + lines.length) % lines.length];
        final (b, e) = lines[i];
        final t = ((b.dx - a.dx) * e.dy - (b.dy - a.dy) * e.dx) / (d.dx * e.dy - d.dy * e.dx);
        return a + d * t;
      }(),
  ];
}

/// [outlines] drawn as paper strips [w] wide, run together.
Path _strips(Iterable<List<Offset>> outlines, double w) {
  var paper = Path();
  for (final o in outlines) {
    paper = Path.combine(PathOperation.union, paper, Path.combine(PathOperation.difference, _poly(o), _poly(_inset(o, w))));
  }
  return paper;
}

/// The cuts that leave just [keep] (in wedge units) on a wedge [half] wide
/// each side (the widest it will be cut on): everything round it, and every
/// hole in it.
List<Cut> cutsLeaving(Path keep, {double half = math.pi / 8}) => _keeping(keep, half: half);

/// The cuts that leave just [keep] (a whole flake, in wedge units) on the
/// wedge: everything round it, and every hole in it.
List<Cut> _keeping(Path keep, {double half = _h6}) {
  // Only the wedge matters, and a little past its folds.
  final wedge = _poly([const Offset(0, .1), _polar(1.6, -half - .1), _polar(1.6, half + .1)]);
  final rings = <List<Offset>>[
    for (final m in Path.combine(PathOperation.intersect, keep, wedge).computeMetrics())
      [
        for (var i = 0, n = (m.length / .004).ceil(); i < n; i++) m.getTangentForOffset(i * m.length / n)!.position,
      ],
  ];
  double area(List<Offset> p) {
    var a = 0.0;
    for (var i = 0; i < p.length; i++) {
      a += p[i].dx * p[(i + 1) % p.length].dy - p[(i + 1) % p.length].dx * p[i].dy;
    }
    return a.abs();
  }

  // A ring inside an odd number of others is a hole, cut; the rest are
  // islands of paper, each kept (any number of them, the biggest perhaps off
  // the paper past its rim). An island within a hole is lost with it.
  final shapes = [for (final r in rings) _poly(r)];
  bool inside(int i, int j) => i != j && area(rings[j]) > area(rings[i]) && shapes[j].contains(rings[i].first);
  final islands = <List<Offset>>[], holes = <List<Offset>>[];
  for (var i = 0; i < rings.length; i++) {
    final depth = [for (var j = 0; j < rings.length; j++) if (inside(i, j)) j].length;
    (depth.isEven ? islands : holes).add(_straightened(rings[i]));
  }
  return [_keepAll(islands), ...holes];
}

/// [p] without the points along its straight runs.
List<Offset> _straightened(List<Offset> p) {
  final out = <Offset>[];
  for (var i = 0; i < p.length; i++) {
    final a = out.isEmpty ? p.last : out.last, b = p[i], c = p[(i + 1) % p.length];
    final d = c - a;
    if (((b.dx - a.dx) * d.dy - (b.dy - a.dy) * d.dx).abs() / d.distance > 1e-4) out.add(b);
  }
  return out;
}

/// Rhombus outlines meeting in the middle as a six-pointed star, with square
/// outlines round it: big ones between its points, small ones on them.
List<Cut> _rhombi() => _keeping(_strips([
      for (final phi in _sixWays(1)) _rhombus(phi, .31, .31, .179),
      for (final phi in _sixWays(-1)) _rhombus(phi, .62, .28, .28),
      for (final phi in _sixWays(1)) _rhombus(phi, .78, .17, .17),
    ], .035));

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

/// Cats lying out along the wedge, heads at the rim with both ears pricked
/// out, the back's hump against one fold and the paws against the other, so
/// the cats join up back to back and paw to paw; their tails curl in towards
/// the middle. Traced from a drawing of the wedge lying on its side, the apex
/// at (40, 96) and the rim 326 px away.
List<Cut> _cats() {
  const traced = [
    (82,101), (86,97), (90,94), (94,91), (98,90), (102,89), (110,87), (114,86), (138,84),
    (146,83), (154,83), (170,81), (174,76), (178,67), (182,63), (186,55), (194,53), (198,51),
    (206,49), (210,48), (214,46), (222,47), (226,53), (230,64), (234,68), (250,70), (258,72),
    (270,74), (274,77), (286,80), (294,77), (298,73), (306,70), (310,67), (322,68), (326,72),
    (334,72), (338,71), (342,70), (346,69), (351,70), (346,76), (342,81), (339,86), (339,99),
    (342,112), (346,113), (351,119), (346,122), (342,122), (338,119), (334,120), (326,123), (318,125),
    (310,124), (302,121), (298,118), (290,114), (286,113), (282,116), (274,118), (266,118), (258,121),
    (250,123), (242,125), (234,127), (230,134), (226,140), (222,146), (214,144), (206,139), (198,139),
    (190,137), (182,135), (178,125), (174,117), (170,108), (166,106), (158,104), (150,100), (146,102),
    (138,100), (126,99), (110,99), (102,100), (94,102), (90,108), (86,110), (82,108),
  ];
  return [
    _keepOnly([for (final (x, y) in traced) Offset((y - 96) / 326, -(x - 40) / 326)]),
  ];
}

/// Zombie hands reaching out from a broad ring, one in the middle of every
/// segment: a wrist, a palm, a thumb out to the side and four crooked fingers.
List<Cut> _zombies() {
  const inner = .3, outer = .465;
  // Traced point by point from a drawing of the wedge 690 px from apex to
  // rim, the apex at (205, 735): from the wrist's right up round a little
  // finger splayed to the right, three crooked fingers (up, then bent over to
  // the left at the knuckle) and a thumb out to the left, back down to the
  // wrist.
  const traced = [
    (247, 402), (244, 354), (247, 348), (253, 336), (265, 324), (271, 300), (274, 282), (281, 264),
    (290, 252), (300, 240), (311, 228), (320, 222), (325, 216), (328, 204), (331, 198), (337, 190),
    (343, 184), (343, 180), (310, 180), (307, 186), (304, 198), (299, 204), (292, 210), (283, 216),
    (278, 222), (265, 222), (262, 216), (265, 210), (268, 204), (271, 198), (277, 192), (280, 186),
    (283, 180), (287, 174), (292, 168), (298, 162), (302, 156), (311, 150), (313, 144), (313, 138),
    (310, 132), (307, 126), (305, 120), (301, 114), (298, 108), (296, 102), (290, 96), (286, 90),
    (280, 84), (275, 78), (268, 72), (262, 72), (256, 78), (253, 84), (253, 102), (258, 108),
    (262, 114), (268, 120), (273, 126), (278, 132), (275, 138), (271, 144), (267, 150), (264, 156),
    (261, 162), (259, 168), (256, 174), (253, 180), (250, 186), (247, 192), (244, 198), (240, 206),
    (232, 204), (232, 198), (232, 180), (235, 174), (237, 168), (240, 162), (241, 156), (243, 150),
    (244, 144), (244, 138), (242, 132), (239, 126), (236, 120), (232, 114), (229, 108), (226, 102),
    (223, 96), (220, 90), (217, 84), (212, 78), (205, 72), (195, 78), (190, 84), (190, 96),
    (194, 102), (197, 108), (200, 114), (205, 120), (211, 126), (215, 132), (217, 138), (217, 156),
    (214, 162), (214, 198), (208, 200), (193, 200), (193, 198), (194, 180), (196, 150), (196, 144),
    (193, 138), (190, 132), (184, 126), (178, 120), (172, 114), (168, 108), (163, 102), (142, 102),
    (139, 108), (139, 120), (142, 126), (152, 130), (160, 132), (166, 138), (169, 144), (169, 156),
    (166, 162), (166, 170), (163, 180), (163, 198), (160, 205), (152, 210), (145, 214), (139, 210),
    (133, 204), (127, 200), (118, 196), (115, 192), (76, 192), (73, 198), (73, 204), (85, 210),
    (109, 210), (115, 216), (121, 222), (127, 228), (133, 234), (136, 240), (142, 246), (145, 252),
    (148, 258), (148, 300), (151, 310), (154, 320), (160, 330), (166, 336), (175, 342), (178, 348),
    (178, 402),
  ];
  Offset onRing(double x, double y) {
    final q = Offset((x - 205) / 690, (y - 735) / 690);
    return q / q.distance * (outer - .005);
  }

  final hand = <Offset>[
    onRing(traced.first.$1.toDouble(), traced.first.$2.toDouble()),
    for (final (x, y) in traced) Offset((x - 205) / 690, (y - 735) / 690),
    onRing(traced.last.$1.toDouble(), traced.last.$2.toDouble()),
  ];
  double phiOf(Offset q) => math.atan2(q.dx, -q.dy);
  const steps = 6;
  final right = phiOf(hand.first), left = phiOf(hand.last);
  final keep = <Offset>[
    _polar(inner, _h6),
    for (var i = 0; i <= steps; i++) _polar(outer, _h6 + (right - _h6) * i / steps),
    ...hand,
    for (var i = 0; i <= steps; i++) _polar(outer, left + (-_h6 - left) * i / steps),
    for (var i = 0; i <= steps * 2; i++) _polar(inner, -_h6 + 2 * _h6 * i / (steps * 2)),
  ];
  // A wavy slit across the ring, in from the left fold (traced from a drawing
  // of the wedge 684 px to a unit, the apex at (179, 713)); it unfolds into a
  // wave across each pair of segments.
  const slit = [(95,431), (120,429), (150,433), (170,441), (185,449), (205,450), (218,447), (223,451), (216,458), (195,460), (170,456), (150,446), (120,442), (95,446)];
  return [
    _keepOnly(keep),
    [for (final (x, y) in slit) Offset((x - 179) / 684, (y - 713) / 684)],
  ];
}

class PaperColor {
  const PaperColor(this.id, this.color);
  final String id;
  String get name => tr('color_$id');
  final Color color;
}

/// Shown six to a row, a column per hue, lighter shades above darker ones.
/// Event flakes use these only, so the player can always cut one alike.
const paperColors = [
  PaperColor('white', Color(0xFFFFFFFF)),
  PaperColor('pink', Color(0xFFFFC7D0)),
  PaperColor('sun', Color(0xFFFFE08A)),
  PaperColor('mint', Color(0xFF9DFFAA)),
  PaperColor('ice', Color(0xFFC4ECFF)),
  PaperColor('lilac', Color(0xFFDCD2FF)),
  PaperColor('grey', Color(0xFF9AA3B5)),
  PaperColor('red', Color(0xFFE0405E)),
  PaperColor('orange', Color(0xFFFF9A3C)),
  PaperColor('green', Color(0xFF2FB37E)),
  PaperColor('blue', Color(0xFF0047AB)),
  PaperColor('violet', Color(0xFF8A5CD6)),
  PaperColor('black', Color(0xFF1E1F26)),
  PaperColor('wine', Color(0xFF8E1F3A)),
  PaperColor('brown', Color(0xFF713600)),
  PaperColor('forest', Color(0xFF1E6B4F)),
  PaperColor('navy', Color(0xFF00275F)),
  PaperColor('plum', Color(0xFF4A1A6B)),
];

const paperPatterns = [
  'plain',
  'dots',
  'stripes',
  'checks',
  'sparkle',
  'bubbles',
  'holo',
  'glass',
  'butterflies',
  'knit',
  'gradient',
  'analogous',
  'wrapper',
  'gingerbread',
  'crystal',
  // The advent calendar's (see [adventRewards]).
  'snowfall',
  'candy',
  'garland',
  'tartan',
  // The shop's alone (see [offers]).
  'chocolate',
];

/// Patterns drawn from a seamless texture (dark lines on white) rather than
/// by hand: its asset, loaded into [paperTextures] at launch.
/// Textures shown in their own shades, multiplied over the paper's colour
/// (as drawn on white paper) rather than as ink lines.
const shadedTextures = {'knit'};

const textureAssets = {
  'butterflies': 'assets/materials/butterfly_mat.png',
  'knit': 'assets/materials/knit_mat.png',
};

/// The decoded [textureAssets], by pattern.
final paperTextures = <String, ui.Image>{};

/// Whether paper with [pattern] shimmers over time: glitter's glints
/// twinkling, a hologram's sheen drifting, crystal's flares flashing.
bool shimmers(String pattern) => pattern == 'sparkle' || pattern == 'holo' || pattern == 'crystal';

/// Whether paper with [pattern] has light flashing on its sheet as it
/// shimmers, laid over the paper, segment by segment: glitter's glints,
/// crystal's flares (see [drawSheetGlints]).
bool sheetGlints(String pattern) => pattern == 'sparkle' || pattern == 'crystal';

/// The light flashing on paper with [pattern] at [time] seconds (see
/// [sheetGlints]), in sheet terms (centre at the origin, radius [r]), over
/// [area] of it.
void drawSheetGlints(Canvas canvas, String pattern, Rect area, Color color, double r, double time) {
  if (pattern == 'crystal') {
    drawCrystalFlares(canvas, r, time);
  } else {
    drawGlints(canvas, area, color, r, time);
  }
}

double wedgeHalfAngle(int folds) => math.pi / (2 * folds);

/// Stencil polygon in wedge units, for the stencil named [tool]; the names
/// are the cases below. Only through [stencilParts], which knows those cut
/// in more than one piece too (not here).
Cut _stencilShape(String tool, double cx, double cy, double r) {
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
    case 'bone' || 'hat' || 'bat' || 'jack':
      for (final q in _halloweenStencils[tool]!) {
        pts.add(Offset(cx + q.dx * r, cy + q.dy * r));
      }
    case 'tree' || 'xstar' || 'gift' || 'bell' || 'gingerman' || 'elfhat' || 'angel':
      for (final q in _christmasStencils[tool]!) {
        pts.add(Offset(cx + q.dx * r, cy + q.dy * r));
      }
    case 'snowman' || 'mitten' || 'cane':
      for (final q in _newYearStencils[tool]!) {
        pts.add(Offset(cx + q.dx * r, cy + q.dy * r));
      }
  }
  return pts;
}

/// Stencil [tool]'s outline in parts, each a cut of its own, at [cx], [cy],
/// radius [r] (see [_stencilShape]): one part for most, more for those cut
/// in pieces (see [_stencilParts]), a strip of paper left between them.
List<Cut> stencilParts(String tool, double cx, double cy, double r) {
  final parts = _stencilParts[tool];
  if (parts == null) return [_stencilShape(tool, cx, cy, r)];
  return [
    for (final part in parts) [for (final q in part) Offset(cx + q.dx * r, cy + q.dy * r)],
  ];
}

/// Stencils cut in more than one piece, each piece's outline at radius 1
/// about the origin (y down), all on the same scale.
const Map<String, List<List<Offset>>> _stencilParts = {
  // A bauble, from assets/stencils/stencil_baulbe.svg: its hook, cap and the
  // top of its ball, a star's points notched into it, and below a strip left
  // across it, the bottom of the ball, a star's lower points notched into its
  // top.
  'ornament': [
    [
      Offset(-0.009, -0.950),
      Offset(0.028, -0.930),
      Offset(0.043, -0.907),
      Offset(0.055, -0.876),
      Offset(0.062, -0.841),
      Offset(0.065, -0.802),
      Offset(0.062, -0.764),
      Offset(0.055, -0.729),
      Offset(0.083, -0.729),
      Offset(0.111, -0.721),
      Offset(0.131, -0.701),
      Offset(0.138, -0.673),
      Offset(0.138, -0.606),
      Offset(0.187, -0.596),
      Offset(0.231, -0.583),
      Offset(0.274, -0.569),
      Offset(0.316, -0.552),
      Offset(0.357, -0.532),
      Offset(0.397, -0.510),
      Offset(0.435, -0.487),
      Offset(0.471, -0.461),
      Offset(0.506, -0.433),
      Offset(0.539, -0.403),
      Offset(0.571, -0.371),
      Offset(0.601, -0.338),
      Offset(0.628, -0.303),
      Offset(0.654, -0.266),
      Offset(0.678, -0.228),
      Offset(0.699, -0.188),
      Offset(0.719, -0.148),
      Offset(0.736, -0.105),
      Offset(0.750, -0.062),
      Offset(0.762, -0.018),
      Offset(0.772, 0.028),
      Offset(0.207, 0.028),
      Offset(0.356, -0.208),
      Offset(0.066, -0.025),
      Offset(-0.009, -0.360),
      Offset(-0.085, -0.025),
      Offset(-0.374, -0.208),
      Offset(-0.225, 0.028),
      Offset(-0.772, 0.028),
      Offset(-0.762, -0.018),
      Offset(-0.750, -0.062),
      Offset(-0.736, -0.105),
      Offset(-0.719, -0.148),
      Offset(-0.699, -0.188),
      Offset(-0.678, -0.228),
      Offset(-0.654, -0.266),
      Offset(-0.628, -0.303),
      Offset(-0.601, -0.338),
      Offset(-0.571, -0.371),
      Offset(-0.539, -0.403),
      Offset(-0.506, -0.433),
      Offset(-0.471, -0.461),
      Offset(-0.435, -0.487),
      Offset(-0.397, -0.510),
      Offset(-0.357, -0.532),
      Offset(-0.316, -0.552),
      Offset(-0.274, -0.569),
      Offset(-0.231, -0.583),
      Offset(-0.187, -0.596),
      Offset(-0.157, -0.602),
      Offset(-0.157, -0.673),
      Offset(-0.149, -0.701),
      Offset(-0.129, -0.721),
      Offset(-0.101, -0.729),
      Offset(-0.073, -0.729),
      Offset(-0.080, -0.764),
      Offset(-0.083, -0.802),
      Offset(-0.080, -0.841),
      Offset(-0.073, -0.876),
      Offset(-0.061, -0.907),
      Offset(-0.046, -0.930),
    ],
    [
      Offset(0.783, 0.212),
      Offset(0.778, 0.263),
      Offset(0.770, 0.313),
      Offset(0.759, 0.362),
      Offset(0.745, 0.410),
      Offset(0.729, 0.456),
      Offset(0.709, 0.501),
      Offset(0.687, 0.544),
      Offset(0.662, 0.586),
      Offset(0.635, 0.626),
      Offset(0.605, 0.665),
      Offset(0.573, 0.701),
      Offset(0.539, 0.735),
      Offset(0.503, 0.768),
      Offset(0.465, 0.797),
      Offset(0.425, 0.825),
      Offset(0.383, 0.850),
      Offset(0.340, 0.873),
      Offset(0.295, 0.893),
      Offset(0.249, 0.910),
      Offset(0.201, 0.924),
      Offset(0.153, 0.935),
      Offset(0.103, 0.943),
      Offset(0.052, 0.948),
      Offset(0.000, 0.950),
      Offset(-0.052, 0.948),
      Offset(-0.103, 0.943),
      Offset(-0.153, 0.935),
      Offset(-0.201, 0.924),
      Offset(-0.249, 0.910),
      Offset(-0.295, 0.893),
      Offset(-0.340, 0.873),
      Offset(-0.383, 0.850),
      Offset(-0.425, 0.825),
      Offset(-0.465, 0.797),
      Offset(-0.503, 0.768),
      Offset(-0.539, 0.735),
      Offset(-0.573, 0.701),
      Offset(-0.605, 0.665),
      Offset(-0.635, 0.626),
      Offset(-0.662, 0.586),
      Offset(-0.687, 0.544),
      Offset(-0.709, 0.501),
      Offset(-0.729, 0.456),
      Offset(-0.745, 0.410),
      Offset(-0.759, 0.362),
      Offset(-0.770, 0.313),
      Offset(-0.778, 0.263),
      Offset(-0.783, 0.212),
      Offset(-0.281, 0.212),
      Offset(-0.191, 0.232),
      Offset(-0.374, 0.522),
      Offset(-0.085, 0.339),
      Offset(-0.009, 0.673),
      Offset(0.066, 0.339),
      Offset(0.356, 0.522),
      Offset(0.173, 0.232),
      Offset(0.262, 0.212),
    ],
    ],
};

/// Points round a circle at [c], radius [k], from [from] to [to] degrees
/// (y down, so increasing angles turn clockwise on screen).
List<Offset> _arcPts(Offset c, double k, double from, double to, [int steps = 10]) => [
      for (var i = 0; i <= steps; i++) c + Offset(math.cos((from + (to - from) * i / steps) * math.pi / 180), math.sin((from + (to - from) * i / steps) * math.pi / 180)) * k,
    ];

/// A shape symmetric left to right, from its right [half] (top to bottom, on
/// the middle line at both ends): that, then its mirror back up.
List<Offset> _mirrored(List<Offset> half) => [...half, for (final q in half.reversed.skip(1).take(half.length - 2)) Offset(-q.dx, q.dy)];

/// The advent calendar's stencils (see [adventRewards]): outlines at radius 1
/// about the origin (y down).
final Map<String, List<Offset>> _newYearStencils = {
  // A snowman, from assets/stencils/stencil_snowman.svg: a top hat, a
  // round head and a round body under it.
  'snowman': const [
Offset(0.270, -0.950),
    Offset(0.293, -0.929),
    Offset(0.288, -0.889),
    Offset(0.283, -0.854),
    Offset(0.278, -0.816),
    Offset(0.273, -0.777),
    Offset(0.268, -0.737),
    Offset(0.263, -0.698),
    Offset(0.258, -0.662),
    Offset(0.254, -0.630),
    Offset(0.249, -0.590),
    Offset(0.263, -0.562),
    Offset(0.294, -0.562),
    Offset(0.325, -0.562),
    Offset(0.357, -0.561),
    Offset(0.380, -0.541),
    Offset(0.386, -0.511),
    Offset(0.380, -0.481),
    Offset(0.357, -0.460),
    Offset(0.324, -0.460),
    Offset(0.330, -0.417),
    Offset(0.342, -0.386),
    Offset(0.352, -0.353),
    Offset(0.358, -0.320),
    Offset(0.362, -0.286),
    Offset(0.364, -0.253),
    Offset(0.363, -0.220),
    Offset(0.359, -0.188),
    Offset(0.353, -0.158),
    Offset(0.339, -0.116),
    Offset(0.334, -0.086),
    Offset(0.355, -0.062),
    Offset(0.371, -0.033),
    Offset(0.379, -0.001),
    Offset(0.383, 0.032),
    Offset(0.385, 0.062),
    Offset(0.393, 0.095),
    Offset(0.416, 0.123),
    Offset(0.440, 0.156),
    Offset(0.460, 0.186),
    Offset(0.479, 0.219),
    Offset(0.496, 0.253),
    Offset(0.508, 0.285),
    Offset(0.516, 0.316),
    Offset(0.523, 0.350),
    Offset(0.528, 0.387),
    Offset(0.531, 0.425),
    Offset(0.531, 0.464),
    Offset(0.529, 0.503),
    Offset(0.523, 0.541),
    Offset(0.509, 0.593),
    Offset(0.489, 0.646),
    Offset(0.464, 0.695),
    Offset(0.434, 0.742),
    Offset(0.399, 0.784),
    Offset(0.359, 0.823),
    Offset(0.315, 0.857),
    Offset(0.266, 0.887),
    Offset(0.214, 0.911),
    Offset(0.157, 0.930),
    Offset(0.097, 0.943),
    Offset(0.065, 0.947),
    Offset(0.033, 0.949),
    Offset(0.000, 0.950),
    Offset(-0.033, 0.949),
    Offset(-0.065, 0.947),
    Offset(-0.097, 0.943),
    Offset(-0.127, 0.937),
    Offset(-0.186, 0.921),
    Offset(-0.240, 0.899),
    Offset(-0.291, 0.873),
    Offset(-0.337, 0.841),
    Offset(-0.379, 0.804),
    Offset(-0.417, 0.764),
    Offset(-0.450, 0.719),
    Offset(-0.477, 0.671),
    Offset(-0.500, 0.620),
    Offset(-0.517, 0.566),
    Offset(-0.525, 0.529),
    Offset(-0.530, 0.490),
    Offset(-0.531, 0.451),
    Offset(-0.530, 0.412),
    Offset(-0.526, 0.375),
    Offset(-0.521, 0.339),
    Offset(-0.513, 0.305),
    Offset(-0.505, 0.276),
    Offset(-0.491, 0.241),
    Offset(-0.473, 0.208),
    Offset(-0.454, 0.176),
    Offset(-0.434, 0.147),
    Offset(-0.410, 0.116),
    Offset(-0.390, 0.092),
    Offset(-0.385, 0.057),
    Offset(-0.382, 0.026),
    Offset(-0.379, -0.005),
    Offset(-0.369, -0.039),
    Offset(-0.352, -0.066),
    Offset(-0.330, -0.089),
    Offset(-0.344, -0.130),
    Offset(-0.356, -0.173),
    Offset(-0.361, -0.204),
    Offset(-0.363, -0.236),
    Offset(-0.363, -0.270),
    Offset(-0.361, -0.303),
    Offset(-0.355, -0.337),
    Offset(-0.347, -0.369),
    Offset(-0.336, -0.401),
    Offset(-0.323, -0.431),
    Offset(-0.306, -0.460),
    Offset(-0.340, -0.460),
    Offset(-0.371, -0.467),
    Offset(-0.385, -0.498),
    Offset(-0.384, -0.530),
    Offset(-0.367, -0.557),
    Offset(-0.333, -0.562),
    Offset(-0.298, -0.562),
    Offset(-0.265, -0.562),
    Offset(-0.267, -0.602),
    Offset(-0.270, -0.645),
    Offset(-0.272, -0.680),
    Offset(-0.274, -0.718),
    Offset(-0.276, -0.757),
    Offset(-0.279, -0.797),
    Offset(-0.283, -0.835),
    Offset(-0.286, -0.872),
    Offset(-0.290, -0.905),
    Offset(-0.292, -0.936),
    Offset(-0.247, -0.950),
    Offset(-0.202, -0.950),
    Offset(-0.157, -0.950),
    Offset(-0.112, -0.950),
    Offset(-0.067, -0.950),
    Offset(-0.022, -0.950),
    Offset(0.023, -0.950),
    Offset(0.068, -0.950),
    Offset(0.112, -0.950),
    Offset(0.157, -0.950),
    Offset(0.202, -0.950),
    Offset(0.247, -0.950),
  ],
  // A mitten, its thumb out to the left, on a cuff.
  'mitten': const [
    Offset(-.4, .92),
    Offset(.4, .92),
    Offset(.4, .6),
    Offset(.5, .3),
    Offset(.52, -.1),
    Offset(.46, -.48),
    Offset(.3, -.78),
    Offset(.06, -.92),
    Offset(-.18, -.86),
    Offset(-.34, -.62),
    Offset(-.4, -.3),
    Offset(-.52, -.42),
    Offset(-.7, -.38),
    Offset(-.8, -.18),
    Offset(-.72, .04),
    Offset(-.5, .28),
    Offset(-.4, .6),
  ],
  // A candy cane: a straight stick, hooked over to the left at the top,
  // both its ends rounded off.
  'cane': [
    const Offset(.49, .81),
    ..._arcPts(const Offset(0, -.35), .49, 0, -180, 16),
    ..._arcPts(const Offset(-.35, -.1), .14, 180, 0, 8),
    ..._arcPts(const Offset(0, -.35), .21, -180, 0, 10),
    const Offset(.21, .81),
    ..._arcPts(const Offset(.35, .81), .14, 180, 0, 8),
  ],
};

/// Christmas stencil outlines at radius 1 about the origin (y down).
final Map<String, List<Offset>> _christmasStencils = {
  // An angel, from assets/stencils/stencil_angel.svg: a round head, wings
  // spread wide either side, a long robe flaring to its hem.
  'angel': const [
Offset(-0.000, -0.950),
    Offset(0.049, -0.947),
    Offset(0.096, -0.938),
    Offset(0.141, -0.923),
    Offset(0.187, -0.898),
    Offset(0.227, -0.863),
    Offset(0.255, -0.824),
    Offset(0.275, -0.783),
    Offset(0.293, -0.734),
    Offset(0.306, -0.681),
    Offset(0.313, -0.630),
    Offset(0.311, -0.582),
    Offset(0.295, -0.529),
    Offset(0.270, -0.479),
    Offset(0.246, -0.438),
    Offset(0.301, -0.478),
    Offset(0.358, -0.513),
    Offset(0.416, -0.539),
    Offset(0.477, -0.560),
    Offset(0.540, -0.579),
    Offset(0.604, -0.599),
    Offset(0.669, -0.623),
    Offset(0.713, -0.643),
    Offset(0.753, -0.673),
    Offset(0.788, -0.712),
    Offset(0.821, -0.753),
    Offset(0.868, -0.767),
    Offset(0.901, -0.730),
    Offset(0.911, -0.678),
    Offset(0.914, -0.628),
    Offset(0.908, -0.579),
    Offset(0.895, -0.533),
    Offset(0.872, -0.490),
    Offset(0.839, -0.454),
    Offset(0.867, -0.408),
    Offset(0.878, -0.360),
    Offset(0.868, -0.312),
    Offset(0.839, -0.265),
    Offset(0.801, -0.235),
    Offset(0.759, -0.208),
    Offset(0.717, -0.184),
    Offset(0.729, -0.136),
    Offset(0.732, -0.088),
    Offset(0.708, -0.046),
    Offset(0.659, -0.023),
    Offset(0.602, -0.006),
    Offset(0.553, 0.008),
    Offset(0.503, 0.022),
    Offset(0.484, 0.070),
    Offset(0.474, 0.117),
    Offset(0.453, 0.170),
    Offset(0.422, 0.214),
    Offset(0.384, 0.251),
    Offset(0.359, 0.297),
    Offset(0.373, 0.350),
    Offset(0.387, 0.399),
    Offset(0.403, 0.456),
    Offset(0.420, 0.517),
    Offset(0.438, 0.579),
    Offset(0.455, 0.639),
    Offset(0.471, 0.695),
    Offset(0.485, 0.742),
    Offset(0.499, 0.790),
    Offset(0.492, 0.838),
    Offset(0.443, 0.863),
    Offset(0.393, 0.884),
    Offset(0.346, 0.902),
    Offset(0.297, 0.918),
    Offset(0.250, 0.929),
    Offset(0.196, 0.937),
    Offset(0.144, 0.943),
    Offset(0.089, 0.947),
    Offset(0.032, 0.950),
    Offset(-0.022, 0.950),
    Offset(-0.078, 0.948),
    Offset(-0.134, 0.944),
    Offset(-0.187, 0.939),
    Offset(-0.234, 0.932),
    Offset(-0.285, 0.921),
    Offset(-0.334, 0.906),
    Offset(-0.382, 0.889),
    Offset(-0.425, 0.871),
    Offset(-0.471, 0.851),
    Offset(-0.504, 0.816),
    Offset(-0.491, 0.761),
    Offset(-0.472, 0.695),
    Offset(-0.456, 0.639),
    Offset(-0.439, 0.579),
    Offset(-0.421, 0.517),
    Offset(-0.403, 0.456),
    Offset(-0.387, 0.399),
    Offset(-0.374, 0.350),
    Offset(-0.360, 0.297),
    Offset(-0.385, 0.251),
    Offset(-0.423, 0.214),
    Offset(-0.450, 0.177),
    Offset(-0.472, 0.127),
    Offset(-0.484, 0.076),
    Offset(-0.482, 0.029),
    Offset(-0.531, 0.014),
    Offset(-0.578, 0.001),
    Offset(-0.627, -0.013),
    Offset(-0.676, -0.029),
    Offset(-0.717, -0.056),
    Offset(-0.735, -0.101),
    Offset(-0.725, -0.150),
    Offset(-0.740, -0.197),
    Offset(-0.780, -0.221),
    Offset(-0.821, -0.249),
    Offset(-0.857, -0.288),
    Offset(-0.876, -0.336),
    Offset(-0.876, -0.384),
    Offset(-0.856, -0.431),
    Offset(-0.865, -0.481),
    Offset(-0.890, -0.522),
    Offset(-0.906, -0.567),
    Offset(-0.914, -0.616),
    Offset(-0.913, -0.666),
    Offset(-0.905, -0.715),
    Offset(-0.883, -0.757),
    Offset(-0.836, -0.767),
    Offset(-0.804, -0.731),
    Offset(-0.772, -0.692),
    Offset(-0.734, -0.656),
    Offset(-0.691, -0.632),
    Offset(-0.648, -0.614),
    Offset(-0.583, -0.592),
    Offset(-0.519, -0.573),
    Offset(-0.457, -0.554),
    Offset(-0.397, -0.531),
    Offset(-0.339, -0.502),
    Offset(-0.283, -0.464),
    Offset(-0.247, -0.431),
    Offset(-0.271, -0.479),
    Offset(-0.295, -0.529),
    Offset(-0.312, -0.582),
    Offset(-0.314, -0.630),
    Offset(-0.307, -0.681),
    Offset(-0.294, -0.734),
    Offset(-0.276, -0.783),
    Offset(-0.255, -0.824),
    Offset(-0.227, -0.863),
    Offset(-0.188, -0.898),
    Offset(-0.141, -0.923),
    Offset(-0.096, -0.938),
    Offset(-0.050, -0.947),
  ],
  // An elf's hat, from assets/stencils/stencil_elf_hat.svg: a brim at the
  // foot, its tip flopping over to the right with a bobble on it.
  'elfhat': const [
Offset(-0.950, 0.270),
    Offset(-0.862, 0.371),
    Offset(-0.858, 0.294),
    Offset(-0.852, 0.219),
    Offset(-0.843, 0.147),
    Offset(-0.833, 0.078),
    Offset(-0.820, 0.011),
    Offset(-0.805, -0.054),
    Offset(-0.787, -0.115),
    Offset(-0.767, -0.174),
    Offset(-0.745, -0.231),
    Offset(-0.720, -0.285),
    Offset(-0.693, -0.337),
    Offset(-0.663, -0.386),
    Offset(-0.630, -0.432),
    Offset(-0.595, -0.477),
    Offset(-0.557, -0.518),
    Offset(-0.516, -0.558),
    Offset(-0.473, -0.594),
    Offset(-0.426, -0.629),
    Offset(-0.377, -0.661),
    Offset(-0.324, -0.691),
    Offset(-0.268, -0.718),
    Offset(-0.210, -0.743),
    Offset(-0.148, -0.765),
    Offset(-0.083, -0.785),
    Offset(-0.002, -0.803),
    Offset(0.067, -0.812),
    Offset(0.144, -0.817),
    Offset(0.229, -0.818),
    Offset(0.317, -0.812),
    Offset(0.407, -0.798),
    Offset(0.497, -0.776),
    Offset(0.584, -0.744),
    Offset(0.666, -0.700),
    Offset(0.741, -0.644),
    Offset(0.806, -0.575),
    Offset(0.850, -0.509),
    Offset(0.878, -0.458),
    Offset(0.902, -0.407),
    Offset(0.921, -0.355),
    Offset(0.942, -0.276),
    Offset(0.950, -0.194),
    Offset(0.945, -0.111),
    Offset(0.934, -0.055),
    Offset(0.915, 0.002),
    Offset(0.890, 0.060),
    Offset(0.931, 0.123),
    Offset(0.948, 0.196),
    Offset(0.938, 0.270),
    Offset(0.905, 0.336),
    Offset(0.850, 0.387),
    Offset(0.781, 0.416),
    Offset(0.707, 0.419),
    Offset(0.635, 0.397),
    Offset(0.576, 0.351),
    Offset(0.536, 0.288),
    Offset(0.521, 0.215),
    Offset(0.531, 0.142),
    Offset(0.566, 0.076),
    Offset(0.621, 0.026),
    Offset(0.691, -0.002),
    Offset(0.765, -0.004),
    Offset(0.754, -0.099),
    Offset(0.729, -0.201),
    Offset(0.693, -0.285),
    Offset(0.648, -0.353),
    Offset(0.595, -0.403),
    Offset(0.536, -0.434),
    Offset(0.471, -0.447),
    Offset(0.403, -0.439),
    Offset(0.333, -0.411),
    Offset(0.262, -0.361),
    Offset(0.191, -0.289),
    Offset(0.156, -0.245),
    Offset(0.137, -0.167),
    Offset(0.127, -0.094),
    Offset(0.126, -0.023),
    Offset(0.136, 0.047),
    Offset(0.157, 0.121),
    Offset(0.178, 0.173),
    Offset(0.204, 0.228),
    Offset(0.235, 0.286),
    Offset(0.273, 0.350),
    Offset(0.407, 0.283),
    Offset(0.407, 0.685),
    Offset(0.344, 0.706),
    Offset(0.282, 0.726),
    Offset(0.222, 0.744),
    Offset(0.164, 0.759),
    Offset(0.108, 0.773),
    Offset(0.053, 0.785),
    Offset(-0.054, 0.803),
    Offset(-0.158, 0.814),
    Offset(-0.261, 0.818),
    Offset(-0.364, 0.814),
    Offset(-0.468, 0.802),
    Offset(-0.576, 0.784),
    Offset(-0.632, 0.772),
    Offset(-0.690, 0.758),
    Offset(-0.749, 0.742),
    Offset(-0.809, 0.725),
    Offset(-0.872, 0.706),
    Offset(-0.937, 0.685),
  ],
  // A gingerbread man: a round head, arms out straight with round ends, and
  // legs apart on round feet.
  'gingerman': _mirrored([
    ..._arcPts(const Offset(0, -.62), .3, -90, 50, 12),
    const Offset(.16, -.32),
    const Offset(.7, -.3),
    ..._arcPts(const Offset(.72, -.17), .13, -90, 90, 8),
    const Offset(.3, -.02),
    const Offset(.34, .3),
    const Offset(.53, .79),
    ..._arcPts(const Offset(.4, .84), .14, -20, 160, 8),
    const Offset(.12, .45),
    const Offset(0, .38),
  ]),
  // A fir tree: three tiers, each wider than the one above, on a trunk.
  'tree': _mirrored(const [
    Offset(0, -1),
    Offset(.36, -.5),
    Offset(.18, -.5),
    Offset(.56, -.04),
    Offset(.32, -.04),
    Offset(.76, .5),
    Offset(.15, .5),
    Offset(.15, .86),
    Offset(0, .86),
  ]),
  // A Christmas star: four long rays, the lowest longest, and four short
  // ones between.
  'xstar': [
    for (var i = 0; i < 16; i++)
      () {
        final a = -math.pi / 2 + i * math.pi / 8;
        final k = switch (i) { 0 => .86, 4 || 12 => .72, 8 => 1.0, _ when i.isEven => .44, _ => .22 };
        return Offset(math.cos(a), math.sin(a)) * k;
      }(),
  ],
  // A gift box: the box, its lid a little wider, and a bow of two loops on top.
  'gift': _mirrored(const [
    Offset(0, -.5),
    Offset(.35, -.95),
    Offset(.52, -.9),
    Offset(.48, -.72),
    Offset(.12, -.45),
    Offset(.85, -.45),
    Offset(.85, -.2),
    Offset(.75, -.2),
    Offset(.75, .85),
    Offset(0, .85),
  ]),
  // A bell: a loop on top, the dome flaring out to a rim, the clapper below.
  'bell': _mirrored(const [
    Offset(0, -.94),
    Offset(.1, -.94),
    Offset(.12, -.8),
    Offset(.32, -.74),
    Offset(.46, -.56),
    Offset(.52, -.3),
    Offset(.56, 0),
    Offset(.64, .24),
    Offset(.8, .42),
    Offset(.88, .58),
    Offset(.2, .58),
    Offset(.17, .72),
    Offset(.08, .82),
    Offset(0, .84),
  ]),
};

/// Halloween stencil outlines at radius 1 about the origin (y down).
final Map<String, List<Offset>> _halloweenStencils = {
  // A bone standing upright: a shaft with two round knobs at each end.
  'bone': () {
    // Knobs [k] round at (±a, ±b), the shaft [w] either side of the middle.
    const a = .2, b = .66, k = .27, w = .15;
    final y = b - math.sqrt(k * k - (w - a) * (w - a));
    final notch = b + math.sqrt(k * k - a * a);
    double deg(Offset c, Offset q) => math.atan2(q.dy - c.dy, q.dx - c.dx) * 180 / math.pi;
    // Each knob from where it meets the shaft (or the notch between the two)
    // round its outside, turning the same way all through.
    List<Offset> knob(Offset c, Offset from, Offset to) {
      final a0 = deg(c, from), a1 = deg(c, to);
      return _arcPts(c, k, a0, a1 >= a0 ? a1 - 360 : a1, 14);
    }

    return [
      ...knob(const Offset(a, -b), Offset(w, -y), Offset(0, -notch)),
      ...knob(const Offset(-a, -b), Offset(0, -notch), Offset(-w, -y)),
      ...knob(const Offset(-a, b), Offset(-w, y), Offset(0, notch)),
      ...knob(const Offset(a, b), Offset(0, notch), Offset(w, y)),
    ];
  }(),
  // A witch's hat: a broad brim, the crown leaning over to the right.
  'hat': [
    for (var i = 0; i <= 12; i++) Offset(math.cos(i * math.pi / 12), .5 + .17 * math.sin(i * math.pi / 12)),
    const Offset(-.88, .42),
    const Offset(-.5, .38),
    const Offset(-.4, .05),
    const Offset(-.22, -.45),
    const Offset(.05, -.78),
    const Offset(.42, -.92),
    const Offset(.72, -.88),
    const Offset(.4, -.66),
    const Offset(.3, -.35),
    const Offset(.36, .05),
    const Offset(.48, .38),
    const Offset(.88, .42),
  ],
  // A bat, wings spread: pointed ears, scalloped wings, a pointed tail.
  'bat': () {
    const half = [
      Offset(0, -.33),
      Offset(.06, -.38),
      Offset(.13, -.52),
      Offset(.16, -.3),
      Offset(.17, -.2),
      Offset(.3, -.17),
      Offset(.45, -.22),
      Offset(.62, -.46),
      Offset(.78, -.2),
      Offset(.98, .14),
      Offset(.84, .1),
      Offset(.7, .11),
      Offset(.6, .14),
      Offset(.52, .26),
      Offset(.43, .2),
      Offset(.32, .17),
      Offset(.21, .2),
      Offset(.12, .3),
      Offset(0, .5),
    ];
    return [...half, for (final q in half.reversed.skip(1).take(half.length - 2)) Offset(-q.dx, q.dy)];
  }(),
  // A jack-o'-lantern's face: two eyes and a toothy grin, one outline joined
  // by bridges run out and back (they cancel out under the non-zero rule).
  'jack': () {
    const eyeL = [Offset(-.72, -.12), Offset(-.34, -.74), Offset(-.18, -.1), Offset(-.45, -.04)];
    final eyeR = [for (final q in eyeL.reversed) Offset(-q.dx, q.dy)];
    double bottom(double x) => .05 + .62 * math.sqrt(math.max(0, 1 - (x / .95) * (x / .95)));
    final mouth = <Offset>[
      for (var i = 0; i <= 8; i++) Offset(-.95 + 1.9 * i / 8, .05 + .12 * math.sin(math.pi * i / 8)),
      for (var i = 0; i <= 18; i++) ...() {
        final x = .95 - 1.9 * i / 18;
        // Teeth: three notches up from the bottom edge.
        if (i == 5 || i == 9 || i == 13) return [Offset(x + .09, bottom(x + .09)), Offset(x, bottom(x) - .3), Offset(x - .09, bottom(x - .09))];
        return [Offset(x, bottom(x))];
      }(),
    ];
    return [...eyeL, eyeL.first, ...mouth, mouth.first, ...eyeR, eyeR.first, mouth.first];
  }(),
};

/// Whether a scissors stroke closes on itself, cutting out what it encloses,
/// rather than slitting the paper along an open line.
// ---- Cutting by hand: how strokes become cuts -----------------------------
// All lengths in wedge units: 1 is the wedge's radius, apex to rim.

/// A finger's stroke takes a new point once it has moved this far from the
/// last: smaller follows curves more closely, with more points to a cut.
/// Unzoomed: zoomed in, it shrinks with the zoom, so a finger's move on the
/// screen counts the same.
const cutPointStep = 0.005;

/// Strokes of no more points than this are taps, not cuts, and are dropped.
const cutMinPoints = 3;

/// A stroke closes into a loop (its inside cut away) when its ends are
/// closer than this (unzoomed; zoomed in, it shrinks with the zoom)...
const loopMaxGap = 0.08;

/// ...and closer than this share of the stroke's length, so a short flick
/// with its ends near isn't taken for one.
const loopMaxGapShare = 0.3;

/// An open stroke is cut as a slit this wide...
const slitWidth = 0.006;

/// ...its ends stretched this far on, so a slit stopping right at an edge
/// still cuts through it (unzoomed; zoomed in, it shrinks with the zoom).
const slitOvershoot = 0.01;

bool isLoop(List<Offset> stroke, {double maxGap = loopMaxGap}) {
  var length = 0.0;
  for (var k = 1; k < stroke.length; k++) {
    length += (stroke[k] - stroke[k - 1]).distance;
  }
  final gap = (stroke.last - stroke.first).distance;
  return gap < maxGap && gap < length * loopMaxGapShare;
}

/// A scissors slit along the open [line]: a band [width] wide, its ends
/// stretched by [overshoot] so a slit stopping right at an edge still cuts through.
Cut slit(List<Offset> line, {double width = slitWidth, double overshoot = slitOvershoot}) {
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

/// How many bytes the tiles in [_tileCache] take, and the most they may:
/// past that the oldest go, so heavy patterns zoomed and recoloured can't
/// pile up.
var _tileBytes = 0;
const _tileBudget = 24 << 20;

/// How much of the screen's own sharpness a tile is drawn at (see
/// [makePaperFill]): half its pixels across, a quarter of the memory, and
/// still far crisper than one drawn in logical pixels.
const _tileSharpness = .5;

/// Paint for the paper: plain colour or a repeating pattern tile. unitPx =
/// paper radius in px; [dpr] the screen's pixels to each of those, a tile
/// being drawn at [_tileSharpness] of them (never fewer than one to each)
/// so it stays sharp (1 where unitPx is in them already).
Paint makePaperFill(Color color, String pattern, double unitPx, {double dpr = 1}) {
  // Gingerbread is its own brown: one tile for it, whatever colour is picked.
  if (pattern == 'gingerbread') color = gingerbreadColor;
  final paint = Paint()..color = color;
  // Crystal's facets are laid over its colour (see [drawCrystalFacets]).
  if (pattern == 'plain' || pattern == 'crystal') return paint;
  // Tinted glass, as see-through as its colour is light: white glass all but
  // clear, dark glass rich. Its glints fall on it from outside (see
  // [drawGlassGlints]).
  if (pattern == 'glass') return paint..color = glassTint(color).withValues(alpha: glassOpacity(color));
  // Gift wrap: its colour, glowing in the middle of the sheet and darker
  // towards its edge (see [wrapperEdge]); its gold laid on separately (see
  // [wrapperGoldLayer] and [drawWedge]).
  if (pattern == 'wrapper') return paint..shader = ui.Gradient.radial(Offset.zero, unitPx, [color, color, wrapperEdge(color)], [0, wrapperFadeFrom, 1]);
  // Gradients from the top of the sheet to the bottom, across the whole
  // unfolded flake, round the hues (as light and saturated all the way, not
  // straight through to a dull grey): see [gradientHues].
  if (gradientHues[pattern] case (final from, final to)) {
    final hsl = HSLColor.fromColor(color);
    const steps = 6;
    // Colours with no hue to turn round run to another colour instead (see
    // [_gradientTo]): out to either end (theirs in the middle) for the
    // gradient, the whole way for hues.
    final target = _gradientTo[color.toARGB32()];
    Color at(double t) => target != null
        ? Color.lerp(color, target, pattern == 'gradient' ? (2 * t - 1).abs() : t)!
        : hsl.withHue((hsl.hue + from + (to - from) * t) % 360).toColor();
    final colors = [for (var i = 0; i <= steps; i++) at(i / steps)];
    return paint..shader = ui.Gradient.linear(Offset(0, -unitPx), Offset(0, unitPx), colors, [for (var i = 0; i <= steps; i++) i / steps]);
  }
  // Scattered patterns get big tiles, so they don't visibly repeat.
  final t = switch (pattern) {
    'sparkle' => sparkleTile(unitPx),
    'bubbles' => sparkleTile(unitPx) * 2.5 * 1.3,
    'gingerbread' => sparkleTile(unitPx),
    // Snowfall's flakes a tenth bigger than the garland's tile.
    'snowfall' => math.max(30.8, unitPx * .44),
    'garland' => math.max(28.0, unitPx * .4),
    'candy' => math.max(24.0, unitPx * .28),
    'tartan' => math.max(20.0, unitPx * .25),
    // One square of a chocolate bar: a few across the paper, chunky.
    'chocolate' => math.max(24.0, unitPx * .25),
    // One hologram cell: a big burst with small ones at its corners.
    'holo' => math.max(16.0, unitPx * .3),
    // A texture's tile: a few across the paper, so its motifs read; the
    // knit's stitches a fifth bigger still.
    'knit' => math.max(43.2, unitPx * 1.08),
    // Gift wrap: a few gold loops across the paper, as on the real thing.
    wrapperGoldLayer => math.max(36.0, unitPx * .6),
    _ when textureAssets.containsKey(pattern) => math.max(36.0, unitPx * .9),
    _ => math.max(8.0, unitPx * 0.075),
  };
  // Drawn, nearly in the screen's pixels (see [_tileSharpness]), at the
  // nearest of a few sizes and scaled to fit, so zooming the board in and
  // out reuses a handful of tiles instead of making new ones.
  final px = t * math.max(1.0, dpr * _tileSharpness);
  final tq = math.pow(1.25, (math.log(px) / math.log(1.25)).round()).round();
  final key = (color, pattern, tq);
  var img = _tileCache.remove(key);
  if (img == null) {
    img = _tile(color, pattern, tq.toDouble());
    _tileBytes += img.width * img.height * 4;
    // The oldest go, within the budget and never more than 48: dropped, not
    // disposed, as a shader may still hold one.
    while (_tileCache.isNotEmpty && (_tileBytes > _tileBudget || _tileCache.length >= 48)) {
      final old = _tileCache.remove(_tileCache.keys.first)!;
      _tileBytes -= old.width * old.height * 4;
    }
  }
  _tileCache[key] = img;
  final k = t / tq;
  return paint..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, Float64List.fromList([k, 0, 0, 0, 0, k, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      // Smooth, as the tile is scaled a little.
      filterQuality: FilterQuality.medium);
}

/// How wide chocolate paper's squares' sloping sides are, as a share of
/// their tile.
const _chocolateBevel = .13;

/// How much chocolate paper's lit sides lose of their colour's fullness for
/// each step lighter: at .16 lighter (the top side), 16% × this.
const _chocolateDull = 3.0;

/// Gingerbread paper's own brown, whatever colour is picked (that one goes
/// to its icing, see [drawWedge]).
const gingerbreadColor = Color(0xFFC46A30);

/// Gingerbread's darker crumbs, in these browns.
const gingerbreadCrumbs = [ui.Color.fromARGB(255, 165, 91, 41), ui.Color.fromARGB(255, 126, 58, 14)];

/// The gold of gift wrap's strings and stars.
const wrapperGold = Color(0xFFF2C14E);

/// Gift wrap's gold's outline: the gold, darker, on paper of any colour.
const wrapperOutline = Color(0xFF8A5A00);

/// How far out from the middle of the sheet gift wrap starts to darken
/// (see [wrapperEdge]), as a share of its radius: 0 at once, 1 not at all.
const wrapperFadeFrom = .3;

/// Gift wrap's colour at the edge of the sheet, running in to the colour
/// itself in the middle: the same hue, deeper (darker, and fuller rather
/// than greyed, as mixing in black would leave it). Light paper (the
/// palette's pastels and white) goes less dark and softer instead: deepened
/// as the rest is, its pastels would turn loud.
Color wrapperEdge(Color color) {
  final hsl = HSLColor.fromColor(color);
  final light = hsl.lightness > .7;
  return hsl.withLightness(hsl.lightness * (light ? .82 : .7)).withSaturation(math.min(1, hsl.saturation * (light ? .55 : 1.15))).toColor();
}

/// The pattern of gift wrap's gold alone, on nothing, to lay over its paper.
const wrapperGoldLayer = 'wrapperGold';

/// How thick gift wrap's gold's outline is (see [wrapperOutline]): its
/// stroke, half of it showing outside the gold, as a share of its tile.
const _wrapperOutline = .008;

/// How close gift wrap's bead strings may come to one another, as a
/// share of its tile.
const _wrapperStringGap = .08;

/// Candy paper's stripes, as shares of its tile: the broad ones' width and
/// the thin ones', and how far across each its white glow runs; how far
/// towards white the glow pales its edge.
const _candyLight = .6;
const _candyBroad = .38, _candyThin = .045, _candyGlow = .4;

/// The gradient patterns, by the hues they run between, in degrees from the
/// paper's own: to its complement (half round), or its analogous neighbours
/// (30° either side, through the paper's colour in the middle).
const gradientHues = {'gradient': (0.0, 180.0), 'analogous': (-30.0, 30.0)};

/// What paper with no hue to turn round runs to in its gradients, by its
/// colour: white to the palette's light blue (ice), black to its red.
const _gradientTo = {
  0xFFFFFFFF: Color(0xFFC4ECFF),
  0xFF1E1F26: Color(0xFFE0405E),
};

/// Side of the glitter pattern's tile, for paper [unitPx] in radius: four
/// times the other patterns', so its dots don't visibly repeat. In step with
/// the paper, not rounded: zooming, the pattern grows with it, never slides.
double sparkleTile(double unitPx) => math.max(32.0, unitPx * .3);

/// Glitter's dots to a tile, however many px it is: zoomed in, the same
/// dots grow, as on real paper, rather than more coming.
const _sparkleDots = 1600;

/// The twinkling glints of glitter paper, in one tile [t] across: where each
/// sits, how big it is, and when in its own cycle it flashes.
/// The glints of one tile, as shares of its side: the same few on every tile,
/// whatever its size in px, so as many to the sheet on the big folded wedge
/// as on a small unfolded flake.
final List<({Offset at, double r, double phase, double period})> _glints = () {
  var seed = 11;
  double rnd() => (seed = (seed * 16807) % 2147483647) / 2147483647;
  return [
    for (var i = 0; i < 6; i++) (at: Offset(rnd(), rnd()), r: .008 + rnd() * .008, phase: rnd(), period: 1.3 * (1.4 + rnd() * 1.6) / .77),
  ];
}();

/// Glitter's glints over [area] (in the same local units the paper fill is
/// laid out in, [unitPx] its radius), each flashing up and dying away on its
/// own beat at [time] seconds. White, or a cool silver on near-white paper,
/// where white would not show.
void drawGlints(Canvas canvas, Rect area, Color color, double unitPx, double time) {
  final t = sparkleTile(unitPx);
  final light = HSLColor.fromColor(color).lightness > .85;
  final base = light ? const Color(0xFF8A9BB8) : const Color(0xFFFFFFFF);
  final paint = Paint();
  for (var ty = (area.top / t).floor(); ty * t < area.bottom; ty++) {
    for (var tx = (area.left / t).floor(); tx * t < area.right; tx++) {
      // Every tile shuffles its glints by a hash of where it lies: each its
      // own spot and beat, so no two tiles flash alike.
      var h = (tx * 73856093) ^ (ty * 19349663);
      double next() {
        h = (h * 1103515245 + 12345) & 0x7fffffff;
        return h / 0x7fffffff;
      }

      for (final g in _glints) {
        final at = Offset((g.at.dx + next()) % 1 * t, (g.at.dy + next()) % 1 * t);
        final phase = g.phase + next();
        // Mostly dark, with a brief flash once a cycle.
        final w = math.sin(2 * math.pi * (time / g.period + phase));
        if (w <= 0) continue;
        final a = w * w * w;
        paint.color = base.withValues(alpha: a);
        canvas.drawCircle(Offset(tx * t, ty * t) + at, 1.1 * math.max(.9, t * g.r) * (.6 + .6 * a), paint);
      }
    }
  }
}

/// Turns [canvas] from a wedge's own frame to the sheet's, for the segment
/// at position [pos] of [folds]: the wedge drawn there is the sheet turned by
/// pos steps (and mirrored at odd positions), so the paper's pattern, drawn
/// after this in sheet terms, runs on unbroken across the unfolded flake.
void toSheet(Canvas canvas, int pos, int folds) {
  if (pos.isOdd) canvas.scale(-1, 1);
  canvas.rotate(-pos * math.pi / folds - sheetTurn(folds));
}

/// How far the sheet's pattern is turned back within it, for paper folded
/// [folds] times, so it lies level on the open flake as it rests (turned
/// [sheetTurn] itself: half a segment, and [restTurns] segments more; see
/// [SnowflakePainter]): a garland across, a gradient top to bottom.
double sheetTurn(int folds) => (restTurns + .5) * math.pi / folds;

/// How many segments round from where it was folded an open flake rests:
/// as it comes to rest after unfolding, a turn of its own symmetry on.
const restTurns = 2;

/// [drawSheetGlints] for a paper wedge drawn by [drawWedge] (same [s],
/// [cuts], [half] and segment [pos] of [folds]), kept to the paper.
void drawWedgeGlints(Canvas canvas, double s, List<Cut> cuts, double half, Color color, double time, {int pos = 0, int folds = 1, String pattern = 'sparkle'}) {
  final bounds = Rect.fromCircle(center: Offset.zero, radius: s * 1.3);
  canvas.saveLayer(bounds, Paint());
  canvas.save();
  canvas.clipPath(Path()
    ..moveTo(0, 0)
    ..arcTo(Rect.fromCircle(center: Offset.zero, radius: s), -math.pi / 2 - half, 2 * half, false)
    ..close());
  toSheet(canvas, pos, folds);
  drawSheetGlints(canvas, pattern, bounds, color, s, time);
  canvas.restore();
  final clear = Paint()..blendMode = BlendMode.clear;
  for (final c in cuts) {
    if (c.length < 3) continue;
    canvas.drawPath(cutPath(c, s)..fillType = PathFillType.nonZero, clear);
  }
  canvas.restore();
}

ui.Image _tile(Color color, String pattern, double t) {
  final rec = ui.PictureRecorder();
  final x = Canvas(rec);
  // Gift wrap's gold alone lies on nothing: the paper is under it.
  if (pattern != wrapperGoldLayer) x.drawRect(Rect.fromLTWH(0, 0, t, t), Paint()..color = color);
  // Navy on light paper, white on dark paper, where navy would vanish.
  final dark = color.computeLuminance() < 0.2;
  final ink = dark ? const Color(0x38FFFFFF) : const Color(0x292E4A94); // rgba(46,74,148,.16)
  final inkLight = dark ? const Color(0x24FFFFFF) : const Color(0x1A2E4A94);
  final texture = paperTextures[pattern];
  if (texture != null && shadedTextures.contains(pattern)) {
    x.drawImageRect(
      texture,
      Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
      Rect.fromLTWH(0, 0, t, t),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..blendMode = BlendMode.multiply,
    );
  } else if (texture != null) {
    // Its dark lines in the ink's colour, the rest left as the paper.
    final c = dark ? const Color(0xFFFFFFFF) : const Color(0xFF2E4A94);
    final a = dark ? .3 : .28;
    x.drawImageRect(
      texture,
      Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
      Rect.fromLTWH(0, 0, t, t),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.matrix([
          0, 0, 0, 0, c.r * 255, //
          0, 0, 0, 0, c.g * 255,
          0, 0, 0, 0, c.b * 255,
          // Its dark ink only: not white, nor any see-through ground.
          -.299 * a, -.587 * a, -.114 * a, a, 0,
        ]),
    );
  }
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
    case 'chocolate':
      // A bar of chocolate in the paper's colour: one square to a tile,
      // raised, its sloping sides lit from the top left (lighter there,
      // darker to the bottom right), meeting the next edge to edge.
      // Near-white paper makes white chocolate, black dark.
      final hsl = HSLColor.fromColor(color);
      // Lighter by adding, and duller as it does (saturated paper, as the
      // palette's brown, would otherwise light up orange); darker by a share
      // of its own lightness, so dark chocolate's shaded sides stay
      // chocolate, not black.
      Color shade(double d) => d >= 0
          ? hsl.withLightness(math.min(1, hsl.lightness + d)).withSaturation(hsl.saturation * (1 - d * _chocolateDull)).toColor()
          : hsl.withLightness(hsl.lightness * (1 + d)).toColor();
      final i0 = t * _chocolateBevel, i1 = t - i0;
      void face(List<Offset> pts, Color c) => x.drawPath(Path()..addPolygon(pts, true), Paint()..color = c);
      // The square whole in its right side's shade first, so nothing shows
      // through where its sides meet.
      x.drawRect(Rect.fromLTWH(0, 0, t, t), Paint()..color = shade(-.15));
      face([Offset(0, t), Offset(i0, i1), Offset(i1, i1), Offset(t, t)], shade(-.28));
      face([Offset.zero, Offset(t, 0), Offset(i1, i0), Offset(i0, i0)], shade(.16));
      face([Offset.zero, Offset(i0, i0), Offset(i0, i1), Offset(0, t)], shade(.08));
      x.drawRect(Rect.fromLTRB(i0, i0, i1, i1), Paint()..color = color);
    case 'checks':
      final p = Paint()..color = inkLight;
      x.drawRect(Rect.fromLTWH(0, 0, t / 2, t / 2), p);
      x.drawRect(Rect.fromLTWH(t / 2, t / 2, t / 2, t / 2), p);
    case 'sparkle':
      // Glitter: a dense scatter of tiny dots in the paper's own colour and
      // shades around it (only darker ones on near-white paper). Its glints twinkle on a layer of
      // their own (see [drawGlints]), where it is animated; still, a few white
      // dots stand in for them.
      final hsl = HSLColor.fromColor(color);
      Color shade(double d) => hsl.withLightness((hsl.lightness + d).clamp(0.0, 1.0)).toColor();
      // Near-white paper has no lighter shades to show, so its grain goes
      // darker, and further, to stand out.
      final light = hsl.lightness > .85;
      final dots = light ? [color, shade(-.1), shade(-.18), shade(-.26), shade(-.34)] : [color, shade(-.14), shade(-.07), shade(.12), shade(.22)];
      var seed = 7;
      double rnd() => (seed = (seed * 16807) % 2147483647) / 2147483647;
      for (var i = 0; i < _sparkleDots; i++) {
        // White glints are rare: one dot in twenty-five.
        final pick = rnd();
        final p = Paint()..color = pick < .04 ? const Color(0xEEFFFFFF) : dots[(pick * dots.length).floor() % dots.length];
        final cx = rnd() * t, cy = rnd() * t, rr = math.max(.6, t * (.004 + rnd() * .009));
        // Dots over an edge come in again on the far side, so tiles meet seamlessly.
        for (final dx in [-t, 0.0, t]) {
          for (final dy in [-t, 0.0, t]) {
            x.drawCircle(Offset(cx + dx, cy + dy), rr, p);
          }
        }
      }
    case 'holo':
      // Holographic foil: a big burst of light and dark rays in the middle of
      // each cell, a rayed diamond where four cells meet. Its rainbow sheen lies
      // over it in broad bands (see [drawHoloSheen]).
      final hsl = HSLColor.fromColor(color);
      Color shade(double d) => hsl.withLightness((hsl.lightness + d).clamp(0.0, 1.0)).toColor();
      final light = hsl.lightness > .85;
      final hi = light ? Color.lerp(color, const Color(0xFFFFFFFF), .6)! : shade(.16);
      final lo = light ? Color.lerp(color, const Color(0xFF8C9BB8), .35)! : shade(-.12);
      // [rays] rays round, light and dark by turns.
      Paint burst(Offset c, int rays, double phase) {
        final colors = <Color>[], stops = <double>[];
        for (var i = 0; i < rays; i++) {
          final c0 = i.isEven ? hi : lo;
          colors.addAll([c0, c0]);
          stops.addAll([i / rays, (i + 1) / rays]);
        }
        return Paint()..shader = SweepGradient(center: Alignment.center, colors: colors, stops: stops, transform: GradientRotation(phase)).createShader(Rect.fromCircle(center: c, radius: t));
      }

      final mid = Offset(t / 2, t / 2);
      // The burst's rays run right out to the cell's edges, meeting the next.
      x.drawRect(Rect.fromLTWH(0, 0, t, t), burst(mid, 20, 0));
      // Where four cells meet, over the bursts' edges: a diamond with its
      // points up, down and to the sides and its sides curving in, with a few
      // broad rays and a round dot in the middle.
      final d = t * .3, k = t * .115;
      for (final c in [Offset.zero, Offset(t, 0), Offset(0, t), Offset(t, t)]) {
        final diamond = Path()
          ..moveTo(c.dx, c.dy - d)
          ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + d, c.dy)
          ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + d)
          ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - d, c.dy)
          ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - d)
          ..close();
        x.drawPath(diamond, burst(c, 16, math.pi / 16));
        x.drawCircle(c, t * .035, Paint()..color = hi);
      }
    case wrapperGoldLayer:
      // Gift wrap's gold, on nothing: long strings of beads winding about,
      // curling into loops here and there, and little stars scattered
      // between, each outlined in a darker gold (see [wrapperOutline]). Laid
      // over the paper (see [drawWedge]). All of it gathered
      // in [gold] first, then drawn: the outline under, the gold over.
      var seed = 9;
      double rnd() => (seed = (seed * 16807) % 2147483647) / 2147483647;
      final gold = Path();
      // Drawn again a tile over, every way, so tiles meet seamlessly.
      void wrapped(void Function(Offset d) draw) {
        for (final dx in [-t, 0.0, t]) {
          for (final dy in [-t, 0.0, t]) {
            draw(Offset(dx, dy));
          }
        }
      }

      // A string walked a little at a time, its heading turning by a bend
      // that swells and changes side as it goes (two waves summed): gently
      // winding mostly, curling right round where the bend runs high.
      List<Offset> string() {
        var at = Offset(rnd() * t, rnd() * t), heading = rnd() * 2 * math.pi;
        final p1 = rnd() * 2 * math.pi, p2 = rnd() * 2 * math.pi, f1 = 4 + rnd() * 3, f2 = 9 + rnd() * 4;
        final length = t * (1.1 + rnd() * .4), ds = t * .004, step = t * .0312;
        final beads = <Offset>[at];
        var since = 0.0;
        for (var s = 0.0; s < length; s += ds) {
          final u = s / t;
          final bend = (14 * math.sin(u * f1 + p1) + 7 * math.sin(u * f2 + p2)) / t;
          heading += bend * ds;
          at += Offset(math.cos(heading), math.sin(heading)) * ds;
          since += ds;
          if (since >= step) {
            beads.add(at);
            since = 0;
          }
        }
        return beads;
      }

      // How far apart two points lie, the tiles' wrapping counted (the
      // nearest copy of each).
      double apart(Offset a, Offset b) {
        var dx = (a.dx - b.dx) % t, dy = (a.dy - b.dy) % t;
        if (dx > t / 2) dx -= t;
        if (dy > t / 2) dy -= t;
        return math.sqrt(dx * dx + dy * dy);
      }

      // How many of [beads] come within [_wrapperStringGap] of those laid.
      final laid = <Offset>[];
      int crowding(List<Offset> beads) {
        final gap = t * _wrapperStringGap;
        var n = 0;
        for (final b in beads) {
          if (laid.any((q) => apart(b, q) < gap)) n++;
        }
        return n;
      }

      // How many times [beads] cross back over themselves: once for a loop,
      // more for a figure of eight and the like, which aren't wanted.
      int crossings(List<Offset> beads) {
        final near = t * .03;
        var n = 0, was = false;
        for (var j = 8; j < beads.length; j++) {
          final now = beads.take(j - 6).any((q) => apart(beads[j], q) < near);
          if (now && !was) n++;
          was = now;
        }
        return n;
      }

      // Each string the one of a few tries that keeps clearest of the rest,
      // and loops round once at most.
      for (var i = 0; i < 3; i++) {
        int cost(List<Offset> s) => crowding(s) + (crossings(s) > 1 ? 1000 : 0);
        var best = string(), fewest = cost(best);
        for (var k = 1; k < 40 && fewest > 0; k++) {
          final s = string(), n = cost(s);
          if (n < fewest) (best, fewest) = (s, n);
        }
        laid.addAll(best);
        for (final b in best) {
          gold.addOval(Rect.fromCircle(center: b, radius: t * .0096));
        }
      }
      // The stars, each kept clear of the others and of the strings: placed
      // where it fits, after a few tries, or left out.
      final stars = <(Offset, double)>[];
      for (var i = 0; i < 26; i++) {
        final k = t * (.012 + rnd() * .012), turn = rnd() * math.pi;
        Offset? c;
        for (var tries = 0; tries < 30 && c == null; tries++) {
          final q = Offset(rnd() * t, rnd() * t);
          if (stars.any((s) => apart(q, s.$1) < s.$2 + k + t * .02)) continue;
          if (laid.any((b) => apart(q, b) < k + t * .025)) continue;
          c = q;
        }
        if (c == null) continue;
        stars.add((c, k));
        final p = Path();
        for (var j = 0; j < 10; j++) {
          final a = turn + j * math.pi / 5, rr = j.isEven ? k : k * .42;
          final q = c + Offset(math.cos(a), math.sin(a)) * rr;
          j == 0 ? p.moveTo(q.dx, q.dy) : p.lineTo(q.dx, q.dy);
        }
        p.close();
        gold.addPath(p, Offset.zero);
      }
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = t * _wrapperOutline
        ..color = wrapperOutline;
      final shine = Paint()..color = wrapperGold;
      wrapped((d) => x.drawPath(gold.shift(d), outline));
      wrapped((d) => x.drawPath(gold.shift(d), shine));
    case 'gingerbread':
      // Baked dough: a scatter of darker brown crumbs, and fewer white ones
      // (sugar), the same few on every tile whatever its size in px. Each an
      // uneven blob of its own: a few bumps round, squashed, turned any way.
      var seed = 3;
      double rnd() => (seed = (seed * 16807) % 2147483647) / 2147483647;
      void speck(Color c, double r) {
        final p = Paint()..color = c;
        final cx = rnd() * t, cy = rnd() * t;
        // The blob about its middle: [n] points at uneven distances round it,
        // joined by curves through the midpoints between them.
        final n = 4 + (rnd() * 3).floor();
        final squash = .5 + rnd() * .5, turn = rnd() * math.pi;
        final pts = [
          for (var k = 0; k < n; k++)
            () {
              final a = (k + rnd() * .6) / n * 2 * math.pi, d = r * (.6 + rnd() * .7);
              return Offset(math.cos(a) * d, math.sin(a) * d * squash);
            }(),
        ];
        Offset mid(int k) => (pts[k % n] + pts[(k + 1) % n]) / 2;
        final blob = Path()..moveTo(mid(0).dx, mid(0).dy);
        for (var k = 1; k <= n; k++) {
          blob.quadraticBezierTo(pts[k % n].dx, pts[k % n].dy, mid(k).dx, mid(k).dy);
        }
        blob.close();
        // Over an edge, in again on the far side, so tiles meet seamlessly.
        for (final dx in [-t, 0.0, t]) {
          for (final dy in [-t, 0.0, t]) {
            x
              ..save()
              ..translate(cx + dx, cy + dy)
              ..rotate(turn)
              ..drawPath(blob, p)
              ..restore();
          }
        }
      }

      for (var i = 0; i < 140; i++) {
        speck(gingerbreadCrumbs[(rnd() * gingerbreadCrumbs.length).floor() % gingerbreadCrumbs.length].withValues(alpha: .55 + rnd() * .4), math.max(.6, t * (.006 + rnd() * .0144)));
      }
      for (var i = 0; i < 36; i++) {
        speck(const Color(0xFFFFF4E6).withValues(alpha: .7 + rnd() * .3), math.max(.6, t * (.0048 + rnd() * .0096)));
      }
    case 'snowfall':
      // Snowflakes, six-armed, and dots of snow: white, or blue on pale paper.
      final c = color.computeLuminance() > .6 ? const Color(0x803E61B8) : const Color(0xE6FFFFFF);
      final arm = Paint()
        ..color = c
        ..strokeWidth = math.max(1.0, t * .012)
        ..strokeCap = StrokeCap.round;
      const flakes = [(.2, .25, .09), (.68, .16, .06), (.56, .6, .1), (.14, .74, .06), (.86, .84, .07), (.4, .42, .045)];
      for (final (fx, fy, fr) in flakes) {
        final r = fr * t;
        for (final dx in [-t, 0.0, t]) {
          for (final dy in [-t, 0.0, t]) {
            final o = Offset(fx * t + dx, fy * t + dy);
            for (var k = 0; k < 6; k++) {
              final a = k * math.pi / 3, u = Offset(math.cos(a), math.sin(a));
              x.drawLine(o, o + u * r, arm);
              // A little V near each arm's tip.
              for (final side in [-1.0, 1.0]) {
                final b = a + side * math.pi / 4;
                x.drawLine(o + u * r * .55, o + u * r * .55 + Offset(math.cos(b), math.sin(b)) * r * .35, arm);
              }
            }
          }
        }
      }
      const dots = [(.42, .1), (.9, .4), (.3, .55), (.75, .38), (.05, .45), (.6, .9), (.32, .92), (.95, .1)];
      for (final (dx, dy) in dots) {
        x.drawCircle(Offset(dx * t, dy * t), math.max(.8, t * .014), Paint()..color = c);
      }
    case 'candy':
      // A candy cane's stripes on white: broad ones in the paper's colour
      // (red on white paper) and a thin one between, each lit along its
      // upper edge by a soft white inner glow, so it looks rounded.
      x.drawRect(Rect.fromLTWH(0, 0, t, t), Paint()..color = const Color(0xFFFFFFFF));
      final c = color.computeLuminance() > .9 ? const Color(0xFFE0405E) : color;
      // Across a stripe of width [w] centred on the line x + y = [k]: its
      // colour paled towards white ([_candyLight]) at its upper left edge,
      // running into the colour itself over [_candyGlow] of it.
      Paint stripe(double k, double w) {
        final mid = Offset(k / 2, k / 2), across = const Offset(1, 1) / math.sqrt2 * .5;
        return Paint()
          ..strokeWidth = w
          ..style = PaintingStyle.stroke
          ..shader = ui.Gradient.linear(mid - across * w, mid + across * w, [Color.lerp(c, const Color(0xFFFFFFFF), _candyLight)!, c, c], [0, _candyGlow, 1]);
      }
      // Each line run on well past the tile's corners, so the broad ones
      // don't end short of its edges.
      for (final o in [-t, 0.0, t]) {
        x.drawLine(Offset(o - t, 2 * t), Offset(o + 2 * t, -t), stripe(o + t, t * _candyBroad));
        x.drawLine(Offset(o - t / 2, 2 * t), Offset(o + 2.5 * t, -t), stripe(o + 1.5 * t, t * _candyThin));
      }
    case 'garland':
      // A string of lights: a wire waving across, a bulb of each colour on it,
      // each glowing; the glows under the wire, the bulbs over it.
      double wave(double px) => t * .5 + t * .12 * math.sin(2 * math.pi * px / t);
      const bulbs = [Color(0xFFE0405E), Color(0xFFFFD34D), Color(0xFF3E9BFF), Color(0xFF2FB37E)];
      Offset bulbAt(int k) {
        final px = (k + .5) / bulbs.length * t;
        return Offset(px, wave(px) + t * .07);
      }

      // Each bulb's glow and its bright spot added to the light under them, as
      // light is, brightening it rather than tinting it over; on near-white
      // paper, with no light to add to, laid over instead, or they would
      // vanish.
      final glowBlend = color.computeLuminance() > .8 ? BlendMode.srcOver : BlendMode.plus;
      for (var k = 0; k < bulbs.length; k++) {
        x.drawCircle(
          bulbAt(k),
          t * .09,
          Paint()
            ..color = bulbs[k].withValues(alpha: .25)
            ..blendMode = glowBlend,
        );
      }
      final wire = Path()..moveTo(0, wave(0));
      for (var i = 1; i <= 40; i++) {
        wire.lineTo(i / 40 * t, wave(i / 40 * t));
      }
      x.drawPath(
        wire,
        Paint()
          ..color = dark ? const Color(0x66FFFFFF) : const Color(0x801E6B4F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, t * .015),
      );
      for (var k = 0; k < bulbs.length; k++) {
        final bulb = bulbAt(k), px = bulb.dx, py = wave(px);
        x.drawRect(Rect.fromCenter(center: Offset(px, py + t * .015), width: t * .04, height: t * .03), Paint()..color = const Color(0xFF6B7280));
        // The bulb in its own colour, and lit: a small bright dot up by its
        // socket, its light added (see [glowBlend]).
        x.drawOval(Rect.fromCenter(center: bulb, width: t * .055, height: t * .085), Paint()..color = bulbs[k]);
        x.drawCircle(
          bulb + Offset(0, -t * .024),
          t * .012,
          Paint()
            ..color = const Color(0xCCFFFFFF)
            ..blendMode = glowBlend,
        );
      }
    case 'tartan':
      // Plaid: broad darker bands either way, deeper where they cross, and
      // thin light lines between.
      final shade = Paint()..color = const Color(0x2E000000);
      final line = Paint()..color = const Color(0x40FFFFFF);
      x.drawRect(Rect.fromLTWH(t * .1, 0, t * .3, t), shade);
      x.drawRect(Rect.fromLTWH(0, t * .1, t, t * .3), shade);
      x.drawRect(Rect.fromLTWH(t * .68, 0, t * .04, t), line);
      x.drawRect(Rect.fromLTWH(0, t * .68, t, t * .04), line);
      x.drawRect(Rect.fromLTWH(t * .24, 0, t * .015, t), line);
      x.drawRect(Rect.fromLTWH(0, t * .24, t, t * .015), line);
    case 'bubbles':
      // Laid out on a square, wrapping round at its edges.
      final circles = _tileBubbles(t);
      for (final dx in [-t, 0.0, t]) {
        for (final dy in [-t, 0.0, t]) {
          x.save();
          x.translate(dx, dy);
          _paintBubbles(x, circles, color, 1, t * .0028);
          x.restore();
        }
      }
  }
  return rec.endRecording().toImageSync(t.toInt(), t.toInt());
}

// ---- Crystal ----------------------------------------------------------------

/// Crystal paper: an octagonal gem seen from above across the whole sheet
/// (centre at the origin, radius 1), as gems are drawn: see-through
/// triangles laid one over another, lighter (white) or darker (the paper's
/// deep shade), so where they cross they make the many facets between them.
/// Its outline's corners a little past the sheet's edge, so its sides clear
/// it. Lit evenly, from no side: each facet's shade its own.
///
/// Made once, in plain numbers, the paper's colour put to them when drawn
/// (see [_colourCrystal]): the triangles' corners ([positions], three to
/// each), and at each corner how it lies on what is under it ([shade]):
/// over 0 the gem's bright shade, under 0 its deep one, as opaque as it is
/// far from 0; [_baseShade] the gem's own colour, opaque, and [_tableShade]
/// that nearly opaque (the table, laid over the rest to calm it).
final _crystal = () {
  const outer = 1.08, table = .42;
  const step = math.pi / 4, startAt = -math.pi / 2;
  Offset at(double r, double a) => Offset(math.cos(a) * r, math.sin(a) * r);
  Offset v(int i) => at(outer, startAt + i * step);
  Offset t(int i) => at(table, startAt + i * step);
  // A share from -1 to 1 for each triangle in turn, the same every launch:
  // the golden ratio's steps, so neighbours seldom match.
  var made = 0;
  double vary() => (++made * .6180339887) % 1 * 2 - 1;
  final positions = <double>[], shade = <double>[];
  void tri(Offset a, Offset b, Offset c, double tone) {
    positions.addAll([a.dx, a.dy, b.dx, b.dy, c.dx, c.dy]);
    shade.addAll(List.filled(3, tone * _crystalContrast));
  }

  // The gem's own colour, fuller than the paper's, under all the rest,
  // wholly hiding the paper.
  for (var i = 0; i < 8; i++) {
    positions.addAll([0, 0, v(i).dx, v(i).dy, v(i + 1).dx, v(i + 1).dy]);
    shade.addAll(const [_baseShade, _baseShade, _baseShade]);
  }

  // A triangle shaded as a whole: lighter or darker by up to [strength],
  // its own, and [offset] on top.
  void lit(Offset a, Offset b, Offset c, double strength, double offset) => tri(a, b, c, strength * vary() + offset);

  for (var i = 0; i < 8; i++) {
    // The caps: each corner's triangle out past the chord between its
    // neighbours, crossing its neighbours' near the rim.
    lit(v(i - 1), v(i), v(i + 1), .5, i.isEven ? .1 : -.14);
  }
  for (var i = 0; i < 8; i++) {
    // The ring between the table and the rim: three triangles to a side,
    // by turns lighter and darker.
    final m = (v(i) + v(i + 1)) / 2;
    lit(v(i), m, t(i), .45, -.16);
    lit(m, v(i + 1), t(i + 1), .45, .1);
    lit(m, t(i), t(i + 1), .4, i.isEven ? .16 : -.06);
  }
  for (var i = 0; i < 8; i++) {
    // The star: from each corner in to the table's corners either side,
    // the arms overlapping one another.
    lit(v(i), t(i - 1), t(i + 1), .45, -.1);
  }
  for (var i = 0; i < 8; i++) {
    // The table: the paper again, nearly hiding what is under it, then a
    // touch lighter, its facets by turns more so.
    positions.addAll([0, 0, t(i).dx, t(i).dy, t(i + 1).dx, t(i + 1).dy]);
    shade.addAll(const [_tableShade, _tableShade, _tableShade]);
  }
  for (var i = 0; i < 8; i++) {
    tri(Offset.zero, t(i), t(i + 1), i.isEven ? .2 : .12);
  }
  // A triangle of white, as opaque as [alpha] (see [_whiteShade]), or
  // corner by corner as [alpha], [alphaB] and [alphaC].
  void white(Offset a, Offset b, Offset c, double alpha, [double? alphaB, double? alphaC]) {
    positions.addAll([a.dx, a.dy, b.dx, b.dy, c.dx, c.dy]);
    shade.addAll([_whiteShade + alpha, _whiteShade + (alphaB ?? alpha), _whiteShade + (alphaC ?? alpha)]);
  }

  // Over it all, light lying along four of the table's edges as on glass: a
  // thin sliver out from each, its point a little past the edge's middle,
  // white as good as solid along the edge and fading out to its point, so
  // it reads as a sheen rather than a grey film.
  for (final i in const [1, 3, 6, 7]) {
    final strong = _glassStrong + .08 * vary();
    white(t(i), at(_whiteReach, startAt + (i + .5) * step), t(i + 1), strong, _glassFaint, strong);
  }
  return (positions: Float32List.fromList(positions), shade: shade);
}();

/// How opaque crystal's glass sheen is at its strongest, along the table's
/// edge, and at its faintest, out at its point.
const _glassStrong = .7, _glassFaint = .12;

/// How far out from the middle crystal's slivers of sheen along the
/// table's edges reach, at their points: the table's corners are at .42.
const _whiteReach = .5;

/// In [_crystal]'s shades: the gem's own colour, opaque, and nearly so
/// ([_tableOpacity]); white, as opaque as it is over [_whiteShade].
const _baseShade = 9.0, _tableShade = 8.0, _tableOpacity = .82, _whiteShade = 10.0;

/// How much stronger than drawn [_crystal]'s shades are, all of them.
const _crystalContrast = 1.45;

/// How much fuller the gem's colour is than the paper's.
const _crystalSaturation = 1.3;

/// Crystal's triangles coloured for each paper colour it has been drawn in:
/// a few dozen at most, the palette's.
final _crystalVertices = <Color, ui.Vertices>{};

/// Crystal paper's triangles (see [_crystal]) coloured for paper of
/// [color]: the gem's colour (the paper's, fuller: see
/// [_crystalSaturation]), its bright shade (lighter, as full, so the light is the gem's
/// colour lit up, not washed out; on near-white paper, white), or its deep
/// shade (the paper multiplied by itself, so darker without greying;
/// near-white paper by ice blue), each as opaque as its shade says.
ui.Vertices _colourCrystal(Color color) {
  var hsl = HSLColor.fromColor(color);
  final whitish = hsl.saturation < .15 && hsl.lightness > .8;
  if (!whitish) {
    hsl = hsl.withSaturation(math.min(1, hsl.saturation * _crystalSaturation));
    color = hsl.toColor();
  }
  final by = whitish ? const Color(0xFF7F9DC4) : color;
  final deep = Color.from(alpha: 1, red: color.r * by.r, green: color.g * by.g, blue: color.b * by.b);
  final bright = whitish ? const Color(0xFFFFFFFF) : hsl.withLightness(math.min(.8, hsl.lightness + .3)).withSaturation(math.min(1, hsl.saturation * 1.1)).toColor();
  return ui.Vertices.raw(
    VertexMode.triangles,
    _crystal.positions,
    colors: Int32List.fromList([
      for (final s in _crystal.shade)
        (s >= _whiteShade
                ? Color.fromRGBO(255, 255, 255, s - _whiteShade)
                : s == _baseShade
                ? color
                : s == _tableShade
                ? color.withValues(alpha: _tableOpacity)
                : s >= 0
                ? bright.withValues(alpha: math.min(1, s))
                : deep.withValues(alpha: math.min(1, -s)))
            .toARGB32(),
    ]),
  );
}

/// Where crystal's flares of light sit on the sheet (at the table's corners
/// and the star's points), their sizes, and when in a round each flashes,
/// as a share of it, so they come by turns.
const _crystalFlares = [(Offset(.3, -.31), 1.0, 0.0), (Offset(-.47, .12), .8, .42), (Offset(.08, .4), .7, .2), (Offset(-.22, -.38), .6, .64), (Offset(.55, .16), .65, .84)];

/// How long a round of crystal's flares takes, in seconds, and what share of
/// it each flare is lit for: up and gone again, then dark till its turn.
const _flareRound = 5.6, _flareLit = .32;

/// How far a flare's rays turn while it is lit, clockwise from level, in
/// radians.
const _flareTurn = .5;

/// A flare's soft glow, at the origin, radius 1.
final _flareGlow = ui.Gradient.radial(Offset.zero, 1, const [Color(0xCCFFFFFF), Color(0x55B4C8FF), Color(0x00B4C8FF)], const [0, .25, 1]);

/// A flare's rays: long and thin across, shorter up and down.
final _flareRays = () {
  Path ray(double long, double thin, double turn) {
    final c = math.cos(turn), s = math.sin(turn);
    Offset p(double x, double y) => Offset(x * c - y * s, x * s + y * c);
    return Path()..addPolygon([p(-long, 0), p(0, -thin), p(long, 0), p(0, thin)], true);
  }

  return Path()
    ..addPath(ray(2.2, .07, 0), Offset.zero)
    ..addPath(ray(1.1, .06, math.pi / 2), Offset.zero);
}();

/// Crystal paper's gem over its [color], laid in sheet terms (centre at the
/// origin, radius [r]): its triangles coloured to it (see [_colourCrystal]),
/// in one draw. Still: its flares go on separately, over it, while it
/// shimmers (see [drawCrystalFlares]).
void drawCrystalFacets(Canvas canvas, double r, Color color) {
  canvas.save();
  canvas.scale(r);
  // The vertices' own colours, the paint's left out.
  canvas.drawVertices(_crystalVertices.putIfAbsent(color, () => _colourCrystal(color)), BlendMode.dst, Paint());
  canvas.restore();
}

/// Crystal paper's flares at [time] seconds, laid in sheet terms (centre at
/// the origin, radius [r]), over the gem: each, in its turn, swelling up out
/// of nothing and dying away, its rays turning a little as it does (from
/// level, clockwise: see [_flareTurn]). Only
/// those lit are drawn, a couple at a time at most.
void drawCrystalFlares(Canvas canvas, double r, double time) {
  final ray = Paint();
  for (final (at, size, phase) in _crystalFlares) {
    final u = (time / _flareRound + phase) % 1;
    if (u >= _flareLit) continue;
    final lit = math.sin(math.pi * u / _flareLit);
    canvas.save();
    canvas.translate(at.dx * r, at.dy * r);
    canvas.rotate(_flareTurn * u / _flareLit);
    canvas.scale(r * .09 * size * (.4 + .6 * lit));
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = _flareGlow
        ..color = Color.fromRGBO(255, 255, 255, lit),
    );
    canvas.drawPath(_flareRays, ray..color = Color.fromRGBO(255, 255, 255, .9 * lit));
    canvas.restore();
  }
}

// ---- Hologram ---------------------------------------------------------------

/// The hologram's rainbow sheen over [area]: soft diagonal bands running
/// round the hues and back, every [unit]·0.8 or so, as foil shifts colour,
/// so even a narrow folded wedge shows a couple. [blend] lays it only over
/// what is drawn already (srcATop), for a sheen added after the paper. At
/// [time] seconds the bands have drifted on, one band's width every 8 s or
/// so, slowly, as foil shimmers.
void drawHoloSheen(Canvas canvas, Rect area, double unit, {BlendMode blend = BlendMode.srcOver, double time = 0}) {
  const hues = [Color(0x70FF9AD5), Color(0x70B9A8FF), Color(0x7080E8FF), Color(0x7090FFC8), Color(0x70FFF19A)];
  final span = unit * .56;
  final drift = Offset(1, 1) * (span * time / 8);
  canvas.drawRect(
    area,
    Paint()
      ..blendMode = blend
      // Bands a further 22° round from the diagonal.
      ..shader = LinearGradient(colors: hues, tileMode: TileMode.mirror, transform: const GradientRotation(22 * math.pi / 180))
          .createShader(Rect.fromPoints(area.topLeft + drift, area.topLeft + drift + Offset(span, span))),
  );
}

// ---- Bubbles ---------------------------------------------------------------

/// One circle of the bubbles pattern: where, how big, and which kind (0..1:
/// soft spot, rimmed spot, pale ring, bright target), with a spot's alpha
/// and whether a ring has a dot in the middle.
typedef _Bubble = ({Offset at, double r, double kind, double alpha, bool dot});

/// Circles of every size laid biggest first, each [space] clear of all the
/// others, so they never touch and lie about evenly spaced; [fit] places a
/// candidate (or moves it, or refuses it with null) and [near] lists where
/// an existing circle also shows to the candidate (its copies across a wrap
/// or a fold).
List<_Bubble> _layBubbles(double size, double space, Offset Function(double Function() rnd) sample, Offset? Function(Offset c, double r) fit, Iterable<Offset> Function(Offset q) near) {
  var seed = 5;
  double rnd() => (seed = (seed * 16807) % 2147483647) / 2147483647;
  final placed = <_Bubble>[];
  for (var tries = 0; tries < 12000 && placed.length < 420; tries++) {
    final r = size * (.006 + .045 * math.pow(1 - tries / 12000, 2.2) * (.75 + .25 * rnd()));
    final c = fit(sample(rnd), r);
    if (c == null) continue;
    if (placed.any((q) => near(q.at).any((a) => (a - c).distance < q.r + r + space))) continue;
    placed.add((at: c, r: r, kind: rnd(), alpha: .55 + rnd() * .3, dot: rnd() < .4));
  }
  return placed;
}

final _tileBubbleCache = <int, List<_Bubble>>{};

/// The bubbles on a square tile [t] across, wrapping round at its edges.
List<_Bubble> _tileBubbles(double t) => _tileBubbleCache.putIfAbsent(
      t.round(),
      () => _layBubbles(
        t,
        t * .012,
        (rnd) => Offset(rnd() * t, rnd() * t),
        (c, r) => c,
        (q) => [for (final dx in [-t, 0.0, t]) for (final dy in [-t, 0.0, t]) q + Offset(dx, dy)],
      ),
    );

/// Paints [circles] (laid out in units [s] px each) for paper [color], rings
/// [w] px thick: colours drawn from the paper, darker spots and paler rings,
/// lighter spots on near-black paper and darker all round on near-white.
void _paintBubbles(Canvas canvas, List<_Bubble> circles, Color color, double s, double w) {
  final hsl = HSLColor.fromColor(color);
  final light = hsl.lightness > .85, deep = hsl.lightness < .15;
  Color shade(double d, [double sat = 0]) =>
      hsl.withLightness((hsl.lightness + d).clamp(0.0, 1.0)).withSaturation((hsl.saturation + sat).clamp(0.0, 1.0)).toColor();
  final dark = shade(deep ? .09 : (light ? -.12 : -.1)), darker = shade(deep ? .16 : (light ? -.2 : -.18));
  final pale = light ? shade(-.3) : Color.lerp(shade(.25), const Color(0xFFE6FBFF), .6)!;
  final bright = light ? shade(-.22, .2) : shade(.12, .25);
  for (final b in circles) {
    final at = b.at * s, r = b.r * s;
    if (b.kind < .6) {
      canvas.drawCircle(at, r, Paint()..color = dark.withValues(alpha: b.alpha));
    } else if (b.kind < .8) {
      canvas.drawCircle(at, r, Paint()..color = dark.withValues(alpha: .6));
      canvas.drawCircle(
        at,
        r - w * .7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 1.4
          ..color = darker,
      );
    } else if (b.kind < .92) {
      canvas.drawCircle(
        at,
        r * .75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 1.3
          ..color = pale,
      );
      if (b.dot) canvas.drawCircle(at, r * .2, Paint()..color = pale);
    } else {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 1.6
        ..color = bright;
      canvas.drawCircle(at, r * .8, ring);
      canvas.drawCircle(at, r * .45, ring);
    }
  }
}

/// Draws the paper wedge (apex at current origin, pointing up) and erases cuts. s = unit radius in px.
/// [pad] widens the wedge by about s·pad past each fold edge, right down to
/// the apex, so mirrored copies overlap without seams. The paper's pattern
/// is laid in sheet terms for the segment at position [pos] of [folds] (see
/// [toSheet]); a hologram ([pattern]) gets its sheen on top, drifted to
/// [sheenTime] seconds, unless [sheen] is false (a flake that turns lays its
/// own, fixed to the screen).
void drawWedge(Canvas canvas, double s, List<Cut> cuts, double half, Paint fill, {double pad = 0, String? pattern, int pos = 0, int folds = 1, bool sheen = true, double sheenTime = 0, Color? icing, double dpr = 1}) {
  final bounds = Rect.fromCircle(center: Offset.zero, radius: s * 1.3);
  canvas.saveLayer(bounds, Paint());
  final wedge = Path()
    ..moveTo(0, s * pad / math.sin(half))
    ..arcTo(Rect.fromCircle(center: Offset.zero, radius: s), -math.pi / 2 - half - pad, 2 * (half + pad), false)
    ..close();
  canvas.save();
  canvas.clipPath(wedge);
  toSheet(canvas, pos, folds);
  canvas.drawRect(bounds, fill);
  if (pattern == 'holo' && sheen) drawHoloSheen(canvas, bounds, s, time: sheenTime);
  if (pattern == 'crystal') drawCrystalFacets(canvas, s, fill.color);
  canvas.restore();
  // Unturned by the segment's place on the sheet: light on glass keeps to
  // the screen.
  if (pattern == 'glass' && sheen) {
    canvas.save();
    canvas.clipPath(wedge);
    drawGlassGlints(canvas, Rect.fromCircle(center: Offset.zero, radius: s));
    canvas.restore();
  }
  // Gift wrap's gold, over its paper.
  if (pattern == 'wrapper') {
    canvas.save();
    canvas.clipPath(wedge);
    toSheet(canvas, pos, folds);
    canvas.drawRect(bounds, makePaperFill(fill.color, wrapperGoldLayer, s, dpr: dpr));
    canvas.restore();
  }
  final clear = Paint()..blendMode = BlendMode.clear;
  for (final c in cuts) {
    if (c.length < 3) continue;
    canvas.drawPath(cutPath(c, s)..fillType = PathFillType.nonZero, clear);
  }
  if (pattern == 'gingerbread') {
    final lines = [
      for (final c in cuts)
        if (c.length >= 3) cutPath(c, s),
    ];
    _bakedEdge(canvas, s, lines, half, pad);
    if (icing != null) _icing(canvas, s, lines, icing);
  }
  canvas.restore();
}

/// Icing piped along gingerbread's cuts: how far in from the edge, and how
/// thick, as shares of the wedge's radius.
const _icingGap = .022, _icingWidth = .0144;

/// A smooth line of icing in [color] along every cut ([lines]) in gingerbread paper,
/// [_icingGap] in from its edge, on the paper only: a ring round each cut
/// (a broad stroke along it less a narrower one), laid over what is there.
void _icing(Canvas canvas, double s, List<Path> lines, Color color) {
  final bounds = Rect.fromCircle(center: Offset.zero, radius: s * 1.3);
  canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.srcATop);
  Paint line(double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final outer = line(2 * s * (_icingGap + _icingWidth))..color = color;
  final inner = line(2 * s * _icingGap)..blendMode = BlendMode.clear;
  for (final l in lines) {
    canvas.drawPath(l, outer);
  }
  for (final l in lines) {
    canvas.drawPath(l, inner);
  }
  // Its inner shadow: what lies either side of the line, in the icing's
  // colour darkened, blurred in over its edges and kept to the line, so it
  // looks piped, rounded.
  final edge = s * _icingShadow;
  canvas.saveLayer(bounds, Paint()
    ..blendMode = BlendMode.srcATop
    ..imageFilter = ui.ImageFilter.blur(sigmaX: edge * .6, sigmaY: edge * .6));
  final shade = icingShade(color);
  final beyond = line(2 * (s * (_icingGap + _icingWidth) + edge))..color = shade;
  final within = line(2 * s * _icingGap)..color = shade;
  final past = line(2 * s * (_icingGap + _icingWidth))..blendMode = BlendMode.clear;
  for (final l in lines) {
    canvas.drawPath(l, beyond);
  }
  for (final l in lines) {
    canvas.drawPath(l, past);
  }
  for (final l in lines) {
    canvas.drawPath(l, within);
  }
  canvas.restore();
  canvas.restore();
}

/// How far the icing's inner shadow reaches in from its edges, as a share of
/// the wedge's radius.
const _icingShadow = .004;

/// The colour of the shadow along icing of [color]: it, darkened.
Color icingShade(Color color) => Color.lerp(color, const Color(0xFF000000), .4)!.withValues(alpha: .85);

/// Gingerbread's baked edge: the colour of its inner shadow.
const gingerbreadShadow = ui.Color.fromARGB(198, 141, 50, 14);

/// How wide the baked edge is, and how soft, as shares of the paper's radius.
const gingerbreadEdgeWidth = .05, gingerbreadEdgeBlur = .04;

/// A soft dark rim inside gingerbread paper (see [gingerbreadShadow]), round
/// the wedge's outside and every cut in it ([lines]), drawn over the paper only. Not
/// along its folds, where the flake runs on unbroken.
void _bakedEdge(Canvas canvas, double s, List<Path> lines, double half, double pad) {
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * gingerbreadEdgeWidth
    ..color = gingerbreadShadow
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * gingerbreadEdgeBlur)
    ..blendMode = BlendMode.srcATop;
  canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: s), -math.pi / 2 - half - pad, 2 * (half + pad), false, p);
  for (final l in lines) {
    canvas.drawPath(l, p);
  }
}

/// Glass's thickness, showing below its edges in [glassShade] the way its
/// shadow falls, but close: how far down, as a share of the flake's (or the
/// board's wedge's) size.
const glassDepth = .01;

/// How opaque glass of [color] is: as see-through as the colour is light,
/// from about a third (white) to three quarters (black).
double glassOpacity(Color color) => ui.lerpDouble(.75, .35, color.computeLuminance())!;

/// Glass is richer than the paper colour picked for it: its saturation (as
/// in HSV) times this, the hue and brightness kept; white, black and greys,
/// with none, stay as they are.
const _glassSaturation = 1.35;

/// The colour of glass of paper [color]: richer (see [_glassSaturation]),
/// solid; [glassOpacity] says how see-through.
Color glassTint(Color color) {
  final hsv = HSVColor.fromColor(color.withValues(alpha: 1));
  return hsv.withSaturation(math.min(1, hsv.saturation * _glassSaturation)).toColor();
}

/// How dark glass's thickness is: its colour's brightness (as in HSV) times
/// this. Seen as see-through as the glass, it is as dense as that.
const _thicknessShade = .55;

/// The colour of glass of [color] seen in its thickness: the glass's own
/// (see [glassTint]), darker; solid.
Color glassShade(Color color) {
  final hsv = HSVColor.fromColor(glassTint(color));
  return hsv.withValue(hsv.value * _thicknessShade).toColor();
}

/// Paints whatever is drawn solid [color] wherever it is drawn at all: see-
/// through glass (never under a quarter opaque) as well, its edges kept soft.
ColorFilter glassSolid(Color color) => ColorFilter.matrix([
      0, 0, 0, 0, color.r * 255, //
      0, 0, 0, 0, color.g * 255,
      0, 0, 0, 0, color.b * 255,
      0, 0, 0, 4, 0,
    ]);

/// Makes see-through glass (never under a quarter opaque) solid, its colours
/// and soft edges kept: to be laid down as see-through again as a whole.
const glassOpaque = ColorFilter.matrix([
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 4, 0,
]);

/// Light glinting on glass over [area]: two pale white streaks slanting
/// across it, each swelling and fading smoothly (no sharp ridge of white
/// down its middle), laid on the screen however the glass turns, as the
/// hologram's sheen is. [blend] lays them only over what is drawn already
/// (srcATop).
void drawGlassGlints(Canvas canvas, Rect area, {BlendMode blend = BlendMode.srcOver}) {
  const light = Color(0xFFFFFFFF);
  Color at(double a) => light.withValues(alpha: a);
  // Each streak, from [from] to [to] along the diagonal at most [peak]
  // strong, a smooth bump (a cosine's) sampled in a few steps.
  const steps = 8;
  final colors = <Color>[], stops = <double>[];
  for (final (from, to, peak) in const [(.32, .42, .3), (.67, .74, .2)]) {
    for (var k = 0; k <= steps; k++) {
      final t = k / steps;
      colors.add(at(peak * (1 - math.cos(2 * math.pi * t)) / 2));
      stops.add(from + (to - from) * t);
    }
  }
  canvas.drawRect(
    area,
    Paint()
      ..blendMode = blend
      ..shader = ui.Gradient.linear(area.topLeft, area.bottomRight, colors, stops),
  );
}

/// The outline of [c] as seen, [s] px to a unit: each closed loop on its own,
/// leaving out the bridges that join several holes into one cut (run out and
/// back along the same line, like the jack-o'-lantern stencil's). A loop ends
/// where the outline comes back to the point it started from.
Path cutOutline(Cut c, double s) {
  final loops = <List<Offset>>[];
  var start = 0;
  for (var k = 1; k < c.length; k++) {
    if (k > start + 2 && c[k] == c[start]) {
      loops.add(c.sublist(start, k));
      start = k + 1;
    }
  }
  // No loop closed early: an ordinary cut, one outline all round.
  if (loops.isEmpty) return cutPath(c, s);
  final path = Path();
  for (final l in loops) {
    path.addPolygon([for (final q in l) q * s], true);
  }
  return path;
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
