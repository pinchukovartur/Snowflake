import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A snowy window frame with glazing bars and snow lying on them, as in
/// assets/UI/Window.svg: under an arched fanlight a sash each side, one pane
/// across, the frame's pieces flat paint lit along their top edges and
/// casting a soft shadow down. What shows through it should be drawn soft,
/// as if seen through frosted glass.
class WindowFrame extends StatelessWidget {
  const WindowFrame({super.key, this.rows = 4, this.snow = true, this.door = 0, this.index = 0, this.windows = 1});

  /// Panes from top to bottom in each sash.
  final int rows;

  /// Snow lying on the bars and sills outside (winter).
  final bool snow;

  /// Bottom rows given over to a door (none if 0): the sashes stop above it,
  /// its opening (see [doorRect]) left for a [WindowDoor] to fill.
  final int door;

  /// Where this window stands in its row, from the left: neighbours take
  /// turns to have a handle on each broad bar, a chequer across them.
  final int index;

  /// Windows in the row: the outer stiles at its ends run whole up the
  /// sides.
  final int windows;

  /// The opening for a door taking the bottom [door] rows in a frame of
  /// [size]: right across, from the rail under the last pane above it down
  /// to the frame's foot.
  static Rect doorRect(Size size, int rows, int door) {
    final glass = paneRects(size, rows);
    return Rect.fromLTRB(0, glass[(rows - door) * 2 - 1].bottom + _stile, size.width, size.height);
  }

  /// The clear glass of every pane under the arch in a frame of [size], row by
  /// row from the top, left sash first: room for things clear of the bars.
  static List<Rect> paneRects(Size size, int rows) {
    final top = _base(size.width) + _stile, bottom = size.height - _stile, mid = size.width / 2;
    final columns = [(_stile, mid - _meet), (mid + _meet, size.width - _stile)];
    return [
      for (final (t, b) in _rowSpans(top, bottom, rows))
        for (final (l, r) in columns) Rect.fromLTRB(l, t, r, b),
    ];
  }

  /// Height of a frame [width] wide with [rows] rows of panes [paneHeight] tall.
  static double heightFor(double width, int rows, double paneHeight) =>
      _fixedHeight(width) + rows * paneHeight + [for (var r = 1; r < rows; r++) _barAbove(r)].fold(0.0, (a, b) => a + b);

  /// How tall each of [rows] panes comes out in a frame of [size].
  static double paneHeightFor(Size size, int rows) => heightFor(size.width, rows, 0) <= size.height
      ? (size.height - heightFor(size.width, rows, 0)) / rows
      : 0;

  /// The fanlight and the sashes' top and bottom rails: the frame's height
  /// without its panes and bars.
  static double _fixedHeight(double width) => _base(width) + 2 * _stile;

  /// Middle height of pane row [row] (0 = the top one under the arch).
  static double paneMiddle(Size size, int rows, int row) => paneRects(size, rows)[row * 2].center.dy;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: _glass),
        RepaintBoundary(child: CustomPaint(painter: _FramePainter(rows, snow: snow, door: door, index: index, windows: windows))),
      ]),
    );
  }
}

/// A glass dome roofing [windows] [WindowFrame]s side by side, filling its
/// box (as wide as they are, and [heightFor] tall): half an ellipse rising
/// from their tops, glazed between bars, a rib curving up to the top from
/// each sash's edge (broad where two windows meet), and two rings round it.
class WindowDome extends StatelessWidget {
  const WindowDome({super.key, required this.windows});
  final int windows;

  /// The dome's height over windows each [windowWidth] wide.
  static double heightFor(double windowWidth) => windowWidth * .9;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _DomePainter(windows), size: Size.infinite));
}

/// The heights of the dome's rings, as shares of its own.
const _domeRings = [.32, .64];

class _DomePainter extends CustomPainter {
  _DomePainter(this.windows);
  final int windows;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height);
    final a = size.width / 2, b = size.height;
    Rect oval(double halfWidth) => Rect.fromCenter(center: c, width: 2 * halfWidth, height: 2 * b);
    final shell = Path()
      ..addArc(oval(a), math.pi, math.pi)
      ..close();
    canvas.save();
    canvas.clipPath(shell);
    // The glass, veiled like the windows', and catching more of the sky's
    // light the higher it curves.
    canvas.drawColor(_glass, BlendMode.srcOver);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x00FFFFFF), Color(0x26FFFFFF), Color(0xBFFFFFFF)],
          stops: [0, .5, 1],
        ).createShader(Offset.zero & size),
    );
    // A rib curving up to the top from [x] at the foot, [width] wide, lit
    // from the top left like the rim.
    void rib(double x, double width) {
      final half = (x - c.dx).abs();
      final band = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCenter(center: c, width: 2 * half + width, height: 2 * b + width)),
        Path()..addOval(Rect.fromCenter(center: c, width: 2 * half - width, height: 2 * b - width)),
      );
      final quarter = x < c.dx ? Rect.fromLTRB(0, 0, c.dx, b) : Rect.fromLTRB(c.dx, 0, size.width, b);
      _piece(canvas, Path.combine(PathOperation.intersect, band, Path()..addRect(quarter)), _rounded);
    }

    // The rings, straight across seen from the front.
    for (final f in _domeRings) {
      final half = a * math.sqrt(1 - f * f);
      _rectPiece(canvas, Rect.fromCenter(center: Offset(c.dx, b - b * f), width: 2 * half, height: _bar), _across);
    }
    // The ribs from every sash's edge, all the way up: broad where two
    // windows meet, as wide as their stiles side by side there; and up the
    // middle, a bar like the fanlights' upright spokes.
    for (var i = 1; i < 2 * windows; i++) {
      final x = size.width * i / (2 * windows);
      if ((x - c.dx).abs() >= 1) rib(x, i.isEven ? 2 * _stile : _bar);
    }
    _rectPiece(canvas, Rect.fromLTRB(c.dx - _bar / 2, 0, c.dx + _bar / 2, b), _mullion);
    // Its rim, as deep as the windows' stiles, lit along its outside and
    // shaded along its inside like the ribs, from the top left.
    final inside = Rect.fromCenter(center: c, width: 2 * (a - _stile), height: 2 * (b - _stile));
    final rim = Path.combine(PathOperation.difference, shell, Path()..addOval(inside));
    _piece(canvas, rim, _rounded);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DomePainter oldDelegate) => oldDelegate.windows != windows;
}

/// Snowflakes landing on a [WindowDome] (laid over it, the same size): each
/// a soft white spot that spreads a little as it fades away, here and there
/// on the glass, one after another as [ticker] runs.
class DomeSnow extends StatelessWidget {
  const DomeSnow({super.key, required this.ticker});
  final AnimationController ticker;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _DomeSnowPainter(ticker), size: Size.infinite)));
}

class _DomeSnowPainter extends CustomPainter {
  _DomeSnowPainter(this.ticker) : super(repaint: ticker);
  final AnimationController ticker;

  /// Flakes landing at once at most: each lands, fades over [_life] seconds,
  /// and lands again somewhere else after a while of its own.
  static const _slots = 21;
  static const _life = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final t = ticker.value * ticker.duration!.inMicroseconds / 1e6;
    final c = Offset(size.width / 2, size.height);
    final a = size.width / 2 - _stile, b = size.height - _stile;
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCenter(center: c, width: 2 * a, height: 2 * b)));
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    for (var i = 0; i < _slots; i++) {
      final own = math.Random(i * 7919 + 1);
      final period = 3.5 + own.nextDouble() * 2.5, start = own.nextDouble() * period;
      final since = t + start;
      final cycle = (since / period).floor();
      final age = since - cycle * period;
      if (age > _life) continue;
      // Where this landing falls: anywhere on the glass.
      final r = math.Random(i * 104729 + cycle * 31 + 7);
      final x = (r.nextDouble() * 2 - 1) * .95;
      final y = math.sqrt(1 - x * x) * r.nextDouble();
      final at = Offset(c.dx + x * a, c.dy - y * b);
      final k = age / _life;
      paint.color = Colors.white.withValues(alpha: .85 * (1 - k) * (1 - k));
      canvas.drawCircle(at, (2 + r.nextDouble() * 2) * (1 + .5 * k), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DomeSnowPainter oldDelegate) => oldDelegate.ticker != ticker;
}

/// Solid wood below a row of [WindowFrame]s: their stiles carried on down,
/// lit at the left edge and shaded at the right like them.
class WindowSill extends StatelessWidget {
  const WindowSill({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SillPainter(), size: Size.infinite);
}

class _SillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final edge = _upright.lit.dx;
    canvas.drawRect(Offset.zero & size, Paint()..color = _wood);
    canvas.drawRect(Rect.fromLTWH(0, 0, edge, size.height), Paint()..color = _woodLight);
    canvas.drawRect(Rect.fromLTWH(size.width - edge, 0, edge, size.height), Paint()..color = _woodDark);
  }

  @override
  bool shouldRepaint(_SillPainter oldDelegate) => false;
}

/// The floor under a [WindowSill], darker than the wood. Light through
/// [windows] windows side by side lies on it in squares, a streak of them
/// from each sash, slanting away from the middle of the row and fading as
/// they go; none from the one with a door ([door]).
class WindowFloor extends StatelessWidget {
  const WindowFloor({super.key, this.windows = 1, this.door = -1});
  final int windows, door;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FloorPainter(windows, door), size: Size.infinite);
}

class _FloorPainter extends CustomPainter {
  _FloorPainter(this.windows, this.door);
  final int windows, door;

  /// How far a streak slants out across its length, as a share of the
  /// floor's height: all by the same, so they run side by side, never
  /// crossing.
  static const _slant = 1.0;

  /// Squares down each streak, and the shadow between them, as a share of
  /// its length.
  static const _squares = 2, _gap = .06;

  /// Where the squares lie down the floor, as shares of its height: out from
  /// the wall, the light falling further into the room.
  static const _from = .18, _to = .90;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _floor);
    final w = size.width / windows, h = size.height, middle = size.width / 2;
    final light = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
      ).createShader(Offset.zero & size);
    for (var i = 0; i < windows; i++) {
      if (i == door) continue;
      final left = i * w, centre = left + w / 2;
      // Slanting away from the middle (straight down in it), mirrored.
      final out = ((centre - middle) / middle).clamp(-1.0, 1.0);
      for (final (x0, x1) in [(left + _stile, centre - _meet), (centre + _meet, left + w - _stile)]) {
        final shift = out * h * _slant;
        // The streak's edges at [t] of the way down.
        Offset leftAt(double t) => Offset(x0 + shift * t, h * t);
        Offset rightAt(double t) => Offset(x1 + shift * t, h * t);
        // In squares, as the panes cast it, the bars between them shadows.
        for (var k = 0; k < _squares; k++) {
          double at(double share) => _from + (_to - _from) * share;
          final t0 = at(k / _squares + _gap / 2), t1 = at((k + 1) / _squares - _gap / 2);
          canvas.drawPath(Path()..addPolygon([leftAt(t0), rightAt(t0), rightAt(t1), leftAt(t1)], true), light);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FloorPainter oldDelegate) => oldDelegate.windows != windows || oldDelegate.door != door;
}

/// The glass itself: a white veil over what shows through.
const _glass = Color(0x1AFFFFFF);

// The frame's paint, its lit and shaded edges and the shadow it casts, as in
// the assets/UI textures.
const _wood = Color(0xFF8B5A2B), _woodLight = Color.fromARGB(255, 109, 63, 41), _woodDark = Color(0xFF5E3A1A);
const _shadow = Color(0x1A000000);
const _blur = MaskFilter.blur(BlurStyle.normal, 1.5);

/// The handles' and hinges' metal: gold, and its darker edge.
const _gold = Color(0xFFF2C14E), _goldEdge = Color(0xFFB07F24);

/// The floor, darker than the wood's shaded edge.
const _floor = Color(0xFF3F5384);

/// How a piece of the frame is lit: the light edge along its sides facing up
/// and left, as thick as [lit] there (the shaded one opposite), and its
/// shadow cast [drop] away.
typedef _Light = ({Offset lit, Offset drop});

/// Stiles (AllSided.png); rails, bars and slanting spokes (Top_Bottom.png);
/// upright spokes (Left_Right.png).
const _Light _upright = (lit: Offset(1, 2), drop: Offset(4, 4));
const _Light _across = (lit: Offset(0, 2), drop: Offset(0, 4));
const _Light _mullion = (lit: Offset(2, 0), drop: Offset(0, 4));

/// Curved pieces (the dome's ribs and rim, the pinwheel's mound): lit along
/// whichever sides face up and left.
const _Light _rounded = (lit: Offset(2, 2), drop: Offset(0, 4));

/// Widths in dp: the sashes' stiles and rails, and the transom under the
/// fanlight (two stiles meet where windows meet); the glazing bars; the
/// fanlight's spokes.
const _stile = 12.0, _bar = 8.0, _spoke = 7.0;

/// Each sash's stile where the two in a window meet: narrower, so the strip
/// between windows stands out, setting them out in pairs of columns.
const _meet = 6.0;

/// The arch's inset from the frame's top and sides.
const _archTop = 12.0, _archSide = 17.0;

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

/// The springing line in a frame [width] wide: the fanlight above, the
/// sashes below, the transom just over it.
double _base(double width) => width * _archRise;

/// The fanlight's height, to the bottom of the transom, as a share of the
/// window's width; its spokes' angles from upright.
const _archRise = .37;
const _spokes = [-50 * math.pi / 180, 0.0, 50 * math.pi / 180];

/// A piece of the frame shaped [shape], lit as [light] says.
void _piece(Canvas canvas, Path shape, _Light light) {
  canvas.drawPath(shape.shift(light.drop), Paint()
    ..color = _shadow
    ..maskFilter = _blur);
  canvas.drawPath(shape, Paint()..color = _wood);
  canvas.drawPath(Path.combine(PathOperation.difference, shape, shape.shift(light.lit)), Paint()..color = _woodLight);
  canvas.drawPath(Path.combine(PathOperation.difference, shape, shape.shift(-light.lit)), Paint()..color = _woodDark);
}

/// [_piece] for a rectangle [r] square to the screen, quicker.
void _rectPiece(Canvas canvas, Rect r, _Light light) {
  final dx = light.lit.dx, dy = light.lit.dy;
  canvas.drawRect(r.shift(light.drop), Paint()
    ..color = _shadow
    ..maskFilter = _blur);
  canvas.drawRect(r, Paint()..color = _wood);
  final lit = Paint()..color = _woodLight, dark = Paint()..color = _woodDark;
  canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, dy), lit);
  canvas.drawRect(Rect.fromLTWH(r.left, r.top, dx, r.height), lit);
  canvas.drawRect(Rect.fromLTRB(r.left, r.bottom - dy, r.right, r.bottom), dark);
  canvas.drawRect(Rect.fromLTRB(r.right - dx, r.top, r.right, r.bottom), dark);
}

/// A spoke [phi] from upright out of [centre], [length] long.
void _spokePiece(Canvas canvas, Offset centre, double phi, double length) {
  final matrix = Matrix4.translationValues(centre.dx, centre.dy, 0)..rotateZ(phi);
  final spoke = (Path()..addRect(Rect.fromLTWH(-_spoke / 2, -length, _spoke, length))).transform(matrix.storage);
  _piece(canvas, spoke, phi == 0 ? _mullion : _across);
}

class _FramePainter extends CustomPainter {
  _FramePainter(this._rows, {required this.snow, required this.door, required this.index, required this.windows});
  final int _rows, door, index, windows;
  final bool snow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, mid = w / 2, base = _base(w);
    var seed = 0;
    // Over a door, the sashes stop short, keeping their panes where they were.
    final rows = _rows - door;
    final bottom = door > 0 ? WindowFrame.doorRect(size, _rows, door).top : size.height;
    final panes = WindowFrame.paneRects(size, _rows);
    // The fanlight's sill, the transom's top, snowed on.
    if (snow) _snow(canvas, _archSide, w - _archSide, base - _stile, _stile, seed++);
    for (var s = 0; s < 2; s++) {
      final left = s == 0 ? 0.0 : mid, right = s == 0 ? mid : w;
      final inLeft = left + (s == 0 ? _stile : _meet), inRight = right - (s == 0 ? _meet : _stile);
      // Snow on the sill outside every bar and the bottom rail, a drift per
      // pane: behind the glass, so the wood hides its foot.
      final edges = [base, for (var r = 0; r < rows; r++) ...[panes[r * 2 + s].top, panes[r * 2 + s].bottom], bottom];
      for (var r = 0; r < rows; r++) {
        final top = edges[2 * r + 2];
        if (snow) _snow(canvas, inLeft, inRight, top, edges[2 * r + 3] - top, seed);
        seed++;
      }
      // The stiles, then the rails across between them.
      _rectPiece(canvas, Rect.fromLTRB(left, base, inLeft, bottom), _upright);
      _rectPiece(canvas, Rect.fromLTRB(inRight, base, right, bottom), _upright);
      for (var i = 0; i < edges.length; i += 2) {
        _rectPiece(canvas, Rect.fromLTRB(inLeft - 1, edges[i], inRight + 1, edges[i + 1]), _across);
      }
    }
    // The fanlight: spokes out of the middle of the springing line, then the
    // wood round its opening (the transom under it, the spandrels over it)
    // covering their ends, lit like the door's.
    final a = mid - _archSide, b = base - _archTop;
    final opening = Path.combine(
      PathOperation.intersect,
      Path()..addOval(Rect.fromCenter(center: Offset(mid, base), width: 2 * a, height: 2 * b)),
      Path()..addRect(Rect.fromLTRB(0, 0, w, base - _stile)),
    );
    // Kept to the glass, their feet and shadows not showing under the transom.
    canvas.save();
    canvas.clipPath(opening);
    for (final phi in _spokes) {
      final reach = 1 / math.sqrt(math.pow(math.sin(phi) / a, 2) + math.pow(math.cos(phi) / b, 2));
      _spokePiece(canvas, Offset(mid, base), phi, reach + 2);
    }
    canvas.restore();
    _piece(canvas, Path.combine(PathOperation.difference, Path()..addRect(Rect.fromLTRB(0, 0, w, base)), opening), _upright);
    // At the ends of the row, the outer stile runs whole from the top down,
    // over the transom's end.
    if (index == 0) _rectPiece(canvas, Rect.fromLTRB(0, 0, _stile, bottom), _upright);
    if (index == windows - 1) _rectPiece(canvas, Rect.fromLTRB(w - _stile, 0, w, bottom), _upright);
    // A handle lying along every other broad bar between bands of panes
    // (chequered with the next window's), on the right sash just past where
    // the two meet.
    for (var r = _group; r < rows; r += _group) {
      if ((index + r ~/ _group).isOdd) continue;
      final y = (panes[(r - 1) * 2 + 1].bottom + panes[r * 2 + 1].top) / 2;
      _handle(canvas, Offset(mid + _meet + 6 + _handleLength / 2, y), across: true);
    }
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
    canvas.drawPath(path, Paint()..color = const Color.fromARGB(255, 223, 221, 236));
  }

  /// A handle's plate, along its length.
  static const _handleLength = 34.0;

  /// A handle centred on [at]: upright, or lying [across].
  static void _handle(Canvas canvas, Offset at, {bool across = false}) {
    Rect box(Offset centre, double long, double short) =>
        across ? Rect.fromCenter(center: centre, width: long, height: short) : Rect.fromCenter(center: centre, width: short, height: long);
    final plate = RRect.fromRectAndRadius(box(at, _handleLength, 9), const Radius.circular(4.5));
    canvas.drawRRect(plate.shift(const Offset(0, 1.5)), Paint()..color = const Color(0x40101A3F));
    canvas.drawRRect(plate, Paint()..color = _gold);
    canvas.drawRRect(
      plate.deflate(.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _goldEdge,
    );
  }

  @override
  bool shouldRepaint(_FramePainter oldDelegate) => oldDelegate._rows != _rows || oldDelegate.snow != snow || oldDelegate.door != door || oldDelegate.index != index || oldDelegate.windows != windows;
}

/// A glazed double door filling its box, square: over each leaf a
/// half-round fanlight with spokes, on a transom; under that the leaf,
/// glazed four panes by two down to [glassHeight] and below that (down
/// through the sill to the floor) a sunk wooden panel. Handles on each leaf
/// where they meet; hinges where it meets the windows.
class WindowDoor extends StatelessWidget {
  const WindowDoor({super.key, required this.glassHeight});
  final double glassHeight;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(painter: _DoorPainter(glassHeight), size: Size.infinite));
}

class _DoorPainter extends CustomPainter {
  _DoorPainter(this.glassHeight);
  final double glassHeight;

  /// The leaves' stiles where they meet (wide enough to take the handles),
  /// the transom under the fanlights, [_transom] above the leaves' top
  /// rails, and how far down in it the spokes meet, out of sight.
  static const _meeting = 26.0, _transom = 4.0, _hub = 10.0;

  /// Panes down and across in each leaf.
  static const _rows = 4, _cols = 2;

  @override
  void paint(Canvas canvas, Size size) {
    // The door's own jambs carry on the window's stiles; the sashes' rail
    // over it is its head.
    final inner = Rect.fromLTRB(_stile, 0, size.width - _stile, size.height);
    final openings = Path();
    final fans = <(Offset, double, Path)>[];
    var leafTop = 0.0;
    for (final (left, right) in [
      (inner.left + _stile, inner.center.dx - _meeting),
      (inner.center.dx + _meeting, inner.right - _stile),
    ]) {
      // The fanlight: a half circle as wide as the glass below, on the transom.
      final r = (right - left) / 2, centre = Offset((left + right) / 2, inner.top + _stile + r);
      final fan = Path.combine(
        PathOperation.intersect,
        Path()..addOval(Rect.fromCircle(center: centre, radius: r)),
        Path()..addRect(Rect.fromLTRB(left, centre.dy - r, right, centre.dy)),
      );
      fans.add((centre, r, fan));
      openings.addPath(fan, Offset.zero);
      // The leaf under it: four panes by two, the bars between them left as wood.
      leafTop = centre.dy + _transom;
      final top = leafTop + _stile, bottom = glassHeight - _stile;
      final paneW = (right - left - (_cols - 1) * _bar) / _cols, paneH = (bottom - top - (_rows - 1) * _bar) / _rows;
      for (var row = 0; row < _rows; row++) {
        for (var c = 0; c < _cols; c++) {
          openings.addRect(Rect.fromLTWH(left + c * (paneW + _bar), top + row * (paneH + _bar), paneW, paneH));
        }
      }
      // The panel below the glass, sunk into the wood like the glass.
      final panel = Rect.fromLTRB(left, glassHeight + _stile, right, inner.bottom - _stile);
      canvas.drawRect(panel, Paint()..color = _wood);
      openings.addRect(panel);
    }
    // Spokes fanning out from under each fanlight's middle, kept to its
    // glass, the wood laid after covering their ends.
    for (final (centre, r, fan) in fans) {
      canvas.save();
      canvas.clipPath(fan);
      for (final phi in _spokes) {
        _spokePiece(canvas, centre.translate(0, _hub), phi, r + _hub);
      }
      canvas.restore();
    }
    // Wood everywhere but the openings, lit like the window's stiles.
    _piece(canvas, Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), openings), _upright);
    // Where the leaves meet: a plain line, top to bottom, fanlights and all.
    canvas.drawRect(Rect.fromLTRB(inner.center.dx - 1, 0, inner.center.dx + 1, size.height), Paint()..color = _woodDark);
    // Handles on the stiles each side of it, halfway down the glass.
    final y = (leafTop + glassHeight) / 2;
    for (final dx in [-1.0, 1.0]) {
      _FramePainter._handle(canvas, Offset(inner.center.dx + dx * _meeting / 2, y));
    }
    // The door hung on the window either side: a hinge on each joint near
    // the top, one halfway down and one near the foot.
    for (final x in [0.0, size.width]) {
      for (final hy in [leafTop + 28, (leafTop + size.height) / 2, size.height - 28]) {
        _hinge(canvas, Offset(x, hy));
      }
    }
  }

  /// A hinge centred on [at]: its knuckles, a barrel in two, along the joint
  /// between door and window, in the handles' metal.
  static void _hinge(Canvas canvas, Offset at) {
    final barrel = RRect.fromRectAndRadius(Rect.fromCenter(center: at, width: 7, height: 26), const Radius.circular(3));
    canvas.drawRRect(barrel.shift(const Offset(1, 2)), Paint()..color = const Color(0x40101A3F));
    canvas.drawRRect(barrel, Paint()..color = _gold);
    final metal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _goldEdge;
    canvas.drawRRect(barrel.deflate(.75), metal);
    canvas.drawLine(at.translate(-3.5, 0), at.translate(3.5, 0), metal);
  }

  @override
  bool shouldRepaint(_DoorPainter oldDelegate) => oldDelegate.glassHeight != glassHeight;
}

/// A paper pinwheel on a stick, set in a mound on top of a [WindowDome] over
/// windows [windowWidth] wide, filling its box ([heightFor] tall, the stick's
/// foot at the bottom), spinning slowly as [ticker] runs.
class DomeVane extends StatelessWidget {
  const DomeVane({super.key, required this.windowWidth, required this.ticker});
  final double windowWidth;
  final AnimationController ticker;

  /// The pinwheel's reach from its hub to a blade's tip.
  static double _reach(double windowWidth) => windowWidth * .13;

  /// Box sizes for windows [windowWidth] wide: room for the blades round the
  /// hub, and the stick under it.
  static double widthFor(double windowWidth) => 2.2 * _reach(windowWidth);
  static double heightFor(double windowWidth) => 3.5 * _reach(windowWidth);

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size(widthFor(windowWidth), heightFor(windowWidth)),
            painter: _VanePainter(ticker),
          ),
        ),
      );
}

class _VanePainter extends CustomPainter {
  _VanePainter(this.ticker) : super(repaint: ticker);
  final AnimationController ticker;

  static const _blade = Color(0xFFF2B51C), _bladeEdge = Color(0xFFFFD34D);
  static const _fold = Color(0xFFFFF6D6), _metal = Color(0xFF66777D);

  /// Blades round the hub, and its turns a second.
  static const _blades = 6, _spin = .12;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2.2, hub = Offset(size.width / 2, r * 1.1);
    // The stick, down from the hub into the mound (which covers its foot).
    final w = r * .09;
    final stick = RRect.fromRectAndRadius(Rect.fromLTRB(hub.dx - w / 2, hub.dy, hub.dx + w / 2, size.height + 6), Radius.circular(w / 2));
    canvas.drawRRect(stick, Paint()..color = _goldEdge);
    canvas.drawRect(Rect.fromLTWH(hub.dx - w / 2 + w * .2, hub.dy, w * .25, size.height + 6 - hub.dy), Paint()..color = _gold);
    // A little mound of the dome's wood round its foot, the rim covering its base.
    final mound = Path()
      ..addArc(Rect.fromCenter(center: Offset(hub.dx, size.height + 6), width: r * 1.45, height: 2 * (r * .45 + 6)), math.pi, math.pi)
      ..close();
    _piece(canvas, mound, _rounded);
    // A glint along its upper left, where the light catches it.
    canvas.drawPath(
      Path.combine(PathOperation.difference, mound, mound.shift(Offset(r * .14, r * .1))),
      Paint()..color = _woodLight.withValues(alpha: .7),
    );

    final t = (ticker.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6;
    canvas.save();
    canvas.translate(hub.dx, hub.dy);
    canvas.rotate(-t * _spin * 2 * math.pi);
    Offset at(double angle, double length) => Offset.fromDirection(angle, length);
    const sweep = .95;
    // Each blade from the hub out to its tip, curling back round to the next.
    for (var i = 0; i < _blades; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / _blades;
      final blade = Path()
        ..moveTo(0, 0)
        ..lineTo(at(a, r).dx, at(a, r).dy)
        ..quadraticBezierTo(at(a + .55, r * .9).dx, at(a + .55, r * .9).dy, at(a + sweep, r * .42).dx, at(a + sweep, r * .42).dy)
        ..close();
      canvas.drawPath(blade, Paint()..color = _blade);
      canvas.drawPath(
        blade,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .04
          ..strokeJoin = StrokeJoin.round
          ..color = _bladeEdge,
      );
    }
    // The white folds where the blades bend in to the middle, a star.
    for (var i = 0; i < _blades; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / _blades;
      canvas.drawPath(Path()..addPolygon([Offset.zero, at(a, r * .5), at(a + sweep, r * .3)], true), Paint()..color = _fold);
    }
    canvas.drawCircle(Offset.zero, r * .11, Paint()..color = _metal);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VanePainter oldDelegate) => oldDelegate.ticker != ticker;
}
