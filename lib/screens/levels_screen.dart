import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../widgets/ds.dart';

class LevelsScreen extends StatelessWidget {
  const LevelsScreen({super.key, required this.game, required this.onBack, required this.onPlay});
  final GameState game;
  final VoidCallback onBack;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    final levels = game.levels;
    final done = levels.where((l) => l.state == LevelState.done).length;
    return SkyBackground(
      child: SafeArea(
        child: Column(children: [
          TopBar(
            left: RoundBtn(LucideIcons.arrowLeft, label: 'Назад', variant: Variant.ghost, size: BtnSize.s, onTap: onBack),
            title: 'Зимний лес',
            right: const SizedBox(width: 44),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 4, 36, 0),
            child: ProgressBar(value: done / levels.length, label: '$done / ${levels.length}', dark: true),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(30, 28, 30, 40),
              child: Column(children: [
                for (var row = 0; row < (levels.length / 3).ceil(); row++)
                  Padding(
                    padding: EdgeInsets.only(top: row == 0 ? 0 : 18),
                    child: Row(children: [
                      for (var col = 0; col < 3; col++)
                        Expanded(
                          child: Builder(builder: (_) {
                            final i = row * 3 + col;
                            if (i >= levels.length) return const SizedBox();
                            final l = levels[i];
                            return Transform.translate(
                              offset: Offset(0, col == 1 ? 22 : 0),
                              child: Center(
                                child: LevelTile(number: l.n, state: l.state, stars: l.stars, onTap: () => onPlay(l.n)),
                              ),
                            );
                          }),
                        ),
                    ]),
                  ),
              ]),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Segmented(
              dark: true,
              value: 'forest',
              options: [
                SegOption('forest', 'Лес', LucideIcons.trees),
                SegOption('city', 'Город', LucideIcons.building2),
                SegOption('north', 'Север', LucideIcons.mountainSnow),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
