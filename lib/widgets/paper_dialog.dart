import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../snowflake/geometry.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import 'ds.dart';

/// The paper dialog: a flake in [paper] up top ([preview], 170 across), then
/// the paper colours and patterns to pick from, each pick passed to
/// [onChanged] at once; "Done" and the cross both call [onClose].
class PaperDialog extends StatelessWidget {
  const PaperDialog({super.key, required this.paper, required this.onChanged, required this.preview, required this.onClose});
  final Paper paper;
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
          // Patterns four to a row, the last row left-aligned with blanks.
          for (var row = 0; row * 4 < paperPatterns.length; row++) ...[
            if (row > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < 4; col++) ...[
                  if (col > 0) const SizedBox(width: 12),
                  Expanded(
                    child: row * 4 + col >= paperPatterns.length
                        ? const SizedBox()
                        : Builder(builder: (_) {
                            final id = paperPatterns[row * 4 + col];
                            return Semantics(
                              button: true,
                              label: tr('pattern_$id'),
                              selected: id == paper.pattern,
                              child: GestureDetector(
                                onTap: () => onChanged(paper.copyWith(pattern: id)),
                                child: Column(
                                  children: [
                                    _PaperSwatch(color: paper.color, pattern: id, selected: id == paper.pattern),
                                    const SizedBox(height: 8),
                                    FittedBox(child: Text(tr('pattern_$id'), style: display(13, color: C.night800))),
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

/// A square of paper in [color] and [pattern] filling its width, for the
/// pattern picker; styled like the colour swatches.
class _PaperSwatch extends StatefulWidget {
  const _PaperSwatch({required this.color, required this.pattern, required this.selected});
  final Color color;
  final String pattern;
  final bool selected;

  @override
  State<_PaperSwatch> createState() => _PaperSwatchState();
}

class _PaperSwatchState extends State<_PaperSwatch> with SingleTickerProviderStateMixin {
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
    if (gradientHues.containsKey(pattern)) {
      // The whole run of colours on the swatch: the sheet's middle at its
      // middle, and its top and bottom at the swatch's.
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
    canvas.restore();
    canvas.drawRRect(
      r.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0x1A101A3F),
    );
  }

  @override
  bool shouldRepaint(_PaperSwatchPainter o) => o.color != color || o.pattern != pattern || o.dpr != dpr || o.twinkle != twinkle;
}
