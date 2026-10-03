import 'package:flutter/material.dart';

import 'snowflake/geometry.dart';

class SavedFlake {
  const SavedFlake({required this.name, this.cuts, this.preset = 'classic', this.folds = 6, this.color, this.pattern = 'plain', this.fav = false});
  final String name;
  final List<Cut>? cuts;
  final String preset;
  final int folds;
  final Color? color;
  final String pattern;
  final bool fav;

  /// Cut by the player; the rest are built-in presets.
  bool get own => cuts != null;
}

class Paper {
  const Paper({this.color = Colors.white, this.pattern = 'plain'});
  final Color color;
  final String pattern;
  Paper copyWith({Color? color, String? pattern}) => Paper(color: color ?? this.color, pattern: pattern ?? this.pattern);
}


/// In-memory game state (progress, currency, collection, settings).
class GameState extends ChangeNotifier {
  int coins = 128;

  bool music = true, sfx = true, vibration = false;

  /// The player has made a cut since launch, so the cutting hint stays hidden.
  bool hasCut = false;

  final saved = <SavedFlake>[
    const SavedFlake(name: 'Кружево', preset: 'lace'),
    const SavedFlake(name: 'Звезда', preset: 'star', color: Color(0xFFFFC7D0), pattern: 'dots'),
    const SavedFlake(name: 'Классика', preset: 'classic'),
    const SavedFlake(name: 'Восьмая', preset: 'classic', folds: 4, color: Color(0xFFC4ECFF), pattern: 'sparkle'),
  ];

  /// The collection as shown: the player's flakes (newest first), then the presets.
  List<SavedFlake> get collection => [...saved.where((f) => f.own), ...saved.where((f) => !f.own)];

  void setSetting({bool? music, bool? sfx, bool? vibration}) {
    this.music = music ?? this.music;
    this.sfx = sfx ?? this.sfx;
    this.vibration = vibration ?? this.vibration;
    notifyListeners();
  }

  void save(SavedFlake f) {
    saved.insert(0, f);
    notifyListeners();
  }

  void remove(SavedFlake f) {
    saved.remove(f);
    notifyListeners();
  }
}
