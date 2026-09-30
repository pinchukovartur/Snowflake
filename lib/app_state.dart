import 'package:flutter/material.dart';

import 'snowflake/geometry.dart';
import 'widgets/ds.dart';

class SavedFlake {
  const SavedFlake({required this.name, this.cuts, this.preset = 'classic', this.folds = 6, this.color, this.pattern = 'plain', this.fav = false});
  final String name;
  final List<Cut>? cuts;
  final String preset;
  final int folds;
  final Color? color;
  final String pattern;
  final bool fav;
}

class Paper {
  const Paper({this.color = Colors.white, this.pattern = 'plain'});
  final Color color;
  final String pattern;
  Paper copyWith({Color? color, String? pattern}) => Paper(color: color ?? this.color, pattern: pattern ?? this.pattern);
}

class Level {
  Level(this.n, this.state, this.stars);
  final int n;
  LevelState state;
  int stars;
}

/// In-memory game state (progress, currency, collection, settings).
class GameState extends ChangeNotifier {
  int coins = 128;
  int get stars => levels.fold(0, (s, l) => s + l.stars);

  bool music = true, sfx = true, vibration = false;

  final levels = List.generate(12, (i) {
    final state = i < 3
        ? LevelState.done
        : i == 3
            ? LevelState.current
            : i < 5
                ? LevelState.open
                : LevelState.locked;
    return Level(i + 1, state, i < 3 ? const [3, 2, 3][i] : 0);
  });

  final saved = <SavedFlake>[
    const SavedFlake(name: 'Кружево', preset: 'lace', fav: true),
    const SavedFlake(name: 'Звезда', preset: 'star', color: Color(0xFFFFC7D0), pattern: 'dots'),
    const SavedFlake(name: 'Классика', preset: 'classic'),
    const SavedFlake(name: 'Восьмая', preset: 'classic', folds: 4, fav: true, color: Color(0xFFC4ECFF), pattern: 'sparkle'),
  ];

  void setSetting({bool? music, bool? sfx, bool? vibration}) {
    this.music = music ?? this.music;
    this.sfx = sfx ?? this.sfx;
    this.vibration = vibration ?? this.vibration;
    notifyListeners();
  }

  /// Records a finished level: keeps the best star result and opens the next one.
  void complete(int n, int earned) {
    final l = levels[n - 1];
    if (earned > l.stars) l.stars = earned;
    l.state = LevelState.done;
    coins += earned * 10;
    if (n < levels.length) {
      final next = levels[n];
      if (next.state == LevelState.locked || next.state == LevelState.open) next.state = LevelState.current;
      if (n + 1 < levels.length && levels[n + 1].state == LevelState.locked) levels[n + 1].state = LevelState.open;
    }
    notifyListeners();
  }

  void save(SavedFlake f) {
    saved.insert(0, f);
    notifyListeners();
  }
}
