import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';
import '../widgets/frosted_window.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.game, required this.onPlay, required this.onGallery});
  final GameState game;
  final VoidCallback onPlay, onGallery;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final _ticker = AnimationController(vsync: this, duration: const Duration(hours: 1))..forward();

  /// The title shows once per launch: fades in, holds a couple of seconds and
  /// fades away, leaving the window clear.
  late final bool _showTitle = !widget.game.titleShown;
  late final _title = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000));
  late final _titleOpacity = _title.drive(TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 400),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 4000),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 600),
  ]));

  @override
  void initState() {
    super.initState();
    if (_showTitle) {
      widget.game.titleShown = true;
      _title.forward().whenComplete(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _title.dispose();
    super.dispose();
  }

  void _openSettings() {
    showDsDialog(
      context,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: widget.game,
          builder: (ctx, _) {
            final g = widget.game;
            return DsDialog(
              title: 'Настройки',
              onClose: () => Navigator.pop(ctx),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsSwitch(
                    label: 'Музыка',
                    checked: g.music,
                    onChanged: (v) => g.setSetting(music: v),
                  ),
                  const SizedBox(height: 16),
                  DsSwitch(
                    label: 'Звуки',
                    checked: g.sfx,
                    onChanged: (v) => g.setSetting(sfx: v),
                  ),
                  const SizedBox(height: 16),
                  DsSwitch(
                    label: 'Вибрация',
                    checked: g.vibration,
                    onChanged: (v) => g.setSetting(vibration: v),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool get _titleUp => _showTitle && !_title.isCompleted;

  /// Pane rows in each sash of the window.
  static const _rows = 8;

  /// Lets the player fill window [pane] with a flake from the collection or
  /// leave it clear, or take down what is there. Flakes hanging in other
  /// panes can't be picked: each goes up once.
  void _pick(int pane) {
    final g = widget.game;
    final filled = g.window.containsKey(pane);
    final current = g.window[pane];
    void choose(BuildContext ctx, SavedFlake? f) {
      g.hang(pane, f);
      Navigator.pop(ctx);
    }

    showDsDialog(
      context,
      builder: (ctx) => DsDialog(
        title: 'Снежинка на окно',
        onClose: () => Navigator.pop(ctx),
        actions: [
          if (filled)
            Btn('Снять с окна', variant: Variant.light, icon: LucideIcons.x, block: true, onTap: () {
              g.unhang(pane);
              Navigator.pop(ctx);
            }),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (final f in g.collection)
                if (identical(f, current) || !g.isHung(f))
                  _PickTile(flake: f, selected: identical(f, current), onTap: () => choose(ctx, f))
                else
                  _PickTile(flake: f, selected: false),
              // Leaving the pane clear comes last, after every flake.
              _PickTile(selected: filled && current == null, onTap: () => choose(ctx, null)),
            ],
          ),
        ),
      ),
    );
  }

  /// The Play and Collection buttons with their gap and bottom padding:
  /// 64 + 6 lip, 12, 52 + 6 lip, 28.
  static const _buttonsHeight = 168.0;

  /// From the bottom padding up to the middle of the Play button
  /// (28, 52 + 6, 12, 6 + 64 / 2): the shade behind the buttons is full up to
  /// there and fades out over [_hazeFade] above.
  static const _playMiddle = 136.0;
  static const _hazeFade = 90.0;

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hazeHeight = _playMiddle + _hazeFade + bottomInset;
    return SkyBackground(
      softDots: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: _Snowfall(ticker: _ticker, hazeHeight: hazeHeight, hazeFade: _hazeFade),
            ),
          ),
          // The snow outside stays put; the frame, two screens tall, scrolls
          // past with the title on its top half, and a sill under it as tall
          // as the buttons, so the bottom row can come up clear of them.
          Positioned.fill(
            // Stops dead at either end: no overscroll stretch or glow.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
              child: LayoutBuilder(
                builder: (_, c) => SingleChildScrollView(
                  child: Column(children: [
                    SizedBox(
                      height: c.maxHeight * 2,
                      child: Stack(children: [
                        const Positioned.fill(child: WindowFrame(rows: _rows, onSill: true)),
                        // Each pane holds a flake from the collection, or a plus to
                        // hang one; the top row waits while the title is up.
                        for (final (i, pane) in WindowFrame.paneRects(Size(c.maxWidth, c.maxHeight * 2), _rows).indexed)
                          if (i >= 2 || !_titleUp)
                            Positioned.fromRect(
                              rect: pane,
                              child: _Pane(flake: g.window[i], clear: g.window.containsKey(i) && g.window[i] == null, onTap: () => _pick(i)),
                            ),
                        if (_titleUp)
                          Positioned(
                            left: 0,
                            right: 0,
                            // Centred in the top pane under the arch, clear of the bars.
                            top: WindowFrame.paneMiddle(Size(c.maxWidth, c.maxHeight * 2), _rows, 0),
                            child: FractionalTranslation(
                              translation: const Offset(0, -.5),
                              child: FadeTransition(
                                opacity: _titleOpacity,
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text(
                                    'Снежинки',
                                    style: display(56, weight: FontWeight.w900, height: 1, shadows: drop(5)).copyWith(letterSpacing: -.56),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Сложи. Вырежи. Раскрой.',
                                    style: body(17, weight: FontWeight.w800, color: C.ice200),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    SizedBox(height: _buttonsHeight + 16 + bottomInset, child: const WindowSill()),
                  ]),
                ),
              ),
            ),
          ),
          // Shade behind the buttons, fading out above them; the snow there is
          // drawn softer too.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: hazeHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [Color(0x00101A3F), Color(0x59101A3F), Color(0x73101A3F)],
                    stops: [0, _hazeFade / hazeHeight, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(screenPad, 8, screenPad, 8),
                  child: Row(
                    children: [
                      CurrencyPill(amount: g.coins),
                      const Spacer(),
                      RoundBtn(LucideIcons.settings, label: 'Настройки', variant: Variant.dark, size: BtnSize.s, onTap: _openSettings),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                  child: Column(
                    children: [
                      Btn('Играть', size: BtnSize.l, icon: LucideIcons.play, block: true, onTap: widget.onPlay),
                      const SizedBox(height: 12),
                      Btn('Моя коллекция', variant: Variant.light, icon: LucideIcons.image, block: true, onTap: widget.onGallery),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One fleck of snow. [depth] 0 is far off, 1 close to the glass: nearer
/// flecks are bigger, brighter and fall faster.
class _Fleck {
  _Fleck(math.Random r)
    : x = r.nextDouble(),
      phase = r.nextDouble(),
      depth = r.nextDouble(),
      sway = 3 + r.nextDouble() * 4,
      swayPhase = r.nextDouble() * 2 * math.pi;
  final double x, phase, depth, sway, swayPhase;

  /// Seconds from the top of the screen to the bottom.
  double get fall => 14 - depth * 7;
  double get alpha => .45 + depth * .5;
}

/// Snow falling outside the window: small round flecks drifting down, seen
/// soft through the glass and softer still in the bottom [hazeHeight] behind
/// the buttons, setting in over its top [hazeFade].
class _Snowfall extends StatefulWidget {
  const _Snowfall({required this.ticker, required this.hazeHeight, required this.hazeFade});
  final AnimationController ticker;
  final double hazeHeight, hazeFade;

  @override
  State<_Snowfall> createState() => _SnowfallState();
}

class _SnowfallState extends State<_Snowfall> {
  final _flecks = List.generate(70, (_) => _Fleck(_rnd));
  static final _rnd = math.Random();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _SnowfallPainter(
          _flecks,
          widget.ticker,
          dpr: MediaQuery.devicePixelRatioOf(context),
          hazeHeight: widget.hazeHeight,
          hazeFade: widget.hazeFade,
        ),
      ),
    );
  }
}

/// Draws every fleck from one sprite sheet of ready-blurred dots, so the snow
/// looks as if seen through frosted glass without blurring the screen.
class _SnowfallPainter extends CustomPainter {
  _SnowfallPainter(this.flecks, this.ticker, {required this.dpr, required this.hazeHeight, required this.hazeFade}) : super(repaint: ticker);
  final List<_Fleck> flecks;
  final AnimationController ticker;
  final double dpr, hazeHeight, hazeFade;

  /// Fleck radii in dp, far to near.
  static const _radii = [1.55, 2.25, 2.6, 2.9];
  static const _sizes = 4;
  static double _radius(int k) => _radii[k];

  /// Blur in dp: through the glass, and behind the buttons.
  static const _sigmas = [2.5, 5.7];

  /// One sprite's square, wide enough for the largest, blurriest dot.
  static const _cell = 2 * (4.0 + 3 * 5.7);

  /// Sprite sheets by device pixel ratio: a row per blur, a column per size.
  static final _sheets = <double, ui.Image>{};

  static ui.Image _sheet(double dpr) => _sheets.putIfAbsent(dpr, () {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec)..scale(dpr);
        for (var l = 0; l < _sigmas.length; l++) {
          for (var k = 0; k < _sizes; k++) {
            c.drawCircle(
              Offset((k + .5) * _cell, (l + .5) * _cell),
              _radius(k),
              Paint()
                ..color = Colors.white
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, _sigmas[l]),
            );
          }
        }
        return rec.endRecording().toImageSync((_sizes * _cell * dpr).ceil(), (_sigmas.length * _cell * dpr).ceil());
      });

  @override
  void paint(Canvas canvas, Size size) {
    final t = (ticker.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6;
    final sheet = _sheet(dpr);
    final px = _cell * dpr, margin = _cell / 2;
    final hazeTop = size.height - hazeHeight;
    final transforms = <RSTransform>[], rects = <Rect>[], colors = <Color>[];
    for (final f in flecks) {
      final ph = (t / f.fall + f.phase) % 1;
      final y = -margin + (size.height + 2 * margin) * ph;
      final x = f.x * size.width + (5 + 7 * f.depth) * math.sin(t / f.sway * 2 * math.pi + f.swayPhase);
      final k = math.min(_sizes - 1, (f.depth * _sizes).floor());
      // Behind the buttons the softer sprite fades in over the plain one.
      final w = ((y - hazeTop) / hazeFade).clamp(0.0, 1.0);
      final haze = w * w * (3 - 2 * w);
      for (final (l, share) in [(0, 1 - haze), (1, haze)]) {
        if (share <= 0) continue;
        transforms.add(RSTransform.fromComponents(rotation: 0, scale: 1 / dpr, anchorX: px / 2, anchorY: px / 2, translateX: x, translateY: y));
        rects.add(Rect.fromLTWH(k * px, l * px, px, px));
        colors.add(Color.fromRGBO(255, 255, 255, f.alpha * share));
      }
    }
    canvas.drawAtlas(sheet, transforms, rects, colors, BlendMode.modulate, null, Paint()..filterQuality = FilterQuality.low);
  }

  @override
  bool shouldRepaint(_SnowfallPainter o) =>
      !identical(o.flecks, flecks) || o.ticker != ticker || o.dpr != dpr || o.hazeHeight != hazeHeight || o.hazeFade != hazeFade;
}

/// One pane of the home window: the flake hanging in it, clear glass when
/// [clear], or else a faint plus to fill it. Either way a tap calls [onTap].
class _Pane extends StatelessWidget {
  const _Pane({required this.flake, required this.clear, required this.onTap});
  final SavedFlake? flake;
  final bool clear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = flake;
    if (clear) {
      // Nothing to see, but still there to tap.
      return Semantics(
        button: true,
        label: 'Пустое стекло',
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: const SizedBox.expand()),
      );
    }
    if (f == null) {
      return Center(
        child: Semantics(
          button: true,
          label: 'Повесить снежинку',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x1FFFFFFF),
                border: Border.all(color: const Color(0x4DFFFFFF), width: 2),
              ),
              child: const Icon(LucideIcons.plus, size: 28, color: Color(0x99FFFFFF)),
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (_, c) => Semantics(
        button: true,
        label: f.name,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: SnowflakeView(
              cuts: f.cuts,
              preset: f.preset,
              folds: f.folds,
              color: f.color,
              pattern: f.pattern,
              size: math.min(c.maxWidth, c.maxHeight) * .78,
              // No glow: it would show through the cut-outs as a pale veil,
              // where the night outside should be.
              glow: false,
            ),
          ),
        ),
      ),
    );
  }
}

/// A choice in the pick-for-the-window dialog: [flake], or leaving the pane
/// clear when there is none. Without [onTap] it can't be picked (the flake
/// already hangs elsewhere) and shows faded.
class _PickTile extends StatelessWidget {
  const _PickTile({this.flake, required this.selected, this.onTap});
  final SavedFlake? flake;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = flake;
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: f?.name ?? 'Пусто',
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? .35 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: C.night700,
              borderRadius: BorderRadius.circular(R.m),
              border: selected ? Border.all(color: C.berry500, width: 3) : null,
            ),
            child: LayoutBuilder(
              builder: (_, c) => Center(
                child: f == null
                    ? Text('Пусто', style: display(15, color: C.ice200))
                    : SnowflakeView(
                        cuts: f.cuts,
                        preset: f.preset,
                        folds: f.folds,
                        color: f.color,
                        pattern: f.pattern,
                        size: c.maxWidth * .74,
                        glow: false,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
