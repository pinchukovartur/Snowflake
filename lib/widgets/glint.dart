import 'dart:async';

import 'package:flutter/material.dart';

/// A streak of light running across what is under it now and then, to draw
/// the eye to a button with something waiting: a pale diagonal band sweeping
/// from its top left to its bottom right over [_sweep], then a rest till the
/// next, clipped to [radius]. Takes no touches.
///
/// Only the sweep is animated; the rest is a plain timer, so between sweeps
/// no frames are drawn for it at all.
class Glint extends StatefulWidget {
  const Glint({super.key, required this.radius});
  final double radius;

  @override
  State<Glint> createState() => _GlintState();
}

class _GlintState extends State<Glint> with SingleTickerProviderStateMixin {
  /// One sweep, and the whole round with the rest after it.
  static const _sweep = Duration(milliseconds: 1200), _round = Duration(milliseconds: 5000);

  late final _ticker = AnimationController(vsync: this, duration: _sweep);
  Timer? _rest;

  @override
  void initState() {
    super.initState();
    _run();
  }

  /// One sweep, then the rest, then the next.
  void _run() => _ticker.forward(from: 0).whenComplete(() {
        if (mounted) _rest = Timer(_round - _sweep, _run);
      });

  @override
  void dispose() {
    _rest?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: CustomPaint(painter: _GlintPainter(_ticker), size: Size.infinite),
        ),
      );
}

class _GlintPainter extends CustomPainter {
  _GlintPainter(this.ticker) : super(repaint: ticker);

  /// The sweep, 0 to 1.
  final Animation<double> ticker;

  /// The band's half width, as a share of the diagonal.
  static const _half = .14;

  @override
  void paint(Canvas canvas, Size size) {
    final t = ticker.value;
    // Resting: nothing to draw.
    if (t <= 0 || t >= 1) return;
    // From wholly off the top left to wholly off the bottom right.
    final at = -_half + t * (1 + 2 * _half);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0x00FFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
          stops: [at - _half, at, at + _half],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlintPainter old) => old.ticker != ticker;
}
