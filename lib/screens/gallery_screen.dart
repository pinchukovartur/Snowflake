import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../l10n.dart';
import '../app_state.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key, required this.game, required this.onBack, required this.onOpen});
  final GameState game;
  final VoidCallback onBack;

  /// Shows a flake on its own, to turn and zoom.
  final ValueChanged<SavedFlake> onOpen;

  /// Asks before taking [f] out of the collection.
  void _confirmRemove(BuildContext context, SavedFlake f) {
    showDsDialog(
      context,
      builder: (ctx) => DsDialog(
        title: tr('delete_q'),
        onClose: () => Navigator.pop(ctx),
        actions: [
          Btn(tr('delete'), icon: LucideIcons.trash2, block: true, onTap: () {
            game.remove(f);
            Navigator.pop(ctx);
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
    final list = game.saved;
    final offerLast = game.last != null && !game.lastSaved;
    return SkyBackground(
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            TopBar(
              left: RoundBtn(LucideIcons.arrowLeft, label: tr('back'), variant: Variant.ghost, size: BtnSize.s, onTap: onBack),
              title: tr('my_collection'),
              // As wide as the back button, so the title centres on the screen.
              right: const SizedBox(width: 44),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text(tr('collection_empty'), style: display(22, color: C.ice200)))
                  : GridView.builder(
                    // With the button below, room to scroll the last row up clear of it
                    // (the small button, 40 + 4 lip, and 12 more).
                    padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 20 + (offerLast ? 56 : 0)),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14 + 6, crossAxisSpacing: 14),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final s = list[i];
                      return GestureDetector(
                        onTap: () => onOpen(s),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: C.night700,
                            borderRadius: BorderRadius.circular(R.l),
                            boxShadow: const [BoxShadow(color: C.night900, offset: Offset(0, 6))],
                          ),
                          child: LayoutBuilder(builder: (_, c) {
                            final size = (c.maxWidth * .78).clamp(0.0, 140.0);
                            return Stack(alignment: Alignment.center, children: [
                              FlakeShadow(
                                size: size,
                                child: SnowflakeView(cuts: s.cuts, folds: s.folds, color: s.color, pattern: s.pattern, size: size),
                              ),
                              if (s.fav)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Semantics(
                                    button: true,
                                    label: tr('delete_from_collection'),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _confirmRemove(context, s),
                                      // A finger-sized target around the small heart.
                                      child: const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: Icon(Icons.favorite, size: 24, color: C.berry600),
                                      ),
                                    ),
                                  ),
                                ),
                            ]);
                          }),
                        ),
                      );
                    },
                  ),
            ),
          ]),
          // The last flake unfolded, while it is not in the collection yet.
          if (offerLast)
            Positioned(
              right: 20,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              child: Semantics(
                label: tr('add_last_to_collection'),
                child: Btn(tr('add_last'), icon: LucideIcons.heart, size: BtnSize.s, onTap: game.saveLast),
              ),
            ),
        ]),
      ),
    );
  }
}
