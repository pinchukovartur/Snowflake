// The store's feature graphic (1024×500), drawn by the game itself: run with
// `flutter run -t lib/store_banner_main.dart`. Each language's picture is
// saved as banner_<lang>.png in the app's cache, for
// `adb exec-out run-as com.Pinchukov.Snowflake cat cache/banner_ru.png`.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

import 'snowflake/snowflake_view.dart';
import 'snowflake/svg_flakes.dart';
import 'theme/tokens.dart';

const _size = Size(1024, 500);

/// Title and tagline in each language the store lists.
const _texts = {
  'ru': (title: 'Снежинки', tagline: 'Сложи. Вырежи. Раскрой.'),
  'en': (title: 'Snowflakes', tagline: 'Fold. Cut. Unfold.'),
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSvgFlakes();
  await loadPaperTextures();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Material(child: _Shoot())));
}

/// Shows the banner in each language in turn, saving each.
class _Shoot extends StatefulWidget {
  const _Shoot();

  @override
  State<_Shoot> createState() => _ShootState();
}

class _ShootState extends State<_Shoot> {
  final _boundary = GlobalKey();
  String _lang = _texts.keys.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _shoot());
  }

  Future<void> _shoot() async {
    await GoogleFonts.pendingFonts([_titleStyle, _taglineStyle]);
    // Once through every language first: each one's letters may need more
    // of a font fetched, not in hand by the time the first frame is drawn.
    for (final lang in _texts.keys) {
      setState(() => _lang = lang);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await GoogleFonts.pendingFonts([_titleStyle, _taglineStyle]);
    }
    for (final lang in _texts.keys) {
      setState(() => _lang = lang);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final box = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await box.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${Directory.systemTemp.path}/banner_$lang.png');
      await file.writeAsBytes(png!.buffer.asUint8List());
      debugPrint('BANNER ${file.path} ${image.width}x${image.height}');
    }
    debugPrint('BANNER DONE');
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: FittedBox(
            child: RepaintBoundary(
              key: _boundary,
              child: SizedBox.fromSize(size: _size, child: _Banner(lang: _lang)),
            ),
          ),
        ),
      );
}

/// Where the title's top left sits, and how wide it may grow.
const _textAt = Offset(62, 170), _textWidth = 600.0, _textGap = 6.0;

final _titleStyle = display(96, weight: FontWeight.w900, shadows: drop(7));
final _taglineStyle = body(33, weight: FontWeight.w800, color: C.ice200).copyWith(shadows: drop(3));

/// The flakes the carpet is woven from: every classic six-fold one, each at
/// least once.
const _presets = ['default_6_1', 'default_6_2', 'classic', 'fern', 'starburst', 'leafy', 'spiky', 'forked', 'chevrons', 'rhombi'];

/// The carpet's colours, left to right: blue, then light blue, then white.
const _shades = [C.ice600, C.ice400, Colors.white];

/// The carpet's flakes' sizes across, smallest and largest: a few big ones.
const _smallest = 190.0, _largest = 340.0;

/// How close two flakes may come, as a share of their radii added up: under
/// 1 they overlap a little, leaving no gaps.
const _packing = .9;

/// A flake in the carpet.
typedef _Flake = ({Offset at, double size, String preset, Color color, double turn});

/// Flakes strewn at random edge to edge with no gaps between, coloured by
/// how far across they are (see [_shades]): the same each time.
final List<_Flake> _carpet = () {
  final random = math.Random(1), flakes = <_Flake>[];
  // Dealt out in turn, shuffled: every one comes up before any comes again.
  final deck = [..._presets]..shuffle(random);
  // Bigger flakes first, smaller ones then filling in round them.
  for (var misses = 0; misses < 4000;) {
    final grown = flakes.length / 6;
    final size = _largest - (_largest - _smallest) * math.min(1.0, grown) * (.6 + random.nextDouble() * .4);
    // Centres a little past the edges, so the carpet runs off them.
    final at = Offset(-60 + random.nextDouble() * (_size.width + 120), -60 + random.nextDouble() * (_size.height + 120));
    if (flakes.any((f) => (f.at - at).distance < (f.size + size) / 2 * _packing)) {
      misses++;
      continue;
    }
    final across = (at.dx / _size.width).clamp(0.0, 1.0) * (_shades.length - 1);
    final i = math.min(across.floor(), _shades.length - 2);
    final color = Color.lerp(_shades[i], _shades[i + 1], across - i)!;
    flakes.add((at: at, size: size, preset: deck[flakes.length % deck.length], color: color, turn: random.nextDouble() * math.pi));
  }
  return flakes;
}();

/// The banner itself: a carpet of flakes, blue on the left turning white on
/// the right, under the title and tagline.
class _Banner extends StatelessWidget {
  const _Banner({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) {
    final text = _texts[lang]!;
    return Stack(clipBehavior: Clip.hardEdge, children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E295C), Color(0xFF3A56A8)],
            ),
          ),
        ),
      ),
      for (final f in _carpet)
        Positioned(
          left: f.at.dx - f.size / 2,
          top: f.at.dy - f.size / 2,
          width: f.size,
          height: f.size,
          child: Transform.rotate(
            angle: f.turn,
            child: FlakeShadow(size: f.size, child: SnowflakeView(preset: f.preset, size: f.size, color: f.color, shading: false)),
          ),
        ),
      Positioned(
        left: _textAt.dx,
        top: _textAt.dy,
        width: _textWidth,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(text.title, style: _titleStyle)),
          const SizedBox(height: _textGap),
          Text(text.tagline, style: _taglineStyle),
        ]),
      ),
    ]);
  }
}
