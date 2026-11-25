import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A paper's or stencil's [name] under its picture, at [size]: wrapping onto
/// a second line when it is too long for one, and only shrinking (as far as
/// [minSize]) when two lines are not enough or a single word is too wide; no
/// word is ever broken.
///
/// With [spill], it takes one line's room, a second line spilling down past
/// it (into the gap before what is below), so its cell is no taller for a
/// longer name; without, two lines' room, the name at its top (one line
/// as high as anyone else's, a second below it).
class ItemName extends StatelessWidget {
  const ItemName(this.name, {super.key, required this.size, this.spill = false, this.minSize = 8, this.color = C.night800});
  final String name;
  final Color color;
  final double size, minSize;
  final bool spill;

  static const _height = 1.1;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    TextStyle at(double s) => display(s, color: color, height: _height);
    // A line's room: a full-size line as ever with [spill], a wrapped one's
    // without.
    final line = size * (spill ? 1.2 : _height);
    return LayoutBuilder(builder: (_, box) {
      final width = box.maxWidth;
      // The biggest size its words all fit at, two lines at most.
      bool fits(double s) {
        final style = at(s);
        for (final word in name.split(' ')) {
          final p = TextPainter(text: TextSpan(text: word, style: style), textDirection: TextDirection.ltr, textScaler: scaler)..layout();
          // A little to spare: the text laid out for real may break a word
          // measured just to fit.
          if (p.width > width - 2) return false;
        }
        final all = TextPainter(text: TextSpan(text: name, style: style), textDirection: TextDirection.ltr, maxLines: 2, textScaler: scaler)..layout(maxWidth: width);
        return !all.didExceedMaxLines;
      }

      var s = size;
      while (s > minSize && !fits(s)) {
        s -= .5;
      }
      final text = Text(name, textAlign: TextAlign.center, maxLines: 2, style: at(s));
      return spill
          ? SizedBox(height: line, child: OverflowBox(maxHeight: line * 2, alignment: Alignment.topCenter, child: text))
          : SizedBox(height: line * 2, child: Align(alignment: Alignment.topCenter, child: text));
    });
  }
}
