import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One fleck of snow. [depth] 0 is far off, 1 close to the glass: nearer
/// flecks are bigger, brighter and fall faster.
class _Fleck {
  _Fleck(math.Random r)
    : x = r.nextDouble(),
      phase = r.nextDouble(),
      depth = r.nextDouble(),
      sway = 3 + r.nextDouble() * 4,
      swayPhase = r.nextDouble() * 2 * math.pi;
  final double x, phase, depth, sway, swayPhase;

  /// Seconds from the top of the screen to the bottom.
  double get fall => (14 - depth * 7) / .64;
  double get alpha => .45 + depth * .5;
}

/// Snow falling outside the window: small round flecks drifting down, seen
/// soft through the glass and softer still in the bottom [hazeHeight] behind
/// the buttons, setting in over its top [hazeFade].
class Snowfall extends StatefulWidget {
  const Snowfall({super.key, required this.ticker, required this.hazeHeight, required this.hazeFade, required this.drift});
  final AnimationController ticker;
  final double hazeHeight, hazeFade;

  /// How far the snow has drifted with the windows' pan, now: the nearest
  /// flecks twice as far as the furthest.
  final Offset Function() drift;

  @override
  State<Snowfall> createState() => _SnowfallState();
}

class _SnowfallState extends State<Snowfall> {
  final _flecks = List.generate(140, (_) => _Fleck(_rnd));
  static final _rnd = math.Random();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SnowfallPainter(
          _flecks,
          widget.ticker,
          dpr: MediaQuery.devicePixelRatioOf(context),
          hazeHeight: widget.hazeHeight,
          hazeFade: widget.hazeFade,
          drift: widget.drift,
        ),
      ),
    );
  }
}

/// Draws every fleck from one sprite sheet of ready-blurred dots, so the snow
/// looks as if seen through frosted glass without blurring the screen.
class _SnowfallPainter extends CustomPainter {
  _SnowfallPainter(this.flecks, this.ticker, {required this.dpr, required this.hazeHeight, required this.hazeFade, required this.drift}) : super(repaint: ticker);
  final List<_Fleck> flecks;
  final AnimationController ticker;
  final double dpr, hazeHeight, hazeFade;
  final Offset Function() drift;

  /// Fleck radii in dp, far to near.
  static const _radii = [.775, 1.125, 1.3, 1.45];
  static const _sizes = 4;
  static double _radius(int k) => _radii[k];

  /// Blur in dp: through the glass, and behind the buttons.
  static const _sigmas = [1.25, 2.85];

  /// One sprite's square, wide enough for the largest, blurriest dot.
  static const _cell = 2 * (2.0 + 3 * 2.85);

  /// Sprite sheets by device pixel ratio: a row per blur, a column per size.
  static final _sheets = <double, ui.Image>{};

  static ui.Image _sheet(double dpr) => _sheets.putIfAbsent(dpr, () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec)..scale(dpr);
        for (var l = 0; l < _sigmas.length; l++) {
          for (var k = 0; k < _sizes; k++) {
            c.drawCircle(
              Offset((k + .5) * _cell, (l + .5) * _cell),
              _radius(k),
              Paint()
                ..color = Colors.white
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, _sigmas[l]),
            );
          }
        }
        return rec.endRecording().toImageSync((_sizes * _cell * dpr).ceil(), (_sigmas.length * _cell * dpr).ceil());
      });

  @override
  void paint(Canvas canvas, Size size) {
    final t = (ticker.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6;
    final sheet = _sheet(dpr);
    final px = _cell * dpr, margin = _cell / 2;
    final hazeTop = size.height - hazeHeight;
    final transforms = <RSTransform>[], rects = <Rect>[], colors = <Color>[];
    final shift = drift();
    final tall = size.height + 2 * margin, wide = size.width + 2 * margin;
    for (final f in flecks) {
      // Wrapping round as it drifts, so the screen stays full.
      final near = 1 + f.depth;
      final ph = (t / f.fall + f.phase + shift.dy * near / tall) % 1;
      final y = -margin + tall * ph;
      final x = -margin + (margin + f.x * size.width + shift.dx * near) % wide + (5 + 7 * f.depth) * math.sin(t / f.sway * 2 * math.pi + f.swayPhase);
      final k = math.min(_sizes - 1, (f.depth * _sizes).floor());
      // Behind the buttons the softer sprite fades in over the plain one.
      final w = ((y - hazeTop) / hazeFade).clamp(0.0, 1.0);
      final haze = w * w * (3 - 2 * w);
      for (final (l, share) in [(0, 1 - haze), (1, haze)]) {
        if (share <= 0) continue;
        transforms.add(RSTransform.fromComponents(rotation: 0, scale: 1 / dpr, anchorX: px / 2, anchorY: px / 2, translateX: x, translateY: y));
        rects.add(Rect.fromLTWH(k * px, l * px, px, px));
        colors.add(Color.fromRGBO(255, 255, 255, f.alpha * share));
      }
    }
    canvas.drawAtlas(sheet, transforms, rects, colors, BlendMode.modulate, null, Paint()..filterQuality = FilterQuality.low);
  }

  @override
  bool shouldRepaint(_SnowfallPainter o) =>
      !identical(o.flecks, flecks) || o.ticker != ticker || o.dpr != dpr || o.hazeHeight != hazeHeight || o.hazeFade != hazeFade;
}
