import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../snowflake/geometry.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';

/// Unfolds the cut wedge fold by fold (2.4s) and then pops the result card.
class RevealScreen extends StatefulWidget {
  const RevealScreen({
    super.key,
    required this.cuts,
    required this.folds,
    required this.paper,
    required this.saved,
    required this.onDone,
    required this.onSave,
    required this.onBack,
  });

  final List<Cut> cuts;
  final int folds;
  final Paper paper;

  /// Whether this flake is in the collection; [onSave] toggles that.
  final bool saved;

  /// [onDone] moves on to a new flake; [onBack] returns to the cut board with the flake as it was before unfolding.
  final VoidCallback onDone, onSave, onBack;

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: Motion.unfold);
  // Linear: each fold eases on its own in SnowflakePainter.
  late final _t = _anim;
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
    return SkyBackground(
      child: SafeArea(
        child: Stack(children: [
          // Makes room for the card: a slow, eased glide up (half the padding).
          AnimatedPadding(
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.only(bottom: _done ? 200 : 0),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(
                  animation: _t,
                  builder: (_, _) => SnowflakeView(
                    cuts: widget.cuts,
                    folds: widget.folds,
                    color: widget.paper.color,
                    pattern: widget.paper.pattern,
                    unfold: _t.value,
                    size: 320,
                    spin: _t.value * 0.6,
                  ),
                ),
                const SizedBox(height: 20),
                // Fades out rather than leaving: removing it would shrink the
                // centred column and drop the flake before it glides up.
                AnimatedOpacity(
                  opacity: _done ? 0 : 1,
                  duration: Motion.pop,
                  child: FadeTransition(
                    opacity: _t,
                    child: Text('Раскрываем…', style: display(30, weight: FontWeight.w900, shadows: drop(3))),
                  ),
                ),
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
                      Btn('Готово', block: true, onTap: widget.onDone),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Btn('Назад', variant: Variant.light, onTap: widget.onBack),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Btn(
                            widget.saved ? 'В коллекции' : 'В коллекцию',
                            variant: Variant.secondary,
                            icon: widget.saved ? Icons.favorite : LucideIcons.heart,
                            iconColor: widget.saved ? C.berry600 : null,
                            block: true,
                            onTap: widget.onSave,
                          ),
                        ),
                      ]),
                    ],
                    child: const Text('Снежинка готова!'),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
