import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/ds.dart';
import 'geometry.dart';
import 'snowflake_view.dart';

/// Side of the shared picture, in pixels.
const _side = 1080;

/// Shares a picture of the flake alone (no buttons, no status bar): drawn
/// afresh, square, on the night sky the game shows it on, with its shadow.
/// No [color] is white paper, as [SnowflakeView] has it. [context] is the
/// button tapped, which the share sheet points from where that matters
/// (tablets).
Future<void> shareFlake(BuildContext context, {required List<Cut> cuts, required int folds, required Color? color, required String pattern}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final png = await _picture(cuts, folds, color ?? const Color(0xFFFFFFFF), pattern);
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(png, mimeType: 'image/png')],
    fileNameOverrides: ['snowflake.png'],
    sharePositionOrigin: origin,
  ));
}

Future<Uint8List> _picture(List<Cut> cuts, int folds, Color color, String pattern) async {
  const side = _side * 1.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  // The sky, top to bottom, its dots as big as on a phone of 360 points across.
  c.drawRect(
    const Rect.fromLTWH(0, 0, side, side),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, const Offset(0, side), SkyBackground.night, const [0, .7, 1]),
  );
  c.save();
  c.scale(side / 360);
  paintSnowDots(c, const Size.square(360));
  c.restore();
  // The flake, 80% across, over its shadow (as FlakeShadow casts it).
  const s = side * .8;
  final flake = SnowflakePainter(cuts: cuts, folds: folds, color: color, pattern: pattern, unfold: 1, spin: 0, shading: true, dpr: 1);
  c.translate((side - s) / 2, (side - s) / 2);
  c.saveLayer(null, Paint()..colorFilter = const ColorFilter.mode(FlakeShadow.color, BlendMode.srcIn));
  c.translate(0, s * .05);
  flake.paint(c, const Size.square(s));
  c.restore();
  flake.paint(c, const Size.square(s));
  final img = await rec.endRecording().toImage(_side, _side);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data!.buffer.asUint8List();
}
