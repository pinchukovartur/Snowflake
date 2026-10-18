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

/// A flake from the collection on its own, on the reveal's sky: turn it and
/// zoom it, hang it in the window, take it out of the collection, or go back.
class FlakeScreen extends StatefulWidget {
  const FlakeScreen({super.key, required this.game, required this.flake, required this.onBack, required this.onHang, required this.freePane});
  final GameState game;
  final SavedFlake flake;

  /// Back to the collection; also once the flake is taken out of it.
  final VoidCallback onBack;

  /// Off to the window, to hang the flake in [freePane].
  final VoidCallback onHang;

  /// The window's first pane still to fill, or null when none is.
  final int? freePane;

  @override
  State<FlakeScreen> createState() => _FlakeScreenState();
}

class _FlakeScreenState extends State<FlakeScreen> with TickerProviderStateMixin, FlakeTurnZoom {
  @override
  double get flakeRadius => 160;

  @override
  void initState() {
    super.initState();
    if (shimmers(widget.flake.pattern)) startTwinkle();
  }

  /// Asks before taking the flake out of the collection; taken out, back to it.
  void _confirmRemove() {
    final f = widget.flake;
    showDsDialog(
      context,
      builder: (ctx) => DsDialog(
        title: tr('delete_q'),
        onClose: () => Navigator.pop(ctx),
        actions: [
          Btn(tr('delete'), icon: LucideIcons.trash2, block: true, onTap: () {
            Navigator.pop(ctx);
            widget.game.delete(f);
            widget.onBack();
          }),
          Btn(tr('keep'), variant: Variant.light, block: true, onTap: () => Navigator.pop(ctx)),
        ],
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FlakeShadow(size: 120, child: SnowflakeView(cuts: f.cuts, folds: f.folds, color: f.color, pattern: f.pattern, size: 120)),
          const SizedBox(height: 12),
          Text(tr('delete_note')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.flake;
    // Hanging already, or with no pane left for it, it can't go up.
    final hung = widget.game.isHung(f);
    return SkyBackground(
      child: SafeArea(
        child: Stack(children: [
          turnZoomGestures(),
          // Centred in the room above the buttons (two rows of them at the
          // bottom, 140 with their gaps), not over the whole screen.
          Padding(
            padding: const EdgeInsets.only(bottom: 140),
            child: Center(
            child: turnZoomFlake(
              (turn) => SnowflakeView(cuts: f.cuts, folds: f.folds, color: f.color, pattern: f.pattern, size: 320, spin: turn, twinkle: twinkleAt),
            ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Btn(
                    hung ? tr('on_window') : tr('hang'),
                    variant: Variant.light,
                    block: true,
                    disabled: hung || widget.freePane == null,
                    onTap: widget.onHang,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    label: tr('delete_from_collection'),
                    child: Btn(
                      tr('in_collection'),
                      variant: Variant.secondary,
                      icon: Icons.favorite,
                      iconColor: C.berry600,
                      block: true,
                      onTap: _confirmRemove,
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Btn(tr('back'), icon: LucideIcons.arrowLeft, variant: Variant.light, block: true, onTap: widget.onBack),
            ]),
          ),
          // Share, at the right of a top bar laid out empty, so it sits where
          // the other screens' top-bar buttons do.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TopBar(
              left: const SizedBox(width: 44),
              title: '',
              right: Builder(
                builder: (ctx) => BarBtn(LucideIcons.share2, label: tr('share'), onTap: () => shareFlake(ctx, cuts: f.cuts, folds: f.folds, color: f.color, pattern: f.pattern)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
