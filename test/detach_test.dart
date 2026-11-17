import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:snowflake/snowflake/detach.dart';
import 'package:snowflake/snowflake/geometry.dart';

/// A strip right across the wedge between heights [y1] and [y2].
Cut band(double y1, double y2) => [Offset(-1, y1), Offset(1, y1), Offset(1, y2), Offset(-1, y2)];

bool covers(List<Cut> pieces, Offset p) => pieces.any((c) => (cutPath(c, 1)..fillType = PathFillType.nonZero).contains(p));

void main() {
  test('untouched paper keeps everything', () {
    expect(detachedPieces(const [], const [], 6), isEmpty);
  });

  test('a notch that does not separate anything drops nothing', () {
    expect(detachedPieces([stencilShape('circle', 0, -0.5, 0.1)], const [], 6), isEmpty);
  });

  test('cutting across near the rim drops the tip', () {
    final pieces = detachedPieces([band(-0.85, -0.8)], const [], 6);
    expect(pieces, hasLength(1));
    expect(covers(pieces, const Offset(0, -0.95)), isTrue);
    expect(covers(pieces, const Offset(0, -0.78)), isFalse);
    expect(covers(pieces, const Offset(0, -0.5)), isFalse);
  });

  test('cutting across near the centre drops the middle', () {
    final pieces = detachedPieces([band(-0.25, -0.2)], const [], 6);
    expect(pieces, hasLength(1));
    expect(covers(pieces, const Offset(0, -0.1)), isTrue);
    expect(covers(pieces, const Offset(0, -0.6)), isFalse);
  });

  test('an island held only by one fold edge falls with its mirror', () {
    // A "C" open to the left, around a bit of paper at the left fold edge.
    const c = [
      Offset(-0.4, -0.7), Offset(-0.05, -0.7), Offset(-0.05, -0.5), Offset(-0.4, -0.5),
      Offset(-0.4, -0.53), Offset(-0.08, -0.53), Offset(-0.08, -0.67), Offset(-0.4, -0.67),
    ];
    final pieces = detachedPieces([c], const [], 6);
    expect(pieces, hasLength(1));
    expect(covers(pieces, const Offset(-0.12, -0.6)), isTrue);
    expect(covers(pieces, const Offset(0, -0.6)), isFalse);
  });

  test('pieces that already fell are not dropped again', () {
    final cuts = [band(-0.85, -0.8)];
    final fallen = detachedPieces(cuts, const [], 6);
    expect(detachedPieces(cuts, fallen, 6), isEmpty);
  });
}
