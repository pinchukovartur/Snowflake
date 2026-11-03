import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Something standing on the floor in front of the home window's door (a fir
/// tree, say), in a box the home screen lays out for it: shown as [painter]
/// draws it there, taking taps inside its [outline] there.
class WindowDecor {
  const WindowDecor({required this.painter, required this.outline});

  final CustomPainter painter;
  final Path Function(Size box) outline;
}

/// What stands in front of the door in this build, set by hand for each
/// release; null for the door alone.
// ignore: unnecessary_nullable_for_final_variable_declarations
const WindowDecor? windowDecor = WindowDecor(painter: _TreePainter(), outline: _TreePainter.outline);

/// A fir tree of three tiers of triangles, lit from the left like the window,
/// on a trunk standing at the bottom of its box, a star on top and baubles
/// hung about it.
class _TreePainter extends CustomPainter {
  const _TreePainter();

  static const _lit = Color(0xFF2E9E73), _dark = Color(0xFF1C7354), _trunk = Color(0xFF8A5A3C);

  /// Each tier's apex and base heights, and its base's width, as shares of
  /// the box: top tier first, each base overlapping the next one's apex.
  static const _tiers = [(.07, .38, .56), (.24, .62, .78), (.44, .9, 1.0)];

  /// Baubles: across from the middle, down, and colour.
  static const _baubles = [
    (-.12, .33, C.berry500), (.14, .3, C.sun500),
    (.2, .55, C.ice400), (-.24, .57, C.sun500), (0.0, .5, C.berry500),
    (-.36, .84, C.ice400), (.33, .85, C.berry500), (.04, .8, C.sun500),
  ];

  static Rect _trunkRect(Size size) => Rect.fromLTRB(size.width * .43, size.height * .86, size.width * .57, size.height);

  /// The five-pointed star on the top tier's apex.
  static List<Offset> _star(Size size) {
    final star = Offset(size.width / 2, size.height * _tiers.first.$1), outer = size.width * .08, inner = outer * .45;
    return [for (var k = 0; k < 10; k++) star + Offset.fromDirection(-math.pi / 2 + k * math.pi / 5, k.isEven ? outer : inner)];
  }

  /// The tree's outline in a box [size]: tiers, trunk and star.
  static Path outline(Size size) {
    final w = size.width, h = size.height, mid = w / 2;
    // Joined as shapes, not just added: overlapping the other way round,
    // added ones would cancel out where they meet.
    var path = Path()..addRect(_trunkRect(size));
    for (final part in [
      _star(size),
      for (final (apex, base, width) in _tiers) [Offset(mid, h * apex), Offset(mid - w * width / 2, h * base), Offset(mid + w * width / 2, h * base)],
    ]) {
      path = Path.combine(PathOperation.union, path, Path()..addPolygon(part, true));
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, mid = w / 2;
    canvas.drawRect(_trunkRect(size), Paint()..color = _trunk);
    for (final (apex, base, width) in _tiers) {
      final a = Offset(mid, h * apex), half = w * width / 2;
      canvas.drawPath(Path()..addPolygon([a, Offset(mid - half, h * base), Offset(mid, h * base)], true), Paint()..color = _lit);
      canvas.drawPath(Path()..addPolygon([a, Offset(mid, h * base), Offset(mid + half, h * base)], true), Paint()..color = _dark);
    }
    final r = w * .035;
    for (final (x, y, c) in _baubles) {
      canvas.drawCircle(Offset(mid + w * x, h * y), r, Paint()..color = c);
    }
    canvas.drawPath(Path()..addPolygon(_star(size), true), Paint()..color = C.sun500);
  }

  @override
  bool shouldRepaint(_TreePainter oldDelegate) => false;
}
