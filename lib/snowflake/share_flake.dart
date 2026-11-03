import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Hundredths of a second each frame of the GIF shows for.
const _gifDelay = 6;

/// Side of the shared video, in pixels (a multiple of 16, as encoders like),
/// its frames a second and bits a second.
const _videoSide = 720, _videoFps = 30, _videoBitrate = 4000000;

/// Asks whether to share a picture of the flake or its unfolding animated,
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

/// Picture or animation. The picture closes it, once made, to be shared.
/// The animation first plays in it (drawn live, as the file will be), then
/// closes it, once made, from its own button.
class _ShareDialog extends StatefulWidget {
  const _ShareDialog(this.flake);
  final _Flake flake;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  bool _previewing = false;

  /// Whether the file to share is being made.
  bool _making = false;

  Future<void> _make(Future<_File> Function(_Flake) make) async {
    setState(() => _making = true);
    final file = await make(widget.flake);
    if (mounted) Navigator.pop(context, file);
  }

  @override
  Widget build(BuildContext context) {
    if (_previewing) {
      return DsDialog(
        title: tr('share'),
        onClose: () => Navigator.pop(context),
        actions: [Btn(_making ? tr('share_making') : tr('share'), icon: LucideIcons.share2, block: true, disabled: _making, onTap: () => _make(_animation))],
        child: ClipRRect(borderRadius: BorderRadius.circular(R.m), child: _LoopPreview(widget.flake)),
      );
    }
    return DsDialog(
      title: tr('share'),
      onClose: () => Navigator.pop(context),
      actions: [
        Btn(_making ? tr('share_making') : tr('share_picture'), icon: LucideIcons.image, block: true, disabled: _making, onTap: () => _make(_picture)),
        Btn(tr('share_animation'), icon: LucideIcons.film, variant: Variant.secondary, block: true, disabled: _making, onTap: () => setState(() => _previewing = true)),
      ],
      child: Text(tr('share_hint')),
    );
  }
}

/// The animation, 240 across, looping for as long as it shows.
class _LoopPreview extends StatefulWidget {
  const _LoopPreview(this.flake);
  final _Flake flake;

  @override
  State<_LoopPreview> createState() => _LoopPreviewState();
}

class _LoopPreviewState extends State<_LoopPreview> with SingleTickerProviderStateMixin {
  late final _loop = _Loop(widget.flake);
  double _t = 0;
  late final _ticker = createTicker((elapsed) => setState(() => _t = elapsed.inMicroseconds / 1e6 % _loop.total));

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size.square(240), painter: _LoopPainter(_loop, _t, MediaQuery.devicePixelRatioOf(context)));
}

class _LoopPainter extends CustomPainter {
  _LoopPainter(this.loop, this.t, this.dpr);
  final _Loop loop;
  final double t, dpr;

  @override
  void paint(Canvas canvas, Size size) => loop.paint(canvas, size.width, t, dpr: dpr);

  @override
  bool shouldRepaint(_LoopPainter old) => old.t != t || old.dpr != dpr;
}

/// The animation: the flake folded, unfolding as on the reveal screen, lying
/// open a while (its glints twinkling, if it has them), fading out and back
/// in folded to loop. It starts folded and in full, not faded: the first
/// frame is all a share sheet's preview or a chat's thumbnail shows.
class _Loop {
  _Loop(this.flake) : _unfolding = Motion.unfold.inMilliseconds / 1000 * unfoldSpan(flake.folds);

  static const _fadeIn = .3, _rest = .3, _open = 1.6, _fadeOut = .3;
  final _Flake flake;
  final double _unfolding;

  /// Seconds it takes, once round.
  double get total => _fadeIn + _rest + _unfolding + _open + _fadeOut;

  /// The scene [t] seconds in, [side] across (see [_paintScene]).
  void paint(Canvas canvas, double side, double t, {double dpr = 1}) {
    // From its fading in folded, which comes last, to loop back to the start.
    final since = (t + _fadeIn) % total;
    final unfold = ((since - _fadeIn - _rest) / _unfolding).clamp(0.0, 1.0);
    final f = flake;
    final painter = SnowflakePainter(
      cuts: f.cuts,
      folds: f.folds,
      color: f.color,
      pattern: f.pattern,
      unfold: unfold,
      // As on the reveal screen: a hologram's sheen drifts all along, glints
      // twinkle once it lies open.
      twinkle: shimmers(f.pattern) && (unfold == 1 || f.pattern == 'holo') ? t : null,
      spin: unfold * 2 * math.pi / f.folds,
      shading: true,
      dpr: dpr,
    );
    _paintScene(canvas, side, painter, opacity: math.min(1.0, math.min(since / _fadeIn, (total - since) / _fadeOut)));
  }

  /// Its frames, [fps] a second, [side] pixels across, as raw RGBA, handed to
  /// [take] one by one as drawn.
  Future<void> frames(int side, double fps, Future<void> Function(ByteData rgba) take) async {
    for (var n = 0; n < (total * fps).round(); n++) {
      final rec = ui.PictureRecorder();
      paint(Canvas(rec), side * 1.0, n / fps);
      final img = await rec.endRecording().toImage(side, side);
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      await take(data!);
    }
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

/// The animation as a file: on Android a video, which chat apps play as an
/// animation (a GIF from the share sheet they often send as a still); a GIF
/// elsewhere, or where the video can't be made.
Future<_File> _animation(_Flake f) async {
  if (Platform.isAndroid) {
    try {
      return await _video(f);
    } on PlatformException catch (e) {
      debugPrint('Video not made: $e');
    }
  }
  return _gif(f);
}

/// Served by MainActivity's VideoWriter.
const _videoChannel = MethodChannel('snowflake/video');

Future<_File> _video(_Flake f) async {
  final path = '${Directory.systemTemp.path}/snowflake.mp4';
  await _videoChannel.invokeMethod('start', {'path': path, 'width': _videoSide, 'height': _videoSide, 'fps': _videoFps, 'bitrate': _videoBitrate});
  // Each frame drawn while the one before is encoded: one at a time sent on.
  Future<void>? sending;
  await _Loop(f).frames(_videoSide, _videoFps * 1.0, (rgba) async {
    await sending;
    sending = _videoChannel.invokeMethod('frame', rgba.buffer.asUint8List());
  });
  await sending;
  await _videoChannel.invokeMethod('finish');
  return (bytes: await File(path).readAsBytes(), type: 'video/mp4', name: 'snowflake.mp4');
}

Future<_File> _gif(_Flake f) async {
  final frames = <TransferableTypedData>[];
  await _Loop(f).frames(_gifSide, 100 / _gifDelay, (rgba) async => frames.add(TransferableTypedData.fromList([rgba])));
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
