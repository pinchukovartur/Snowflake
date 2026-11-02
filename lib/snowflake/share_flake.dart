import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';
import 'geometry.dart';
import 'gif_encoder.dart';
import 'snowflake_view.dart';

/// Side of the shared picture, in pixels.
const _side = 1080;

/// Side of the shared animation, in pixels: GIF grows fast with it.
const _gifSide = 480;

/// Hundredths of a second each frame of the animation shows for.
const _gifDelay = 6;

/// Asks whether to share a picture of the flake or its unfolding as a GIF,
/// and shares that. No [color] is white paper, as [SnowflakeView] has it.
/// [context] is the button tapped, which the share sheet points from where
/// that matters (tablets).
Future<void> shareFlake(BuildContext context, {required List<Cut> cuts, required int folds, required Color? color, required String pattern}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final flake = (cuts: cuts, folds: folds, color: color ?? const Color(0xFFFFFFFF), pattern: pattern);
  final file = await showDsDialog<_File>(context, builder: (_) => _ShareDialog(flake));
  if (file == null) return;
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(file.bytes, mimeType: file.type)],
    fileNameOverrides: [file.name],
    sharePositionOrigin: origin,
  ));
}

typedef _Flake = ({List<Cut> cuts, int folds, Color color, String pattern});
typedef _File = ({Uint8List bytes, String type, String name});

/// Picture or animation. The picture closes it, once made, to be shared;
/// the animation, once made, plays in it, to be shared from there.
class _ShareDialog extends StatefulWidget {
  const _ShareDialog(this.flake);
  final _Flake flake;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  /// What is being made, if anything.
  Future<_File> Function(_Flake)? _making;
  _File? _gif;

  Future<void> _make(Future<_File> Function(_Flake) make) async {
    setState(() => _making = make);
    final file = await make(widget.flake);
    if (!mounted) return;
    if (make == _animation) {
      setState(() {
        _making = null;
        _gif = file;
      });
    } else {
      Navigator.pop(context, file);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gif = _gif;
    if (gif != null) {
      return DsDialog(
        title: tr('share'),
        onClose: () => Navigator.pop(context),
        actions: [Btn(tr('share'), icon: LucideIcons.share2, block: true, onTap: () => Navigator.pop(context, gif))],
        child: ClipRRect(
          borderRadius: BorderRadius.circular(R.m),
          child: Image.memory(gif.bytes, width: 240, height: 240, gaplessPlayback: true),
        ),
      );
    }
    final making = _making != null;
    return DsDialog(
      title: tr('share'),
      onClose: () => Navigator.pop(context),
      actions: [
        Btn(_making == _picture ? tr('share_making') : tr('share_picture'), icon: LucideIcons.image, block: true, disabled: making, onTap: () => _make(_picture)),
        Btn(
          _making == _animation ? tr('share_making') : tr('share_animation'),
          icon: LucideIcons.film,
          variant: Variant.secondary,
          block: true,
          disabled: making,
          onTap: () => _make(_animation),
        ),
      ],
      child: Text(tr('share_hint')),
    );
  }
}

Future<_File> _picture(_Flake f) async {
  const side = _side * 1.0;
  final rec = ui.PictureRecorder();
  _paintScene(Canvas(rec), side, SnowflakePainter(cuts: f.cuts, folds: f.folds, color: f.color, pattern: f.pattern, unfold: 1, spin: 0, shading: true, dpr: 1));
  final img = await rec.endRecording().toImage(_side, _side);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return (bytes: data!.buffer.asUint8List(), type: 'image/png', name: 'snowflake.png');
}

/// The flake folded, unfolding as on the reveal screen, lying open a while
/// (its glints twinkling, if it has them), fading out and back in folded to
/// loop. It starts folded and in full, not faded: the first frame is all a
/// share sheet's preview or a chat's thumbnail shows.
Future<_File> _animation(_Flake f) async {
  const side = _gifSide * 1.0, step = _gifDelay / 100;
  const fadeIn = .3, rest = .3, open = 1.6, fadeOut = .3;
  final unfolding = Motion.unfold.inMilliseconds / 1000 * unfoldSpan(f.folds);
  final total = fadeIn + rest + unfolding + open + fadeOut;
  final twinkles = shimmers(f.pattern);
  final frames = <TransferableTypedData>[];
  for (var t = 0.0; t < total - step / 2; t += step) {
    // From its fading in folded, which comes last, to loop back to the start.
    final since = (t + fadeIn) % total;
    final unfold = ((since - fadeIn - rest) / unfolding).clamp(0.0, 1.0);
    final opacity = math.min(1.0, math.min(since / fadeIn, (total - since) / fadeOut));
    final rec = ui.PictureRecorder();
    _paintScene(
      Canvas(rec),
      side,
      SnowflakePainter(
        cuts: f.cuts,
        folds: f.folds,
        color: f.color,
        pattern: f.pattern,
        unfold: unfold,
        // As on the reveal screen: a hologram's sheen drifts all along,
        // glints twinkle once it lies open.
        twinkle: twinkles && (unfold == 1 || f.pattern == 'holo') ? t : null,
        spin: unfold * 2 * math.pi / f.folds,
        shading: true,
        dpr: 1,
      ),
      opacity: opacity,
    );
    final img = await rec.endRecording().toImage(_gifSide, _gifSide);
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
    frames.add(TransferableTypedData.fromList([data!]));
  }
  final gif = await Isolate.run(() => encodeGif([for (final d in frames) d.materialize().asUint8List()], _gifSide, _gifSide, _gifDelay));
  return (bytes: gif, type: 'image/gif', name: 'snowflake.gif');
}

/// [flake] on the night sky the game shows it on, square, [side] across, with
/// its shadow, as see-through over the sky as [opacity].
void _paintScene(Canvas c, double side, SnowflakePainter flake, {double opacity = 1}) {
  // The sky, top to bottom, its dots as big as on a phone of 360 points across.
  c.drawRect(
    Rect.fromLTWH(0, 0, side, side),
    Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, side), SkyBackground.night, const [0, .7, 1]),
  );
  c.save();
  c.scale(side / 360);
  paintSnowDots(c, const Size.square(360));
  c.restore();
  // The flake, 80% across, over its shadow (as FlakeShadow casts it).
  final s = side * .8;
  if (opacity < 1) c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
  c.translate((side - s) / 2, (side - s) / 2);
  c.saveLayer(null, Paint()..colorFilter = const ColorFilter.mode(FlakeShadow.color, BlendMode.srcIn));
  c.translate(0, s * .05);
  flake.paint(c, Size.square(s));
  c.restore();
  flake.paint(c, Size.square(s));
  if (opacity < 1) c.restore();
}
