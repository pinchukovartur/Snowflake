import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A snowy window frame with glazing bars, snow lying on them and light
/// glinting on the panes. What shows through it should be drawn soft, as if
/// seen through frosted glass.
class WindowFrame extends StatelessWidget {
  const WindowFrame({super.key, this.rows = 4, this.onSill = false});

  /// Panes from top to bottom in each sash.
  final int rows;

  /// A [WindowSill] follows straight on below, so the casing has no bottom
  /// edge of its own.
  final bool onSill;

  /// The clear glass of every pane under the arch in a frame of [size], row by
  /// row from the top, left sash first: room for things clear of the bars.
  static List<Rect> paneRects(Size size, int rows) {
    final inner = (Offset.zero & size).deflate(_casing);
    final base = inner.top + inner.width * _archRise;
    final glasses = [
      Rect.fromLTRB(inner.left, base, inner.center.dx, inner.bottom).deflate(_stile),
      Rect.fromLTRB(inner.center.dx, base, inner.right, inner.bottom).deflate(_stile),
    ];
    return [
      for (final (top, bottom) in _rowSpans(glasses.first.top, glasses.first.bottom, rows))
        for (final g in glasses) Rect.fromLTRB(g.left, top, g.right, bottom),
    ];
  }

  /// Height of a frame [width] wide with [rows] rows of panes [paneHeight] tall.
  static double heightFor(double width, int rows, double paneHeight) =>
      _fixedHeight(width) + rows * paneHeight + [for (var r = 1; r < rows; r++) _barAbove(r)].fold(0.0, (a, b) => a + b);

  /// How tall each of [rows] panes comes out in a frame of [size].
  static double paneHeightFor(Size size, int rows) => heightFor(size.width, rows, 0) <= size.height
      ? (size.height - heightFor(size.width, rows, 0)) / rows
      : 0;

  /// The casing, fanlight and sash rails: the frame's height without its panes and bars.
  static double _fixedHeight(double width) => 2 * _casing + (width - 2 * _casing) * _archRise + 2 * _stile;

  /// Middle height of pane row [row] (0 = the top one under the arch).
  static double paneMiddle(Size size, int rows, int row) => paneRects(size, rows)[row * 2].center.dy;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(fit: StackFit.expand, children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: _sheen)),
        RepaintBoundary(child: CustomPaint(painter: _FramePainter(rows, onSill: onSill))),
      ]),
    );
  }
}

/// Solid wood below a [WindowFrame] with `onSill`: the casing carried on
/// down, bevelled at the sides like it.
class WindowSill extends StatelessWidget {
  const WindowSill({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SillPainter(), size: Size.infinite);
}

class _SillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _wood);
    const w = 1.5;
    canvas.drawLine(const Offset(w / 2, 0), Offset(w / 2, size.height), Paint()
      ..strokeWidth = w
      ..color = _woodLight);
    canvas.drawLine(Offset(size.width - w / 2, 0), Offset(size.width - w / 2, size.height), Paint()
      ..strokeWidth = w
      ..color = _woodDark);
  }

  @override
  bool shouldRepaint(_SillPainter oldDelegate) => false;
}

/// Light on the glass: a faint haze with two diagonal glints.
const _sheen = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0x14FFFFFF), Color(0x26FFFFFF), Color(0x0AFFFFFF), Color(0x1CFFFFFF), Color(0x0AFFFFFF)],
  stops: [0, .22, .42, .55, .8],
);

// Painted wood in the brand's ice blue, lit from the top left.
const _wood = Color(0xFF7D98C6), _woodLight = Color(0xFFB4C8E8), _woodDark = Color(0xFF51689A);

/// Widths in dp: the casing round the screen, each sash's own frame (two of
/// them meet in the middle), and the glazing bars.
const _casing = 16.0, _stile = 9.0, _bar = 7.0;

/// Every [_group] rows the bar is [_groupBar] wide, setting the window out in
/// bands the player can fill each on a theme of their own.
const _group = 3, _groupBar = 18.0;

/// Width of the bar above pane row [r] (r ≥ 1).
double _barAbove(int r) => r % _group == 0 ? _groupBar : _bar;

/// Top and bottom of each of [rows] pane rows in glass running from [top] to
/// [bottom], the bars between them taken out.
List<(double, double)> _rowSpans(double top, double bottom, int rows) {
  var bars = 0.0;
  for (var r = 1; r < rows; r++) {
    bars += _barAbove(r);
  }
  final h = (bottom - top - bars) / rows;
  final spans = <(double, double)>[];
  var y = top;
  for (var r = 0; r < rows; r++) {
    if (r > 0) y += _barAbove(r);
    spans.add((y, y + h));
    y += h;
  }
  return spans;
}

/// Panes across each sash: one, so only the middle stile divides the window
/// upright.
const _cols = 1;

/// The arched fanlight over the sashes: its rise as a share of the window's
/// width, and its spokes' angles from upright.
const _archRise = .36;
const _spokes = [-50 * math.pi / 180, 0.0, 50 * math.pi / 180];

class _FramePainter extends CustomPainter {
  _FramePainter(this._rows, {required this.onSill});
  final int _rows;
  final bool onSill;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final inner = outer.deflate(_casing);
    // The springing line: the fanlight above, the sashes below.
    final base = inner.top + inner.width * _archRise;
    var seed = 0;
    _fanlight(canvas, Rect.fromLTRB(inner.left, inner.top, inner.right, base), seed++);
    final body = Rect.fromLTRB(inner.left, base, inner.right, inner.bottom);
    final sashes = [
      Rect.fromLTRB(body.left, body.top, body.center.dx, body.bottom),
      Rect.fromLTRB(body.center.dx, body.top, body.right, body.bottom),
    ];
    for (final sash in sashes) {
      final glass = sash.deflate(_stile);
      final paneW = glass.width / _cols;
      final spans = _rowSpans(glass.top, glass.bottom, _rows);
      // Snow on the sill outside every bar and the bottom rail, a drift per
      // pane: behind the glass, so the wood hides its foot.
      for (var r = 1; r <= _rows; r++) {
        final last = r == _rows;
        final top = last ? glass.bottom : spans[r - 1].$2;
        for (var c = 0; c < _cols; c++) {
          final x0 = glass.left + c * paneW + (c > 0 ? _bar / 2 : 0);
          final x1 = glass.left + (c + 1) * paneW - (c < _cols - 1 ? _bar / 2 : 0);
          _snow(canvas, x0, x1, top, last ? _stile : _barAbove(r), seed++);
        }
      }
      for (final (top, bottom) in spans) {
        for (var c = 0; c < _cols; c++) {
          _shadeGlass(canvas, Rect.fromLTRB(glass.left + c * paneW, top, glass.left + (c + 1) * paneW, bottom));
        }
      }
      for (var c = 1; c < _cols; c++) {
        _woodBar(canvas, Rect.fromCenter(center: Offset(glass.left + c * paneW, glass.center.dy), width: _bar, height: glass.height));
      }
      for (var r = 1; r < _rows; r++) {
        _woodBar(canvas, Rect.fromLTRB(glass.left, spans[r - 1].$2, glass.right, spans[r].$1));
      }
      _woodRing(canvas, sash, glass);
    }
    _woodRing(canvas, outer, inner, openBottom: onSill);
    _handle(canvas, Offset(sashes[1].left + _stile / 2, body.top + body.height * .55));
  }

  /// Half-elliptical fanlight filling [r] (the ellipse's centre at the middle
  /// of its bottom edge): snow on its sill, spokes fanning out from the
  /// middle, and wood round the glass up into the corners of the casing.
  static void _fanlight(Canvas canvas, Rect r, int seed) {
    final c = r.bottomCenter;
    final a = r.width / 2, b = r.height;
    _snow(canvas, r.left + _stile, r.right - _stile, r.bottom - _stile, _stile, seed);
    for (final phi in _spokes) {
      // Out to the arch, which covers the end.
      final len = 1 / math.sqrt(math.pow(math.sin(phi) / a, 2) + math.pow(math.cos(phi) / b, 2));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(phi);
      _woodBar(canvas, Rect.fromLTWH(-_bar / 2, -len, _bar, len));
      canvas.restore();
    }
    final glass = Path.combine(
      PathOperation.intersect,
      Path()..addOval(Rect.fromCenter(center: c, width: 2 * (a - _stile), height: 2 * (b - _stile))),
      Path()..addRect(Rect.fromLTRB(r.left, r.top, r.right, r.bottom - _stile)),
    );
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(r), glass), Paint()..color = _wood);
    // The opening steps down into the wood: shaded along the arch, lit along the sill.
    canvas.save();
    canvas.clipPath(glass);
    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _woodDark,
    );
    canvas.drawLine(
      Offset(r.left, r.bottom - _stile - .75),
      Offset(r.right, r.bottom - _stile - .75),
      Paint()
        ..strokeWidth = 1.5
        ..color = _woodLight,
    );
    canvas.restore();
  }

  /// The wood's shadow falling on the glass along a pane's top and left.
  static void _shadeGlass(Canvas canvas, Rect pane) {
    const depth = 7.0, shade = Color(0x30101A3F), clear = Color(0x00101A3F);
    canvas.drawRect(
      Rect.fromLTWH(pane.left, pane.top, pane.width, depth),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [shade, clear]).createShader(Rect.fromLTWH(pane.left, pane.top, pane.width, depth)),
    );
    canvas.drawRect(
      Rect.fromLTWH(pane.left, pane.top, depth, pane.height),
      Paint()..shader = const LinearGradient(colors: [shade, clear]).createShader(Rect.fromLTWH(pane.left, pane.top, depth, pane.height)),
    );
  }

  /// Bevel lines just inside [r]: [tl] along the top and left, [br] along the
  /// bottom (unless not [bottom]) and right.
  static void _edges(Canvas canvas, Rect r, Color tl, Color br, {bool bottom = true}) {
    const w = 1.5;
    final e = r.deflate(w / 2);
    final light = Paint()
      ..strokeWidth = w
      ..color = tl;
    final dark = Paint()
      ..strokeWidth = w
      ..color = br;
    canvas.drawLine(e.topLeft, e.topRight, light);
    canvas.drawLine(e.topLeft, e.bottomLeft, light);
    if (bottom) canvas.drawLine(e.bottomLeft, e.bottomRight, dark);
    canvas.drawLine(e.topRight, e.bottomRight, dark);
  }

  static void _woodBar(Canvas canvas, Rect r) {
    canvas.drawRect(r, Paint()..color = _wood);
    _edges(canvas, r, _woodLight, _woodDark);
  }

  /// A frame: wood between [outer] and [inner], raised outside and stepping
  /// down into the opening; with [openBottom] the wood runs on below.
  static void _woodRing(Canvas canvas, Rect outer, Rect inner, {bool openBottom = false}) {
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(outer)
        ..addRect(inner),
      Paint()..color = _wood,
    );
    _edges(canvas, outer, _woodLight, _woodDark, bottom: !openBottom);
    _edges(canvas, inner.inflate(1.5), _woodDark, _woodLight);
  }

  /// A drift on the sill behind the bar whose top is at [top], between [x0]
  /// and [x1]: heaped unevenly above the bar and thinning out at the ends. It
  /// reaches down into the bar ([barH] deep) so the wood, painted over it,
  /// covers its foot.
  static void _snow(Canvas canvas, double x0, double x1, double top, double barH, int seed) {
    final rnd = math.Random(seed * 7919 + 13);
    final p1 = rnd.nextDouble() * 2 * math.pi, p2 = rnd.nextDouble() * 2 * math.pi;
    final heap = 1.0 + rnd.nextDouble() * 1.5;
    double ramp(double x) {
      final d = (math.min(x - x0, x1 - x) / 10).clamp(0.0, 1.0);
      return d * d * (3 - 2 * d);
    }

    double up(double x) => (5 + heap * math.sin(x * .07 + p1) + 1.2 * math.sin(x * .19 + p2)) * ramp(x);

    final foot = top + barH / 2;
    final path = Path()..moveTo(x0, foot);
    for (var x = x0; x < x1; x += 2) {
      path.lineTo(x, top - up(x));
    }
    path
      ..lineTo(x1, top)
      ..lineTo(x1, foot)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  /// Window latch on the stile where the sashes meet.
  static void _handle(Canvas canvas, Offset at) {
    final plate = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: 9, height: 34), const Radius.circular(4.5));
    canvas.drawRRect(plate.shift(const Offset(0, 1.5)), Paint()..color = const Color(0x40101A3F));
    canvas.drawRRect(plate, Paint()..color = const Color(0xFFDCE4F0));
    canvas.drawRRect(
      plate.deflate(.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF8FA1BE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: at + const Offset(0, 3), width: 4, height: 20), const Radius.circular(2)),
      Paint()..color = const Color(0xFF8FA1BE),
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate._rows != _rows || oldDelegate.onSill != onSill;
}
