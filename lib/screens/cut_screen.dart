import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../snowflake/cut_board.dart';
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

const _maxCuts = 8;

class CutScreen extends StatefulWidget {
  const CutScreen({super.key, required this.game, required this.level, required this.onLevels, required this.onUnfold});
  final GameState game;
  final int level;
  final VoidCallback onLevels;
  final void Function(List<Cut> cuts, Paper paper) onUnfold;

  @override
  State<CutScreen> createState() => CutScreenState();
}

class CutScreenState extends State<CutScreen> {
  List<Cut> _cuts = const [];
  String _tool = 'free';
  Paper _paper = const Paper();

  void _addCut(Cut c) {
    if (widget.game.vibration) HapticFeedback.lightImpact();
    setState(() => _cuts = [..._cuts, c]);
  }

  /// Opens the pause dialog (also used for the system back gesture).
  void pause() {
    showDsDialog(
      context,
      builder: (ctx) {
        return DsDialog(
          title: 'Пауза',
          onClose: () => Navigator.pop(ctx),
          actions: [
            Btn('Продолжить', icon: LucideIcons.play, block: true, onTap: () => Navigator.pop(ctx)),
            Btn(
              'К уровням',
              variant: Variant.light,
              icon: LucideIcons.map,
              block: true,
              onTap: () {
                Navigator.pop(ctx);
                widget.onLevels();
              },
            ),
          ],
          child: const Text('Снежинка подождёт тебя.'),
        );
      },
    );
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
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: SnowflakeView(preset: 'classic', size: 110, color: _paper.color, pattern: _paper.pattern, glow: false),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final (i, p) in paperColors.indexed) ...[
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
                                      if (p.color == _paper.color) const BoxShadow(color: C.berry500, spreadRadius: 4),
                                      const BoxShadow(color: C.snow300, offset: Offset(0, 3)),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      for (final (i, (id, name)) in paperPatterns.indexed) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => set(_paper.copyWith(pattern: id)),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
                              decoration: BoxDecoration(
                                color: id == _paper.pattern ? C.berry100 : C.snow50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: id == _paper.pattern ? C.berry500 : C.snow200, width: 2),
                              ),
                              child: Column(
                                children: [
                                  SnowflakeView(cuts: const [], size: 36, color: _paper.color, pattern: id, glow: false),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    child: Text(name, style: display(10, color: C.night800)),
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
                  left: RoundBtn(LucideIcons.pause, label: 'Пауза', variant: Variant.ghost, size: BtnSize.s, onTap: pause),
                  title: 'Уровень ${widget.level}',
                  right: Tooltip(
                    message: 'Образец',
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: C.night700, borderRadius: BorderRadius.circular(18)),
                      child: const SnowflakeView(preset: 'classic', size: 44, glow: false),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 6, 28, 0),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.scissors, size: 20, color: C.ice200),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ProgressBar(value: _cuts.length / _maxCuts, tone: Tone.berry, height: 14, dark: true),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 40,
                        child: Text('${_cuts.length}/$_maxCuts', textAlign: TextAlign.right, style: display(15)),
                      ),
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
                      CutBoard(
                        height: h,
                        cuts: _cuts,
                        tool: _tool,
                        color: _paper.color,
                        pattern: _paper.pattern,
                        disabled: _cuts.length >= _maxCuts,
                        onCut: _addCut,
                      ),
                      if (_cuts.isEmpty)
                        Positioned(
                          top: math.min(70, c.maxHeight * .12),
                          left: 16,
                          right: 16,
                          child: IgnorePointer(
                            child: Center(
                              child: HintBubble(
                                _tool == 'free'
                                    ? 'Обведи пальцем кусочек, чтобы вырезать'
                                    : 'Нажми на бумагу, потяни — и трафарет станет больше',
                              ),
                            ),
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
                  disabled: _cuts.isEmpty,
                  onTap: () => setState(() => _cuts = _cuts.sublist(0, _cuts.length - 1)),
                ),
                const SizedBox(width: 14),
                RoundBtn(
                  LucideIcons.rotateCcw,
                  label: 'Начать заново',
                  disabled: _cuts.isEmpty,
                  onTap: () => setState(() => _cuts = const []),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Btn(
                    'Раскрыть',
                    size: BtnSize.l,
                    icon: LucideIcons.sparkles,
                    block: true,
                    disabled: _cuts.length < 2,
                    onTap: () => widget.onUnfold(_cuts, _paper),
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
