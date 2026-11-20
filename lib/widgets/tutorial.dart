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

/// What the tutorials say to the player: the penguin in its circle on the
/// left, saying it in a speech bubble (see [_BubbleFrame]) across the rest
/// of the row. Placed by the screens, mostly up top where their top bar
/// stands otherwise.
class TutorialBubble extends StatelessWidget {
  const TutorialBubble(this.text, {super.key});
  final String text;

  static const _penguin = 'assets/Dialog_Pinguin.png';

  /// The penguin's width (its circle's too: the circle fills the picture's
  /// width at its foot, the hat sticking out over it), and the picture's
  /// height over width.
  static const _penguinWidth = 80.0, _penguinAspect = 622 / 512;

  /// The soft shadow under the penguin's circle and the bubble.
  static const bubbleShadow = BoxShadow(color: Color(0x40101A3F), offset: Offset(0, 4), blurRadius: 8);

  /// What the penguin says is written in: dark chocolate, to go with the
  /// bubble's brown outline.
  static const _ink = Color(0xFF533B22);

  /// The bubble's pop: the size it starts from, and how long it takes.
  static const _popFrom = .85;
  static const _pop = Duration(milliseconds: 350);

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Row(
      children: [
        // Only the circle takes room in the row: the hat sticks out over it
        // without making the row taller.
        SizedBox.square(
          dimension: _penguinWidth,
          child: Stack(clipBehavior: Clip.none, children: [
            // Under the circle, still while it rocks.
            const Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [bubbleShadow])),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _penguinWidth * _penguinAspect,
              child: _Sway(
                // About the circle's middle, not the picture's.
                pivot: const Alignment(0, 1 - 1 / _penguinAspect),
                // Decoded at the size it shows, not the source's.
                child: Image.asset(_penguin, width: _penguinWidth, height: _penguinWidth * _penguinAspect, cacheWidth: (_penguinWidth * dpr).round()),
              ),
            ),
          ]),
        ),
        // Room for the bubble's tail.
        const SizedBox(width: _BubbleFrame.tailWidth + 2),
        Expanded(
          // Springs out of the penguin, a touch past its size and back, as it
          // appears and each time it says something new.
          child: TweenAnimationBuilder<double>(
            key: ValueKey(text),
            tween: Tween(begin: _popFrom, end: 1),
            duration: _pop,
            curve: Curves.easeOutBack,
            builder: (_, s, child) => Transform.scale(scale: s, alignment: Alignment.centerLeft, child: child),
            child: _BubbleFrame(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Text(text, textAlign: TextAlign.center, style: body(22, weight: FontWeight.w800, color: _ink, height: 1.25)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The bubble's paper and outline, any size, around [child], built from two
/// pictures: the outline's top left corner (Dialog_Bubble_Body), mirrored into
/// all four with its last row and column stretched along the sides, and the
/// tail (Dialog_Bubble_Tail) out of the left side, under the outline.
class _BubbleFrame extends StatelessWidget {
  const _BubbleFrame({required this.child});
  final Widget child;

  static const _corner = 'assets/Dialog_Bubble_Body.png', _tail = 'assets/Dialog_Bubble_Tail.png';

  /// The corner picture's pixels per logical pixel, and its outline's width in
  /// its own pixels.
  static const _cornerScale = 1.5, _outline = 5.0;

  /// Stretched: the corner's last pixel, paper. In logical pixels, as Flutter
  /// takes it with a scale: it multiplies it back up itself.
  static const _stretch = Rect.fromLTWH(36 / _cornerScale, 32 / _cornerScale, 1 / _cornerScale, 1 / _cornerScale);

  /// The outline's outer corner radius, logical.
  static const _radius = 20.0;

  /// The tail's width and height over width, and how high its bottom is off the
  /// bubble's.
  static const tailWidth = 17.0, _tailAspect = 96 / 97, _tailUp = 18.0;

  @override
  Widget build(BuildContext context) {
    Widget quarter({required bool right, required bool bottom}) => Transform.flip(
          flipX: right,
          flipY: bottom,
          child: Image.asset(_corner, scale: _cornerScale, centerSlice: _stretch, fit: BoxFit.fill),
        );
    return Stack(
      clipBehavior: Clip.none,
      // As wide as it is let be, not just its text.
      fit: StackFit.passthrough,
      children: [
        // The shadow, under the paper's rounded rectangle.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(_radius)), boxShadow: [TutorialBubble.bubbleShadow]),
          ),
        ),
        // Under the outline, as far into it as it is wide.
        Positioned(
          left: -tailWidth + _outline / _cornerScale,
          bottom: _tailUp,
          child: Image.asset(_tail, width: tailWidth, height: tailWidth * _tailAspect),
        ),
        Positioned.fill(
          child: LayoutBuilder(builder: (_, box) {
            // A hair over half each way, so no seam shows where they meet.
            final w = box.maxWidth / 2 + .5, h = box.maxHeight / 2 + .5;
            return Stack(children: [
              Positioned(left: 0, top: 0, width: w, height: h, child: quarter(right: false, bottom: false)),
              Positioned(right: 0, top: 0, width: w, height: h, child: quarter(right: true, bottom: false)),
              Positioned(left: 0, bottom: 0, width: w, height: h, child: quarter(right: false, bottom: true)),
              Positioned(right: 0, bottom: 0, width: w, height: h, child: quarter(right: true, bottom: true)),
            ]);
          }),
        ),
        child,
      ],
    );
  }
}

/// Its [child] rocking gently side to side about [pivot], over and over.
/// Painted once and only turned: the turning costs no repaint.
class _Sway extends StatefulWidget {
  const _Sway({required this.pivot, required this.child});
  final Alignment pivot;
  final Widget child;

  @override
  State<_Sway> createState() => _SwayState();
}

class _SwayState extends State<_Sway> with SingleTickerProviderStateMixin {
  /// One way, left to right (or back): a whole rock is twice this.
  late final _rock = AnimationController(vsync: this, duration: const Duration(milliseconds: 1820))..repeat(reverse: true);

  /// Up to 5° each way, eased at both ends.
  static final _turn = Tween(begin: -5 / 360, end: 5 / 360).chain(CurveTween(curve: Curves.easeInOutSine));

  @override
  void dispose() {
    _rock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _turn.animate(_rock), alignment: widget.pivot, child: RepaintBoundary(child: widget.child));
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
