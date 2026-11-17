import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../snowflake/geometry.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import 'ds.dart';

/// The paper dialog: a flake in [paper] up top ([preview], 170 across), then
/// the paper colours and [patterns] to pick from, each pick passed to
/// [onChanged] at once; "Done" and the cross both call [onClose].
class PaperDialog extends StatelessWidget {
  const PaperDialog({super.key, required this.paper, required this.onChanged, required this.preview, required this.onClose, this.patterns = paperPatterns});
  final Paper paper;

  /// Those of [paperPatterns] the player has (see [GameState.unlocked]).
  final List<String> patterns;
  final ValueChanged<Paper> onChanged;
  final Widget Function(Paper paper) preview;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DsDialog(
      title: tr('paper'),
      onClose: onClose,
      actions: [Btn(tr('done'), icon: LucideIcons.check, block: true, onTap: onClose)],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          FlakeShadow(size: 170, child: preview(paper)),
          const SizedBox(height: 20),
          // The paper colours, six to a row.
          for (var r = 0; r < paperColors.length; r += 6) ...[
            if (r > 0) const SizedBox(height: 12),
            Row(
              children: [
                for (final (i, p) in paperColors.skip(r).take(6).indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: p.name,
                      selected: p.color == paper.color,
                      child: GestureDetector(
                        onTap: () => onChanged(paper.copyWith(color: p.color)),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: p.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x1A101A3F), width: 2),
                              boxShadow: [
                                const BoxShadow(color: C.snow300, offset: Offset(0, 3)),
                                // Later shadows paint on top: the selection ring covers the drop shadow.
                                if (p.color == paper.color) const BoxShadow(color: C.berry500, spreadRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 20),
          // Patterns four to a row, each row left-aligned with blanks; the
          // Christmas pack's in a row of their own after the rest.
          for (final (row, ids) in _patternRows(patterns).indexed) ...[
            if (row > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < 4; col++) ...[
                  if (col > 0) const SizedBox(width: 12),
                  Expanded(
                    child: col >= ids.length
                        ? const SizedBox()
                        : Builder(builder: (_) {
                            final id = ids[col];
                            return Semantics(
                              button: true,
                              label: tr('pattern_$id'),
                              selected: id == paper.pattern,
                              child: GestureDetector(
                                onTap: () => onChanged(paper.copyWith(pattern: id)),
                                child: Column(
                                  children: [
                                    Stack(clipBehavior: Clip.none, children: [
                                      PaperSwatch(color: paper.color, pattern: id, selected: id == paper.pattern),
                                      if (christmasPatterns.contains(id)) const Positioned(top: -6, right: -6, child: _ChristmasBadge()),
                                    ]),
                                    const SizedBox(height: 8),
                                    // One full-size line tall, so a long name shrunk to
                                    // fit sits centred on it rather than riding up.
                                    SizedBox(
                                      height: 13 * 1.2,
                                      child: FittedBox(child: Text(tr('pattern_$id'), style: display(13, color: C.night800, height: 1.2))),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The pattern picker's rows of [patterns]: the everyday ones four to a
/// row, then the Christmas pack's in a row of their own (if any are there).
List<List<String>> _patternRows(List<String> patterns) {
  final everyday = [for (final p in patterns) if (!christmasPatterns.contains(p)) p];
  final christmas = [for (final p in patterns) if (christmasPatterns.contains(p)) p];
  return [
    for (var i = 0; i < everyday.length; i += 4) everyday.sublist(i, (i + 4).clamp(0, everyday.length)),
    if (christmas.isNotEmpty) christmas,
  ];
}

/// A white fir tree in a little green disc, in the corner of a Christmas pack
/// pattern's swatch.
class _ChristmasBadge extends StatelessWidget {
  const _ChristmasBadge();

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: const Color(0xFF2FB37E),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x33101A3F), offset: Offset(0, 1.5), blurRadius: 2)],
        ),
        child: const Icon(LucideIcons.treePine, size: 18, color: Colors.white),
      );
}

/// A square of paper in [color] and [pattern] filling its width, for the
/// pattern picker; styled like the colour swatches.
class PaperSwatch extends StatefulWidget {
  const PaperSwatch({super.key, required this.color, required this.pattern, this.selected = false});
  final Color color;
  final String pattern;
  final bool selected;

  @override
  State<PaperSwatch> createState() => _PaperSwatchState();
}

class _PaperSwatchState extends State<PaperSwatch> with SingleTickerProviderStateMixin {
  /// Seconds the paper has shimmered for, on a swatch that [shimmers].
  double _twinkleAt = 0;
  late final _twinkle = createTicker((elapsed) => setState(() => _twinkleAt = elapsed.inMicroseconds / 1e6));

  @override
  void initState() {
    super.initState();
    if (shimmers(widget.pattern)) _twinkle.start();
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color, pattern = widget.pattern, selected = widget.selected;
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          boxShadow: [
            const BoxShadow(color: C.snow300, offset: Offset(0, 3)),
            if (selected) const BoxShadow(color: C.berry500, spreadRadius: 4),
          ],
        ),
        child: CustomPaint(painter: _PaperSwatchPainter(color, pattern, MediaQuery.devicePixelRatioOf(context), shimmers(pattern) ? _twinkleAt : null)),
      ),
    );
  }
}

const _radius = 12.0;

class _PaperSwatchPainter extends CustomPainter {
  _PaperSwatchPainter(this.color, this.pattern, this.dpr, this.twinkle);
  final Color color;
  final String pattern;
  final double dpr;

  /// Seconds the paper has shimmered for, on a swatch that shimmers.
  final double? twinkle;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_radius));
    // The pattern tile is a bitmap: lay it out in device pixels so it stays crisp.
    canvas.save();
    canvas.scale(1 / dpr);
    var rr = RRect.fromRectAndRadius(Offset.zero & size * dpr, Radius.circular(_radius * dpr));
    if (gradientHues.containsKey(pattern) || pattern == 'wrapper') {
      // The whole run of colours on the swatch: the sheet's middle at its
      // middle, and its top and bottom (its edge) at the swatch's.
      canvas.translate(rr.width / 2, rr.height / 2);
      rr = rr.shift(Offset(-rr.width / 2, -rr.height / 2));
      canvas.drawRRect(rr, makePaperFill(color, pattern, rr.height / 2));
    } else {
      canvas.drawRRect(rr, makePaperFill(color, pattern, 100 * dpr));
    }
    final tw = twinkle;
    if (tw != null && pattern == 'sparkle') {
      canvas.clipRRect(rr);
      drawGlints(canvas, rr.outerRect, color, 100 * dpr, tw);
    }
    if (pattern == 'holo') {
      canvas.clipRRect(rr);
      drawHoloSheen(canvas, rr.outerRect, 100 * dpr, time: tw ?? 0);
    }
    // Glass glinting.
    if (pattern == 'glass') {
      canvas.save();
      canvas.clipRRect(rr);
      drawGlassGlints(canvas, rr.outerRect);
      canvas.restore();
    }
    // Gift wrap's gold, over its paper.
    if (pattern == 'wrapper') canvas.drawRRect(rr, makePaperFill(color, wrapperGoldLayer, 100 * dpr));
    canvas.restore();
    if (pattern == 'gingerbread') _gingerbread(canvas, size, r);
    canvas.drawRRect(
      r.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x1A101A3F),
    );
  }

  /// Gingerbread's swatch dressed as a biscuit: its baked edge (the inner
  /// shadow its flakes have, see [gingerbreadShadow]) and a little fir tree
  /// piped on it in icing of the paper's colour, as its cuts get.
  void _gingerbread(Canvas canvas, Size size, RRect r) {
    // As on a flake as big round as the swatch is across.
    final s = size.shortestSide;
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * gingerbreadEdgeWidth
        ..color = gingerbreadShadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * gingerbreadEdgeBlur),
    );
    canvas.restore();
    // The tree's outline: tiers zigzagging out down its right side, across
    // its foot, and back up its left.
    final w = size.width, h = size.height, cx = w / 2;
    const right = [Offset(.18, .4), Offset(.08, .4), Offset(.26, .6), Offset(.12, .6), Offset(.3, .8)];
    final tree = Path()..moveTo(cx, h * .18);
    for (final q in right) {
      tree.lineTo(cx + q.dx * w, q.dy * h);
    }
    for (final q in right.reversed) {
      tree.lineTo(cx - q.dx * w, q.dy * h);
    }
    tree.close();
    final icing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    // Its shadow first, a touch down, then the icing over it.
    canvas.drawPath(tree.shift(const Offset(0, 1)), icing..color = icingShade(color));
    canvas.drawPath(tree, icing..color = color);
  }

  @override
  bool shouldRepaint(_PaperSwatchPainter o) => o.color != color || o.pattern != pattern || o.dpr != dpr || o.twinkle != twinkle;
}
