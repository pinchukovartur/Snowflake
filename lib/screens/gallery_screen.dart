import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key, required this.game, required this.onBack});
  final GameState game;
  final VoidCallback onBack;

  /// Asks before taking [f] out of the collection.
  void _confirmRemove(BuildContext context, SavedFlake f) {
    showDsDialog(
      context,
      builder: (ctx) => DsDialog(
        title: 'Удалить?',
        onClose: () => Navigator.pop(ctx),
        actions: [
          Btn('Удалить', icon: LucideIcons.trash2, block: true, onTap: () {
            game.remove(f);
            Navigator.pop(ctx);
          }),
          Btn('Оставить', variant: Variant.light, block: true, onTap: () => Navigator.pop(ctx)),
        ],
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SnowflakeView(cuts: f.cuts, preset: f.preset, folds: f.folds, color: f.color, pattern: f.pattern, size: 120, glow: false),
          const SizedBox(height: 12),
          Text('«${f.name}» пропадёт из коллекции.'),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = game.collection;
    return SkyBackground(
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          TopBar(
            left: RoundBtn(LucideIcons.arrowLeft, label: 'Назад', variant: Variant.ghost, size: BtnSize.s, onTap: onBack),
            title: 'Моя коллекция',
            right: RoundBtn(LucideIcons.share2, label: 'Поделиться', variant: Variant.ghost, size: BtnSize.s, onTap: () {}),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14 + 6, crossAxisSpacing: 14),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final s = list[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: C.night700,
                    borderRadius: BorderRadius.circular(R.l),
                    boxShadow: const [BoxShadow(color: C.night900, offset: Offset(0, 6))],
                  ),
                  child: LayoutBuilder(builder: (_, c) {
                    return Stack(alignment: Alignment.center, children: [
                      SnowflakeView(
                        cuts: s.cuts,
                        preset: s.preset,
                        folds: s.folds,
                        color: s.color,
                        pattern: s.pattern,
                        size: (c.maxWidth * .78).clamp(0, 140),
                      ),
                      if (s.fav)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Semantics(
                            button: true,
                            label: 'Удалить из коллекции',
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
                      Positioned(left: 12, bottom: 10, child: Text(s.name, style: display(13, color: C.ice200))),
                    ]);
                  }),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
