import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../snowflake/cut_board.dart';
import '../snowflake/detach.dart';
import '../snowflake/geometry.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';

/// Height of the tool row laid over the foot of the board (a small round
/// button, as in the stencil list, and its lip, plus the gap below): all the
/// board keeps clear under the wedge. The stencil list (left) and the cut
/// button (right) rise higher, but beside the wedge's narrow foot.
const _toolsH = 44 + 4 + 12.0;

/// Where the board starts: just below the home button (row padding 12, the
/// button 64 + lip 6, and a 12 gap), so a cut can start among the fold and
/// cut counters, which let touches through to it (all but the fold toggle).
const _boardTop = 12 + 70 + 12.0;

/// Foot of the fold toggle under the home button: the folds mark 18 + 4 and
/// the 52-tall toggle below [_boardTop].
const _countersFoot = _boardTop + 22 + 52;

/// The event panel: square, 38% of a screen [width] dp wide (156 on a
/// 411-wide phone), 32 px in from the right of a 1125-px-wide mock-up.
double _eventSide(double width) => width * .38;
double _eventRight(double width) => width * 32 / 1125;

/// Room kept above the wedge on the board: the rest of the top row (to the
/// foot of the event panel, [_eventSide] tall, or of the counters, whichever
/// is lower) and 12 clear.
double _topRowFoot(double width) => math.max(12 + _eventSide(width), _countersFoot) - _boardTop + 12;

/// Room round the small 44 buttons in the stencil list.
const _stencilsPad = 2.0;

/// The open stencil list: two columns of 44 cells side by side, five and a
/// half rows in view with 2 between, padded (the half row shows it scrolls).
const _stencilsListW = 2 * 44 + 2 * _stencilsPad;
const _stencilsListH = 5.5 * 44 + 5 * 2 + 2 * _stencilsPad;

/// Gap between the tools in a row [width] wide: 20, or less (down to 6) when
/// the stencil list beside them needs the room. The stencils button, grown
/// ×1.12 when on, keeps 6 clear of the list, which keeps 8 from the edge.
double _toolsGap(double width) => (width / 2 - 66 - (8 + _stencilsListW + 6 + 3)).clamp(6.0, 20.0);

/// Stencil shapes, picked from the list the stencil button opens.
const _stencils = [
  ('star', LucideIcons.star, 'Звезда'),
  ('circle', LucideIcons.circle, 'Круг'),
  ('triangle', LucideIcons.triangle, 'Треугольник'),
  ('square', LucideIcons.square, 'Квадрат'),
  ('heart', LucideIcons.heart, 'Сердце'),
  ('drop', LucideIcons.droplet, 'Капля'),
  ('diamond', LucideIcons.diamond, 'Ромб'),
  ('hexagon', LucideIcons.hexagon, 'Шестиугольник'),
  // Halloween; stand-in icons for now.
  ('bone', LucideIcons.bone, 'Кость'),
  ('hat', LucideIcons.wandSparkles, 'Шляпа ведьмы'),
  ('bat', LucideIcons.moon, 'Летучая мышь'),
  ('jack', LucideIcons.smile, 'Светильник Джека'),
];

/// The Halloween stencils, set apart in the list.
const _halloween = {'bone', 'hat', 'bat', 'jack'};

/// Cuts on the board and the pieces each one dropped, in step, on paper
/// folded [folds] times.
typedef CutState = ({List<Cut> cuts, List<List<Cut>> drops, int folds});

/// The flake being cut, kept outside the screen so coming back from the
/// reveal finds it as it was.
class CutSession {
  List<Cut> cuts = const [];

  /// Pieces that fell off after each cut, in step with [cuts].
  List<List<Cut>> drops = const [];
  List<Cut> fallen = const [];

  /// How many times the paper is folded: 6 or 4 (a six- or eight-pointed flake).
  int folds = 6;

  /// Earlier states, for undo, and undone ones, for redo. A cut or a reset is
  /// one step, and so is refolding paper that has cuts; a new step forgets
  /// what was undone (no branches). Paper and tool choices aren't steps. An
  /// event starts with none, so undo never reaches back past its start.
  final past = <CutState>[], future = <CutState>[];
  String tool = 'free';

  /// The stencil last picked, shown on the stencil button.
  String stencil = 'star';
  Paper paper = const Paper();

  /// The event being played, if any: kept here, not on the screen, so it
  /// outlasts leaving the screen and coming back.
  _EventRun? _event;

  /// Helps left in the event: each shows its flake's cuts for a moment.
  int _helps = 0;
}

/// Helps an event starts with, and how long one shows the cuts.
const _eventHelps = 2;
const _helpLength = Duration(seconds: 3);

/// An event under way: its [flake], and the paper as it was before (cuts,
/// folds, look and undo history), which leaving the event brings back.
typedef _EventRun = ({_EventFlake flake, CutState before, Paper paper, List<CutState> past, List<CutState> future});

class CutScreen extends StatefulWidget {
  const CutScreen({super.key, required this.game, required this.session, required this.onHome, required this.onUnfold});
  final GameState game;
  final CutSession session;
  final VoidCallback onHome;

  /// [shape] is the player's cuts plus the pieces that fell off.
  final void Function(List<Cut> shape, int folds, Paper paper) onUnfold;

  @override
  State<CutScreen> createState() => _CutScreenState();
}

class _CutScreenState extends State<CutScreen> with TickerProviderStateMixin {
  CutSession get _s => widget.session;
  List<Cut> get _cuts => _s.cuts;
  List<List<Cut>> get _drops => _s.drops;
  List<Cut> get _fallen => _s.fallen;
  int get _folds => _s.folds;
  String get _tool => _s.tool;
  set _tool(String t) => _s.tool = t;

  /// The list of stencils is open above the toolbar.
  bool _stencilsOpen = false;

  /// Bumped by the scissors button to cut the stencil out.
  int _stencilCut = 0;

  /// The event shown in the top-right panel: the seasonal one at first.
  int _event = _events.indexWhere((e) => e.id == _seasonalEvent);

  /// An event is on: its flake was picked from the panel, which gives way to
  /// a button out of the event.
  bool get _eventOn => _s._event != null;

  /// The event's intro: its flake, big, folds back into a wedge that settles
  /// on the paper; its cuts fade, then the wedge itself. No input meanwhile.
  AnimationController? _intro;
  bool get _introRunning => _intro?.isAnimating ?? false;

  /// The intro's beats, in seconds from its start: the flake fades in, folds
  /// (for [_foldSecs], longer where flaps fold one after the other), settles
  /// on the paper, shows its cuts a while, loses them, and fades away.
  late double _foldSecs;
  double get _foldedAt => .4 + _foldSecs;
  double get _settledAt => _foldedAt + 1;
  double get _cutsFadeAt => _settledAt + 1.4;
  double get _cutsGoneAt => _cutsFadeAt + 1;
  double get _paperInAt => _cutsGoneAt + .4;
  double get _introSecs => _paperInAt + .4;

  /// Seconds into the intro.
  double get _introAt => (_intro?.value ?? 1) * _introSecs;

  /// How far the board's paper has faded in, once the event's wedge has lost
  /// its cuts: over that wedge, still solid, so nothing shows through midway
  /// (fading both at once let the table show through, a flash on dark paper).
  double get _paperShown => _intro == null ? 1 : ((_introAt - _cutsGoneAt) / (_paperInAt - _cutsGoneAt)).clamp(0.0, 1.0);

  /// How far the board's fold edges have faded in: over the wedge's landing.
  double get _edgesShown => _intro == null ? 1 : ((_introAt - _foldedAt) / (_settledAt - _foldedAt)).clamp(0.0, 1.0);

  /// Bumped to give the board a fresh start (unzoomed) when an event begins.
  int _boardKey = 0;

  void _startEvent(_EventFlake f) {
    _s._event = (flake: f, before: _state, paper: _paper, past: [..._s.past], future: [..._s.future]);
    _s._helps = _eventHelps;
    _s.past.clear();
    _s.future.clear();
    _stencilsOpen = false;
    _tool = 'free';
    _paper = Paper(color: f.color, pattern: f.pattern);
    _boardKey++;
    // Fresh paper, folded like the event's flake.
    _show((cuts: const [], drops: const [], folds: f.folds));
    _intro?.dispose();
    _foldSecs = 2 * unfoldSpan(f.folds);
    _intro = AnimationController(vsync: this, duration: Duration(milliseconds: (_introSecs * 1000).round()))
      ..addListener(_onTick)
      ..addStatusListener((_) => setState(() {}))
      ..forward();
  }

  /// Bumped on every frame of the intro or a help: only the board redraws.
  final _frame = ValueNotifier(0);
  bool _wasArriving = false;

  void _onTick() {
    _frame.value++;
    // The rest of the screen only when the flake has come in (the skip tap
    // goes).
    if (_introArriving != _wasArriving) setState(() => _wasArriving = _introArriving);
  }

  /// Whether the intro is still bringing its flake in: until its wedge has
  /// settled on the paper.
  bool get _introArriving => _introRunning && _introAt < _settledAt;

  /// A tap while the flake comes in skips to the moment its wedge lies on
  /// the paper; the rest plays on from there.
  void _skipIntro() {
    final i = _intro;
    if (i == null || !_introArriving) return;
    i.forward(from: _settledAt / _introSecs);
  }

  /// Leaves the event: the paper goes back to how it was before it.
  void _endEvent() {
    final e = _s._event;
    if (e == null) return;
    _s._event = null;
    _intro?.dispose();
    _intro = null;
    _help?.dispose();
    _help = null;
    _paper = e.paper;
    _s.past
      ..clear()
      ..addAll(e.past);
    _s.future
      ..clear()
      ..addAll(e.future);
    _boardKey++;
    _show(e.before);
  }

  @override
  void dispose() {
    _intro?.dispose();
    _help?.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// A help showing: the event flake's cuts fade in over the paper, stay, and
  /// fade out again.
  AnimationController? _help;
  bool get _helping => _help?.isAnimating ?? false;
  double get _hintOpacity {
    final h = _help;
    if (h == null || !h.isAnimating) return 0;
    final end = _helpLength.inMilliseconds / 1000, t = h.value * end;
    return math.min(t / .3, (end - t) / .4).clamp(0.0, 1.0);
  }

  void _useHelp() {
    if (_s._helps == 0 || _helping || _introRunning) return;
    setState(() => _s._helps--);
    _help?.dispose();
    _help = AnimationController(vsync: this, duration: _helpLength)
      ..addListener(_onTick)
      ..addStatusListener((_) => setState(() {}))
      ..forward();
  }

  /// The intro's layer over the board, [w] wide with the screen's middle
  /// [midY] down it: the event's flake, at the reveal's size, folding and
  /// settling onto the wedge whose apex is at [apex], [radius] long.
  Widget _introLayer(double w, double midY, Offset apex, double radius) {
    final f = _s._event!.flake;
    final t = _introAt;
    double phase(double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);
    final appear = Curves.easeOut.transform(phase(0, .4));
    final fold = 1 - phase(.4, _foldedAt);
    final settle = Curves.easeInOutCubic.transform(phase(_foldedAt, _settledAt));
    // Gone only under the board's paper, which hides all but its padded rim.
    final cutsGone = phase(_cutsFadeAt, _cutsGoneAt), gone = phase(_paperInAt, _introSecs);
    const size = 320.0;
    // The flake's wedge reaches 0.48 of its box from the middle.
    final scale = (1 - settle) * (.9 + .1 * appear) + settle * radius / (size * .48);
    final at = Offset.lerp(Offset(w / 2, midY), apex, settle)!;
    Widget view(List<Cut>? cuts) => SnowflakeView(cuts: cuts, preset: f.preset, folds: f.folds, color: f.color, pattern: f.pattern, unfold: fold, size: size);
    return Stack(children: [
      Positioned(
        left: at.dx - size / 2,
        top: at.dy - size / 2,
        width: size,
        height: size,
        child: Opacity(
          opacity: appear * (1 - gone),
          child: Transform.scale(
            scale: scale,
            child: Stack(children: [
              view(null),
              // Plain paper fading in over the cuts, filling them in. (Under them it
              // would fill every hole at once, the cut paper being opaque elsewhere.)
              if (cutsGone > 0) Opacity(opacity: cutsGone, child: view(const [])),
            ]),
          ),
        ),
      ),
    ]);
  }

  void _pickStencil(String id) => setState(() {
    if (_tool == id) {
      // The stencil already out: the list has done its job and closes.
      _stencilsOpen = false;
    } else {
      _tool = id;
      _s.stencil = id;
    }
  });
  Paper get _paper => _s.paper;

  set _paper(Paper p) => _s.paper = p;

  CutState get _state => (cuts: _cuts, drops: _drops, folds: _folds);

  void _show(CutState st) => setState(() {
    _s
      ..cuts = st.cuts
      ..drops = st.drops
      ..fallen = [for (final d in st.drops) ...d]
      ..folds = st.folds;
  });

  /// A new step: remembered for undo, and whatever was undone is dropped.
  void _step(CutState next) {
    _s.past.add(_state);
    _s.future.clear();
    _show(next);
  }

  void _addCut(Cut c) {
    if (widget.game.vibration) HapticFeedback.lightImpact();
    final cuts = [..._cuts, c];
    _step((cuts: cuts, drops: [..._drops, detachedPieces(cuts, _fallen, _folds)], folds: _folds));
  }

  void _reset() => _step((cuts: const [], drops: const [], folds: _folds));

  /// Cuts made for one wedge don't fit another, so refolding starts the paper
  /// afresh, as an undoable step when there was something to lose.
  void _refold(int folds) {
    if (folds == _folds) return;
    final blank = (cuts: const <Cut>[], drops: const <List<Cut>>[], folds: folds);
    _cuts.isEmpty ? _show(blank) : _step(blank);
  }

  void _undo() {
    _s.future.add(_state);
    _show(_s.past.removeLast());
  }

  void _redo() {
    _s.past.add(_state);
    _show(_s.future.removeLast());
  }

  /// The paper dialog is up; the palette tool shows as on meanwhile.
  bool _paperOpen = false;

  void _openPaper() {
    setState(() {
      _stencilsOpen = false;
      _paperOpen = true;
    });
    showDsDialog(
      context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void set(Paper p) {
              setState(() => _paper = p);
              setLocal(() {});
            }

            return DsDialog(
              title: 'Бумага',
              onClose: () => Navigator.pop(ctx),
              actions: [Btn('Готово', icon: LucideIcons.check, block: true, onTap: () => Navigator.pop(ctx))],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  // Solid drop shadow like the colour swatches', so white paper reads on the white card.
                  Stack(
                    children: [
                      Transform.translate(
                        offset: const Offset(0, 3),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(C.snow300, BlendMode.srcIn),
                          child: SnowflakeView(preset: 'classic', size: 170, color: _paper.color, pattern: _paper.pattern),
                        ),
                      ),
                      SnowflakeView(preset: 'classic', size: 170, color: _paper.color, pattern: _paper.pattern),
                    ],
                  ),
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
                              selected: p.color == _paper.color,
                              child: GestureDetector(
                                onTap: () => set(_paper.copyWith(color: p.color)),
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
                                        if (p.color == _paper.color) const BoxShadow(color: C.berry500, spreadRadius: 4),
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
                                    final (id, name) = paperPatterns[row * 4 + col];
                                    return Semantics(
                                      button: true,
                                      label: name,
                                      selected: id == _paper.pattern,
                                      child: GestureDetector(
                                        onTap: () => set(_paper.copyWith(pattern: id)),
                                        child: Column(
                                          children: [
                                            _PaperSwatch(color: _paper.color, pattern: id, selected: id == _paper.pattern),
                                            const SizedBox(height: 8),
                                            FittedBox(child: Text(name, style: display(13, color: C.night800))),
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
          },
        );
      },
    ).then((_) {
      if (mounted) setState(() => _paperOpen = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: C.surfaceTable,
      child: Column(
        children: [
          // Night strip behind the status bar.
          Container(height: pad.top, color: C.night800),
          // The board runs up under the top row to just below the home button,
          // so a cut can start that high; the row's own controls (and the
          // event panel) sit over it and keep their touches.
          Expanded(
            child: Stack(
              children: [
                // No input while an event's intro plays, but for the way out of it.
                Positioned.fill(
                  top: _boardTop,
                  child: ValueListenableBuilder(
                    valueListenable: _frame,
                    builder: (_, _, _) => AbsorbPointer(
                      absorbing: _introRunning,
                      child: LayoutBuilder(
                        builder: (_, c) {
                          // The wedge sits midway between the top row and the tool row, with
                          // at least 12 clear above and below, as big as that room allows, short
                          // of the screen's width for the wider (four-fold) wedge less 16 a side:
                          // the same size whichever way the paper is folded.
                          final topRowFoot = _topRowFoot(c.maxWidth);
                          final widest = (c.maxWidth - 32) / (2 * math.sin(wedgeHalfAngle(4)) * 0.94);
                          // 95% of that, for a little air round it.
                          final h = .95 * math.min(widest, (c.maxHeight - topRowFoot - _toolsH - 24) / 0.94);
                          final apexY = (topRowFoot + c.maxHeight - _toolsH) / 2 + 0.47 * h;
                          return SizedBox.fromSize(
                            size: c.biggest,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Under the board, so the board's fold edges show over the event's
                                // wedge as it lands, before the board's own paper comes back.
                                if (_intro != null && _intro!.value < 1)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: _introLayer(c.maxWidth, (c.maxHeight + _boardTop) / 2 - _boardTop, Offset(c.maxWidth / 2, apexY), h * 0.94),
                                    ),
                                  ),
                                Positioned.fill(
                                  // Only its fold edges under the intro, fading in as the event's wedge
                                  // lands; its paper waits until that wedge has lost its cuts (it would
                                  // show white through them).
                                  child: Opacity(
                                    opacity: _edgesShown,
                                    child: CutBoard(
                                      key: ValueKey(_boardKey),
                                      paperOpacity: _paperShown,
                                      hintCuts: _eventOn ? snowflakePresets[_s._event!.flake.preset] ?? const [] : const [],
                                      hintOpacity: _hintOpacity,
                                      height: h,
                                      topInset: topRowFoot,
                                      bottomInset: _toolsH,
                                      // Cuts may start well off the paper, so a slit can run in from outside.
                                      touchMargin: 120,
                                      folds: _folds,
                                      cuts: _cuts,
                                      fallen: _fallen,
                                      tool: _tool,
                                      stencilCut: _stencilCut,
                                      color: _paper.color,
                                      pattern: _paper.pattern,
                                      onCut: _addCut,
                                      // Until the first touch on the board since launch, a phantom
                                      // stroke shows how to cut.
                                      demo: !widget.game.hintDismissed && _tool == 'free' && !_eventOn && !_paperOpen,
                                    // Still under the paper dialog: no shimmer ticking unseen.
                                    shimmer: !_paperOpen,
                                      onTouch: widget.game.dismissHint,
                                    ),
                                  ),
                                ),
                                // With a stencil out: the scissors that cut it, at the right.
                                if (_tool != 'free' && !_paperOpen)
                                  Positioned(
                                    right: 16,
                                    bottom: _toolsH - 8,
                                    child: RoundBtn(LucideIcons.scissors, label: 'Вырезать', variant: Variant.soft, size: BtnSize.l, onTap: () => setState(() => _stencilCut++)),
                                  ),
                                // The stencil list, when open: a two-column grid left of the
                                // stencils button, level with the tools.
                                if (_tool != 'free' && !_paperOpen && _stencilsOpen)
                                  Positioned(
                                    // Just left of the stencils button (the tool row is centred), but
                                    // never off the screen's edge.
                                    left: math.max(8, c.maxWidth / 2 - 66 - _toolsGap(c.maxWidth) - 9 - _stencilsListW),
                                    bottom: 12,
                                    width: _stencilsListW,
                                    height: _stencilsListH,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: C.paper,
                                        borderRadius: BorderRadius.circular(26),
                                        boxShadow: const [BoxShadow(color: C.snow300, offset: Offset(0, 4))],
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      // Two to a row; the Halloween ones together on an orange ground.
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(_stencilsPad),
                                        child: Column(children: [
                                          for (final (i, group) in [
                                            [for (final t in _stencils) if (!_halloween.contains(t.$1)) t],
                                            [for (final t in _stencils) if (_halloween.contains(t.$1)) t],
                                          ].indexed)
                                            if (group.isNotEmpty)
                                              Container(
                                                margin: EdgeInsets.only(top: i > 0 ? 2 : 0),
                                                decoration: i > 0 ? BoxDecoration(color: const Color(0xFFFF7A1A), borderRadius: BorderRadius.circular(22)) : null,
                                                child: Column(children: [
                                                  for (var r = 0; r * 2 < group.length; r++)
                                                    Padding(
                                                      padding: EdgeInsets.only(top: r > 0 ? 2 : 0),
                                                      child: Row(children: [
                                                        for (final (id, icon, label) in group.skip(r * 2).take(2))
                                                          SizedBox.square(
                                                            dimension: 44,
                                                            // Just the 44 circle in the layout: the button's
                                                            // lip room (flat here anyway) hangs below it.
                                                            child: OverflowBox(
                                                              alignment: Alignment.topCenter,
                                                              maxHeight: 48,
                                                              child: RoundBtn(
                                                                icon,
                                                                label: label,
                                                                size: BtnSize.s,
                                                                // Flat and full size even when picked: the colour
                                                                // alone marks it, inside its cell.
                                                                variant: _tool == id
                                                                    ? Variant.secondary
                                                                    : i > 0
                                                                        ? Variant.clear
                                                                        : Variant.light,
                                                                flat: true,
                                                                onTap: () => _pickStencil(id),
                                                              ),
                                                            ),
                                                          ),
                                                      ]),
                                                    ),
                                                ]),
                                              ),
                                        ]),
                                      ),
                                    ),
                                  ),
                                // Tools float over the board's foot, so nothing hides the paper
                                // between them and the action row.
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 12,
                                  child: Builder(
                                    builder: (_) {
                                      // The paper dialog takes over: neither cutting tool shows as on meanwhile.
                                      final stencilOn = _tool != 'free' && !_paperOpen;
                                      final scissorsOn = _tool == 'free' && !_paperOpen;
                                      final (_, stencilIcon, _) = _stencils.firstWhere((t) => t.$1 == _s.stencil);
                                      // Centred: stencils, scissors in the middle, paper.
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Shows the last stencil; opens the list of all of them.
                                          RoundBtn(
                                            stencilIcon,
                                            label: 'Трафареты',
                                            size: BtnSize.s,
                                            variant: stencilOn || _stencilsOpen ? Variant.secondary : Variant.light,
                                            active: stencilOn,
                                            // From the scissors it takes out the last stencil (a star at
                                            // first) along with the list; after that it only opens and
                                            // closes the list.
                                            onTap: () => setState(() {
                                              if (_tool != 'free') {
                                                _stencilsOpen = !_stencilsOpen;
                                              } else {
                                                _tool = _s.stencil;
                                                _stencilsOpen = true;
                                              }
                                            }),
                                          ),
                                          SizedBox(width: _toolsGap(c.maxWidth)),
                                          RoundBtn(
                                            LucideIcons.scissors,
                                            label: 'Ножницы',
                                            size: BtnSize.s,
                                            variant: scissorsOn ? Variant.secondary : Variant.light,
                                            active: scissorsOn,
                                            onTap: () => setState(() {
                                              _tool = 'free';
                                              _stencilsOpen = false;
                                            }),
                                          ),
                                          SizedBox(width: _toolsGap(c.maxWidth)),
                                          RoundBtn(
                                            LucideIcons.palette,
                                            label: 'Бумага',
                                            size: BtnSize.s,
                                            variant: _paperOpen ? Variant.secondary : Variant.light,
                                            active: _paperOpen,
                                            onTap: _openPaper,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Over the board while the event's flake comes in: a tap skips ahead.
                if (_introArriving) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _skipIntro)),
                Padding(
                  padding: EdgeInsets.fromLTRB(screenPad, 12, _eventRight(MediaQuery.sizeOf(context).width), 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Home, and below it this flake's folds and cut count.
                      Expanded(
                        child: AbsorbPointer(
                          absorbing: _introRunning,
                          // Only as tall as it needs: below it the board keeps its touches.
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Btn('Домой', icon: LucideIcons.house, variant: Variant.orange, size: BtnSize.l, fontSize: 26, padX: 12, block: true, onTap: widget.onHome),
                              const SizedBox(height: 12),
                              // Folds and cuts of this flake, each under its mark, centred
                              // under the home button.
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Column(
                                    children: [
                                      // Lets touches through to the board beneath.
                                      const IgnorePointer(child: Icon(_foldsIcon, size: 18, color: C.snow700)),
                                      const SizedBox(height: 4),
                                      Segmented<int>(options: const [SegOption(4, '4'), SegOption(6, '6')], value: _folds, onChanged: _refold, fontSize: 14),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  // Lets touches through to the board. Fixed width, so the
                                  // scissors stay put however many digits the count has.
                                  IgnorePointer(
                                    child: SizedBox(
                                      width: 40,
                                      child: Column(
                                        children: [
                                          const Icon(LucideIcons.scissors, size: 18, color: C.snow700),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            height: 52,
                                            child: Center(
                                              child: Text(
                                                '${_cuts.length}',
                                                style: display(15, weight: FontWeight.w700, color: C.night800),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // During an event its panel gives way, in the same room, to the way
                      // out of it and, under that, a help with how many are left. The panel
                      // stays alive meanwhile, so it picks up where it was.
                      if (_eventOn)
                        SizedBox(
                          width: _eventSide(MediaQuery.sizeOf(context).width),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Btn('Назад', icon: LucideIcons.arrowLeft, variant: Variant.light, size: BtnSize.l, padX: 8, block: true, onTap: _endEvent),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  RoundBtn.text(
                                    '?',
                                    label: 'Подсказка',
                                    disabled: _s._helps == 0 || _helping || _introRunning,
                                    onTap: _useHelp,
                                  ),
                                  const SizedBox(width: 10),
                                  Text('×${_s._helps}', style: display(24, color: C.night800)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      Visibility(
                        visible: !_eventOn,
                        maintainState: true,
                        child: _EventPanel(
                          paused: _eventOn,
                          side: _eventSide(MediaQuery.sizeOf(context).width),
                          index: _event,
                          onStep: (d) => setState(() => _event = (_event + d) % _events.length),
                          onPick: _startEvent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AbsorbPointer(
            absorbing: _introRunning,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, pad.bottom + 14),
              child: Row(
                children: [
                  RoundBtn(LucideIcons.rotateCcw, label: 'Начать заново', size: BtnSize.s, disabled: _cuts.isEmpty, onTap: _reset),
                  const SizedBox(width: 10),
                  RoundBtn(LucideIcons.undo2, label: 'Отменить', size: BtnSize.s, disabled: _s.past.isEmpty, onTap: _undo),
                  const SizedBox(width: 10),
                  RoundBtn(LucideIcons.redo2, label: 'Вернуть', size: BtnSize.s, disabled: _s.future.isEmpty, onTap: _redo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Btn(
                      'Раскрыть',
                      // No icon: with three round buttons beside it, the word needs the room.
                      size: BtnSize.l,
                      block: true,
                      disabled: _cuts.isEmpty,
                      onTap: () => widget.onUnfold([..._cuts, ..._fallen], _folds, _paper),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The seasonal event's [id] in [_events]: the panel opens on it.
const _seasonalEvent = 'halloween';

/// A flake an event shows, and sets out to be made again.
typedef _EventFlake = ({String preset, int folds, Color color, String pattern});

/// Events on offer, one at a time in the event panel, each showing its
/// [flakes] in turn over its [title]: on the panel's night blue, or on its
/// [image] across the whole panel. A [loud] title is heavier, purple outlined
/// in white. Tapping the panel starts the event with the flake it shows.
const _events = [
  (
    id: 'repeat',
    title: 'Повторить снежинку',
    image: null,
    loud: false,
    flakes: [
      (preset: 'fern', folds: 6, color: Color(0xFFFFFFFF), pattern: 'plain'),
      (preset: 'starburst', folds: 6, color: Color(0xFFC4ECFF), pattern: 'plain'),
      (preset: 'leafy', folds: 6, color: Color(0xFFFFE08A), pattern: 'plain'),
      (preset: 'spiky', folds: 6, color: Color(0xFFDCD2FF), pattern: 'plain'),
      (preset: 'forked', folds: 6, color: Color(0xFFBFF0DC), pattern: 'plain'),
      (preset: 'chevrons', folds: 6, color: Color(0xFFFFC7D0), pattern: 'plain'),
    ],
  ),
  (
    id: 'halloween',
    title: 'Хэллоуинская снежинка',
    image: 'assets/Halloween_Event_Ico.png',
    loud: true,
    flakes: [
      (preset: 'pumpkins', folds: 6, color: Color(0xFFFF9A3C), pattern: 'plain'),
      (preset: 'web', folds: 6, color: Color(0xFF1E1F26), pattern: 'plain'),
      (preset: 'spiders', folds: 6, color: Color(0xFF4A1A6B), pattern: 'plain'),
      (preset: 'bats', folds: 6, color: Color(0xFF8A5CD6), pattern: 'plain'),
      (preset: 'ghosts', folds: 6, color: Color(0xFFFFFFFF), pattern: 'plain'),
      (preset: 'hats', folds: 6, color: Color(0xFF1E6B4F), pattern: 'plain'),
      (preset: 'cats', folds: 6, color: Color(0xFF1E2F6B), pattern: 'plain'),
      (preset: 'zombies', folds: 6, color: Color(0xFFBFF0DC), pattern: 'plain'),
    ],
  ),
];

/// Mark for the number of folds, wherever it is shown.
const _foldsIcon = LucideIcons.layers2;

/// One event at a time, stepped through with the arrows; its flakes take
/// turns every [_flakeEvery], the next rising in from below.
class _EventPanel extends StatefulWidget {
  const _EventPanel({required this.side, required this.index, required this.onStep, required this.onPick, this.paused = false});

  /// Hidden behind an event: its flakes stop taking turns meanwhile.
  final bool paused;

  /// The panel is square, this many dp across.
  final double side;
  final int index;
  final ValueChanged<int> onStep;

  /// A tap on the panel starts the event with the flake it shows just then.
  final ValueChanged<_EventFlake> onPick;

  @override
  State<_EventPanel> createState() => _EventPanelState();
}

const _flakeEvery = Duration(seconds: 5);

class _EventPanelState extends State<_EventPanel> {
  int _flake = 0;
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    _timer = widget.paused ? null : _tick();
  }

  Timer _tick() => Timer.periodic(_flakeEvery, (_) => setState(() {
    _flake++;
    _rise = 1;
  }));

  /// Which way the last turn went: 1 the next flake rising in from below, −1
  /// the one before dropping in from above.
  int _rise = 1;

  /// A swipe up shows the next flake, down the one before, and gives it a
  /// full turn before the next.
  void _swipe(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < 100) return;
    setState(() {
      _rise = v < 0 ? 1 : -1;
      _flake += _rise;
    });
    _startTimer();
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    // The title is fitted to the display face; measured again once it has
    // loaded (asking for both weights here starts them loading).
    GoogleFonts.pendingFonts([_titleStyle(true), _titleStyle(false)]).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_EventPanel old) {
    super.didUpdateWidget(old);
    // Stepping to an event opens on one of its flakes at random, given its full turn.
    if (old.index != widget.index) {
      _flake = math.Random().nextInt(_events[widget.index].flakes.length);
      _startTimer();
    } else if (old.paused != widget.paused) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.side;
    final e = _events[widget.index];
    final f = e.flakes[_flake % e.flakes.length];
    Widget arrow(int step) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onStep(step),
      child: SizedBox(width: 26, height: 44, child: CustomPaint(painter: _ChevronPainter(step))),
    );
    // A switcher of its own per event: stepping to another event swaps the
    // flake at once, only the timed turns rise in from below.
    Widget flake(double size) => AnimatedSwitcher(
      key: ValueKey(widget.index),
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // The next flake rises in from below as the last one rises out (the other
      // way after a swipe down).
      transitionBuilder: (child, anim) {
        final incoming = child.key == ValueKey('${widget.index}/$_flake');
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: Offset(0, (incoming ? .6 : -.6) * _rise), end: Offset.zero).animate(anim),
            child: child,
          ),
        );
      },
      // Tilted 10° clockwise, only here: a playful touch for events. Turned as
      // a whole, so the flake keeps its baked image.
      child: Transform.rotate(
        key: ValueKey('${widget.index}/$_flake'),
        angle: 10 * math.pi / 180,
        child: SnowflakeView(preset: f.preset, folds: f.folds, color: f.color, pattern: f.pattern, size: size),
      ),
    );
    final image = e.image;
    return Semantics(
      label: e.title,
      button: true,
      child: GestureDetector(
        onTap: () => widget.onPick(f),
        onVerticalDragEnd: _swipe,
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(color: C.night800, borderRadius: BorderRadius.circular(image != null ? 8 : 28)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (image != null) Positioned.fill(child: Image.asset(image, fit: BoxFit.cover)),
              // The title runs under the arrows, so it gets nearly the whole width.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 60% of the panel, leaving room for a two-line title.
                    flake(side * .6),
                    const SizedBox(height: 6),
                    // Set a little lower than its place in the column, the flake left where it is.
                    Transform.translate(
                      offset: const Offset(0, 4),
                      child: LayoutBuilder(
                        builder: (ctx, c) {
                          final style = _titleStyle(e.loud);
                          // Wraps between words as usual, made smaller only if the longest
                          // word would not fit on a line: never broken inside a word.
                          final size = _wordsFit(e.title, style, c.maxWidth, MediaQuery.textScalerOf(ctx));
                          if (!e.loud) {
                            return Text(e.title, textAlign: TextAlign.center, style: style.copyWith(fontSize: size, color: Colors.white));
                          }
                          // Purple on a white outline, the outline drawn first underneath.
                          return Stack(children: [
                            Text(
                              e.title,
                              textAlign: TextAlign.center,
                              // The display face, but painted as a stroke (a style can't carry
                              // both a colour and a foreground paint).
                              style: TextStyle(
                                fontFamily: style.fontFamily,
                                fontSize: size,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 3.5 * size / 17
                                  ..strokeJoin = StrokeJoin.round
                                  ..color = Colors.white,
                              ),
                            ),
                            Text(e.title, textAlign: TextAlign.center, style: style.copyWith(fontSize: size, color: const Color(0xFF7B3FD1))),
                          ]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(left: 0, child: arrow(-1)),
              Positioned(right: 0, child: arrow(1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// An event title's face: heavier and bigger when [loud].
TextStyle _titleStyle(bool loud) => loud ? display(17, weight: FontWeight.w900, height: 1.1) : display(16, height: 1.1);

/// The font size, at most [style]'s, at which every word of [text] fits in
/// [width] (with room for an outline), as the system's text [scaler] will
/// enlarge it. Android scales small text up more than large, so it is found
/// in a few steps rather than by one ratio. Measured in the real face only
/// once it has loaded (see [_EventPanelState.initState]).
double _wordsFit(String text, TextStyle style, double width, TextScaler scaler) {
  double widest(double size) {
    var w = 0.0;
    for (final word in text.split(' ')) {
      final p = TextPainter(text: TextSpan(text: word, style: style.copyWith(fontSize: size)), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
      w = math.max(w, p.width);
      p.dispose();
    }
    return w;
  }

  final room = width - 6;
  var size = style.fontSize!;
  for (var i = 0; i < 8; i++) {
    final w = widest(size);
    if (w <= room) break;
    size *= room / w;
  }
  return size;
}

/// A chevron pointing left (`step` −1) or right (+1), red on a white halo
/// like the cut lines on the board.
class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.step);
  final int step;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final dx = 4.5 * step, dy = 8.0;
    final path = Path()
      ..moveTo(c.dx - dx, c.dy - dy)
      ..lineTo(c.dx + dx, c.dy)
      ..lineTo(c.dx - dx, c.dy + dy);
    Paint line(double w, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawPath(path, line(7, Colors.white));
    canvas.drawPath(path, line(3.5, C.berry600));
  }

  @override
  bool shouldRepaint(_ChevronPainter o) => o.step != step;
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
    final rr = RRect.fromRectAndRadius(Offset.zero & size * dpr, Radius.circular(_radius * dpr));
    canvas.drawRRect(rr, makePaperFill(color, pattern, 100 * dpr));
    final tw = twinkle;
    if (tw != null && pattern == 'sparkle') {
      canvas.clipRRect(rr);
      drawGlints(canvas, rr.outerRect, color, 100 * dpr, tw);
    }
    if (pattern == 'holo') {
      canvas.clipRRect(rr);
      drawHoloSheen(canvas, rr.outerRect, 100 * dpr, time: tw ?? 0);
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
