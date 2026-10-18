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

  /// Shows a flake on its own, to turn and zoom (and take out of the
  /// collection, or hang in the window).
  final ValueChanged<SavedFlake> onOpen;

  @override
  Widget build(BuildContext context) {
    final list = game.saved;
    final offerLast = game.last != null && !game.lastSaved;
    final offerUndo = game.deleted != null;
    // The buttons at the bottom right, each 40 + 4 lip, 12 apart.
    final buttons = (offerUndo ? 1 : 0) + (offerLast ? 1 : 0);
    return SkyBackground(
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          Column(children: [
            TopBar(
              left: BarBtn(LucideIcons.arrowLeft, label: tr('back'), onTap: onBack),
              title: tr('my_collection'),
              // As wide as the back button, so the title centres on the screen.
              right: const SizedBox(width: 44),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: list.isEmpty
                  ? Center(child: Text(tr('collection_empty'), style: display(22, color: C.ice200)))
                  : GridView.builder(
                    // With buttons below, room to scroll the last row up clear of them.
                    padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 20 + buttons * 56),
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
                              // Hanging in the window: said so in the corner, as when picking one for it.
                              if (game.isHung(s))
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(color: C.night800, borderRadius: BorderRadius.circular(R.s)),
                                    child: Text(tr('on_window'), style: display(13, color: Colors.white, height: 1)),
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
          // A flake just deleted, to put back; and the last flake unfolded,
          // while it is not in the collection yet.
          if (buttons > 0)
            Positioned(
              right: 20,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (offerUndo) Btn(tr('undo_delete'), icon: LucideIcons.undo2, size: BtnSize.s, onTap: game.undoDelete),
                if (offerUndo && offerLast) const SizedBox(height: 12),
                if (offerLast)
                  Semantics(
                    label: tr('add_last_to_collection'),
                    child: Btn(tr('add_last'), icon: LucideIcons.heart, size: BtnSize.s, onTap: game.saveLast),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}
