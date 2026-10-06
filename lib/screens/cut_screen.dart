import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../snowflake/cut_board.dart';
import '../snowflake/detach.dart';
import '../snowflake/geometry.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';

/// Height of the tool row laid over the foot of the board (a small round
/// button, as in the stencil list, and its lip, plus the gap below).
const _toolsH = 44 + 4 + 12.0;

/// Where the board starts, under the top row: just below the fold toggle
/// (row padding 12, the home button 64 + lip 6, a 12 gap, the folds mark
/// 22 + 4, and the 52-tall toggle).
const _boardTop = 12 + 70 + 12 + 26 + 52.0;

/// Room kept above the wedge on the board: the rest of the top row (to the
/// foot of the 176-tall example panel) and 12 clear.
const _toggleFoot = 12 + 176 - _boardTop + 12;

/// Height of the stencil list: just the picked stencil's circle, a small
/// 44 button grown ×1.12 when on (≈ 49.3).
const _stencilsH = 50.0;

/// Room around a 44 button inside the list, so the grown circle fills it.
const _stencilsPad = (_stencilsH - 44) / 2;

/// Top of the stencil list above the tools, from the board's foot. Its row is
/// centred on the 78-tall scissors button beside it, so the list itself sits
/// (78 − 50) / 2 = 14 above the row's foot.
const _stencilsTop = _toolsH - 8 + 14 + _stencilsH;

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
];

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
  /// one step, and so is refolding paper that has cuts; a new step forgets what was undone (no branches). Paper and
  /// tool choices aren't steps.
  final past = <CutState>[], future = <CutState>[];
  String tool = 'free';

  /// The stencil last picked, shown on the stencil button.
  String stencil = 'star';
  Paper paper = const Paper();
}

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

class _CutScreenState extends State<CutScreen> {
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

  /// The example flake shown in the top-right panel.
  int _example = 0;

  void _pickStencil(String id) => setState(() {
    if (_tool == id) {
      // The stencil already out goes back to where it starts.
      _stencilReset++;
    } else {
      _tool = id;
      _s.stencil = id;
    }
  });
  Paper get _paper => _s.paper;

  /// Bumped by tapping the stencil already chosen, to put it back where it starts.
  int _stencilReset = 0;
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
                        offset: const Offset(0, 5),
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.mode(C.snow300, BlendMode.srcIn),
                          child: SnowflakeView(preset: 'classic', size: 170, color: _paper.color, pattern: _paper.pattern, glow: false),
                        ),
                      ),
                      SnowflakeView(preset: 'classic', size: 170, color: _paper.color, pattern: _paper.pattern, glow: false),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Pastels, then bold colours, six to a row.
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
                  Row(
                    children: [
                      for (final (i, (id, name)) in paperPatterns.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Semantics(
                            button: true,
                            label: name,
                            selected: id == _paper.pattern,
                            child: GestureDetector(
                              onTap: () => set(_paper.copyWith(pattern: id)),
                              child: Column(
                                children: [
                                  _PaperSwatch(color: _paper.color, pattern: id, selected: id == _paper.pattern),
                                  const SizedBox(height: 8),
                                  FittedBox(
                                    child: Text(name, style: display(11, color: C.night800)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
          // The board runs up under the top row to just below the fold toggle,
          // so a cut can start that high; the row's own controls (and the
          // example panel) sit over it and keep their touches.
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  top: _boardTop,
                  child: LayoutBuilder(
                    builder: (_, c) {
                      // The wedge sits midway between the fold toggle and the stencil
                      // list, with at least 12 clear above and below.
                      final h = math.min(410.0, (c.maxHeight - _toggleFoot - _stencilsTop - 24) / 0.94);
                      final apexY = (_toggleFoot + c.maxHeight - _stencilsTop) / 2 + 0.47 * h;
                      return SizedBox.fromSize(
                        size: c.biggest,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: CutBoard(
                                height: h,
                                topInset: _toggleFoot,
                                bottomInset: _stencilsTop,
                                // Cuts may start well off the paper, so a slit can run in from outside.
                                touchMargin: 120,
                                folds: _folds,
                                cuts: _cuts,
                                fallen: _fallen,
                                tool: _tool,
                                stencilReset: _stencilReset,
                                stencilCut: _stencilCut,
                                color: _paper.color,
                                pattern: _paper.pattern,
                                onCut: _addCut,
                              ),
                            ),
                            if (!widget.game.hintDismissed)
                              Positioned(
                                // Under the wedge's apex (CutBoard centres an h-high box, apex 8 above its bottom).
                                top: math.min(apexY + 14, c.maxHeight - _toolsH - 84),
                                left: 16,
                                right: 16,
                                child: IgnorePointer(child: Center(child: HintBubble(_tool == 'free' ? 'Обведи пальцем кусочек, чтобы вырезать' : 'Двигай трафарет и жми на ножницы', tailUp: true))),
                              ),
                            // With a stencil out: its list (when open), scrolled
                            // sideways, and the scissors that cut it, at the right.
                            if (_tool != 'free' && !_paperOpen)
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: _toolsH - 8,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: !_stencilsOpen
                                          ? const SizedBox()
                                          : Container(
                                              height: _stencilsH,
                                              decoration: BoxDecoration(
                                                color: C.paper,
                                                borderRadius: BorderRadius.circular(26),
                                                boxShadow: const [BoxShadow(color: C.snow300, offset: Offset(0, 4))],
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: ListView.separated(
                                                scrollDirection: Axis.horizontal,
                                                padding: const EdgeInsets.all(_stencilsPad),
                                                itemCount: _stencils.length,
                                                separatorBuilder: (_, _) => const SizedBox(width: 2),
                                                itemBuilder: (_, i) {
                                                  final (id, icon, label) = _stencils[i];
                                                  // Just the 44 circle in the layout: the button's
                                                  // lip room (flat here anyway) hangs below it.
                                                  return SizedBox.square(
                                                    dimension: 44,
                                                    child: OverflowBox(
                                                      alignment: Alignment.topCenter,
                                                      maxHeight: 48,
                                                      child: RoundBtn(
                                                        icon,
                                                        label: label,
                                                        size: BtnSize.s,
                                                        variant: _tool == id ? Variant.secondary : Variant.light,
                                                        active: _tool == id,
                                                        // Flat even when picked: the colour alone marks it.
                                                        flat: true,
                                                        onTap: () => _pickStencil(id),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 10),
                                    RoundBtn(LucideIcons.scissors, label: 'Вырезать', variant: Variant.soft, size: BtnSize.l, onTap: () => setState(() => _stencilCut++)),
                                  ],
                                ),
                              ),
                            // Tools float over the board's foot, so nothing hides the paper
                            // between them and the action row.
                            Positioned(
                              left: 24,
                              right: 24,
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
                                        // From the scissors it takes out the last stencil (a circle at
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
                                      const SizedBox(width: 20),
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
                                      const SizedBox(width: 20),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(screenPad, 12, screenPad, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Home, and below it this flake's folds and cut count.
                      Expanded(
                        child: Padding(
                          // Flush with the top of the example panel.
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Btn('Домой', icon: LucideIcons.house, variant: Variant.orange, size: BtnSize.l, fontSize: 26, padX: 12, block: true, onTap: widget.onHome),
                              const SizedBox(height: 12),
                              // Folds and cuts of this flake, each under its mark.
                              Row(
                                children: [
                                  Column(
                                    children: [
                                      const Icon(_foldsIcon, size: 22, color: C.snow700),
                                      const SizedBox(height: 4),
                                      Segmented<int>(options: const [SegOption(4, '4'), SegOption(6, '6')], value: _folds, onChanged: _refold),
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
                                          const Icon(LucideIcons.scissors, size: 22, color: C.snow700),
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            height: 52,
                                            child: Center(
                                              child: Text(
                                                '${_cuts.length}',
                                                style: display(18, weight: FontWeight.w700, color: C.night800),
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
                      _ExamplePanel(index: _example, onStep: (d) => setState(() => _example = (_example + d) % _examples.length)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
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
        ],
      ),
    );
  }
}

/// Sample flakes for the example panel: what the presets, folds and papers can make.
const _examples = [
  (preset: 'lace', folds: 6, color: Color(0xFFFFFFFF), pattern: 'plain'),
  (preset: 'star', folds: 6, color: Color(0xFFFFC7D0), pattern: 'dots'),
  (preset: 'classic', folds: 4, color: Color(0xFFC4ECFF), pattern: 'sparkle'),
  (preset: 'lace', folds: 4, color: Color(0xFFFFE08A), pattern: 'stripes'),
  (preset: 'star', folds: 4, color: Color(0xFFBFF0DC), pattern: 'plain'),
  (preset: 'classic', folds: 6, color: Color(0xFFDCD2FF), pattern: 'checks'),
  (preset: 'lace', folds: 6, color: Color(0xFFE0405E), pattern: 'dots'),
  (preset: 'star', folds: 6, color: Color(0xFF3E61B8), pattern: 'sparkle'),
];

/// Mark for the number of folds, wherever it is shown.
const _foldsIcon = LucideIcons.layers2;

/// One example flake at a time, stepped through with the arrows, with how
/// many folds and cuts it took.
class _ExamplePanel extends StatelessWidget {
  const _ExamplePanel({required this.index, required this.onStep});
  final int index;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final e = _examples[index];
    final cuts = snowflakePresets[e.preset]?.length ?? 0;
    Widget arrow(int step) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onStep(step),
      child: SizedBox(width: 36, height: 60, child: CustomPaint(painter: _ChevronPainter(step))),
    );
    // Wider than tall: the arrows get room beside the flake instead of over it.
    return Container(
      width: 204,
      height: 176,
      decoration: BoxDecoration(color: C.night800, borderRadius: BorderRadius.circular(28)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SnowflakeView(preset: e.preset, folds: e.folds, color: e.color, pattern: e.pattern, size: 140, glow: false),
          Positioned(left: 0, child: arrow(-1)),
          Positioned(right: 0, child: arrow(1)),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xCC101A3F), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(_foldsIcon, size: 18, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('${e.folds}', style: display(16, color: Colors.white)),
                  const SizedBox(width: 12),
                  const Icon(LucideIcons.scissors, size: 18, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('$cuts', style: display(16, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chevron pointing left (`step` −1) or right (+1), red on a white halo
/// like the cut lines on the board.
class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.step);
  final int step;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final dx = 6.0 * step, dy = 11.0;
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
    canvas.drawPath(path, line(8, Colors.white));
    canvas.drawPath(path, line(4, C.berry600));
  }

  @override
  bool shouldRepaint(_ChevronPainter o) => o.step != step;
}

/// A square of paper in [color] and [pattern] filling its width, for the
/// pattern picker; styled like the colour swatches.
class _PaperSwatch extends StatelessWidget {
  const _PaperSwatch({required this.color, required this.pattern, required this.selected});
  final Color color;
  final String pattern;
  final bool selected;

  @override
  Widget build(BuildContext context) {
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
        child: CustomPaint(painter: _PaperSwatchPainter(color, pattern, MediaQuery.devicePixelRatioOf(context))),
      ),
    );
  }
}

const _radius = 12.0;

class _PaperSwatchPainter extends CustomPainter {
  _PaperSwatchPainter(this.color, this.pattern, this.dpr);
  final Color color;
  final String pattern;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(_radius));
    // The pattern tile is a bitmap: lay it out in device pixels so it stays crisp.
    canvas.save();
    canvas.scale(1 / dpr);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size * dpr, Radius.circular(_radius * dpr)), makePaperFill(color, pattern, 100 * dpr));
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
  bool shouldRepaint(_PaperSwatchPainter o) => o.color != color || o.pattern != pattern || o.dpr != dpr;
}
