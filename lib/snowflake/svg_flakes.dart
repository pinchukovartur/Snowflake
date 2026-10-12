import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';

import 'geometry.dart';

/// Where flakes drawn on a wedge template (tools/flake_templates) go: each
/// `name.svg` there becomes the preset `name`.
const _folder = 'assets/flakes/';

/// The templates' wedge: its point (the flake's centre) and its radius, in
/// SVG units; and its fill, by which it is known (exports may lose the
/// group's name).
const _apex = Offset(500, 1050);
const _radius = 1000.0;
const _templateFill = '#eaf4ff';

/// Decodes the paper patterns' textures into [paperTextures].
Future<void> loadPaperTextures() async {
  for (final MapEntry(key: pattern, value: asset) in textureAssets.entries) {
    final codec = await instantiateImageCodec((await rootBundle.load(asset)).buffer.asUint8List());
    paperTextures[pattern] = (await codec.getNextFrame()).image;
  }
}

/// Adds every flake in [_folder] to [snowflakePresets].
Future<void> loadSvgFlakes() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  for (final asset in manifest.listAssets()) {
    if (!asset.startsWith(_folder) || !asset.endsWith('.svg')) continue;
    final name = asset.substring(_folder.length, asset.length - 4);
    snowflakePresets[name] = flakeFromSvg(await rootBundle.loadString(asset));
  }
}

/// The cuts a wedge template's drawing makes: its filled shapes cut away, or,
/// if there is a group named "paper", only the paper drawn in it left (less
/// any shapes outside it). The template (its group, or anything in its
/// fill), unfilled shapes, and anything defined rather than drawn are left
/// out.
List<Cut> flakeFromSvg(String svg) {
  Path? paper;
  var cuts = Path();
  final size = _viewBox(svg);
  // Open groups, with what each brings: its transform, its name, and the
  // fill it passes down.
  final groups = <({String tag, Float64List m, String name, String fill})>[];
  for (final t in RegExp(r'<(/?)([\w:]+)([^>]*?)(/?)>', dotAll: true).allMatches(svg)) {
    final closing = t[1]!.isNotEmpty, tag = t[2]!, attrs = t[3]!, empty = t[4]!.isNotEmpty;
    if (closing) {
      final i = groups.lastIndexWhere((g) => g.tag == tag);
      if (i >= 0) groups.removeRange(i, groups.length);
      continue;
    }
    final parent = groups.isEmpty ? _identity() : groups.last.m;
    final m = _times(parent, _transform(_attr(attrs, 'transform')));
    final name = _attr(attrs, 'inkscape:label') ?? _attr(attrs, 'id') ?? '';
    final fill = (_style(attrs, 'fill') ?? _attr(attrs, 'fill') ?? (groups.isEmpty ? 'black' : groups.last.fill)).toLowerCase();
    if (!empty && const {'g', 'svg', 'defs', 'clipPath', 'mask', 'symbol', 'pattern', 'a'}.contains(tag)) {
      groups.add((tag: tag, m: m, name: name, fill: fill));
      continue;
    }
    final names = groups.map((g) => g.name.toLowerCase());
    if (names.contains('template') || groups.any((g) => const {'defs', 'clipPath', 'mask', 'symbol', 'pattern'}.contains(g.tag))) continue;
    if (fill == 'none' || fill == 'transparent' || fill == _templateFill) continue;
    final shape = _shape(tag, attrs, size);
    if (shape == null) continue;
    final placed = shape.transform(_times(_toWedge(), m));
    if (names.contains('paper')) {
      paper = paper == null ? placed : Path.combine(PathOperation.union, paper, placed);
    } else {
      cuts = Path.combine(PathOperation.union, cuts, placed);
    }
  }
  final all = Path()..addRect(const Rect.fromLTRB(-2, -2, 2, 1));
  return cutsLeaving(Path.combine(PathOperation.difference, paper ?? all, cuts));
}

/// The drawing's own size, from its view box or else its width and height.
Size _viewBox(String svg) {
  final root = RegExp(r'<svg\b[^>]*>', dotAll: true).firstMatch(svg)?[0] ?? '';
  final box = _attr(root, 'viewBox');
  if (box != null) {
    final n = _numbers(box);
    if (n.length == 4) return Size(n[2], n[3]);
  }
  return Size(_number(_attr(root, 'width')) ?? 1000, _number(_attr(root, 'height')) ?? 1100);
}

/// A drawn shape as a path, in SVG units; null if [tag] draws none, or it
/// fills the whole drawing (as a frame's background does).
Path? _shape(String tag, String a, Size size) {
  double n(String k, [double or = 0]) => _number(_attr(a, k)) ?? or;
  final path = Path()..fillType = (_attr(a, 'fill-rule') ?? _style(a, 'fill-rule')) == 'evenodd' ? PathFillType.evenOdd : PathFillType.nonZero;
  switch (tag) {
    case 'path':
      _addPathData(path, _attr(a, 'd') ?? '');
    case 'rect':
      final r = Rect.fromLTWH(n('x'), n('y'), n('width'), n('height'));
      if (r.left <= 0 && r.top <= 0 && r.right >= size.width && r.bottom >= size.height) return null;
      final rx = n('rx', n('ry')), ry = n('ry', rx);
      path.addRRect(RRect.fromRectXY(r, rx, ry));
    case 'circle':
      path.addOval(Rect.fromCircle(center: Offset(n('cx'), n('cy')), radius: n('r')));
    case 'ellipse':
      path.addOval(Rect.fromCenter(center: Offset(n('cx'), n('cy')), width: 2 * n('rx'), height: 2 * n('ry')));
    case 'polygon' || 'polyline':
      final p = _numbers(_attr(a, 'points') ?? '');
      path.addPolygon([for (var i = 0; i + 1 < p.length; i += 2) Offset(p[i], p[i + 1])], true);
    default:
      return null;
  }
  return path;
}

/// Path data (`d`) drawn onto [path]: lines, curves and arcs, absolute or
/// relative.
void _addPathData(Path path, String d) {
  final tokens = RegExp(r'[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?').allMatches(d).map((m) => m[0]!).toList();
  var i = 0;
  var cmd = '';
  var at = Offset.zero, start = Offset.zero;
  // The last curve's second control point, for the smooth ones that mirror it.
  Offset? lastCubic, lastQuad;
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double next() => double.parse(tokens[i++]);
  // Flags in arcs may run together with no separator ("01").
  bool flag() {
    final t = tokens[i];
    if (t.length > 1 && (t[0] == '0' || t[0] == '1') && !t.contains('.')) {
      tokens[i] = t.substring(1);
      return t[0] == '1';
    }
    i++;
    return t == '1' || double.parse(t) != 0;
  }

  while (i < tokens.length) {
    if (isCmd(tokens[i])) {
      cmd = tokens[i++];
    } else if (cmd.isEmpty) {
      i++;
      continue;
    }
    final rel = cmd == cmd.toLowerCase();
    Offset pt() {
      final p = Offset(next(), next());
      return rel ? at + p : p;
    }

    var cubic = false, quad = false;
    switch (cmd.toUpperCase()) {
      case 'M':
        at = start = pt();
        path.moveTo(at.dx, at.dy);
        // Pairs after the first are lines.
        cmd = rel ? 'l' : 'L';
      case 'L':
        at = pt();
        path.lineTo(at.dx, at.dy);
      case 'H':
        at = Offset(rel ? at.dx + next() : next(), at.dy);
        path.lineTo(at.dx, at.dy);
      case 'V':
        at = Offset(at.dx, rel ? at.dy + next() : next());
        path.lineTo(at.dx, at.dy);
      case 'C':
        final c1 = pt(), c2 = pt(), p = pt();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p.dx, p.dy);
        lastCubic = c2;
        at = p;
        cubic = true;
      case 'S':
        final c1 = lastCubic == null ? at : at * 2 - lastCubic;
        final c2 = pt(), p = pt();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p.dx, p.dy);
        lastCubic = c2;
        at = p;
        cubic = true;
      case 'Q':
        final c = pt(), p = pt();
        path.quadraticBezierTo(c.dx, c.dy, p.dx, p.dy);
        lastQuad = c;
        at = p;
        quad = true;
      case 'T':
        final c = lastQuad == null ? at : at * 2 - lastQuad;
        final p = pt();
        path.quadraticBezierTo(c.dx, c.dy, p.dx, p.dy);
        lastQuad = c;
        at = p;
        quad = true;
      case 'A':
        final rx = next().abs(), ry = next().abs(), rot = next();
        final large = flag(), sweep = flag();
        final p = pt();
        path.arcToPoint(p, radius: Radius.elliptical(rx, ry), rotation: rot, largeArc: large, clockwise: sweep);
        at = p;
      case 'Z':
        path.close();
        at = start;
    }
    if (!cubic) lastCubic = null;
    if (!quad) lastQuad = null;
  }
}

String? _attr(String attrs, String name) =>
    RegExp('(?:^|\\s)${RegExp.escape(name)}\\s*=\\s*["\']([^"\']*)["\']').firstMatch(attrs)?[1];

/// A property set in the `style` attribute.
String? _style(String attrs, String name) =>
    RegExp('(?:^|;)\\s*${RegExp.escape(name)}\\s*:\\s*([^;]+)').firstMatch(_attr(attrs, 'style') ?? '')?[1]?.trim();

double? _number(String? s) => s == null ? null : double.tryParse(RegExp(r'[-+.\deE]+').firstMatch(s)?[0] ?? '');

List<double> _numbers(String s) => [for (final m in RegExp(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?').allMatches(s)) double.parse(m[0]!)];

// ---- 2D transforms, as 4×4 column-major matrices (what Path.transform takes)

Float64List _identity() => _affine(1, 0, 0, 1, 0, 0);

/// The SVG matrix(a b c d e f).
Float64List _affine(double a, double b, double c, double d, double e, double f) =>
    Float64List.fromList([a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]);

Float64List _times(Float64List x, Float64List y) {
  final r = Float64List(16);
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 4; j++) {
      var s = 0.0;
      for (var k = 0; k < 4; k++) {
        s += x[k * 4 + i] * y[j * 4 + k];
      }
      r[j * 4 + i] = s;
    }
  }
  return r;
}

/// A `transform` attribute's list, applied right to left as SVG does.
Float64List _transform(String? t) {
  var m = _identity();
  if (t == null) return m;
  for (final f in RegExp(r'(\w+)\s*\(([^)]*)\)').allMatches(t)) {
    final v = _numbers(f[2]!);
    final step = switch (f[1]) {
      'matrix' when v.length == 6 => _affine(v[0], v[1], v[2], v[3], v[4], v[5]),
      'translate' when v.isNotEmpty => _affine(1, 0, 0, 1, v[0], v.length > 1 ? v[1] : 0),
      'scale' when v.isNotEmpty => _affine(v[0], 0, 0, v.length > 1 ? v[1] : v[0], 0, 0),
      'rotate' when v.isNotEmpty => () {
          final a = v[0] * math.pi / 180, c = math.cos(a), s = math.sin(a);
          final cx = v.length > 2 ? v[1] : 0.0, cy = v.length > 2 ? v[2] : 0.0;
          return _times(_times(_affine(1, 0, 0, 1, cx, cy), _affine(c, s, -s, c, 0, 0)), _affine(1, 0, 0, 1, -cx, -cy));
        }(),
      'skewX' when v.isNotEmpty => _affine(1, 0, math.tan(v[0] * math.pi / 180), 1, 0, 0),
      'skewY' when v.isNotEmpty => _affine(1, math.tan(v[0] * math.pi / 180), 0, 1, 0, 0),
      _ => _identity(),
    };
    m = _times(m, step);
  }
  return m;
}

/// From the templates' SVG units to wedge units (centre at the origin,
/// radius 1).
Float64List _toWedge() => _affine(1 / _radius, 0, 0, 1 / _radius, -_apex.dx / _radius, -_apex.dy / _radius);
