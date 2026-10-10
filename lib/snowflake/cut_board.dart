import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import 'detach.dart';
import 'geometry.dart';

/// Interactive folded wedge: drag a loop to cut a piece out or a line to slit
/// the paper (tool `free`). Any other tool is a stencil shape (see
/// [stencilShape]), put on the paper in a selection box like a paint
/// program's: drag it about, size it by the corner handles, stretch it by the
/// side ones, turn it by the knob above, and cut it out (see [stencilCut]) as
/// many times as you like. Pieces appended to [fallen] drop off the board.
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
    this.paperOpacity = 1,
    this.hintCuts = const [],
    this.hintOpacity = 0,
    this.stencilCut = 0,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final List<Cut> cuts, fallen;
  final ValueChanged<Cut> onCut;
  final int folds;
  final double height, touchMargin;
  final String tool;
  final Color color;
  final String pattern;

  /// How much of the paper (with its shadow and cut outlines) shows; the
  /// dotted fold edges always do. Below 1 while an event's own wedge lies there.
  final double paperOpacity;

  /// Cuts shown over the paper as a hint (an event's flake to make again),
  /// at [hintOpacity]: not cut, just marked.
  final List<Cut> hintCuts;
  final double hintOpacity;

  /// Bump to cut the stencil out where it stands (the button for it lives
  /// outside the board).
  final int stencilCut;

  /// Room at the top and foot taken by controls laid over the board: the
  /// wedge (as drawn: arc to apex) centres in the space between them, while
  /// the board itself, and its clip, runs on underneath.
  final double topInset, bottomInset;

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
enum _StencilDrag { move, handle, rotate }

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
    // A new shape (or a reshaped wedge) starts again in the middle of the
    // paper, at its first size and turn.
    if (old.tool != widget.tool || old.folds != widget.folds) {
      _stencilAt = null;
      _sx = _sy = _stencilR0;
      _stencilTurn = 0;
    }
    if (old.stencilCut != widget.stencilCut) {
      // After this frame: cutting reports back to the parent, which is building.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cutStencil();
      });
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
    _press.dispose();
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

  /// Stencil centre in wedge units; null = not placed yet.
  Offset? _stencilAt;
  static const _stencilR0 = 0.12;

  /// The stencil's size across and up: its unit shape scaled by these.
  double _sx = _stencilR0, _sy = _stencilR0;
  static const _minScale = 0.03, _maxScale = 0.4;

  /// Stencil rotation, radians clockwise.
  double _stencilTurn = 0;

  /// Selection box: px between the shape and the box, and from the box's top
  /// to the rotate knob.
  static const _boxPad = 6.0, _knobGap = 34.0;

  /// The tool's shape at radius 1 about the origin, and its bounds.
  Cut get _unitShape => stencilShape(widget.tool, 0, 0, 1);
  Rect get _unitBox => cutPath(_unitShape, 1).getBounds();

  /// The selection box in the stencil's own (unturned) frame, wedge units.
  Rect get _box {
    final b = _unitBox;
    return Rect.fromLTRB(b.left * _sx, b.top * _sy, b.right * _sx, b.bottom * _sy).inflate(_boxPad / _s);
  }

  /// Where the stencil starts: the middle of the paper, the wedge's centroid
  /// (2·sin h / 3h of the radius up from the apex, for half-angle h).
  Offset get _stencilCentre {
    final h = wedgeHalfAngle(widget.folds);
    return _stencilAt ??= Offset(0, -2 * math.sin(h) / (3 * h));
  }

  /// From the stencil's own frame to the wedge's, and back.
  Offset _fromStencil(Offset q) {
    final c = _stencilCentre, cos = math.cos(_stencilTurn), sin = math.sin(_stencilTurn);
    return c + Offset(q.dx * cos - q.dy * sin, q.dx * sin + q.dy * cos);
  }

  Offset _toStencil(Offset p) {
    final d = p - _stencilCentre, cos = math.cos(_stencilTurn), sin = math.sin(_stencilTurn);
    return Offset(d.dx * cos + d.dy * sin, -d.dx * sin + d.dy * cos);
  }

  Cut get _stencil => [for (final q in _unitShape) _fromStencil(Offset(q.dx * _sx, q.dy * _sy))];

  /// The box's handles in its own frame, clockwise from the top-left corner:
  /// corners at even indices, side middles at odd ones.
  List<Offset> get _handles {
    final b = _box;
    return [b.topLeft, b.topCenter, b.topRight, b.centerRight, b.bottomRight, b.bottomCenter, b.bottomLeft, b.centerLeft];
  }

  /// The rotate knob, above the middle of the box's top.
  Offset get _knob => _box.topCenter - Offset(0, _knobGap / _s);

  _StencilDrag? _drag;
  int _dragHandle = 0;
  Offset _dragLast = Offset.zero;

  /// Resizes by handle [h] to follow the finger at [p]: a side handle moves
  /// its side (and the opposite one, keeping the centre), a corner scales both
  /// ways at once.
  void _resizeTo(int h, Offset p) {
    final q = _toStencil(p), b = _unitBox, pad = _boxPad / _s;
    double clamp(double v) => v.clamp(_minScale, _maxScale);
    switch (h) {
      case 1:
        _sy = clamp((q.dy + pad) / b.top);
      case 5:
        _sy = clamp((q.dy - pad) / b.bottom);
      case 3:
        _sx = clamp((q.dx - pad) / b.right);
      case 7:
        _sx = clamp((q.dx + pad) / b.left);
      default:
        // Along the corner's own diagonal, so the shape keeps its proportions.
        final corner = Offset(h == 0 || h == 6 ? b.left * _sx : b.right * _sx, h <= 2 ? b.top * _sy : b.bottom * _sy);
        final t = (q.dx * corner.dx + q.dy * corner.dy) / corner.distanceSquared;
        final lo = math.max(_minScale / _sx, _minScale / _sy), hi = math.min(_maxScale / _sx, _maxScale / _sy);
        final k = t.clamp(lo, hi);
        _sx *= k;
        _sy *= k;
    }
  }

  /// The stencil pressing into the paper as it is applied: 0 at rest, dipping
  /// to 1 mid-way and back.
  late final _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..addListener(() => setState(() {}));
  static const _pressDepth = 0.1;

  void _cutStencil() {
    _press.forward(from: 0);
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
    if (_pinching) return;
    final p = _toUnit(e.localPosition);
    if (_stencilTool) {
      // The knob turns and the handles resize; a touch anywhere else drags the
      // stencil along, so even a small one need not be hit exactly.
      double away(Offset q) => (e.localPosition - (_apex + _fromStencil(q) * _s)).distance;
      final handles = _handles;
      var nearest = 0;
      for (var i = 1; i < handles.length; i++) {
        if (away(handles[i]) < away(handles[nearest])) nearest = i;
      }
      if (away(_knob) < 26) {
        setState(() => _drag = _StencilDrag.rotate);
      } else if (away(handles[nearest]) < 22) {
        _drag = _StencilDrag.handle;
        _dragHandle = nearest;
      } else {
        _drag = _StencilDrag.move;
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
      case _StencilDrag.handle:
        setState(() => _resizeTo(_dragHandle, p));
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
    // Also hides the degrees shown while turning.
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
      // The drawn wedge spans 0.06·h − 8 … h − 8 of its box; centre that span.
      final mid = (widget.topInset + c.maxHeight - widget.bottomInset) / 2;
      _origin = Offset((c.maxWidth - _width) / 2, mid - 0.53 * widget.height + 8);
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
                  ? (
                      shape: _stencil,
                      box: [for (final q in [_box.topLeft, _box.topRight, _box.bottomRight, _box.bottomLeft]) _fromStencil(q)],
                      handles: [for (final q in _handles) _fromStencil(q)],
                      knob: _fromStencil(_knob),
                      knobBase: _fromStencil(_box.topCenter),
                      turn: _stencilTurn,
                      turning: _drag == _StencilDrag.rotate,
                      centre: _stencilCentre,
                      press: math.sin(_press.value * math.pi),
                    )
                  : null,
              half: wedgeHalfAngle(widget.folds),
              s: _s,
              apex: _apex,
              color: widget.color,
              pattern: widget.pattern,
              paperOpacity: widget.paperOpacity,
              hint: widget.hintOpacity > 0 ? (cuts: widget.hintCuts, opacity: widget.hintOpacity) : null,
            ),
          ),
        ),
      );
      return board;
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
    required this.paperOpacity,
    required this.hint,
  });

  final List<Cut> cuts, fallen;
  final List<(List<Cut> pieces, List<Cut> cuts, double t)> drops;
  final List<(Cut cut, double t)> misses;
  final _Live? live;

  /// The stencil's outline with its selection box (corners), the box's
  /// handles, the rotate knob and where its stalk meets the box, and how far
  /// it is turned (shown while [turning]), while a stencil tool is on.
  final ({Cut shape, List<Offset> box, List<Offset> handles, Offset knob, Offset knobBase, double turn, bool turning, Offset centre, double press})? stencil;
  final double half, s;
  final Offset apex;
  final Color color;
  final String pattern;
  final double paperOpacity;
  final ({List<Cut> cuts, double opacity})? hint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(apex.dx, apex.dy);

    final fill = makePaperFill(color, pattern, s);
    if (paperOpacity > 0) {
      final fading = paperOpacity < 1;
      if (fading) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, paperOpacity));
      // Soft shadow wedge underneath (shows through the holes too).
      final shadow = Path()
        ..moveTo(0, 6)
        ..arcTo(Rect.fromCircle(center: const Offset(0, 6), radius: s), -math.pi / 2 - half, 2 * half, false)
        ..close();
      canvas.drawPath(shadow, Paint()..color = const Color(0x292E4A94));

      drawWedge(canvas, s, [...cuts, ...fallen], half, fill);
      if (fading) canvas.restore();
    }

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
    if (paperOpacity > 0) {
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

    // A hint: the cuts to make, tinted and outlined, kept to the wedge.
    final hint = this.hint;
    if (hint != null) {
      canvas.save();
      canvas.clipPath(Path()
        ..moveTo(0, 0)
        ..arcTo(Rect.fromCircle(center: Offset.zero, radius: s), -math.pi / 2 - half, 2 * half, false)
        ..close());
      final a = hint.opacity;
      final tint = Paint()..color = C.berry600.withValues(alpha: .22 * a);
      final line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = C.berry600.withValues(alpha: a);
      for (final c in hint.cuts) {
        canvas.drawPath(cutPath(c, s), tint);
      }
      for (final c in hint.cuts) {
        drawDashed(canvas, cutPath(c, s), _halo(line, alpha: a), 7, 5);
        drawDashed(canvas, cutPath(c, s), line, 7, 5);
      }
      canvas.restore();
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
      // Pressed in about its centre as it is applied.
      canvas.save();
      canvas.translate(st.centre.dx * s, st.centre.dy * s);
      final k = 1 - _CutBoardState._pressDepth * st.press;
      canvas.scale(k);
      canvas.translate(-st.centre.dx * s, -st.centre.dy * s);
      final path = cutPath(st.shape, s);
      canvas.drawPath(path, Paint()..color = const Color(0x2EE0405E));
      drawDashed(canvas, path, _halo(stroke), 8, 6);
      drawDashed(canvas, path, stroke, 8, 6);
      _paintSelection(canvas, st.box, st.handles, st.knob, st.knobBase, st.turn);
      if (st.turning) _paintDegrees(canvas, st.knob * s, st.turn);
      canvas.restore();
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

  /// The paint-program selection round the stencil: a thin box, square
  /// handles on its corners and side middles, and the rotate knob on a stalk
  /// above it. Points are in wedge units.
  void _paintSelection(Canvas canvas, List<Offset> box, List<Offset> handles, Offset knob, Offset knobBase, double turn) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = C.night800;
    final outline = Path()..addPolygon([for (final p in box) p * s], true);
    canvas.drawPath(outline, _halo(line));
    canvas.drawPath(outline, line);

    // Stalk up to the knob.
    canvas.drawLine(knobBase * s, knob * s, _halo(line));
    canvas.drawLine(knobBase * s, knob * s, line);

    final fill = Paint()..color = Colors.white;
    for (final h in handles) {
      canvas.save();
      canvas.translate(h.dx * s, h.dy * s);
      canvas.rotate(turn);
      final r = Rect.fromCenter(center: Offset.zero, width: 9, height: 9);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, line);
      canvas.restore();
    }

    // The knob in berry on a white halo, like the cut marks.
    final k = knob * s;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = C.berry600;
    canvas.drawCircle(k, 15, fill);
    canvas.drawCircle(k, 15, _halo(ring));
    canvas.drawCircle(k, 15, ring);
    const icon = LucideIcons.rotateCw;
    final glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 18, fontWeight: FontWeight.w700, color: C.berry600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, k - Offset(glyph.width / 2, glyph.height / 2));
  }

  /// The turn in whole degrees (clockwise, 0…359), above the knob at [k] px.
  void _paintDegrees(Canvas canvas, Offset k, double turn) {
    final deg = ((turn % (2 * math.pi)) * 180 / math.pi).round() % 360;
    TextPainter text(TextStyle style) => TextPainter(text: TextSpan(text: '$deg°', style: style), textDirection: TextDirection.ltr)..layout();
    final outline = text(display(14).copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    ));
    final label = text(display(14, color: C.berry700));
    final at = k + Offset(-label.width / 2, -15 - 6 - label.height);
    outline.paint(canvas, at);
    label.paint(canvas, at);
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
      o.paperOpacity != paperOpacity ||
      o.hint != hint ||
      o.s != s;
}
