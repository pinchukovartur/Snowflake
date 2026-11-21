import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// An event title's face: heavier and bigger when [loud].
TextStyle eventTitleStyle(bool loud) => loud ? display(17, weight: FontWeight.w900, height: 1.1) : display(16, height: 1.1);

/// An event's title (or a shop set's), centred, [size] px: white, or its
/// [ink] (purple unless given) on a white outline when [loud]; if [fade] is given, that runs
/// from its first colour at the top to its second at the bottom instead.
class EventTitle extends StatelessWidget {
  /// Extra room between words, as a share of the font size.
  static const wordGap = .25;

  /// How thick the white outline of a loud title is, as a share of its size.
  static const outline = 3.5 / 17;

  const EventTitle(this.text, {super.key, required this.loud, required this.size, this.maxLines, this.ink = defaultInk, this.fade});
  final String text;
  final Color ink;
  final (Color, Color)? fade;
  static const defaultInk = Color(0xFF7B3FD1);
  final bool loud;
  final double size;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    // Words set further apart than the face's own spacing, which runs them together.
    final style = eventTitleStyle(loud).copyWith(fontSize: size, wordSpacing: size * wordGap);
    Text line(TextStyle s) => Text(text, textAlign: TextAlign.center, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis, style: s);
    if (!loud) return line(style.copyWith(color: Colors.white));
    // The outline drawn first underneath; both centred in the room given.
    return Stack(alignment: Alignment.center, children: [
      // The display face, but painted as a stroke (a style can't carry both a
      // colour and a foreground paint).
      line(TextStyle(
        fontFamily: style.fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w900,
        height: 1.1,
        wordSpacing: style.wordSpacing,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * outline
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      )),
      if (fade case (final top, final bottom))
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]).createShader(r),
          child: line(style.copyWith(color: Colors.white)),
        )
      else
        line(style.copyWith(color: ink)),
    ]);
  }
}
