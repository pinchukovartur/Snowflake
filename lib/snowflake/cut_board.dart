import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'geometry.dart';

/// Interactive folded wedge: drag a loop to cut (tool `free`) or tap-and-drag
/// to stamp a stencil (`circle`, `square`, `triangle`, `star`, `heart`, `drop`).
/// Pieces appended to [fallen] drop off the board.
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

class _Live {
  const _Live(this.pts, {this.center, this.stencil = false});
  final Cut pts;
  final Offset? center;
  final bool stencil;
}

/// Pieces falling off, drawn as the paper was when they let go.
class _Drop {
  _Drop(this.pieces, this.cuts, this.anim);
  final List<Cut> pieces, cuts;
  final AnimationController anim;
}

class _CutBoardState extends State<CutBoard> with TickerProviderStateMixin {
  _Live? _live;
  final _drops = <_Drop>[];

  @override
  void didUpdateWidget(CutBoard old) {
    super.didUpdateWidget(old);
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
    super.dispose();
  }

  /// Top-left of the [CutBoard.widthFor] × height box, set on layout.
  Offset _origin = Offset.zero;

  double get _s => widget.height * 0.94;
  double get _width => CutBoard.widthFor(widget.height, widget.folds);
  Offset get _apex => _origin + Offset(_width / 2, widget.height - 8);

  /// Where a cut may start: the paper's bounds plus [CutBoard.touchMargin].
  Rect get _touchZone {
    final w = _s * math.sin(wedgeHalfAngle(widget.folds));
    return Rect.fromLTRB(_apex.dx - w, _apex.dy - _s, _apex.dx + w, _apex.dy).inflate(widget.touchMargin);
  }

  Offset _toUnit(Offset local) => (local - _apex) / _s;

  Cut _stamp(Offset c, Offset p) => stencilShape(widget.tool, c.dx, c.dy, ((p - c).distance).clamp(0.05, 0.3));

  void _down(PointerDownEvent e) {
    if (widget.disabled || !_touchZone.contains(e.localPosition)) return;
    final p = _toUnit(e.localPosition);
    setState(() => _live = widget.tool == 'free' ? _Live([p]) : _Live(_stamp(p, p), center: p, stencil: true));
  }

  void _move(PointerMoveEvent e) {
    final d = _live;
    if (d == null) return;
    final p = _toUnit(e.localPosition);
    if (d.stencil) {
      setState(() => _live = _Live(_stamp(d.center!, p), center: d.center, stencil: true));
      return;
    }
    if ((p - d.pts.last).distance > 0.008) setState(() => _live = _Live([...d.pts, p]));
  }

  void _up([PointerEvent? _]) {
    final d = _live;
    setState(() => _live = null);
    if (d == null) return;
    if (d.stencil) {
      widget.onCut(d.pts);
    } else if (d.pts.length > 4) {
      widget.onCut(d.pts);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      _origin = Offset((c.maxWidth - _width) / 2, (c.maxHeight - widget.height) / 2);
      return Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: CustomPaint(
          size: c.biggest,
          painter: _BoardPainter(
            cuts: widget.cuts,
            fallen: widget.fallen,
            drops: [for (final d in _drops) (d.pieces, d.cuts, d.anim.value)],
            live: _live,
            half: wedgeHalfAngle(widget.folds),
            s: _s,
            apex: _apex,
            color: widget.color,
            pattern: widget.pattern,
            showGhosts: widget.showGhosts,
          ),
        ),
      );
    });
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.cuts,
    required this.fallen,
    required this.drops,
    required this.live,
    required this.half,
    required this.s,
    required this.apex,
    required this.color,
    required this.pattern,
    required this.showGhosts,
  });

  final List<Cut> cuts, fallen;
  final List<(List<Cut> pieces, List<Cut> cuts, double t)> drops;
  final _Live? live;
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
      for (final c in cuts) {
        drawDashed(canvas, cutPath(c, s), ghost, 6, 6);
      }
    }

    final l = live;
    if (l != null && l.pts.length > 1) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = C.berry600;
      final path = cutPath(l.pts, s, close: l.stencil);
      if (l.stencil) {
        canvas.drawPath(path, Paint()..color = const Color(0x2EE0405E));
        drawDashed(canvas, path, stroke, 8, 6);
      } else {
        canvas.drawPath(path, stroke);
        canvas.drawCircle(l.pts.first * s, 6, Paint()..color = C.berry600);
      }
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

  @override
  bool shouldRepaint(_BoardPainter o) =>
      !identical(o.cuts, cuts) ||
      !identical(o.fallen, fallen) ||
      drops.isNotEmpty ||
      o.drops.isNotEmpty ||
      o.live != live ||
      o.color != color ||
      o.pattern != pattern ||
      o.s != s;
}
