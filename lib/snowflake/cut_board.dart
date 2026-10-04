import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import '../widgets/ds.dart';
import 'detach.dart';
import 'geometry.dart';

/// Interactive folded wedge: drag a loop to cut a piece out or a line to slit
/// the paper (tool `free`). A stencil tool (`circle`, `square`, `triangle`,
/// `star`, `heart`, `drop`) puts its shape beside the wedge: drag it about,
/// turn it by the ring around it, resize it by the arrows outside the ring, and cut
/// it out with the scissors button, as many times as you like. Pieces appended to [fallen] drop off the board.
///
/// Fills its constraints with the wedge centred in a [widthFor] × [height] box;
/// a cut can start up to [touchMargin] away from the paper.
class CutBoard extends StatefulWidget {
  const CutBoard({
    super.key,
    required this.cuts,
    required this.onCut,
    this.fallen = const [],
    this.folds = 6,
    this.height = 440,
    this.touchMargin = 48,
    this.tool = 'free',
    this.color = Colors.white,
    this.pattern = 'plain',
    this.disabled = false,
    this.showGhosts = true,
  });

  final List<Cut> cuts, fallen;
  final ValueChanged<Cut> onCut;
  final int folds;
  final double height, touchMargin;
  final String tool;
  final Color color;
  final String pattern;
  final bool disabled, showGhosts;

  static double widthFor(double height, int folds) =>
      math.max(2 * math.sin(wedgeHalfAngle(folds)) * height * 0.94 + 40, 160).ceilToDouble();

  @override
  State<CutBoard> createState() => _CutBoardState();
}

/// A scissors stroke in progress.
class _Live {
  const _Live(this.pts);
  final Cut pts;
}

/// What a finger is doing to the stencil.
enum _StencilDrag { move, resize, rotate }

/// Pieces falling off, drawn as the paper was when they let go.
class _Drop {
  _Drop(this.pieces, this.cuts, this.anim);
  final List<Cut> pieces, cuts;
  final AnimationController anim;
}

/// A cut that missed the paper: its outline fades away and nothing is cut.
class _Miss {
  _Miss(this.cut, this.anim);
  final Cut cut;
  final AnimationController anim;
}

class _CutBoardState extends State<CutBoard> with TickerProviderStateMixin {
  _Live? _live;
  final _drops = <_Drop>[];
  final _misses = <_Miss>[];

  @override
  void didUpdateWidget(CutBoard old) {
    super.didUpdateWidget(old);
    // A new shape (or a reshaped wedge) starts again beside the paper.
    if (old.tool != widget.tool || old.folds != widget.folds) {
      _stencilAt = null;
      _stencilR = _stencilR0;
      _stencilTurn = 0;
    }
    final f = widget.fallen, o = old.fallen;
    if (f.length <= o.length || (o.isNotEmpty && !identical(f[o.length - 1], o.last))) return;
    final anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    final drop = _Drop(f.sublist(o.length), [...widget.cuts, ...o], anim);
    _drops.add(drop);
    anim
      ..addListener(() => setState(() {}))
      ..forward().whenComplete(() {
        if (mounted) setState(() => _drops.remove(drop));
        anim.dispose();
      });
  }

  @override
  void dispose() {
    for (final d in _drops) {
      d.anim.dispose();
    }
    for (final m in _misses) {
      m.anim.dispose();
    }
    super.dispose();
  }

  /// Top-left of the [CutBoard.widthFor] × height box, set on layout.
  Offset _origin = Offset.zero;

  /// Pinch zoom: the unzoomed board maps to the view as `p · _zoom + _pan`.
  double _zoom = 1;
  Offset _pan = Offset.zero;
  static const _maxZoom = 4.0;

  /// Fingers on the board, by pointer id.
  final _pointers = <int, Offset>{};

  /// A second finger turned the touch into a pinch; no cutting until every
  /// finger is lifted.
  bool _pinching = false;
  ({double dist, Offset mid, double zoom, Offset pan})? _pinchFrom;

  double get _s => widget.height * 0.94 * _zoom;
  double get _width => CutBoard.widthFor(widget.height, widget.folds);
  Offset get _apex => (_origin + Offset(_width / 2, widget.height - 8)) * _zoom + _pan;

  /// Where a cut may start: the paper's bounds plus [CutBoard.touchMargin].
  Rect get _touchZone {
    final w = _s * math.sin(wedgeHalfAngle(widget.folds));
    return Rect.fromLTRB(_apex.dx - w, _apex.dy - _s, _apex.dx + w, _apex.dy).inflate(widget.touchMargin);
  }

  Offset _toUnit(Offset local) => (local - _apex) / _s;

  // ---- Stencil ------------------------------------------------------------

  bool get _stencilTool => widget.tool != 'free';

  /// Stencil centre and radius in wedge units; null centre = not placed yet.
  Offset? _stencilAt;
  static const _stencilR0 = 0.12;
  double _stencilR = _stencilR0;

  /// Stencil rotation, radians clockwise.
  double _stencilTurn = 0;

  /// The rotation ring sits just outside the shape; the handle rides on it.
  static const _ring = 1.35;

  /// How far up the wedge the stencil starts and the scissors button sits:
  /// low, where the wedge is narrow and there is room either side.
  static const _stencilRise = 0.18;

  /// Distance in px from the board's side to the scissors button's centre
  /// (a large round button, 72 across, 20 in from the edge); the stencil
  /// starts as far in from the other side.
  static const _sideInset = 20 + 36.0;

  /// Left of the wedge where it narrows, mirroring the scissors button on the
  /// right, but with the whole ring on the board and never on the paper.
  Offset get _stencilCentre {
    const y = -_stencilRise;
    final edge = -y * math.tan(wedgeHalfAngle(widget.folds));
    final unit = widget.height * 0.94;
    final left = -(_origin.dx + _width / 2) / unit; // the board's left side
    final mirror = left + _sideInset / unit;
    // Pulled in if the ring (wider than the button) would run off the board.
    final onBoard = left + _stencilR * _ring + 12 / unit;
    return _stencilAt ??= Offset(math.min(math.max(mirror, onBoard), -edge - _stencilR * _ring - 0.02), y);
  }

  Cut get _stencil {
    final c = _stencilCentre;
    final cos = math.cos(_stencilTurn), sin = math.sin(_stencilTurn);
    return [
      for (final q in stencilShape(widget.tool, c.dx, c.dy, _stencilR))
        c + Offset((q.dx - c.dx) * cos - (q.dy - c.dy) * sin, (q.dx - c.dx) * sin + (q.dy - c.dy) * cos),
    ];
  }

  /// Resize handle: just outside the ring at the lower-right, a fixed
  /// [_handleGap] px beyond it whatever the zoom.
  static const _handleGap = 24.0;
  Offset get _handle => _stencilCentre + const Offset(math.sqrt1_2, math.sqrt1_2) * (_stencilR * _ring + _handleGap / _s);

  _StencilDrag? _drag;
  Offset _dragLast = Offset.zero;

  void _cutStencil() {
    if (widget.disabled) return;
    final cut = _stencil;
    if (cutsPaper(cut, [...widget.cuts, ...widget.fallen], widget.folds)) {
      widget.onCut(cut);
    } else {
      _fadeOut(cut);
    }
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length >= 2) {
      // Whatever the first finger started is dropped, not cut.
      setState(() {
        _live = null;
        _drag = null;
      });
      _pinching = true;
      _startPinch();
      return;
    }
    if (_pinching || widget.disabled) return;
    final p = _toUnit(e.localPosition);
    if (_stencilTool) {
      // The handle resizes and the ring turns; a touch anywhere else drags the
      // stencil along, so even a small one need not be hit exactly.
      final nearHandle = (e.localPosition - (_apex + _handle * _s)).distance < 32;
      final fromCentre = (e.localPosition - (_apex + _stencilCentre * _s)).distance;
      final onRing = (fromCentre - _stencilR * _ring * _s).abs() < 22;
      _drag = nearHandle
          ? _StencilDrag.resize
          : onRing
              ? _StencilDrag.rotate
              : _StencilDrag.move;
      if (_drag == _StencilDrag.rotate) {
        // A tap on the ring turns the stencil's top to point at it at once;
        // dragging on from there keeps turning.
        final a = p - _stencilCentre;
        setState(() => _stencilTurn = math.atan2(a.dy, a.dx) + math.pi / 2);
      }
      _dragLast = p;
      return;
    }
    if (!_touchZone.contains(e.localPosition)) return;
    setState(() => _live = _Live([p]));
  }

  void _move(PointerMoveEvent e) {
    if (_pointers.containsKey(e.pointer)) _pointers[e.pointer] = e.localPosition;
    if (_pinching) {
      if (_pointers.length >= 2) _pinchTo();
      return;
    }
    final p = _toUnit(e.localPosition);
    switch (_drag) {
      case _StencilDrag.move:
        setState(() => _stencilAt = _stencilCentre + (p - _dragLast));
        _dragLast = p;
        return;
      case _StencilDrag.resize:
        setState(() => _stencilR = (((p - _stencilCentre).distance - _handleGap / _s) / _ring).clamp(0.04, 0.35));
        return;
      case _StencilDrag.rotate:
        // Turns by the angle the finger swept round the centre.
        final a = p - _stencilCentre, b = _dragLast - _stencilCentre;
        setState(() => _stencilTurn += math.atan2(a.dy, a.dx) - math.atan2(b.dy, b.dx));
        _dragLast = p;
        return;
      case null:
    }
    final d = _live;
    if (d == null) return;
    if ((p - d.pts.last).distance > 0.008) setState(() => _live = _Live([...d.pts, p]));
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pinching) {
      if (_pointers.isEmpty) {
        _pinching = false;
      } else if (_pointers.length >= 2) {
        _startPinch();
      }
      return;
    }
    _drag = null;
    final d = _live;
    setState(() => _live = null);
    if (d == null || d.pts.length <= 4) return;
    final cut = isLoop(d.pts) ? d.pts : slit(d.pts);
    if (cutsPaper(cut, [...widget.cuts, ...widget.fallen], widget.folds)) {
      widget.onCut(cut);
    } else {
      _fadeOut(cut);
    }
  }

  (Offset, Offset) get _twoFingers {
    final it = _pointers.values.iterator..moveNext();
    final a = it.current;
    it.moveNext();
    return (a, it.current);
  }

  void _startPinch() {
    final (a, b) = _twoFingers;
    _pinchFrom = (dist: math.max((a - b).distance, 1.0), mid: (a + b) / 2, zoom: _zoom, pan: _pan);
  }

  /// Scales by how far the fingers spread and keeps the point that was under
  /// their midpoint under it, so two fingers also drag the board around.
  void _pinchTo() {
    final from = _pinchFrom;
    if (from == null) return;
    final (a, b) = _twoFingers;
    final zoom = (from.zoom * (a - b).distance / from.dist).clamp(1.0, _maxZoom);
    final anchor = (from.mid - from.pan) / from.zoom;
    setState(() {
      _zoom = zoom;
      _pan = zoom == 1 ? Offset.zero : (a + b) / 2 - anchor * zoom;
    });
  }

  void _fadeOut(Cut cut) {
    final anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    final miss = _Miss(cut, anim);
    _misses.add(miss);
    anim
      ..addListener(() => setState(() {}))
      ..forward().whenComplete(() {
        if (mounted) setState(() => _misses.remove(miss));
        anim.dispose();
      });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      _origin = Offset((c.maxWidth - _width) / 2, (c.maxHeight - widget.height) / 2);
      final board = Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        // A zoomed-in wedge stays inside the board.
        child: ClipRect(
          child: CustomPaint(
            size: c.biggest,
            painter: _BoardPainter(
              cuts: widget.cuts,
              fallen: widget.fallen,
              drops: [for (final d in _drops) (d.pieces, d.cuts, d.anim.value)],
              misses: [for (final m in _misses) (m.cut, m.anim.value)],
              live: _live,
              stencil: _stencilTool
                  ? (shape: _stencil, centre: _stencilCentre, ring: _stencilR * _ring, turn: _stencilTurn, handle: _handle)
                  : null,
              half: wedgeHalfAngle(widget.folds),
              s: _s,
              apex: _apex,
              color: widget.color,
              pattern: widget.pattern,
              showGhosts: widget.showGhosts,
            ),
          ),
        ),
      );
      if (!_stencilTool) return board;
      // Over the board, so its taps never reach the stencil drag. Right of the
      // wedge, centred level with where the stencil starts on the left.
      final rowY = _origin.dy + widget.height - 8 - _stencilRise * widget.height * 0.94;
      return Stack(children: [
        Positioned.fill(child: board),
        Positioned(
          right: _sideInset - 36,
          top: rowY - 36,
          child: RoundBtn(LucideIcons.scissors, label: 'Вырезать', variant: Variant.soft, size: BtnSize.l, disabled: widget.disabled, onTap: _cutStencil),
        ),
      ]);
    });
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.cuts,
    required this.fallen,
    required this.drops,
    required this.misses,
    required this.live,
    required this.stencil,
    required this.half,
    required this.s,
    required this.apex,
    required this.color,
    required this.pattern,
    required this.showGhosts,
  });

  final List<Cut> cuts, fallen;
  final List<(List<Cut> pieces, List<Cut> cuts, double t)> drops;
  final List<(Cut cut, double t)> misses;
  final _Live? live;

  /// The stencil's outline, rotation ring (and how far it is turned) and
  /// resize handle, while a stencil tool is on.
  final ({Cut shape, Offset centre, double ring, double turn, Offset handle})? stencil;
  final double half, s;
  final Offset apex;
  final Color color;
  final String pattern;
  final bool showGhosts;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(apex.dx, apex.dy);

    // Soft shadow wedge underneath (shows through the holes too).
    final shadow = Path()
      ..moveTo(0, 6)
      ..arcTo(Rect.fromCircle(center: const Offset(0, 6), radius: s), -math.pi / 2 - half, 2 * half, false)
      ..close();
    canvas.drawPath(shadow, Paint()..color = const Color(0x292E4A94));

    final fill = makePaperFill(color, pattern, s);
    drawWedge(canvas, s, [...cuts, ...fallen], half, fill);

    // Dotted fold edges.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = C.snow300;
    for (final sgn in const [-1, 1]) {
      final line = Path()
        ..moveTo(0, 0)
        ..lineTo(sgn * math.sin(half) * s, -math.cos(half) * s);
      drawDashed(canvas, line, edge, 2, 7);
    }

    // Dashed outlines of removed pieces.
    if (showGhosts) {
      final ghost = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x73E0405E);
      // All halos first, so one cut's halo never covers another's line.
      for (final c in cuts) {
        drawDashed(canvas, _outline(c), _halo(ghost), 6, 6);
      }
      for (final c in cuts) {
        drawDashed(canvas, _outline(c), ghost, 6, 6);
      }
    }

    // Cuts that missed the paper: shown, then faded out.
    for (final (c, t) in misses) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = C.berry600.withValues(alpha: 1 - t);
      drawDashed(canvas, _outline(c), _halo(paint, alpha: 1 - t), 8, 6);
      drawDashed(canvas, _outline(c), paint, 8, 6);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = C.berry600;

    final st = stencil;
    if (st != null) {
      final (:shape, :centre, :ring, :turn, :handle) = st;
      // Ring to grab for turning, on a soft band in the wedge's shadow colour.
      // Centred, not dropped: an offset would read as the cut landing lower.
      canvas.drawCircle(
        centre * s,
        ring * s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..color = const Color(0x292E4A94),
      );
      final ringLine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x59E0405E);
      canvas.drawCircle(centre * s, ring * s, _halo(ringLine));
      canvas.drawCircle(centre * s, ring * s, ringLine);
      _paintTurn(canvas, centre * s, ring * s, turn);
      final path = cutPath(shape, s);
      canvas.drawPath(path, Paint()..color = const Color(0x2EE0405E));
      drawDashed(canvas, path, _halo(stroke), 8, 6);
      drawDashed(canvas, path, stroke, 8, 6);
      _paintResize(canvas, handle * s);
    }

    final l = live;
    if (l != null && l.pts.length > 1) {
      final path = cutPath(l.pts, s, close: false);
      canvas.drawPath(path, _halo(stroke));
      canvas.drawPath(path, stroke);
      canvas.drawCircle(l.pts.first * s, 8, Paint()..color = Colors.white);
      canvas.drawCircle(l.pts.first * s, 6, Paint()..color = C.berry600);
    }

    // Loose pieces fall away, tumbling outwards and fading.
    for (final (pieces, dropCuts, t) in drops) {
      for (final piece in pieces) {
        final path = cutPath(piece, s);
        final c = path.getBounds().center;
        final side = c.dx < 0 ? -1.0 : 1.0;
        canvas.save();
        canvas.translate(c.dx + side * 40 * t, c.dy + 520 * t * t);
        canvas.rotate(side * 0.9 * t);
        canvas.translate(-c.dx, -c.dy);
        canvas.clipPath(path);
        canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - t * t));
        drawWedge(canvas, s, dropCuts, half, fill);
        canvas.restore();
        canvas.restore();
      }
    }
    canvas.restore();
  }

  /// Turn gauge on the ring: a notch at the stencil's own upright, and an arc
  /// from there clockwise round to where that upright now points.
  void _paintTurn(Canvas canvas, Offset c, double r, double turn) {
    // Always measured clockwise, 0…360°, so the arc never flips direction.
    final t = turn % (2 * math.pi);
    // Whole degrees, as labelled; a hair short of 360° reads (and draws) as 0.
    final deg = (t * 180 / math.pi).round() % 360;
    const up = -math.pi / 2;
    // As fine as the ring's own line.
    final notch = Paint()
      ..strokeWidth = 1.5
      ..color = const Color(0x59E0405E);
    final dir = Offset(math.cos(up), math.sin(up));
    canvas.drawLine(c + dir * (r - 9), c + dir * (r + 9), _halo(notch));
    canvas.drawLine(c + dir * (r - 9), c + dir * (r + 9), notch);
    if (deg != 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = C.berry600;
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawArc(rect, up, t, false, _halo(arc));
      canvas.drawArc(rect, up, t, false, arc);
    }
    // Where the upright points now; on the notch while unturned.
    final end = Offset(math.cos(up + t), math.sin(up + t));
    canvas.drawCircle(c + end * r, 6, Paint()..color = Colors.white);
    canvas.drawCircle(c + end * r, 4, Paint()..color = C.berry600);

    // Centred just above the ring.
    // White outline under the figures, like the halo under the arrows.
    TextPainter text(TextStyle style) =>
        TextPainter(text: TextSpan(text: '$deg°', style: style), textDirection: TextDirection.ltr)..layout();
    final outline = text(display(14).copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    ));
    final label = text(display(14, color: C.berry700));
    final at = c + Offset(-label.width / 2, -r - 12 - label.height);
    outline.paint(canvas, at);
    label.paint(canvas, at);
  }

  /// Resize handle: a diagonal double arrow pointing out from and in to the
  /// stencil, on a white halo so it reads over paper.
  void _paintResize(Canvas canvas, Offset at) {
    const d = Offset(math.sqrt1_2, math.sqrt1_2);
    const n = Offset(-math.sqrt1_2, math.sqrt1_2);
    const len = 11.0, head = 6.0;
    final path = Path()
      ..moveTo((at - d * len).dx, (at - d * len).dy)
      ..lineTo((at + d * len).dx, (at + d * len).dy);
    for (final sgn in const [1.0, -1.0]) {
      final tip = at + d * (len * sgn);
      final back = tip - d * (head * sgn);
      path
        ..moveTo((back + n * head).dx, (back + n * head).dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo((back - n * head).dx, (back - n * head).dy);
    }
    Paint line(double w, Color c) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.drawPath(path, line(7, Colors.white));
    canvas.drawPath(path, line(3, C.berry600));
  }

  /// White underlay a little wider than the red line [p], so cut marks still
  /// read on red (or any dark) paper.
  static Paint _halo(Paint p, {double alpha = 1}) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = p.strokeWidth + 3
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = Colors.white.withValues(alpha: alpha);

  /// Dashed-outline path of [c]; a slit, a hairline band, is one line rather than both of its edges.
  Path _outline(Cut c) {
    final line = slitLine(c);
    return line != null ? cutPath(line, s, close: false) : cutPath(c, s);
  }

  @override
  bool shouldRepaint(_BoardPainter o) =>
      !identical(o.cuts, cuts) ||
      !identical(o.fallen, fallen) ||
      drops.isNotEmpty ||
      o.drops.isNotEmpty ||
      misses.isNotEmpty ||
      o.misses.isNotEmpty ||
      o.live != live ||
      o.stencil != stencil ||
      o.apex != apex ||
      o.color != color ||
      o.pattern != pattern ||
      o.s != s;
}
