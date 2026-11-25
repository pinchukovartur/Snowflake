import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Little four-pointed stars flying off something [size] across (a flake,
/// a gift), over and over: each from its rim straight out, a touch up, growing bright
/// and fading as it goes; white, warmed with [color].
class Sparks extends StatefulWidget {
  const Sparks({super.key, required this.color, required this.size});
  final Color color;
  final double size;

  @override
  State<Sparks> createState() => _SparksState();
}

class _SparksState extends State<Sparks> with SingleTickerProviderStateMixin {
  late final _time = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _SparksPainter(_time, Color.lerp(widget.color, Colors.white, .55)!)),
      );
}

class _SparksPainter extends CustomPainter {
  _SparksPainter(this.time, this.color) : super(repaint: time);
  final Animation<double> time;
  final Color color;

  /// How many stars are about at once; from and to how far out from the
  /// middle each flies, as shares of the flake's size (from its rim, the
  /// flake hiding any nearer); how big a star is at its brightest, in
  /// px.
  static const _count = 12, _from = .48, _to = .66, _star = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), w = size.shortestSide;
    final paint = Paint();
    for (var k = 0; k < _count; k++) {
      // Each its own way out, start and speed: the golden ratio's steps, so
      // neighbours seldom match.
      final a = (k * .618034) % 1, b = (k * .754878 + .3) % 1;
      // A whole number of flights to a round of [time] (two to four, each
      // its own), so it runs on unbroken as that starts again.
      final u = (time.value * (2 + k % 3) + a * 7.3) % 1;
      final angle = 2 * math.pi * ((k + a) / _count);
      final dir = Offset(math.cos(angle), math.sin(angle) - .12);
      final at = c + dir * (w * (_from + (_to - _from) * u));
      final lit = math.sin(math.pi * u);
      final r = _star * (.5 + .5 * b) * (.4 + .6 * lit);
      final q = r * .28;
      paint.color = color.withValues(alpha: lit);
      canvas.drawPath(
        Path()
          ..addPolygon([
            at + Offset(0, -r), at + Offset(q, -q), at + Offset(r, 0), at + Offset(q, q), //
            at + Offset(0, r), at + Offset(-q, q), at + Offset(-r, 0), at + Offset(-q, -q),
          ], true),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparksPainter old) => old.color != color;
}
