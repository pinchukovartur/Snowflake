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

const _tools = [
  ('free', LucideIcons.scissors, 'Ножницы'),
  ('circle', LucideIcons.circle, 'Круг'),
  ('triangle', LucideIcons.triangle, 'Треугольник'),
  ('square', LucideIcons.square, 'Квадрат'),
  ('star', LucideIcons.star, 'Звезда'),
  ('heart', LucideIcons.heart, 'Сердце'),
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
    widget.game.hasCut = true;
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

  void _openPaper() {
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
                  Stack(children: [
                    Transform.translate(
                      offset: const Offset(0, 5),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(C.snow300, BlendMode.srcIn),
                        child: SnowflakeView(preset: 'classic', size: 170, color: _paper.color, pattern: _paper.pattern, glow: false),
                      ),
                    ),
                    SnowflakeView(preset: 'classic', size: 170, color: _paper.color, pattern: _paper.pattern, glow: false),
                  ]),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return ColoredBox(
      color: C.surfaceTable,
      child: Column(
        children: [
          // Night header with rounded bottom corners.
          Container(
            padding: EdgeInsets.only(top: pad.top, bottom: 12),
            decoration: const BoxDecoration(
              color: C.night800,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              children: [
                TopBar(
                  left: RoundBtn(LucideIcons.house, label: 'Домой', variant: Variant.ghost, size: BtnSize.s, onTap: widget.onHome),
                  title: 'Снежинка',
                  // As wide as the home button, keeping the title centred.
                  right: const SizedBox(width: 44),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
                  // Cuts made on this flake.
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.scissors, size: 20, color: C.ice200),
                      const SizedBox(width: 8),
                      Text('${_cuts.length}', style: display(18)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) {
                final h = math.min(410.0, c.maxHeight - 24);
                return SizedBox.fromSize(
                  size: c.biggest,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CutBoard(
                          height: h,
                          // Cuts may start well off the paper, so a slit can run in from outside.
                          touchMargin: 120,
                          folds: _folds,
                          cuts: _cuts,
                          fallen: _fallen,
                          tool: _tool,
                          color: _paper.color,
                          pattern: _paper.pattern,
                          onCut: _addCut,
                        ),
                      ),
                      if (!widget.game.hasCut)
                        Positioned(
                          // Under the wedge's apex (CutBoard centres an h-high box, apex 8 above its bottom).
                          top: math.min((c.maxHeight + h) / 2 + 6, c.maxHeight - 84),
                          left: 16,
                          right: 16,
                          child: IgnorePointer(
                            child: Center(
                              child: HintBubble(
                                _tool == 'free'
                                    ? 'Обведи пальцем кусочек, чтобы вырезать'
                                    : 'Нажми на бумагу, потяни — и трафарет станет больше',
                                tailUp: true,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 14,
                        left: 16,
                        child: RoundBtn(
                          LucideIcons.rotateCcw,
                          label: 'Начать заново',
                          size: BtnSize.s,
                          disabled: _cuts.isEmpty,
                          onTap: _reset,
                        ),
                      ),
                      Positioned(
                        top: 10,
                        child: Segmented<int>(
                          options: const [SegOption(4, '4'), SegOption(6, '6')],
                          value: _folds,
                          onChanged: _refold,
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 16,
                        child: RoundBtn(
                          LucideIcons.palette,
                          label: 'Бумага',
                          variant: Variant.secondary,
                          size: BtnSize.s,
                          onTap: _openPaper,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            decoration: BoxDecoration(
              color: C.paper,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [BoxShadow(color: C.snow300, offset: Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final (id, icon, label) in _tools)
                  RoundBtn(
                    icon,
                    label: label,
                    size: BtnSize.s,
                    variant: _tool == id ? Variant.secondary : Variant.light,
                    active: _tool == id,
                    flat: _tool != id,
                    onTap: () => setState(() => _tool = id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, pad.bottom + 14),
            child: Row(
              children: [
                RoundBtn(
                  LucideIcons.undo2,
                  label: 'Отменить',
                  disabled: _s.past.isEmpty,
                  onTap: _undo,
                ),
                const SizedBox(width: 14),
                RoundBtn(
                  LucideIcons.redo2,
                  label: 'Вернуть',
                  disabled: _s.future.isEmpty,
                  onTap: _redo,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Btn(
                    'Раскрыть',
                    size: BtnSize.l,
                    icon: LucideIcons.sparkles,
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
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size * dpr, Radius.circular(_radius * dpr)),
      makePaperFill(color, pattern, 100 * dpr),
    );
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
