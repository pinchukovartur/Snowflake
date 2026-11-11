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
import '../widgets/window_decor.dart';


/// The coin counter is off until coins are earned and spent somewhere;
/// the coins themselves are still kept (see GameState.coins).
const _showCoins = false;

/// What the window looks out on. Set by hand for each release: winter for the
/// Christmas one.
enum Season { autumn, winter }

const season = Season.winter;

/// The autumn view: a sunny sky with a maple in leaf, seen through the glass.
const _autumnView = 'assets/Autumn_Window_Bg.png';

/// The winter view: a snowy plain under the northern lights, snow falling
/// over it (see [_Snowfall]).
const _winterView = 'assets/Winter_Window_Bg.png';

/// The view through the glass this season.
const _outsideView = season == Season.winter ? _winterView : _autumnView;

/// A patch of frost behind the game's title on the window.
const _titleBg = 'assets/Window_Title_Bg.png';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.game, required this.onPlay, required this.onGallery, this.arriving, this.back, this.onArrived, this.onView});
  final GameState game;
  final VoidCallback onPlay, onGallery;

  /// Off to a flake's own screen from the collection open for [WindowBack.pane],
  /// to come back to the window as it was left (see [back]).
  final void Function(SavedFlake flake, WindowBack from)? onView;

  /// Back from a flake's own screen opened from the collection (see
  /// [onView]): the window as it was left, the collection open again; with
  /// [WindowBack.hang], that flake goes up in the pane, as if picked there.
  final WindowBack? back;

  /// A flake on its way to the window: the window scrolls to its first pane
  /// still to fill, and it appears there (see [freePane]).
  final SavedFlake? arriving;

  /// Called as soon as the screen takes [arriving] or [back] in hand.
  final VoidCallback? onArrived;

  /// The first pane in [game]'s window still to fill (a plus, not glass left
  /// clear on purpose), or null when every one is.
  static int? freePane(GameState game) {
    for (var i = 0; i < HomeScreenState._panes; i++) {
      if (!game.window.containsKey(i) && !HomeScreenState._behindDoor(i)) return i;
    }
    return null;
  }

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

/// Where the window was left for a flake's own screen: the collection open
/// for [pane], the window panned and zoomed by [view]. [hang]: a flake to
/// hang in [pane] on coming back.
typedef WindowBack = ({int pane, Matrix4 view, SavedFlake? hang});

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

  /// A flake just taken down, leaving its pane: rising a little as it fades.
  late final _leave = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  ({int pane, SavedFlake flake})? _leaving;

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
    if (widget.back case final back?) {
      widget.onArrived?.call();
      _view.value = back.view.clone();
      _picking = _sheetPane = back.pane;
      _sheetRoom = true;
      _sheet.value = 1;
      // Built again once laid out: the collection is as tall as half the
      // screen, not known on the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      if (back.hang case final f?) {
        // Once the screen has come in, as if picked in the collection.
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          if (!identical(f, widget.game.window[back.pane])) _hangInto(back.pane, f);
          _closePicker();
        });
      }
    }
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
    _leave.dispose();
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

  /// Takes the flake in [pane] down: it rises a little and fades away, the
  /// pane's plus showing through meanwhile.
  Future<void> _takeDown(int pane) async {
    final f = widget.game.window[pane];
    widget.game.unhang(pane);
    if (f == null) return;
    final leaving = (pane: pane, flake: f);
    setState(() => _leaving = leaving);
    await _leave.forward(from: 0);
    if (mounted && identical(_leaving, leaving)) setState(() => _leaving = null);
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

  /// Skips the title, if up and not yet fading, on to fading away.
  void _skipTitle() {
    const fade = (_titleIn + _titleHold) / (_titleIn + _titleHold + _titleOut);
    if (!_titleUp || _title.value >= fade) return;
    // Fading out from there (full, if it was still fading in).
    _title.value = fade;
    _title.forward();
  }

  /// Windows side by side, each as wide as the screen, with an arch of its own
  /// over its two sashes; pane rows in each sash, in bands of three.
  static const _windows = 3, _rows = GameState.panesPerWindow ~/ 2;

  /// Panes in all: numbered window by window, then (as in a window of its
  /// own) row by row from the top, left sash first. So the first window's
  /// panes come first, as when there was just the one.
  static const _panes = _windows * _rows * 2;

  /// Pane [i]'s glass, in the frame of all the windows, each [frame] in size.
  static Rect _paneRect(Size frame, int i) =>
      WindowFrame.paneRects(frame, _rows)[i % (_rows * 2)].shift(Offset(i ~/ (_rows * 2) * frame.width, 0));

  /// The middle window has a door in place of its bottom [_doorRows] rows:
  /// it has no panes there.
  static const _doorWindow = 1, _doorRows = 3;

  static bool _behindDoor(int i) => i ~/ (_rows * 2) == _doorWindow && i % (_rows * 2) ~/ 2 >= _rows - _doorRows;

  /// The door's glazed part (the rest runs on down through the sill), in
  /// [frame] of all the windows.
  static Rect _doorRect(Size frame) => WindowFrame.doorRect(frame, _rows, _doorRows).shift(Offset(_doorWindow * frame.width, 0));

  /// What stands in front of the door, against the door's glazed part: this
  /// much taller (as wide as its picture makes that), and its foot this share
  /// of its height below the floor's edge, a little out into the room.
  static const _decorGrow = 1.42, _decorDrop = .03;

  /// Where what stands in front of the door stands, in [frame] of all the
  /// windows: centred on the door, down on the floor.
  static Rect _decorRect(Size frame) {
    final door = _doorRect(frame);
    final h = door.height * _decorGrow, w = h * (windowDecor?.aspect ?? 1);
    final foot = door.bottom + _sillFor(frame) + h * _decorDrop;
    return Rect.fromLTWH(door.center.dx - w / 2, foot - h, w, h);
  }

  /// Over the windows, as panned about: the sky over the dome, the
  /// pinwheel standing on top of it, and the dome; how tall, over windows
  /// [width] wide.
  static double _roofHeight(double width) => DomeVane.heightFor(width) + width * .5;
  static double _aboveWindows(double width) => _roofHeight(width) + WindowDome.heightFor(width);

  /// Pane [i]'s glass as panned about: under the roof over the windows.
  static Rect _paneOnView(Size frame, int i) => _paneRect(frame, i).shift(Offset(0, _aboveWindows(frame.width)));

  /// The windows have been panned to start just under the dome, the first
  /// one's top at the top of the screen, as before it (see
  /// [didChangeDependencies]).
  bool _placed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The windows are as wide as the screen, and so the dome as tall as that
    // makes it: known before they are laid out. Coming back to them (see
    // [HomeScreen.back]), they are where they were left.
    if (_placed) return;
    _placed = true;
    if (widget.back != null) return;
    _view.value = Matrix4.translationValues(0, -_aboveWindows(MediaQuery.sizeOf(context).width), 0);
  }

  /// The sill under the windows, as tall as a row of panes with its bar: it
  /// and the door's foot come up clear of the buttons, the floor going on
  /// behind them.
  static double _sillFor(Size frame) => _paneRect(frame, 2).top - _paneRect(frame, 0).top;

  /// The floor under the sill: as tall as the buttons, so the sill can come
  /// up clear of them.
  double get _floorHeight => _buttonsHeight + 16 + MediaQuery.paddingOf(context).bottom;

  /// The roof, the windows, the sill under them and the floor: how tall at
  /// full size.
  double get _wallHeight => _aboveWindows(_frame.width) + _frame.height + _sillFor(_frame) + _floorHeight;

  /// How far the windows can be panned each way, from the top left: the
  /// wall's own reach ([_wallReach]), and the collection's room under it.
  Offset get _panReach => _wallReach + Offset(0, _sheetRoom ? _sheetHeight : 0);

  /// How far the wall, without the collection's room, reaches past the screen
  /// each way at full size.
  Offset get _wallReach => Offset(math.max(0, _windows * _frame.width - _viewWidth), math.max(0, _wallHeight - _viewHeight));

  /// Takes the windows' size from the room they fill, [c]: done by each part
  /// laid out in it, the first of them before any uses it.
  void _layOut(BoxConstraints c) {
    _frame = Size(c.maxWidth, _frameHeight(c.biggest));
    _viewWidth = c.maxWidth;
    _viewHeight = c.maxHeight;
  }

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
    final scaleFrom = from.entry(0, 0);
    final middle = Offset(_viewWidth / 2, _viewHeight / 2);
    // The windows' points in the middle of the screen, now and at the end.
    final aimFrom = (middle - Offset(t.x, t.y)) / scaleFrom, aim = (middle - shift) / scale;
    final ease = CurveTween(curve: curve);
    void move() {
      final v = ease.transform(_pan.value);
      final k = scaleFrom * math.pow(scale / scaleFrom, v);
      final o = middle - Offset.lerp(aimFrom, aim, v)! * k;
      // Depth scaled too: InteractiveViewer reads the scale with
      // getMaxScaleOnAxis, and a depth left at 1 would throw its clamping off.
      _view.value = Matrix4.translationValues(o.dx, o.dy, 0)..scaleByDouble(k, k, k, 1);
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
  ///
  /// From the overview, the windows grow back to full size on the way, as
  /// slowly as [_backTo] has them, the floor shrinking back once there.
  void _bringUp(int pane) {
    if (!mounted || _frame.isEmpty) return;
    final r = _paneOnView(_frame, pane);
    final top = MediaQuery.paddingOf(context).top + 64;
    final growing = _view.value.entry(0, 0) < 1;
    _panTo(
      Offset(r.center.dx - _viewWidth / 2, r.center.dy - (top + _viewHeight - _sheetHeight) / 2),
      growing ? _overviewTime : const Duration(milliseconds: 350),
      growing ? Curves.easeInOutCubic : Curves.easeOutCubic,
    ).whenComplete(() {
      if (mounted && !_overview && _tallFloor) setState(() => _tallFloor = false);
    });
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

  /// All the windows shown at once, small: shrunk to the screen's width and
  /// panned up and down; a tap on a pane brings them back to full size there.
  bool _overview = false;

  /// Where the windows were panned before the overview, to go back to.
  Offset _beforeOverview = Offset.zero;

  static const _overviewTime = Duration(milliseconds: 450);

  /// How far the overview shrinks the windows: to the screen's width.
  double get _overviewScale => _viewWidth / (_windows * _frame.width);

  /// The floor is grown for the overview, so shrunk it is still as tall as
  /// the buttons and the sill comes up clear of them; from going into the
  /// overview till back out of it at full size.
  bool _tallFloor = false;

  double get _floorShown => _tallFloor ? _floorHeight / _overviewScale : _floorHeight;

  /// Shrinks the windows to the screen's width, edge to edge, the part of
  /// them in the middle of the screen staying there; or, shown so already,
  /// brings them back as they were.
  void _toggleOverview() {
    if (_leaveOverview()) return;
    if (_frame.isEmpty) return;
    _closePicker();
    final scale = _overviewScale;
    // All of them, top to bottom, as they shrink; kept on the screen.
    final height = (_wallHeight - _floorHeight) * scale + _floorHeight;
    final middle = _panned.dy + _viewHeight / 2;
    final top = (_viewHeight / 2 - middle * scale).clamp(math.min(0.0, _viewHeight - height), 0.0).toDouble();
    _beforeOverview = _panned;
    setState(() => _overview = _tallFloor = true);
    _viewTo(scale, Offset(0, top), _overviewTime, Curves.easeInOutCubic);
  }

  /// Brings the windows to full size (from the overview, if in it) with
  /// what stands in front of the door in the middle between the top bar and
  /// the buttons.
  void _goToDecor() {
    if (_frame.isEmpty) return;
    _closePicker();
    if (_overview) {
      _backTo(_decorPan);
    } else {
      _panTo(_decorPan, _overviewTime, Curves.easeInOutCubic);
    }
  }

  /// What stands in front of the door, as panned about: under the roof.
  Rect get _decorOnView => _decorRect(_frame).shift(Offset(0, _aboveWindows(_frame.width)));

  /// How far [_goToDecor] pans the windows at full size: what stands in
  /// front of the door in the middle between the top bar and the buttons, as
  /// near as they reach (the collection's room left out).
  Offset get _decorPan {
    final r = _decorOnView;
    final top = MediaQuery.paddingOf(context).top + 64, bottom = _viewHeight - _floorHeight;
    final reach = _wallReach;
    return Offset((r.center.dx - _viewWidth / 2).clamp(0.0, reach.dx), (r.center.dy - (top + bottom) / 2).clamp(0.0, reach.dy));
  }

  /// Parallax: what stands in front of the door, nearer than the windows,
  /// moves this share faster than them on the screen; the view outside,
  /// further off, drifts this share of the screen each way as they pan from
  /// end to end.
  static const _decorDepth = .3, _outsideDrift = .1;

  /// How far what stands in front of the door is drawn off its place, in the
  /// windows' own measure: at rest where [_goToDecor] brings it, further off
  /// the further it is from there on the screen. Less as the windows shrink,
  /// and none in the overview.
  Offset get _decorShift {
    if (_frame.isEmpty) return Offset.zero;
    final m = _view.value, s = m.entry(0, 0), t = m.getTranslation();
    final full = _overviewScale;
    final depth = full >= 1 ? _decorDepth : _decorDepth * ((s - full) / (1 - full)).clamp(0.0, 1.0);
    if (depth == 0) return Offset.zero;
    final r = _decorOnView;
    final rest = r.center - _decorPan;
    return (Offset(t.x, t.y) + r.center * s - rest) * depth / s;
  }

  /// How far the view outside is drawn off its place on the screen: drifting
  /// the way the windows pan, but only [_outsideDrift] of the screen from the
  /// middle to either end.
  Offset get _outsideShift {
    if (_frame.isEmpty) return Offset.zero;
    // Over the wall's own reach, not the collection's room under it, so the
    // view does not jump as that comes and goes.
    final reach = _wallReach, t = _view.value.getTranslation();
    double drift(double panned, double reach, double side) =>
        reach <= 0 ? 0 : (.5 - (panned / reach).clamp(0.0, 1.0)) * 2 * _outsideDrift * side;
    return Offset(drift(-t.x, reach.dx, _viewWidth), drift(-t.y, reach.dy, _viewHeight));
  }

  /// Back from the overview to where the windows were; whether it was up.
  bool _leaveOverview() {
    if (!_overview) return false;
    _backTo(_beforeOverview);
    return true;
  }

  /// Back from the overview to full size, with [point] of the windows (as
  /// panned about) in the middle of the screen, as near as they reach.
  void _zoomInAt(Offset point) => _backTo(point - Offset(_viewWidth / 2, _viewHeight / 2));

  /// Back from the overview to full size, straight into picking a flake for
  /// [pane]: the windows heading for where the collection wants it.
  void _pickFromOverview(int pane) {
    setState(() => _overview = false);
    _pick(pane);
  }

  /// Back from the overview to full size, panned to [to]; the sill shrinks
  /// back once there.
  void _backTo(Offset to) {
    setState(() => _overview = false);
    _panTo(to, _overviewTime, Curves.easeInOutCubic).whenComplete(() {
      if (mounted && !_overview) setState(() => _tallFloor = false);
    });
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
        // Outside the window: the season's view (see [_outsideView]), centred
        // and a fifth taller than the screen, so its edges show through. It
        // drifts a little as the windows pan, being further off.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (_, c) {
              // Drifting by the windows' size, before they are built.
              _layOut(c);
              return ClipRect(
                child: OverflowBox(
                  maxWidth: c.maxHeight * 1.2,
                  maxHeight: c.maxHeight * 1.2,
                  child: AnimatedBuilder(
                    animation: _view,
                    builder: (_, child) => Transform.translate(offset: _outsideShift, child: child),
                    child: RepaintBoundary(child: Image.asset(_outsideView, fit: BoxFit.cover)),
                  ),
                ),
              );
            },
          ),
        ),
        // In winter, snow falling over it.
        if (season == Season.winter)
          Positioned.fill(child: RepaintBoundary(child: _Snowfall(ticker: _ticker, hazeHeight: hazeHeight, hazeFade: _hazeFade, drift: () => _outsideShift))),
        // The windows, wider and taller than the screen, pan past in any
        // direction, with the roof over them and the sill and floor under
        // them. They stop dead at the edges.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (_, c) {
              _layOut(c);
              final frame = _frame;
              final door = _doorRect(frame).shift(Offset(0, _aboveWindows(frame.width)));
              return InteractiveViewer(
                transformationController: _view,
                constrained: false,
                scaleEnabled: false,
                // In the overview too: as wide as the screen there, they pan
                // up and down.
                boundaryMargin: EdgeInsets.zero,
                // A finger on the glass takes over from a pan under way.
                onInteractionStart: (_) => _pan.stop(),
                // With the collection open, a tap on a frame or the sill closes it
                // (a pane takes its own taps, moving the choice to it). In the
                // overview, a tap anywhere zooms back in there.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _overview || _picking == null ? null : _closePicker,
                  onTapUp: _overview ? (d) => _zoomInAt(d.localPosition) : null,
                  child: SizedBox(
                    width: _windows * frame.width,
                    child: Stack(children: [
                    Column(children: [
                    // A dome roofing the windows, above the screen at first,
                    // and a pinwheel on top of it, spinning in the sky.
                    SizedBox(
                      height: _roofHeight(frame.width),
                      child: Align(alignment: Alignment.bottomCenter, child: DomeVane(windowWidth: frame.width, ticker: _ticker)),
                    ),
                    SizedBox(
                      height: WindowDome.heightFor(frame.width),
                      // In winter, snowflakes landing on its glass.
                      child: Stack(fit: StackFit.expand, children: [
                        const WindowDome(windows: _windows),
                        if (season == Season.winter) DomeSnow(ticker: _ticker),
                      ]),
                    ),
                    SizedBox(
                      height: frame.height,
                      child: Stack(children: [
                        for (var w = 0; w < _windows; w++)
                          Positioned(
                            left: w * frame.width,
                            top: 0,
                            width: frame.width,
                            height: frame.height,
                            child: WindowFrame(rows: _rows, snow: season == Season.winter, door: w == _doorWindow ? _doorRows : 0, index: w, windows: _windows),
                          ),
                        // Each pane holds a flake from the collection, or a plus to
                        // hang one.
                        for (var i = 0; i < _panes; i++)
                          if (!_behindDoor(i))
                            Positioned.fromRect(
                              rect: _paneRect(frame, i),
                              child: _arriving(
                                i,
                                _Pane(flake: g.window[i], clear: g.window.containsKey(i) && g.window[i] == null, plusOpacity: _plusOpacity, onTap: () => _overview ? _pickFromOverview(i) : _pick(i)),
                              ),
                            ),
                        // A flake just taken down, rising out of its pane as it fades.
                        if (_leaving case (:final pane, :final flake))
                          Positioned.fromRect(
                            rect: _paneRect(frame, pane),
                            child: IgnorePointer(
                              child: FadeTransition(
                                opacity: CurvedAnimation(parent: _leave, curve: Curves.easeIn).drive(Tween(begin: 1.0, end: 0.0)),
                                child: SlideTransition(
                                  position: CurvedAnimation(parent: _leave, curve: Curves.easeOutCubic).drive(Tween(begin: Offset.zero, end: const Offset(0, -.15))),
                                  child: _Pane(flake: flake, clear: false, plusOpacity: _plusOpacity, onTap: () {}),
                                ),
                              ),
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
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    SizedBox(height: _sillFor(frame), child: const WindowSill()),
                    SizedBox(height: _floorShown, child: const WindowFloor(windows: _windows, door: _doorWindow)),
                    if (_sheetRoom) SizedBox(height: _sheetHeight),
                  ]),
                    // The door, down through the sill to the floor, and what
                    // stands in front of it: a tap on that (inside its outline,
                    // the panes round it keeping theirs) brings it into view.
                    Positioned.fromRect(
                      rect: Rect.fromLTRB(door.left, door.top, door.right, door.bottom + _sillFor(frame)),
                      child: WindowDoor(glassHeight: door.height),
                    ),
                    // Nearer than the windows, it moves faster than them (see
                    // [_decorShift]).
                    if (windowDecor case final d?)
                      Positioned.fromRect(
                        rect: _decorOnView,
                        child: AnimatedBuilder(
                          animation: _view,
                          builder: (_, child) => Transform.translate(offset: _decorShift, child: child),
                          child: ClipPath(
                            clipper: _OutlineClipper(d.outline),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _goToDecor,
                              child: RepaintBoundary(child: Image.asset(d.image, fit: BoxFit.fill, filterQuality: FilterQuality.medium)),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  ),
                ),
              );
            },
          ),
        ),
        // The title, while up, on the screen where the first window's top row
        // starts out, staying there whatever the windows do.
        if (_titleUp)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (_, c) {
                  _layOut(c);
                  final frame = _frame;
                  return Stack(children: [
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
                  ]);
                },
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
                onView: widget.onView == null ? null : (f) => widget.onView!(f, (pane: _sheetPane, view: _view.value.clone(), hang: null)),
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
                  _takeDown(_sheetPane);
                  _closePicker();
                },
              ),
            ),
          ),
      ],
    );
    // Any touch anywhere skips the title on to fading out, the touch still
    // doing what it does.
    return Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => _skipTitle(), child: view);
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
  double get fall => (14 - depth * 7) / .64;
  double get alpha => .45 + depth * .5;
}

/// Snow falling outside the window: small round flecks drifting down, seen
/// soft through the glass and softer still in the bottom [hazeHeight] behind
/// the buttons, setting in over its top [hazeFade].
class _Snowfall extends StatefulWidget {
  const _Snowfall({required this.ticker, required this.hazeHeight, required this.hazeFade, required this.drift});
  final AnimationController ticker;
  final double hazeHeight, hazeFade;

  /// How far the snow has drifted with the windows' pan, now: the nearest
  /// flecks twice as far as the furthest.
  final Offset Function() drift;

  @override
  State<_Snowfall> createState() => _SnowfallState();
}

class _SnowfallState extends State<_Snowfall> {
  final _flecks = List.generate(140, (_) => _Fleck(_rnd));
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
          drift: widget.drift,
        ),
      ),
    );
  }
}

/// Draws every fleck from one sprite sheet of ready-blurred dots, so the snow
/// looks as if seen through frosted glass without blurring the screen.
class _SnowfallPainter extends CustomPainter {
  _SnowfallPainter(this.flecks, this.ticker, {required this.dpr, required this.hazeHeight, required this.hazeFade, required this.drift}) : super(repaint: ticker);
  final List<_Fleck> flecks;
  final AnimationController ticker;
  final double dpr, hazeHeight, hazeFade;
  final Offset Function() drift;

  /// Fleck radii in dp, far to near.
  static const _radii = [.775, 1.125, 1.3, 1.45];
  static const _sizes = 4;
  static double _radius(int k) => _radii[k];

  /// Blur in dp: through the glass, and behind the buttons.
  static const _sigmas = [1.25, 2.85];

  /// One sprite's square, wide enough for the largest, blurriest dot.
  static const _cell = 2 * (2.0 + 3 * 2.85);

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
    final shift = drift();
    final tall = size.height + 2 * margin, wide = size.width + 2 * margin;
    for (final f in flecks) {
      // Wrapping round as it drifts, so the screen stays full.
      final near = 1 + f.depth;
      final ph = (t / f.fall + f.phase + shift.dy * near / tall) % 1;
      final y = -margin + tall * ph;
      final x = -margin + (margin + f.x * size.width + shift.dx * near) % wide + (5 + 7 * f.depth) * math.sin(t / f.sway * 2 * math.pi + f.swayPhase);
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

/// Clips to [outline] in the box clipped, so taps outside it fall through.
class _OutlineClipper extends CustomClipper<Path> {
  const _OutlineClipper(this.outline);
  final Path Function(Size box) outline;

  @override
  Path getClip(Size size) => outline(size);

  @override
  bool shouldReclip(_OutlineClipper oldClipper) => oldClipper.outline != outline;
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
    this.onView,
  });
  final GameState game;
  final int pane;

  /// A flake opened on its own screen, by the magnifier on its tile.
  final ValueChanged<SavedFlake>? onView;

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
                      _PickTile(
                        flake: f,
                        selected: identical(f, current),
                        onTap: identical(f, current) || !g.isHung(f) ? () => onPick(f) : null,
                        onView: widget.onView == null ? null : () => widget.onView!(f),
                      ),
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
/// already hangs elsewhere): grey, marked "on the window". A magnifier in
/// the corner opens the flake on its own screen ([onView]).
class _PickTile extends StatelessWidget {
  const _PickTile({this.flake, required this.selected, this.onTap, this.onView});
  final SavedFlake? flake;
  final bool selected;
  final VoidCallback? onTap, onView;

  /// The magnifier's size across, as tall as the badge beside it; and the
  /// room round it a finger can still hit.
  static const _lens = 24.0, _lensSlop = 8.0;

  /// How far in from the tile's edges the magnifier and the badge sit.
  static const _inset = 8.0;

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
              // Already on another pane: said so in the corner (the other
              // one, with the magnifier there, as tall as it and level with it).
              if (onTap == null)
                Positioned(
                  left: onView != null && f != null ? _inset : null,
                  right: onView != null && f != null ? null : _inset,
                  bottom: _inset,
                  child: Container(
                    height: _lens,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: C.night800, borderRadius: BorderRadius.circular(R.s)),
                    child: Text(tr('on_window'), style: display(13, color: Colors.white, height: 1)),
                  ),
                ),
              if (onView case final view? when f != null)
                Positioned(
                  right: _inset - _lensSlop,
                  bottom: _inset - _lensSlop,
                  child: Semantics(
                    button: true,
                    label: tr('view_flake'),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: view,
                      // A finger's worth round it, the circle itself kept small.
                      child: Padding(
                        padding: const EdgeInsets.all(_lensSlop),
                        child: Container(
                          width: _lens,
                          height: _lens,
                          decoration: const BoxDecoration(color: C.night800, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.search, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
