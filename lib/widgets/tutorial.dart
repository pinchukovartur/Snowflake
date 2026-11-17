import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The tutorial's yellow arrow, pointing down at what to tap and bobbing over it.
class TutorialArrow extends StatefulWidget {
  const TutorialArrow({super.key});

  @override
  State<TutorialArrow> createState() => _TutorialArrowState();
}

class _TutorialArrowState extends State<TutorialArrow> with SingleTickerProviderStateMixin {
  late final _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Coming up out of nothing as it appears.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, a, child) => Opacity(opacity: a, child: child),
      child: AnimatedBuilder(
        animation: _bob,
        builder: (_, child) => Transform.translate(offset: Offset(0, -10 * Curves.easeInOut.transform(_bob.value)), child: child),
        child: const CustomPaint(size: Size(44, 56), painter: _ArrowPainter()),
      ),
    );
  }
}

/// A fat arrow pointing down: sun yellow, outlined darker.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, shaft = w * .22, head = h * .5;
    final path = Path()
      ..moveTo(w / 2 - shaft, 2)
      ..lineTo(w / 2 + shaft, 2)
      ..lineTo(w / 2 + shaft, h - head)
      ..lineTo(w - 2, h - head)
      ..lineTo(w / 2, h - 2)
      ..lineTo(2, h - head)
      ..lineTo(w / 2 - shaft, h - head)
      ..close();
    canvas.drawPath(path, Paint()..color = C.sun500);
    canvas.drawPath(
      path,
      Paint()
        ..color = C.sun700
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

/// What the tutorials say to the player, in a rectangle of paper across the
/// top of the screen, where its top bar stands otherwise.
class TutorialBubble extends StatelessWidget {
  const TutorialBubble(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Across the whole row.
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: C.paper,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: C.snow300, offset: Offset(0, 4))],
      ),
      child: Text(text, textAlign: TextAlign.center, style: display(22, weight: FontWeight.w700, color: C.night800)),
    );
  }
}

/// While [on], its [child] swells and settles gently in place, over and over,
/// to draw the eye.
class Beckon extends StatefulWidget {
  const Beckon({super.key, required this.on, required this.child});
  final bool on;
  final Widget child;

  @override
  State<Beckon> createState() => _BeckonState();
}

class _BeckonState extends State<Beckon> with SingleTickerProviderStateMixin {
  /// One way, small to big (or back): a whole breath is twice this.
  late final _beat = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  /// Up to 5% bigger, eased in and out at both ends.
  static final _scale = Tween(begin: 1.0, end: 1.05).chain(CurveTween(curve: Curves.easeInOutSine));

  @override
  void initState() {
    super.initState();
    if (widget.on) _beat.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(Beckon old) {
    super.didUpdateWidget(old);
    if (widget.on && !_beat.isAnimating) {
      _beat.repeat(reverse: true);
    } else if (!widget.on && _beat.isAnimating) {
      _beat
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale.animate(_beat), child: widget.child);
  }
}
