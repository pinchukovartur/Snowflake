import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../snowflake/geometry.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';

/// Unfolds the cut wedge (1.4s ease-out) and then pops the star result.
class RevealScreen extends StatefulWidget {
  const RevealScreen({
    super.key,
    required this.level,
    required this.cuts,
    required this.paper,
    required this.onNext,
    required this.onSave,
    required this.onReplay,
  });

  final int level;
  final List<Cut> cuts;
  final Paper paper;
  final VoidCallback onNext, onSave, onReplay;

  static int starsFor(int cuts) => cuts >= 6 ? 3 : cuts >= 4 ? 2 : 1;

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: Motion.unfold);
  late final _t = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _anim.forward().then((_) => Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted) setState(() => _done = true);
        }));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stars = RevealScreen.starsFor(widget.cuts.length);
    return SkyBackground(
      child: SafeArea(
        child: Stack(children: [
          AnimatedPadding(
            duration: Motion.pop,
            curve: Motion.out,
            padding: EdgeInsets.only(bottom: _done ? 330 : 0),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(end: _done ? 240 : 320),
                  duration: Motion.pop,
                  curve: Motion.out,
                  builder: (_, size, _) => AnimatedBuilder(
                    animation: _t,
                    builder: (_, _) => SnowflakeView(
                      cuts: widget.cuts,
                      color: widget.paper.color,
                      pattern: widget.paper.pattern,
                      unfold: _t.value,
                      size: size,
                      spin: _t.value * 0.6,
                    ),
                  ),
                ),
                if (!_done) ...[
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _t,
                    child: Text('Раскрываем…', style: display(30, weight: FontWeight.w900, shadows: drop(3))),
                  ),
                ],
              ]),
            ),
          ),
          if (_done)
            Positioned(
              left: 20,
              right: 20,
              bottom: 12,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Motion.pop,
                builder: (_, v, child) => Opacity(
                  opacity: v,
                  child: Transform.scale(scale: .6 + .4 * Motion.bounce.transform(v), child: child),
                ),
                child: Center(
                  child: DsDialog(
                    title: 'Отлично!',
                    actions: [
                      Btn('Дальше', iconRight: LucideIcons.arrowRight, block: true, onTap: widget.onNext),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: Btn('В коллекцию', variant: Variant.secondary, icon: LucideIcons.heart, block: true, onTap: widget.onSave)),
                        const SizedBox(width: 10),
                        RoundBtn(LucideIcons.rotateCcw, label: 'Ещё раз', onTap: widget.onReplay),
                      ]),
                    ],
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: StarRating(value: stars, size: 44, arc: true),
                      ),
                      Text('Уровень ${widget.level} пройден. +${stars * 10}'),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
