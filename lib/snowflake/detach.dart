import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'geometry.dart';

/// Raster cell in wedge units: about a pixel on the cut board.
const _cell = 1 / 400;

/// Paper kept past the fold edges, a bit wider than the seam pad in
/// SnowflakeView, so fallen outlines cover that pad too.
const _pad = 0.007;

/// Outlines of the paper pieces that no longer hold on after [cuts]
/// (pieces in [fallen] are already gone).
///
/// Unfolded, a piece touching a fold edge is joined to its mirror image, and one
/// touching both edges runs right round the flake. So a piece's real size is its
/// area in the wedge ×1, ×2 or ×(2·folds): the biggest stays, the rest fall off.
List<Cut> detachedPieces(List<Cut> cuts, List<Cut> fallen, int folds) {
  final half = wedgeHalfAngle(folds);
  final cosH = math.cos(half), sinH = math.sin(half);
  final (paper, cols, rows, x0, y0) = _paperLeft([...cuts, ...fallen], folds);

  // 4-connected pieces; label = piece index + 1.
  final label = Int32List(cols * rows);
  final queue = Int32List(cols * rows);
  final starts = <int>[], weights = <int>[];
  for (var start = 0; start < paper.length; start++) {
    if (paper[start] == 0 || label[start] != 0) continue;
    final id = starts.length + 1;
    var head = 0, tail = 0;
    var left = false, right = false;
    label[start] = id;
    queue[tail++] = start;
    while (head < tail) {
      final p = queue[head++];
      final i = p % cols, j = p ~/ cols;
      final x = x0 + (i + .5) * _cell, y = y0 + (j + .5) * _cell;
      if (x * cosH - y * sinH < _cell / 2) left = true;
      if (-x * cosH - y * sinH < _cell / 2) right = true;
      for (final q in [if (i > 0) p - 1, if (i < cols - 1) p + 1, if (j > 0) p - cols, if (j < rows - 1) p + cols]) {
        if (paper[q] == 1 && label[q] == 0) {
          label[q] = id;
          queue[tail++] = q;
        }
      }
    }
    starts.add(start);
    weights.add(tail * (left && right ? 2 * folds : left || right ? 2 : 1));
  }
  if (starts.length < 2) return const [];

  var kept = 0;
  for (var k = 1; k < weights.length; k++) {
    if (weights[k] > weights[kept]) kept = k;
  }
  return [
    for (var k = 0; k < starts.length; k++)
      if (k != kept) _outline(label, cols, rows, k + 1, starts[k], x0, y0),
  ];
}

/// Whether [cut] would take away any of the paper left after [gone] (cuts and
/// fallen pieces): a cut wholly off the paper, or inside a hole, misses.
bool cutsPaper(Cut cut, List<Cut> gone, int folds) {
  final (paper, cols, rows, x0, y0) = _paperLeft(gone, folds);
  return _clearPolygon(paper, cols, rows, x0, y0, cut) > 0;
}

/// The wedge rasterised (1 = paper, by cell centre) with [gone] cleared, and
/// the grid's size and top-left corner in wedge units.
(Uint8List, int, int, double, double) _paperLeft(List<Cut> gone, int folds) {
  final half = wedgeHalfAngle(folds);
  final cosH = math.cos(half), sinH = math.sin(half);
  final x0 = -(sinH + _pad), y0 = -1.0;
  final cols = (-2 * x0 / _cell).ceil(), rows = ((1 + _pad / sinH) / _cell).ceil();

  final paper = Uint8List(cols * rows);
  for (var j = 0; j < rows; j++) {
    final y = y0 + (j + .5) * _cell;
    for (var i = 0; i < cols; i++) {
      final x = x0 + (i + .5) * _cell;
      if (x * x + y * y <= 1 && x * cosH - y * sinH >= -_pad && -x * cosH - y * sinH >= -_pad) paper[j * cols + i] = 1;
    }
  }
  for (final c in gone) {
    _clearPolygon(paper, cols, rows, x0, y0, c);
  }
  return (paper, cols, rows, x0, y0);
}

/// Clears the cells whose centres lie inside [poly] (non-zero rule, like the
/// cut paths); returns how many held paper.
int _clearPolygon(Uint8List grid, int cols, int rows, double x0, double y0, Cut poly) {
  if (poly.length < 3) return 0;
  var cleared = 0;
  var minY = poly.first.dy, maxY = minY;
  for (final p in poly) {
    minY = math.min(minY, p.dy);
    maxY = math.max(maxY, p.dy);
  }
  final xs = <(double, int)>[];
  final j0 = math.max(0, ((minY - y0) / _cell - .5).floor());
  final j1 = math.min(rows - 1, ((maxY - y0) / _cell - .5).ceil());
  for (var j = j0; j <= j1; j++) {
    final y = y0 + (j + .5) * _cell;
    xs.clear();
    for (var k = 0; k < poly.length; k++) {
      final a = poly[k], b = poly[(k + 1) % poly.length];
      if ((a.dy <= y) == (b.dy <= y)) continue;
      xs.add((a.dx + (y - a.dy) / (b.dy - a.dy) * (b.dx - a.dx), b.dy > a.dy ? 1 : -1));
    }
    xs.sort((p, q) => p.$1.compareTo(q.$1));
    var winding = 0;
    for (var k = 0; k < xs.length - 1; k++) {
      winding += xs[k].$2;
      if (winding == 0) continue;
      final from = math.max(0, ((xs[k].$1 - x0) / _cell - .5).ceil());
      final to = math.min(cols - 1, ((xs[k + 1].$1 - x0) / _cell - .5).floor());
      for (var i = from; i <= to; i++) {
        cleared += grid[j * cols + i];
        grid[j * cols + i] = 0;
      }
    }
  }
  return cleared;
}

/// Outer boundary of piece [id] along cell edges, pushed out by a cell so no
/// paper sliver is left along the cut, then simplified.
Cut _outline(Int32List label, int cols, int rows, int id, int start, double x0, double y0) {
  bool inside(int i, int j) => i >= 0 && j >= 0 && i < cols && j < rows && label[j * cols + i] == id;
  // Headings E S W N (clockwise on screen) and their outward (left-hand) normals.
  const dx = [1, 0, -1, 0], dy = [0, 1, 0, -1];
  const nx = [0, 1, 0, -1], ny = [-1, 0, 1, 0];

  // [start] is the piece's first cell in scan order, so its top-left corner is
  // a corner of the boundary. Walk with the piece on the right.
  final i0 = start % cols, j0 = start ~/ cols;
  final corners = <(int, int, int)>[]; // vertex + heading leaving it
  var vx = i0, vy = j0, d = 0;
  do {
    final (rx, ry, lx, ly) = switch (d) {
      0 => (vx, vy, vx, vy - 1),
      1 => (vx - 1, vy, vx, vy),
      2 => (vx - 1, vy - 1, vx - 1, vy),
      _ => (vx, vy - 1, vx - 1, vy - 1),
    };
    final nd = !inside(rx, ry) ? (d + 1) % 4 : inside(lx, ly) ? (d + 3) % 4 : d;
    if (nd != d || corners.isEmpty) corners.add((vx, vy, nd));
    d = nd;
    vx += dx[d];
    vy += dy[d];
  } while (vx != i0 || vy != j0);

  final pts = [
    for (final (k, (cx, cy, dOut)) in corners.indexed)
      Offset(
        x0 + (cx + nx[dOut] + nx[corners[(k - 1) % corners.length].$3]) * _cell,
        y0 + (cy + ny[dOut] + ny[corners[(k - 1) % corners.length].$3]) * _cell,
      ),
  ];
  return _simplify(pts, _cell * .6);
}

/// Ramer–Douglas–Peucker on a closed ring.
List<Offset> _simplify(List<Offset> pts, double eps) {
  final n = pts.length;
  if (n < 8) return pts;
  Offset at(int k) => pts[k % n];
  var far = 0;
  for (var k = 1; k < n; k++) {
    if ((pts[k] - pts[0]).distanceSquared > (pts[far] - pts[0]).distanceSquared) far = k;
  }
  final keep = List.filled(n, false);
  keep[0] = keep[far] = true;
  void rdp(int a, int b) {
    final p = at(a), seg = at(b) - p, len = seg.distance;
    var idx = -1;
    var best = eps;
    for (var k = a + 1; k < b; k++) {
      final v = at(k) - p;
      final dist = len == 0 ? v.distance : (v.dx * seg.dy - v.dy * seg.dx).abs() / len;
      if (dist > best) {
        best = dist;
        idx = k;
      }
    }
    if (idx < 0) return;
    keep[idx] = true;
    rdp(a, idx);
    rdp(idx, b);
  }

  rdp(0, far);
  rdp(far, n);
  return [for (var k = 0; k < n; k++) if (keep[k]) pts[k]];
}
