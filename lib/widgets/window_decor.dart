import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../app_state.dart';

/// Something standing on the floor in front of the home window's door (a fir
/// tree, say), drawn from [image], in a box the home screen lays out for it
/// as wide as [aspect] times its height: taking taps inside its [outline]
/// there. If it has a [thawed] picture too, that from day [thawsOn] (its
/// month and day) of the season on, through to its January.
class WindowDecor {
  const WindowDecor({
    required this.image,
    this.thawed,
    this.thawsOn = (12, 25),
    required this.aspect,
    required this.outline,
    this.thawedAspect = 1,
    this.lights = const [],
  });

  final String image;
  final String? thawed;
  final (int, int) thawsOn;
  final double aspect;
  final Path Function(Size box) outline;

  /// The [thawed] picture's width over its height, and where on it its
  /// lights are, as shares of its width and height: blinking there once
  /// it is thawed (see [DecorLights]).
  final double thawedAspect;
  final List<Offset> lights;

  /// Whether it is [thawed] on day [now].
  bool thawedOn(DateTime now) {
    if (thawed == null) return false;
    final (month, day) = thawsOn;
    return now.month == 1 || (now.month == month && now.day >= day);
  }
}

/// For testing what stands in front of the door: a tap on it thaws it or
/// freezes it again, whatever the day (see [WindowDecor.thawed]). Debug
/// builds only.
const decorCheat = true && kDebugMode && !storeShots;

/// What stands in front of the door in this build, set by hand for each
/// release; null for the door alone. This one a fir tree frozen in ice,
/// thawing on Christmas Day.
// ignore: unnecessary_nullable_for_final_variable_declarations
const WindowDecor? windowDecor = WindowDecor(
  image: 'assets/Christmas/Christmas_Tree_Frozen.png',
  thawed: 'assets/Christmas/Christmas_Tree_Unfrozen.png',
  aspect: 1035 / 1519,
  outline: _treeOutline,
  thawedAspect: 1024 / 1536,
  lights: _treeLights,
);

/// The thawed fir tree's lights, where its picture has them: top to bottom.
const _treeLights = [
  Offset(0.538, 0.090),
  Offset(0.476, 0.105),
  Offset(0.536, 0.166),
  Offset(0.603, 0.172),
  Offset(0.391, 0.198),
  Offset(0.501, 0.222),
  Offset(0.636, 0.235),
  Offset(0.707, 0.256),
  Offset(0.408, 0.271),
  Offset(0.334, 0.286),
  Offset(0.582, 0.299),
  Offset(0.529, 0.309),
  Offset(0.472, 0.327),
  Offset(0.731, 0.357),
  Offset(0.307, 0.388),
  Offset(0.261, 0.392),
  Offset(0.651, 0.433),
  Offset(0.435, 0.458),
  Offset(0.518, 0.459),
  Offset(0.375, 0.463),
  Offset(0.567, 0.463),
  Offset(0.633, 0.464),
  Offset(0.291, 0.507),
  Offset(0.716, 0.522),
  Offset(0.795, 0.525),
  Offset(0.453, 0.595),
  Offset(0.570, 0.598),
  Offset(0.512, 0.606),
  Offset(0.297, 0.619),
  Offset(0.729, 0.621),
  Offset(0.243, 0.631),
  Offset(0.167, 0.634),
  Offset(0.820, 0.637),
  Offset(0.869, 0.637),
  Offset(0.369, 0.706),
  Offset(0.432, 0.709),
  Offset(0.717, 0.710),
  Offset(0.786, 0.716),
  Offset(0.599, 0.736),
  Offset(0.865, 0.741),
  Offset(0.649, 0.745),
  Offset(0.910, 0.746),
  Offset(0.263, 0.759),
  Offset(0.161, 0.770),
  Offset(0.833, 0.827),
  Offset(0.457, 0.831),
  Offset(0.336, 0.837),
  Offset(0.401, 0.844),
  Offset(0.674, 0.854),
  Offset(0.961, 0.854),
  Offset(0.227, 0.891),
  Offset(0.166, 0.897),
];

/// Lights blinking on what stands in front of the door, over its picture
/// (fitted into the box, on the floor, as wide as [aspect] times its
/// height) at [lights] on it: in four colours, all of a colour together,
/// the colours by turns. Each colour's lights are painted once; only how
/// strongly each lot shows changes as they blink, so blinking costs no
/// repainting.
class DecorLights extends StatefulWidget {
  const DecorLights({super.key, required this.aspect, required this.lights});
  final double aspect;
  final List<Offset> lights;

  @override
  State<DecorLights> createState() => _DecorLightsState();
}

class _DecorLightsState extends State<DecorLights> with SingleTickerProviderStateMixin {
  /// The colours, a light to each in turn.
  static const _colours = [Color(0xFFFF0061), Color(0xFF00FF97), Color(0xFFFF9900), Color(0xFF00ECFF)];

  /// One round of blinking: each colour lit up and out again in its turn.
  late final _round = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _round.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        // The bulbs, out: small and white, so they show between
        // blinks. Painted once, never changing.
        RepaintBoundary(
          child: CustomPaint(
            painter: _BulbsPainter(widget.aspect, widget.lights),
          ),
        ),
        for (var c = 0; c < _colours.length; c++)
          FadeTransition(
            opacity: _round.drive(_Blink(c / _colours.length)),
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _LightsPainter(widget.aspect, [for (var i = c; i < widget.lights.length; i += _colours.length) widget.lights[i]], _colours[c]),
              ),
            ),
          ),
      ]);
}

/// A colour's lights' strength through a round, starting [phase] of the
/// way in: up out of nothing and back over [_lit] of the round, out between.
class _Blink extends Animatable<double> {
  const _Blink(this.phase);
  final double phase;

  /// What share of a round a colour's lights are lit for: at .5 two colours
  /// at once (the four by turns a quarter apart), at .25 or less one at a
  /// time.
  static const _lit = 1.0;

  @override
  double transform(double t) {
    final u = (t + 1 - phase) % 1;
    return u < _lit ? math.sin(math.pi * u / _lit) : 0;
  }
}

/// Lights of one [colour] at [lights] on a picture [aspect] wide, fitted
/// into the box on the floor: each a white heart in a glow of its colour.
class _LightsPainter extends CustomPainter {
  const _LightsPainter(this.aspect, this.lights, this.colour);
  final double aspect;
  final List<Offset> lights;
  final Color colour;

  /// A light's glow's radius, as a share of the picture's width.
  static const _glow = .035;

  @override
  void paint(Canvas canvas, Size size) {
    final h = math.min(size.height, size.width / aspect), w = h * aspect;
    final pic = Rect.fromLTWH((size.width - w) / 2, size.height - h, w, h);
    final r = w * _glow;
    for (final l in lights) {
      final at = Offset(pic.left + l.dx * w, pic.top + l.dy * h);
      canvas.drawCircle(
        at,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFFFFFFF), colour, colour.withValues(alpha: 0)],
            stops: const [0, .25, 1],
          ).createShader(Rect.fromCircle(center: at, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_LightsPainter old) => old.aspect != aspect || old.colour != colour || old.lights != lights;
}

/// The bulbs at [lights] on a picture [aspect] wide, fitted into the box on
/// the floor, out: each a small solid white disc, whatever colour it lights
/// up in.
class _BulbsPainter extends CustomPainter {
  const _BulbsPainter(this.aspect, this.lights);
  final double aspect;
  final List<Offset> lights;

  /// A bulb's radius, as a share of the picture's width.
  static const _radius = .009;

  @override
  void paint(Canvas canvas, Size size) {
    final h = math.min(size.height, size.width / aspect), w = h * aspect;
    final pic = Rect.fromLTWH((size.width - w) / 2, size.height - h, w, h);
    final paint = Paint()..color = const Color.fromARGB(181, 255, 255, 255);
    for (final l in lights) {
      canvas.drawCircle(Offset(pic.left + l.dx * w, pic.top + l.dy * h), w * _radius, paint);
    }
  }

  @override
  bool shouldRepaint(_BulbsPainter old) => old.aspect != aspect || old.lights != lights;
}

/// The fir tree's outline in a box [size], roughly, frozen or thawed: from
/// its tip widening down its tiers to its lowest branches, the whole width
/// of its box, and its foot. Where a tap on it counts (see [WindowDecor]).
Path _treeOutline(Size size) => Path()
  ..addPolygon([
    for (final (x, y) in const [
      (.5, 0.0),
      (.6, .12),
      (.72, .35),
      (.86, .6),
      (1.0, .85),
      (1.0, 1.0),
      (0.0, 1.0),
      (0.0, .85),
      (.14, .6),
      (.28, .35),
      (.4, .12),
    ])
      Offset(size.width * x, size.height * y),
  ], true);
