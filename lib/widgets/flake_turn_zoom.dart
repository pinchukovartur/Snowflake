import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// A flake on show that the player can turn and zoom: a lone finger on the
/// flake turns it (and a flick sets it coasting), two fingers pinch it bigger
/// and push it about.
///
/// Put [turnZoomGestures] under everything in a full-screen [Stack], and the
/// flake from [turnZoomFlake] wherever it sits.
mixin FlakeTurnZoom<T extends StatefulWidget> on TickerProviderStateMixin<T> {
  /// Radius of the flake as laid out, before zoom: where a finger can grab it.
  double get flakeRadius;

  /// How far the player has turned the flake; after a flick it coasts on
  /// from [_glide].
  double _turn = 0;
  late final AnimationController _glide = AnimationController.unbounded(vsync: this)..addListener(() => _turn = _glide.value);
  final _flakeKey = GlobalKey();
  bool _grabbing = false;
  double _lastAngle = 0, _speed = 0;
  final _sinceMove = Stopwatch();

  /// Pinch zoom (1 = as laid out) and the pan that goes with it.
  double _zoom = 1, _pinchFrom = 1;
  Offset _pan = Offset.zero;
  bool _pinching = false;
  static const _maxZoom = 3.0;

  /// Seconds the paper has shimmered for, once [startTwinkle] has been
  /// called (for a flake on paper that [shimmers]).
  double twinkleAt = 0;
  late final _twinkle = createTicker((elapsed) => setState(() => twinkleAt = elapsed.inMicroseconds / 1e6));

  void startTwinkle() {
    if (!_twinkle.isActive) _twinkle.start();
  }

  @override
  void dispose() {
    _glide.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  /// The flake's centre on screen, or null before it is laid out.
  Offset? get _flakeCentre {
    final box = _flakeKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(box.size.center(Offset.zero));
  }

  void _scaleStart(ScaleStartDetails d) {
    if (d.pointerCount >= 2) {
      // A second finger turns the touch into a pinch: no more turning, no coasting.
      _grabbing = false;
      _glide.stop();
      _pinching = true;
      _pinchFrom = _zoom;
      return;
    }
    _pinching = false;
    _grab(d.focalPoint);
  }

  void _scaleUpdate(ScaleUpdateDetails d) {
    if (_pinching) {
      setState(() {
        _zoom = (_pinchFrom * d.scale).clamp(1.0, _maxZoom);
        // The flake can be pushed about only as far as the zoom has outgrown the view.
        final reach = flakeRadius * (_zoom - 1);
        _pan = Offset((_pan.dx + d.focalPointDelta.dx).clamp(-reach, reach), (_pan.dy + d.focalPointDelta.dy).clamp(-reach, reach));
      });
    } else {
      _drag(d.focalPoint);
    }
  }

  void _scaleEnd(ScaleEndDetails d) {
    // Fingers still down: the gesture restarts (as a pinch, or a lone finger after one lifts).
    if (d.pointerCount > 0) {
      _grabbing = false;
      return;
    }
    if (_pinching) {
      _pinching = false;
      return;
    }
    _release();
  }

  void _grab(Offset at) {
    final c = _flakeCentre;
    // Only the flake itself can be taken hold of, not the air round it.
    _grabbing = c != null && (at - c).distance <= flakeRadius * _zoom;
    if (!_grabbing) return;
    _glide.stop();
    final a = at - c!;
    _lastAngle = math.atan2(a.dy, a.dx);
    _speed = 0;
    _sinceMove.reset();
    _sinceMove.start();
  }

  void _drag(Offset at) {
    final c = _flakeCentre;
    if (!_grabbing || c == null) return;
    final a = at - c;
    final angle = math.atan2(a.dy, a.dx);
    var da = angle - _lastAngle;
    if (da > math.pi) da -= 2 * math.pi;
    if (da < -math.pi) da += 2 * math.pi;
    _lastAngle = angle;
    final dt = _sinceMove.elapsedMicroseconds / 1e6;
    _sinceMove.reset();
    if (dt > 0) _speed = _speed * .6 + da / dt * .4;
    setState(() => _turn += da);
  }

  void _release() {
    if (!_grabbing) return;
    _grabbing = false;
    // A finger that stopped before lifting leaves the flake still.
    final v = _sinceMove.elapsedMilliseconds > 80 ? 0.0 : _speed.clamp(-18.0, 18.0);
    if (v.abs() < .3) return;
    _glide.value = _turn;
    _glide.animateWith(FrictionSimulation(.08, _turn, v));
  }

  /// The whole view takes the gesture: a lone finger on the flake turns it, two pinch it.
  Widget turnZoomGestures() => Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _scaleStart,
          onScaleUpdate: _scaleUpdate,
          onScaleEnd: _scaleEnd,
        ),
      );

  /// The flake [builder] draws for the player's turn (radians), zoomed and
  /// panned; rebuilt as it coasts and whenever [also] ticks.
  Widget turnZoomFlake(Widget Function(double turn) builder, {Listenable? also}) => IgnorePointer(
        // Touches pass through: the gesture view below does the touching.
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(_pan.dx, _pan.dy, 0)..scaleByDouble(_zoom, _zoom, 1, 1),
          child: AnimatedBuilder(
            animation: also == null ? _glide : Listenable.merge([also, _glide]),
            builder: (_, _) => KeyedSubtree(key: _flakeKey, child: builder(_turn)),
          ),
        ),
      );
}
