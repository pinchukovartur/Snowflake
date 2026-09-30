import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'geometry.dart';

/// Interactive folded wedge: drag a loop to cut (tool `free`) or tap-and-drag
/// to stamp a stencil (`circle`, `square`, `triangle`, `star`, `heart`, `drop`).
class CutBoard extends StatefulWidget {
  const CutBoard({
    super.key,
    required this.cuts,
    required this.onCut,
    this.folds = 6,
    this.height = 440,
    this.tool = 'free',
    this.color = Colors.white,
    this.pattern = 'plain',
    this.disabled = false,
    this.showGhosts = true,
  });

  final List<Cut> cuts;
  final ValueChanged<Cut> onCut;
  final int folds;
  final double height;
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

class _CutBoardState extends State<CutBoard> {
  _Live? _live;

  double get _s => widget.height * 0.94;
  double get _width => CutBoard.widthFor(widget.height, widget.folds);
  Offset get _apex => Offset(_width / 2, widget.height - 8);

  Offset _toUnit(Offset local) => (local - _apex) / _s;

  Cut _stamp(Offset c, Offset p) => stencilShape(widget.tool, c.dx, c.dy, ((p - c).distance).clamp(0.05, 0.3));

  void _down(PointerDownEvent e) {
    if (widget.disabled) return;
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
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: CustomPaint(
        size: Size(_width, widget.height),
        painter: _BoardPainter(
          cuts: widget.cuts,
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
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.cuts,
    required this.live,
    required this.half,
    required this.s,
    required this.apex,
    required this.color,
    required this.pattern,
    required this.showGhosts,
  });

  final List<Cut> cuts;
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

    drawWedge(canvas, s, cuts, half, makePaperFill(color, pattern, s));

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
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoardPainter o) =>
      !identical(o.cuts, cuts) || o.live != live || o.color != color || o.pattern != pattern || o.s != s;
}
