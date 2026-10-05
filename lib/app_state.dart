import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Map<String, Object?> toJson() => {
        'name': name,
        if (cuts != null) 'cuts': [for (final c in cuts!) [for (final p in c) [_r(p.dx), _r(p.dy)]]],
        'preset': preset,
        'folds': folds,
        if (color != null) 'color': color!.toARGB32(),
        'pattern': pattern,
        'fav': fav,
      };

  factory SavedFlake.fromJson(Map<String, Object?> j) => SavedFlake(
        name: j['name'] as String,
        cuts: (j['cuts'] as List?)
            ?.map((c) => [for (final p in c as List) Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())])
            .toList(),
        preset: j['preset'] as String? ?? 'classic',
        folds: j['folds'] as int? ?? 6,
        color: j['color'] == null ? null : Color(j['color'] as int),
        pattern: j['pattern'] as String? ?? 'plain',
        fav: j['fav'] as bool? ?? false,
      );

  static double _r(double v) => (v * 10000).roundToDouble() / 10000;
}

class Paper {
  const Paper({this.color = Colors.white, this.pattern = 'plain'});
  final Color color;
  final String pattern;
  Paper copyWith({Color? color, String? pattern}) => Paper(color: color ?? this.color, pattern: pattern ?? this.pattern);
}


/// Game state (currency, collection, settings), kept in the app's preferences
/// so it survives restarts.
class GameState extends ChangeNotifier {
  GameState(this._prefs) {
    coins = _prefs.getInt(_kCoins) ?? coins;
    music = _prefs.getBool(_kMusic) ?? music;
    sfx = _prefs.getBool(_kSfx) ?? sfx;
    vibration = _prefs.getBool(_kVibration) ?? vibration;
    _hasCut = _prefs.getBool(_kHasCut) ?? false;
    final raw = _prefs.getString(_kCollection);
    if (raw != null) {
      try {
        final list = [for (final j in jsonDecode(raw) as List) SavedFlake.fromJson((j as Map).cast<String, Object?>())];
        saved
          ..clear()
          ..addAll(list);
      } catch (e) {
        // A broken record must not stop the game: keep the built-in collection.
        debugPrint('Collection not restored: $e');
      }
    }
  }

  final SharedPreferences _prefs;

  static const _kCoins = 'coins';
  static const _kMusic = 'settings.music';
  static const _kSfx = 'settings.sfx';
  static const _kVibration = 'settings.vibration';
  static const _kHasCut = 'hint.hasCut';
  static const _kCollection = 'collection.v1';

  int coins = 128;

  bool music = true, sfx = true, vibration = false;

  /// The player has made a cut at least once, so the cutting hint stays hidden.
  bool get hasCut => _hasCut;
  set hasCut(bool v) {
    if (v == _hasCut) return;
    _hasCut = v;
    _prefs.setBool(_kHasCut, v);
  }

  bool _hasCut = false;

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
    _prefs.setBool(_kMusic, this.music);
    _prefs.setBool(_kSfx, this.sfx);
    _prefs.setBool(_kVibration, this.vibration);
    notifyListeners();
  }

  void save(SavedFlake f) {
    saved.insert(0, f);
    _storeCollection();
    notifyListeners();
  }

  void remove(SavedFlake f) {
    saved.remove(f);
    _storeCollection();
    notifyListeners();
  }

  void _storeCollection() => _prefs.setString(_kCollection, jsonEncode([for (final f in saved) f.toJson()]));
}
