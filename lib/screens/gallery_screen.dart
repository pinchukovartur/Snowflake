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

  @override
  Widget build(BuildContext context) {
    final list = game.saved;
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
                      if (s.fav) const Positioned(top: 10, right: 10, child: Icon(LucideIcons.heart, size: 20, color: C.berry500)),
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
