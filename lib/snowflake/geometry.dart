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
  // New Year pack (not offered yet), four-fold.
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

/// Shown six to a row, a column per hue, lighter shades above darker ones.
/// Event flakes use these only, so the player can always cut one alike.
const paperColors = [
  PaperColor('white', 'Белая', Color(0xFFFFFFFF)),
  PaperColor('pink', 'Розовая', Color(0xFFFFC7D0)),
  PaperColor('sun', 'Жёлтая', Color(0xFFFFE08A)),
  PaperColor('mint', 'Мятная', Color(0xFFBFF0DC)),
  PaperColor('ice', 'Голубая', Color(0xFFC4ECFF)),
  PaperColor('lilac', 'Сиреневая', Color(0xFFDCD2FF)),
  PaperColor('grey', 'Серая', Color(0xFF9AA3B5)),
  PaperColor('red', 'Красная', Color(0xFFE0405E)),
  PaperColor('orange', 'Оранжевая', Color(0xFFFF9A3C)),
  PaperColor('green', 'Зелёная', Color(0xFF2FB37E)),
  PaperColor('blue', 'Синяя', Color(0xFF3E61B8)),
  PaperColor('violet', 'Фиолетовая', Color(0xFF8A5CD6)),
  PaperColor('black', 'Чёрная', Color(0xFF1E1F26)),
  PaperColor('wine', 'Бордовая', Color(0xFF8E1F3A)),
  PaperColor('brown', 'Коричневая', Color(0xFF8B5A2B)),
  PaperColor('forest', 'Тёмно-зелёная', Color(0xFF1E6B4F)),
  PaperColor('navy', 'Тёмно-синяя', Color(0xFF1E2F6B)),
  PaperColor('plum', 'Тёмно-фиолетовая', Color(0xFF4A1A6B)),
];

const paperPatterns = [
  ('plain', 'Гладкая'),
  ('dots', 'Горошек'),
  ('stripes', 'Полоски'),
  ('checks', 'Клетка'),
  ('sparkle', 'Блёстки'),
  ('bubbles', 'Кружочки'),
  ('holo', 'Голограмма'),
];

/// Whether paper with [pattern] shimmers over time: glitter's glints
/// twinkling, a hologram's sheen drifting.
bool shimmers(String pattern) => pattern == 'sparkle' || pattern == 'holo';

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
    case 'bone' || 'hat' || 'bat' || 'jack':
      for (final q in _halloweenStencils[tool]!) {
        pts.add(Offset(cx + q.dx * r, cy + q.dy * r));
      }
  }
  return pts;
}

/// Points round a circle at [c], radius [k], from [from] to [to] degrees
/// (y down, so increasing angles turn clockwise on screen).
List<Offset> _arcPts(Offset c, double k, double from, double to, [int steps = 10]) => [
      for (var i = 0; i <= steps; i++) c + Offset(math.cos((from + (to - from) * i / steps) * math.pi / 180), math.sin((from + (to - from) * i / steps) * math.pi / 180)) * k,
    ];

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
  // Scattered patterns get big tiles, so they don't visibly repeat.
  final t = switch (pattern) {
    'sparkle' => sparkleTile(unitPx),
    'bubbles' => sparkleTile(unitPx) * 2.5 * 1.3,
    // One hologram cell: a big burst with small ones at its corners.
    'holo' => math.max(16.0, unitPx * .3),
    _ => math.max(8.0, unitPx * 0.075),
  };
  // Drawn at the nearest of a few sizes and scaled to fit, so zooming the
  // board in and out reuses a handful of tiles instead of making new ones.
  final tq = math.pow(1.25, (math.log(t) / math.log(1.25)).round()).round();
  final key = (color, pattern, tq);
  var img = _tileCache.remove(key);
  if (img == null) {
    img = _tile(color, pattern, tq.toDouble());
    // The oldest go: dropped, not disposed, as a shader may still hold one.
    while (_tileCache.length >= 48) {
      _tileCache.remove(_tileCache.keys.first);
    }
  }
  _tileCache[key] = img;
  final k = t / tq;
  return paint..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, Float64List.fromList([k, 0, 0, 0, 0, k, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      // Smooth, as the tile is scaled a little.
      filterQuality: FilterQuality.medium);
}

/// Side of the glitter pattern's tile, for paper [unitPx] in radius: four
/// times the other patterns', so its dots don't visibly repeat.
double sparkleTile(double unitPx) => (math.max(8, (unitPx * 0.075).round()) * 4).toDouble();

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
  if (pos == 0) return;
  if (pos.isOdd) canvas.scale(-1, 1);
  canvas.rotate(-pos * math.pi / folds);
}

/// [drawGlints] for a paper wedge drawn by [drawWedge] (same [s], [cuts],
/// [half] and segment [pos] of [folds]), kept to the paper.
void drawWedgeGlints(Canvas canvas, double s, List<Cut> cuts, double half, Color color, double time, {int pos = 0, int folds = 1}) {
  final bounds = Rect.fromCircle(center: Offset.zero, radius: s * 1.3);
  canvas.saveLayer(bounds, Paint());
  canvas.save();
  canvas.clipPath(Path()
    ..moveTo(0, 0)
    ..arcTo(Rect.fromCircle(center: Offset.zero, radius: s), -math.pi / 2 - half, 2 * half, false)
    ..close());
  toSheet(canvas, pos, folds);
  drawGlints(canvas, bounds, color, s, time);
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
      final n = (t * t / 9).round();
      for (var i = 0; i < n; i++) {
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
void drawWedge(Canvas canvas, double s, List<Cut> cuts, double half, Paint fill, {double pad = 0, String? pattern, int pos = 0, int folds = 1, bool sheen = true, double sheenTime = 0}) {
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
  canvas.restore();
  final clear = Paint()..blendMode = BlendMode.clear;
  for (final c in cuts) {
    if (c.length < 3) continue;
    canvas.drawPath(cutPath(c, s)..fillType = PathFillType.nonZero, clear);
  }
  canvas.restore();
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
