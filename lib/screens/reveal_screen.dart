import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../app_state.dart';
import '../snowflake/geometry.dart';
import '../snowflake/share_flake.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';
import '../widgets/flake_turn_zoom.dart';

/// Unfolds the cut wedge fold by fold and then pops the result card.
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

class _RevealScreenState extends State<RevealScreen> with TickerProviderStateMixin, FlakeTurnZoom {
  // Stretched where flaps open one after the other, so each keeps its pace;
  // linear, as each fold eases on its own in SnowflakePainter.
  late final _anim = AnimationController(vsync: this, duration: Motion.unfold * unfoldSpan(widget.folds));
  bool _done = false;

  @override
  double get flakeRadius => 160;

  @override
  void initState() {
    super.initState();
    if (shimmers(widget.paper.pattern)) startTwinkle();
    // On completion, however reached (played out or skipped), the card follows.
    _anim.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _done = true);
      });
    });
    _anim.forward();
  }

  /// A tap while the flake unfolds jumps to it lying open, as a tap skips an
  /// event's intro.
  void _skipUnfold() {
    if (_anim.isAnimating) _anim.value = 1;
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
          turnZoomGestures(),
          // Makes room for the card: a slow, eased glide up (half the padding).
          AnimatedPadding(
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.only(bottom: _done ? 200 : 0),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                turnZoomFlake(
                  also: _anim,
                  (turn) => SnowflakeView(
                    cuts: widget.cuts,
                    folds: widget.folds,
                    color: widget.paper.color,
                    pattern: widget.paper.pattern,
                    unfold: _anim.value,
                    size: 320,
                    // Glints twinkle once the flake lies open; a hologram's sheen
                    // drifts all along.
                    twinkle: _anim.isCompleted || widget.paper.pattern == 'holo' ? twinkleAt : null,
                    // One turn of the flake's own symmetry (2π / folds), so it comes to rest
                    // as every flake does, a crease upright.
                    spin: _anim.value * 2 * math.pi / widget.folds + turn,
                  ),
                ),
                const SizedBox(height: 20),
                // Fades out rather than leaving: removing it would shrink the
                // centred column and drop the flake before it glides up.
                AnimatedOpacity(
                  opacity: _done ? 0 : 1,
                  duration: Motion.pop,
                  child: FadeTransition(
                    opacity: _anim,
                    child: Text(tr('unfolding'), style: display(30, weight: FontWeight.w900, shadows: drop(3))),
                  ),
                ),
              ]),
            ),
          ),
          // Share, at the right of a top bar laid out empty, so it sits where
          // the other screens' top-bar buttons do. Only once the
          // flake lies open (with the card): while it unfolds a tap anywhere
          // skips ahead, so a button there would only seem to work.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_done,
              child: AnimatedOpacity(
                opacity: _done ? 1 : 0,
                duration: Motion.pop,
                child: TopBar(
                  left: const SizedBox(width: 44),
                  title: '',
                  right: Builder(
                    builder: (ctx) => RoundBtn(
                      LucideIcons.share2,
                      label: tr('share'),
                      variant: Variant.ghost,
                      size: BtnSize.s,
                      onTap: () => shareFlake(ctx, cuts: widget.cuts, folds: widget.folds, color: widget.paper.color, pattern: widget.paper.pattern),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Over everything while the flake unfolds: a tap skips to the end.
          if (!_anim.isCompleted)
            Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _skipUnfold)),
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
                    title: tr('great'),
                    actions: [
                      Btn(tr('done'), block: true, onTap: widget.onDone),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Btn(tr('back'), variant: Variant.light, onTap: widget.onBack),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Btn(
                            widget.saved ? tr('in_collection') : tr('to_collection'),
                            variant: Variant.secondary,
                            icon: widget.saved ? Icons.favorite : LucideIcons.heart,
                            iconColor: widget.saved ? C.berry600 : null,
                            block: true,
                            onTap: widget.onSave,
                          ),
                        ),
                      ]),
                    ],
                    child: Text(tr('flake_ready')),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
