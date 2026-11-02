import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../app_state.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';
import '../widgets/frosted_window.dart';


/// The coin counter is off until coins are earned and spent somewhere;
/// the coins themselves are still kept (see GameState.coins).
const _showCoins = false;

/// The night, darker under the window: the glass's white haze (about 11% where
/// it is clear of glints) lifts it back to the other screens' sky. Each is
/// `(c − 255·a) / (1 − a)` of [SkyBackground.night], for a = .11.
const _skyUnderHaze = [Color(0xFF001047), Color(0xFF153487), Color(0xFF264EAF)];

/// What the window looks out on. Set by hand for each release: autumn now,
/// winter in the next update.
enum Season { autumn, winter }

const season = Season.autumn;

/// The autumn view: a sunny sky with a maple in leaf, seen through the glass.
const _autumnView = 'assets/Autumn_Window_Bg.png';

/// A patch of frost behind the game's title on the window.
const _titleBg = 'assets/Window_Title_Bg.png';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.game, required this.onPlay, required this.onGallery, this.arriving, this.onArrived});
  final GameState game;
  final VoidCallback onPlay, onGallery;

  /// A flake on its way to the window: the window scrolls to its first pane
  /// still to fill, and it appears there (see [freePane]).
  final SavedFlake? arriving;

  /// Called as soon as the screen takes [arriving] in hand.
  final VoidCallback? onArrived;

  /// The first pane in [game]'s window still to fill (a plus, not glass left
  /// clear on purpose), or null when every one is.
  static int? freePane(GameState game) {
    for (var i = 0; i < HomeScreenState._panes; i++) {
      if (!game.window.containsKey(i)) return i;
    }
    return null;
  }

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final _ticker = AnimationController(vsync: this, duration: const Duration(hours: 1))..forward();

  /// Where the windows have been panned to, and how far shrunk (only in the
  /// overview: see [_toggleOverview]).
  final _view = TransformationController();

  /// The windows moved for the player: see [_viewTo].
  late final _pan = AnimationController(vsync: this);

  /// What moves them along [_pan], for the move under way (or cut short).
  VoidCallback? _panMove;

  /// The collection, sliding up from the bottom to pick a flake for a pane:
  /// 1 all the way up. Linear, so a finger dragging it down moves it in step;
  /// its slides are eased as they run (see [_pick], [_closePicker]).
  late final _sheet = AnimationController(vsync: this, duration: _sheetTime);
  static const _sheetTime = Duration(milliseconds: 280);

  /// The pane the collection is open for, or null when it is closed.
  int? _picking;

  /// The pane the collection shows choices for: [_picking], kept while it
  /// slides away so what it shows doesn't change on the way out.
  int _sheetPane = 0;

  /// Room under the sill as tall as the collection, so even the bottom panes
  /// scroll up clear of it: there while it is open and until it has gone.
  bool _sheetRoom = false;

  /// One window's frame and the screen they pan in, as last laid out.
  Size _frame = Size.zero;
  double _viewWidth = 0, _viewHeight = 0;

  /// The collection covers the lower half of the screen.
  double get _sheetHeight => _viewHeight * .5;

  /// A flake just hung from its own screen, coming into its pane.
  late final _arrive = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  int? _arrivingPane;

  /// The title shows once per launch: fades in, holds a couple of seconds and
  /// fades away, leaving the window clear.
  late final bool _showTitle = !widget.game.titleShown;
  late final _title = AnimationController(vsync: this, duration: const Duration(milliseconds: _titleIn + _titleHold + _titleOut));
  late final _titleOpacity = _title.drive(TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: _titleIn.toDouble()),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: _titleHold.toDouble()),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: _titleOut.toDouble()),
  ]));

  /// The title's fade in, hold and fade out, in ms.
  static const _titleIn = 400, _titleHold = 4000, _titleOut = 600;

  /// The panes' pluses, fading in as the title fades out; there all along
  /// when the title isn't shown.
  late final Animation<double> _plusOpacity = _showTitle
      ? CurvedAnimation(parent: _title, curve: const Interval((_titleIn + _titleHold) / (_titleIn + _titleHold + _titleOut), 1, curve: Curves.easeOut))
      : const AlwaysStoppedAnimation(1.0);

  @override
  void initState() {
    super.initState();
    final f = widget.arriving;
    if (f != null) {
      // Taken in hand at once, so it never comes again on a later visit, even
      // if it can't be hung after all.
      widget.onArrived?.call();
      // Once the screen has come in and the window is laid out.
      Future.delayed(const Duration(milliseconds: 250), () => _hangArriving(f));
    }
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
    _view.dispose();
    _pan.dispose();
    _sheet.dispose();
    _arrive.dispose();
    super.dispose();
  }

  /// Scrolls the window to put its first free pane in the middle of the
  /// screen, then hangs [f] there, growing into it.
  Future<void> _hangArriving(SavedFlake f) async {
    final pane = HomeScreen.freePane(widget.game);
    if (!mounted || pane == null || _frame.isEmpty) return;
    final r = _paneOnView(_frame, pane);
    await _panTo(r.center - Offset(_viewWidth / 2, _viewHeight / 2), const Duration(milliseconds: 600), Curves.easeInOutCubic);
    if (mounted) _hangInto(pane, f);
  }

  /// Hangs [f] in [pane], growing into it.
  Future<void> _hangInto(int pane, SavedFlake f) async {
    setState(() => _arrivingPane = pane);
    widget.game.hang(pane, f);
    await _arrive.forward(from: 0);
    if (mounted && _arrivingPane == pane) setState(() => _arrivingPane = null);
  }

  void _openSettings() {
    // The settings over the collection, never both: it closes first.
    _closePicker();
    showDsDialog(
      context,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: widget.game,
          builder: (ctx, _) {
            final g = widget.game;
            return DsDialog(
              title: tr('settings'),
              onClose: () => Navigator.pop(ctx),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsSwitch(
                    label: tr('sounds'),
                    checked: g.sfx,
                    onChanged: (v) => g.setSetting(sfx: v),
                  ),
                  const SizedBox(height: 16),
                  DsSwitch(
                    label: tr('vibration'),
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

  /// Windows side by side, each as wide as the screen, with an arch of its own
  /// over its two sashes; pane rows in each sash, in bands of three.
  static const _windows = 3, _rows = 8;

  /// Panes in all: numbered window by window, then (as in a window of its
  /// own) row by row from the top, left sash first. So the first window's
  /// panes come first, as when there was just the one, twenty-four rows deep.
  static const _panes = _windows * _rows * 2;

  /// Pane [i]'s glass, in the frame of all the windows, each [frame] in size.
  static Rect _paneRect(Size frame, int i) =>
      WindowFrame.paneRects(frame, _rows)[i % (_rows * 2)].shift(Offset(i ~/ (_rows * 2) * frame.width, 0));

  /// Pane [i]'s glass as panned about: under the dome over the windows.
  static Rect _paneOnView(Size frame, int i) => _paneRect(frame, i).shift(Offset(0, WindowDome.heightFor(frame.width)));

  /// The windows have been panned to start just under the dome, the first
  /// one's top at the top of the screen, as before it (see
  /// [didChangeDependencies]).
  bool _placed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The windows are as wide as the screen, and so the dome as tall as that
    // makes it: known before they are laid out.
    if (_placed) return;
    _placed = true;
    _view.value = Matrix4.translationValues(0, -WindowDome.heightFor(MediaQuery.sizeOf(context).width), 0);
  }

  /// The sill under the windows: as tall as the buttons, so the bottom row
  /// can come up clear of them.
  double get _sillHeight => _buttonsHeight + 16 + MediaQuery.paddingOf(context).bottom;

  /// How far the windows can be panned each way, from the top left.
  Offset get _panReach => Offset(
        math.max(0, _windows * _frame.width - _viewWidth),
        math.max(0, WindowDome.heightFor(_frame.width) + _frame.height + _sillHeight + (_sheetRoom ? _sheetHeight : 0) - _viewHeight),
      );

  /// How far the windows are panned, from the top left; meant for them at
  /// full size, not in the overview (where they are shrunk too).
  Offset get _panned {
    final t = _view.value.getTranslation();
    return Offset(-t.x, -t.y);
  }

  /// Pans the windows so [to] (as near as they reach) is at the screen's top
  /// left, at their full size. Done when the pan is, or cut short.
  Future<void> _panTo(Offset to, Duration duration, Curve curve) {
    final reach = _panReach;
    return _viewTo(1, -Offset(to.dx.clamp(0.0, reach.dx), to.dy.clamp(0.0, reach.dy)), duration, curve);
  }

  /// Brings the windows to [scale], their top left at [shift] on the screen:
  /// the point of them in the middle of the screen gliding straight to the
  /// one that ends there, and the scale changing evenly (by ratio, not by
  /// difference), so a zoom heads for where it lands rather than swinging
  /// about a corner.
  Future<void> _viewTo(double scale, Offset shift, Duration duration, Curve curve) {
    final from = _view.value, t = from.getTranslation();
    // Along x (not getMaxScaleOnAxis, which counts the depth's 1 too).
    final scaleFrom = from.entry(0, 0);
    final middle = Offset(_viewWidth / 2, _viewHeight / 2);
    // The windows' points in the middle of the screen, now and at the end.
    final aimFrom = (middle - Offset(t.x, t.y)) / scaleFrom, aim = (middle - shift) / scale;
    final ease = CurveTween(curve: curve);
    void move() {
      final v = ease.transform(_pan.value);
      final k = scaleFrom * math.pow(scale / scaleFrom, v);
      final o = middle - Offset.lerp(aimFrom, aim, v)! * k;
      _view.value = Matrix4.translationValues(o.dx, o.dy, 0)..scaleByDouble(k, k, 1, 1);
    }

    // A move cut short (by a finger, or by another move) leaves its own off,
    // and never completes: its follower goes here, and its wait ends below.
    if (_panMove case final last?) _pan.removeListener(last);
    _panMove = move;
    _pan
      ..stop()
      ..duration = duration
      ..addListener(move);
    return _pan.forward(from: 0).orCancel.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (_panMove == move) {
        _pan.removeListener(move);
        _panMove = null;
      }
    });
  }

  /// The panes are as tall as when eight rows filled two screens.
  static double _frameHeight(Size view) =>
      WindowFrame.heightFor(view.width, _rows, WindowFrame.paneHeightFor(Size(view.width, view.height * 2), 8));

  /// Opens the collection to fill window [pane] (hang a flake, leave it clear
  /// or take down what is there), the window scrolling the pane up clear of
  /// it. Open already, it moves on to [pane]; for the same pane, it closes.
  void _pick(int pane) {
    if (_picking == pane) {
      _closePicker();
      return;
    }
    setState(() {
      _picking = _sheetPane = pane;
      _sheetRoom = true;
    });
    _sheet.animateTo(1, curve: Curves.easeOutCubic);
    // Once the room under the sill is laid out, so the bottom panes can rise.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bringUp(pane));
  }

  /// Pans the windows so [pane] sits in the middle across, and in the upper
  /// half between the settings button and the collection.
  void _bringUp(int pane) {
    if (!mounted || _frame.isEmpty) return;
    final r = _paneOnView(_frame, pane);
    final top = MediaQuery.paddingOf(context).top + 64;
    _panTo(Offset(r.center.dx - _viewWidth / 2, r.center.dy - (top + _viewHeight - _sheetHeight) / 2), const Duration(milliseconds: 350), Curves.easeOutCubic);
  }

  /// Closes the collection, if open; the window stays where it was scrolled,
  /// but for coming back within reach once the room under the sill goes.
  /// Whether it was open.
  bool _closePicker() {
    if (_picking == null) return false;
    setState(() => _picking = null);
    final reach = math.max(0.0, _panReach.dy - _sheetHeight);
    if (_panned.dy > reach) _panTo(Offset(_panned.dx, reach), _sheetTime, Curves.easeInOutCubic);
    _sheet.animateBack(0, curve: Curves.easeInCubic).whenComplete(() {
      if (mounted && _picking == null) setState(() => _sheetRoom = false);
    });
    return true;
  }

  /// The collection dragged down by its top, [dy] px.
  void _dragSheet(double dy) {
    if (_picking != null) _sheet.value -= dy / _sheetHeight;
  }

  /// The collection let go: flung down, or dragged past a third of the way,
  /// it closes; else it springs back up.
  void _dropSheet(double velocity) {
    if (_picking == null) return;
    if (velocity > 700 || _sheet.value < 2 / 3) {
      _closePicker();
    } else {
      _sheet.animateTo(1, curve: Curves.easeOutCubic);
    }
  }

  /// The system back button: closes the collection if it is open, and says
  /// whether it did (if not, the back is the app's to handle).
  bool handleBack() => _closePicker() || _leaveOverview();

  /// All the windows shown at once, small, to see the whole of them: panning
  /// is off, and a tap on a pane brings the windows back to full size there.
  bool _overview = false;

  /// Where the windows were panned before the overview, to go back to.
  Offset _beforeOverview = Offset.zero;

  static const _overviewTime = Duration(milliseconds: 450);

  /// Shrinks the windows to fit between the top bar and the buttons, in the
  /// middle; or, shown so already, brings them back as they were.
  void _toggleOverview() {
    if (_leaveOverview()) return;
    if (_frame.isEmpty) return;
    _closePicker();
    final pad = MediaQuery.paddingOf(context);
    final top = pad.top + 64, bottom = _viewHeight - _buttonsHeight - pad.bottom;
    final width = _windows * _frame.width;
    // The windows fitted in, the dome over them going up off the screen.
    final scale = math.min(_viewWidth / width, (bottom - top) / _frame.height);
    final windowsTop = top + (bottom - top - _frame.height * scale) / 2;
    _beforeOverview = _panned;
    setState(() => _overview = true);
    _viewTo(scale, Offset((_viewWidth - width * scale) / 2, windowsTop - WindowDome.heightFor(_frame.width) * scale), _overviewTime, Curves.easeInOutCubic);
  }

  /// Back from the overview to where the windows were; whether it was up.
  bool _leaveOverview() {
    if (!_overview) return false;
    setState(() => _overview = false);
    _panTo(_beforeOverview, _overviewTime, Curves.easeInOutCubic);
    return true;
  }

  /// Back from the overview to full size, with pane [i] in the middle.
  void _zoomInTo(int i) {
    setState(() => _overview = false);
    _panTo(_paneOnView(_frame, i).center - Offset(_viewWidth / 2, _viewHeight / 2), _overviewTime, Curves.easeInOutCubic);
  }

  /// The Play and Collection buttons with their gap and bottom padding:
  /// 64 + 6 lip, 12, 52 + 6 lip, 28.
  static const _buttonsHeight = 168.0;

  /// From the bottom padding up to the middle of the Play button
  /// (28, 52 + 6, 12, 6 + 64 / 2): the shade behind the buttons is full up to
  /// there and fades out over [_hazeFade] above.
  static const _playMiddle = 136.0;
  static const _hazeFade = 90.0;

  /// Pane [i]'s [child], growing and fading in if its flake is just arriving.
  Widget _arriving(int i, Widget child) {
    if (i != _arrivingPane) return child;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _arrive, curve: const Interval(0, .5)),
      child: ScaleTransition(scale: CurvedAnimation(parent: _arrive, curve: Curves.easeOutBack), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final hazeHeight = _playMiddle + _hazeFade + bottomInset;
    final view = Stack(
      children: [
        // Outside the window: snow falling in the night in winter; in autumn a
        // still, sunny day, the picture centred and a fifth taller than the
        // screen, so the tree's edge and the sun's rays show through.
        Positioned.fill(
          child: season == Season.winter
              ? RepaintBoundary(child: _Snowfall(ticker: _ticker, hazeHeight: hazeHeight, hazeFade: _hazeFade))
              : LayoutBuilder(
                  builder: (_, c) => ClipRect(
                    child: OverflowBox(
                      maxWidth: c.maxHeight * 1.2,
                      maxHeight: c.maxHeight * 1.2,
                      child: Image.asset(_autumnView, fit: BoxFit.cover),
                    ),
                  ),
                ),
        ),
        // The view outside stays put; the windows, wider and taller than the
        // screen, pan past in any direction with the title on the first one's
        // top half, and the sill under them. They stop dead at the edges.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (_, c) {
              final frame = Size(c.maxWidth, _frameHeight(c.biggest));
              _frame = frame;
              _viewWidth = c.maxWidth;
              _viewHeight = c.maxHeight;
              return InteractiveViewer(
                transformationController: _view,
                constrained: false,
                scaleEnabled: false,
                // Still in the overview: the whole of them is in sight.
                panEnabled: !_overview,
                boundaryMargin: EdgeInsets.zero,
                // A finger on the glass takes over from a pan under way.
                onInteractionStart: (_) => _pan.stop(),
                // With the collection open, a tap on a frame or the sill closes it
                // (a pane takes its own taps, moving the choice to it).
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _picking == null ? null : _closePicker,
                  child: SizedBox(
                    width: _windows * frame.width,
                    child: Column(children: [
                    // A dome roofing the windows, above the screen at first.
                    SizedBox(height: WindowDome.heightFor(frame.width), child: const WindowDome(windows: _windows)),
                    SizedBox(
                      height: frame.height,
                      child: Stack(children: [
                        for (var w = 0; w < _windows; w++)
                          Positioned(
                            left: w * frame.width,
                            top: 0,
                            width: frame.width,
                            height: frame.height,
                            child: const WindowFrame(rows: _rows, onSill: true, snow: season == Season.winter),
                          ),
                        // Each pane holds a flake from the collection, or a plus to
                        // hang one; the title, while up, shows over the first
                        // window's top row.
                        for (var i = 0; i < _panes; i++)
                          Positioned.fromRect(
                            rect: _paneRect(frame, i),
                            child: _arriving(
                              i,
                              _Pane(flake: g.window[i], clear: g.window.containsKey(i) && g.window[i] == null, plusOpacity: _plusOpacity, onTap: () => _overview ? _zoomInTo(i) : _pick(i)),
                            ),
                          ),
                        // The pane being picked for, outlined.
                        if (_picking case final p?)
                          Positioned.fromRect(
                            rect: _paneRect(frame, p),
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  border: Border.all(color: C.berry500, width: 4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        if (_titleUp)
                          Positioned(
                            left: 0,
                            width: frame.width,
                            // Centred in the top pane under the arch, clear of the bars.
                            top: WindowFrame.paneMiddle(frame, _rows, 0),
                            child: FractionalTranslation(
                              translation: const Offset(0, -.5),
                              child: FadeTransition(
                                opacity: _titleOpacity,
                                // As wide as the words, not the screen, for the frost to fit them.
                                child: Center(
                                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                                  // Frost on the glass behind the title, its soft edges well
                                  // past the words, so the flakes in the panes show round it;
                                  // set a little low, under the subtitle more than over the title.
                                  Positioned(
                                    left: -48,
                                    right: -48,
                                    top: -40,
                                    bottom: -80,
                                    child: Image.asset(_titleBg, fit: BoxFit.fill),
                                  ),
                                  Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text(
                                    tr('app_title'),
                                    style: display(56, weight: FontWeight.w900, height: 1, shadows: drop(5)).copyWith(letterSpacing: -.56),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    tr('home_subtitle'),
                                    // The title's shadow colour, on the pale frost behind it in any season.
                                    style: body(17, weight: FontWeight.w800, color: C.night900),
                                  ),
                                ]),
                                ]),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    SizedBox(height: _sillHeight, child: const WindowSill()),
                    if (_sheetRoom) SizedBox(height: _sheetHeight),
                  ]),
                  ),
                ),
              );
            },
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
                    if (_showCoins) CurrencyPill(amount: g.coins),
                    const Spacer(),
                    // All the windows at once, small, and back.
                    BarBtn(_overview ? LucideIcons.zoomIn : LucideIcons.zoomOut, label: tr(_overview ? 'zoom_in' : 'whole_window'), onTap: _toggleOverview),
                    const SizedBox(width: 8),
                    BarBtn(LucideIcons.settings, label: tr('settings'), onTap: _openSettings),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                child: Column(
                  children: [
                    Btn(tr('play'), size: BtnSize.l, icon: LucideIcons.play, block: true, onTap: widget.onPlay),
                    const SizedBox(height: 12),
                    Btn(tr('my_collection'), variant: Variant.light, icon: LucideIcons.image, block: true, onTap: widget.onGallery),
                  ],
                ),
              ),
            ],
          ),
        ),
        // The collection, over the buttons, to pick a flake for a pane.
        if (_sheetRoom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _sheetHeight,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(_sheet),
              child: _CollectionSheet(
                game: g,
                pane: _sheetPane,
                onDrag: _dragSheet,
                onDrop: _dropSheet,
                onPick: (f) {
                  // A flake grows into the pane, as one hung from its own screen does;
                  // the one hanging there already, picked again, just stays.
                  if (f == null) {
                    g.hang(_sheetPane, null);
                  } else if (!identical(f, g.window[_sheetPane])) {
                    _hangInto(_sheetPane, f);
                  }
                  _closePicker();
                },
                onPlay: () {
                  _closePicker();
                  widget.onPlay();
                },
                onUnhang: () {
                  g.unhang(_sheetPane);
                  _closePicker();
                },
              ),
            ),
          ),
      ],
    );
    return season == Season.winter ? SkyBackground(softDots: true, colors: _skyUnderHaze, child: view) : view;
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
/// [clear], or else a faint plus to fill it. Either way a tap anywhere on the
/// glass calls [onTap].
class _Pane extends StatelessWidget {
  const _Pane({required this.flake, required this.clear, required this.plusOpacity, required this.onTap});
  final SavedFlake? flake;
  final bool clear;

  /// How far the plus has faded in (flakes show at once, whatever this is).
  final Animation<double> plusOpacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = flake;
    if (clear) {
      // Nothing to see, but still there to tap.
      return Semantics(
        button: true,
        label: tr('empty_glass'),
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: const SizedBox.expand()),
      );
    }
    if (f == null) {
      // The whole glass takes the tap, not just the plus in its middle.
      return Semantics(
        button: true,
        label: tr('hang_flake'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: FadeTransition(
              opacity: plusOpacity,
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
        ),
      );
    }
    return LayoutBuilder(
      builder: (_, c) => Semantics(
        button: true,
        label: tr('flake'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: FlakeShadow(
              size: math.min(c.maxWidth, c.maxHeight) * .858,
              child: SnowflakeView(cuts: f.cuts, folds: f.folds, color: f.color, pattern: f.pattern, size: math.min(c.maxWidth, c.maxHeight) * .858),
            ),
          ),
        ),
      ),
    );
  }
}

/// The collection sliding up over the home screen, to fill [pane]: the flakes
/// two to a row (those hanging in other panes greyed and marked, not to be
/// picked), then leaving the pane clear; and, when the pane is filled, taking
/// it down. It opens on that pane's flake, or the first free ones (see
/// [_CollectionSheetState._showCurrent]).
class _CollectionSheet extends StatefulWidget {
  const _CollectionSheet({
    required this.game,
    required this.pane,
    required this.onPick,
    required this.onUnhang,
    required this.onPlay,
    required this.onDrag,
    required this.onDrop,
  });
  final GameState game;
  final int pane;

  /// Its top (handle and title) dragged down, by so many px; and let go, at
  /// so many px a second downward.
  final ValueChanged<double> onDrag, onDrop;

  /// A flake, or null to leave the pane clear.
  final ValueChanged<SavedFlake?> onPick;
  final VoidCallback onUnhang;

  /// Goes off to cut a flake: offered in place of the grid while the
  /// collection is empty.
  final VoidCallback onPlay;

  @override
  State<_CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends State<_CollectionSheet> {
  final _scroll = ScrollController();

  /// The grid's side padding, its top padding, and the gap between its tiles.
  static const _pad = 20.0, _top = 4.0, _gap = 14.0;

  @override
  void initState() {
    super.initState();
    // Already there as it slides up.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrent(animate: false));
  }

  @override
  void didUpdateWidget(_CollectionSheet old) {
    super.didUpdateWidget(old);
    if (old.pane != widget.pane) WidgetsBinding.instance.addPostFrameCallback((_) => _showCurrent(animate: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the grid to put in its middle (as far as the grid goes) the
  /// flake hanging in the pane, or with none there, the first row with a flake
  /// still free to hang (or, every one hanging, leaving the pane clear).
  void _showCurrent({required bool animate}) {
    if (!mounted || !_scroll.hasClients) return;
    final g = widget.game;
    final current = g.window[widget.pane];
    var i = current == null ? -1 : g.saved.indexWhere((f) => identical(f, current));
    if (i < 0) i = g.saved.indexWhere((f) => !g.isHung(f));
    // The "clear" tile, after every flake.
    if (i < 0) i = g.saved.length;
    // Square tiles, two to a row.
    final side = (context.size!.width - 2 * _pad - _gap) / 2;
    final middle = _top + (i ~/ 2) * (side + _gap) + side / 2;
    final target = (middle - _scroll.position.viewportDimension / 2).clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final pane = widget.pane;
    final onPick = widget.onPick;
    final filled = g.window.containsKey(pane);
    final current = g.window[pane];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: C.night800,
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl)),
        boxShadow: [BoxShadow(color: Color(0x59101A3F), offset: Offset(0, -6), blurRadius: 30)],
      ),
      child: Column(children: [
        // Its top takes the drag that pulls it down, the handle showing so.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) => widget.onDrag(d.delta.dy),
          onVerticalDragEnd: (d) => widget.onDrop(d.velocity.pixelsPerSecond.dy),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 20, 20),
              child: Row(children: [
                Expanded(child: Text(tr('my_collection'), style: display(22, height: 1.1, shadows: drop(3)))),
                if (filled) Btn(tr('unhang'), variant: Variant.light, icon: LucideIcons.x, size: BtnSize.s, onTap: widget.onUnhang),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: g.saved.isEmpty
              // Nothing to hang yet: off to cut the first one.
              ? Padding(
                  padding: EdgeInsets.fromLTRB(32, 0, 32, MediaQuery.paddingOf(context).bottom + 20),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(tr('collection_empty'), style: display(22, color: C.ice200), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Btn(tr('play'), size: BtnSize.l, icon: LucideIcons.play, block: true, onTap: widget.onPlay),
                  ]),
                )
              : GridView.count(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(_pad, _top, _pad, MediaQuery.paddingOf(context).bottom + 20),
                  // Two to a row, as in the collection.
                  crossAxisCount: 2,
                  mainAxisSpacing: _gap,
                  crossAxisSpacing: _gap,
                  children: [
                    for (final f in g.saved)
                      if (identical(f, current) || !g.isHung(f))
                        _PickTile(flake: f, selected: identical(f, current), onTap: () => onPick(f))
                      else
                        _PickTile(flake: f, selected: false),
                    // Leaving the pane clear comes last, after every flake.
                    _PickTile(selected: filled && current == null, onTap: () => onPick(null)),
                  ],
                ),
        ),
      ]),
    );
  }
}

/// A choice in the collection opened for a pane: [flake], or leaving the pane
/// clear when there is none. Without [onTap] it can't be picked (the flake
/// already hangs elsewhere): grey, marked "on the window".
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
      label: f == null ? tr('empty') : tr('flake'),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: onTap == null ? C.snow700 : C.night700,
            borderRadius: BorderRadius.circular(R.l),
            border: selected ? Border.all(color: C.berry500, width: 3) : null,
            boxShadow: const [BoxShadow(color: C.night900, offset: Offset(0, 6))],
          ),
          child: LayoutBuilder(
            builder: (_, c) => Stack(children: [
              Center(
                child: f == null
                    ? Text(tr('empty'), style: display(15, color: C.ice200))
                    : FlakeShadow(
                        size: (c.maxWidth * .78).clamp(0, 140),
                        child: SnowflakeView(cuts: f.cuts, folds: f.folds, color: f.color, pattern: f.pattern, size: (c.maxWidth * .78).clamp(0, 140)),
                      ),
              ),
              // Already on another pane: said so in the corner.
              if (onTap == null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: C.night800, borderRadius: BorderRadius.circular(R.s)),
                    child: Text(tr('on_window'), style: display(13, color: Colors.white, height: 1)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
