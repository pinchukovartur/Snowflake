import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'snowflake/geometry.dart';

/// For testing tutorials: set to true to make every launch the first one, the
/// tutorials all showing again (the stored "seen" marks are cleared at start).
/// Not limited to debug builds for now (see the check in [GameState]): a
/// release build with this on clears them too, so turn it off before one goes
/// to players.
const forceFirstLaunch = true;

/// A flake the player cut and kept.
class SavedFlake {
  const SavedFlake({required this.cuts, this.folds = 6, this.color, this.pattern = 'plain', this.fav = false});
  final List<Cut> cuts;
  final int folds;
  final Color? color;
  final String pattern;
  final bool fav;

  Map<String, Object?> toJson() => {
        'cuts': [for (final c in cuts) [for (final p in c) [_r(p.dx), _r(p.dy)]]],
        'folds': folds,
        if (color != null) 'color': color!.toARGB32(),
        'pattern': pattern,
        'fav': fav,
      };

  /// Null for a record without cuts: one of the built-in presets that used to
  /// be kept in the collection.
  static SavedFlake? fromJson(Map<String, Object?> j) {
    final cuts = j['cuts'] as List?;
    if (cuts == null) return null;
    return SavedFlake(
      cuts: [for (final c in cuts) [for (final p in c as List) Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())]],
      folds: j['folds'] as int? ?? 6,
      color: j['color'] == null ? null : Color(j['color'] as int),
      pattern: j['pattern'] as String? ?? 'plain',
      fav: j['fav'] as bool? ?? false,
    );
  }

  static double _r(double v) => (v * 10000).roundToDouble() / 10000;
}

class Paper {
  const Paper({this.color = Colors.white, this.pattern = 'plain'});
  final Color color;
  final String pattern;
  Paper copyWith({Color? color, String? pattern}) => Paper(color: color ?? this.color, pattern: pattern ?? this.pattern);
}

/// Game state (currency, collection, settings, the home window), kept in the
/// app's preferences so it survives restarts.
class GameState extends ChangeNotifier {
  GameState(this._prefs) {
    coins = _prefs.getInt(_kCoins) ?? coins;
    sfx = _prefs.getBool(_kSfx) ?? sfx;
    vibration = _prefs.getBool(_kVibration) ?? vibration;
    // Debug builds only, if the check is put back: `kDebugMode && forceFirstLaunch`.
    if (forceFirstLaunch /* && kDebugMode */) _prefs.remove(_kTutorials);
    _tutorialsSeen.addAll(_prefs.getStringList(_kTutorials) ?? const []);
    // As stored, built-in presets (from older versions) still in it, as null.
    var stored = <SavedFlake?>[];
    final raw = _prefs.getString(_kCollection);
    if (raw != null) {
      try {
        stored = [for (final j in jsonDecode(raw) as List) SavedFlake.fromJson((j as Map).cast<String, Object?>())];
        saved.addAll(stored.whereType<SavedFlake>());
      } catch (e) {
        // A broken record must not stop the game: start the collection afresh.
        stored = [];
        debugPrint('Collection not restored: $e');
      }
    }
    final lastRaw = _prefs.getString(_kLast);
    if (lastRaw != null) {
      try {
        last = SavedFlake.fromJson((jsonDecode(lastRaw) as Map).cast<String, Object?>());
      } catch (e) {
        debugPrint('Last flake not restored: $e');
      }
    }
    // Panes refer to flakes by their place in the collection as stored; a
    // pane that held a preset is left to fill again.
    final win = _prefs.getString(_kWindow);
    if (win != null) {
      try {
        (jsonDecode(win) as Map).forEach((k, v) {
          final pane = int.parse(k as String), i = v as int?;
          if (i == null) {
            window[pane] = null;
          } else if (i >= 0 && i < stored.length && stored[i] != null) {
            window[pane] = stored[i];
          }
        });
      } catch (e) {
        window.clear();
        debugPrint('Window not restored: $e');
      }
    }
    // Stored again without the presets, the panes renumbered to match.
    if (stored.contains(null)) {
      _storeCollection();
      _storeWindow();
    }
    // Restored apart from the collection, [last] may be a copy of a flake in
    // it: made that very flake, so from here on it is known at a glance.
    final l = last;
    if (l != null) last = _inCollection(l, jsonEncode(l.toJson())) ?? l;
  }

  /// The flake in the collection just like [f] (whose JSON is [key]), if any.
  SavedFlake? _inCollection(SavedFlake f, String key) {
    for (final s in saved) {
      if (identical(s, f) || jsonEncode(s.toJson()) == key) return s;
    }
    return null;
  }

  final SharedPreferences _prefs;

  static const _kCoins = 'coins';
  static const _kSfx = 'settings.sfx';
  static const _kVibration = 'settings.vibration';
  static const _kCollection = 'collection.v1';
  static const _kWindow = 'window.v1';
  static const _kLast = 'last.v1';
  static const _kTutorials = 'tutorials.seen.v1';

  int coins = 128;

  bool sfx = true, vibration = false;

  /// The home screen has shown the game's title since launch; coming back to
  /// it leaves the window clear.
  bool titleShown = false;

  /// The tutorials the player has been through, by id, kept for good: each
  /// shows until marked, and then never again (see [forceFirstLaunch]).
  final _tutorialsSeen = <String>{};

  bool tutorialSeen(String id) => _tutorialsSeen.contains(id);

  void markTutorialSeen(String id) {
    if (!_tutorialsSeen.add(id)) return;
    _prefs.setStringList(_kTutorials, [..._tutorialsSeen]);
    notifyListeners();
  }

  /// The collection: the player's flakes, newest first. (The built-in
  /// presets are the game's own, for its events, and never in it.)
  final saved = <SavedFlake>[];

  void setSetting({bool? sfx, bool? vibration}) {
    this.sfx = sfx ?? this.sfx;
    this.vibration = vibration ?? this.vibration;
    _prefs.setBool(_kSfx, this.sfx);
    _prefs.setBool(_kVibration, this.vibration);
    notifyListeners();
  }

  void save(SavedFlake f) {
    saved.insert(0, f);
    if (identical(f, last)) _lastIsSaved = true;
    _storeCollection();
    _storeWindow();
    notifyListeners();
  }

  /// Deletes [f] for good, as the player asked: out of the collection, and,
  /// if it is the [last] one unfolded, no more offered to add back (unlike
  /// [remove], which "Done"'s toggle uses and may undo).
  void delete(SavedFlake f) {
    deleted = (flake: f, at: saved.indexOf(f), panes: [for (final e in window.entries) if (identical(e.value, f)) e.key], wasLast: identical(f, last));
    remove(f);
    if (identical(f, last)) {
      last = null;
      _lastIsSaved = null;
      _prefs.remove(_kLast);
    }
  }

  /// The flake [delete]d last, with where it was (its place in the
  /// collection, the panes it hung in, whether it was [last]), while that can
  /// still be undone: until the player leaves the collection (see
  /// [forgetDeleted]). Not stored.
  ({SavedFlake flake, int at, List<int> panes, bool wasLast})? deleted;

  /// Puts the [deleted] flake back as it was.
  void undoDelete() {
    final d = deleted;
    if (d == null) return;
    deleted = null;
    saved.insert(d.at.clamp(0, saved.length), d.flake);
    for (final p in d.panes) {
      // Unless filled again meanwhile.
      if (!window.containsKey(p)) window[p] = d.flake;
    }
    if (d.wasLast) {
      last = d.flake;
      _lastIsSaved = true;
      _prefs.setString(_kLast, jsonEncode(d.flake.toJson()));
    }
    _storeCollection();
    _storeWindow();
    notifyListeners();
  }

  /// The [deleted] flake is gone for good: no more undoing it.
  void forgetDeleted() {
    if (deleted == null) return;
    deleted = null;
    notifyListeners();
  }

  void remove(SavedFlake f) {
    saved.remove(f);
    if (identical(f, last)) _lastIsSaved = false;
    window.removeWhere((_, w) => identical(w, f));
    _storeCollection();
    _storeWindow();
    notifyListeners();
  }

  /// The flake unfolded last, kept (only the one) so it can still be added
  /// to the collection later.
  SavedFlake? last;

  void setLast(SavedFlake f) {
    final key = jsonEncode(f.toJson());
    // The same flake unfolded again is the one already saved, not a copy to
    // save twice: looked for once here, so [lastSaved] needn't.
    final kept = _inCollection(f, key);
    last = kept ?? f;
    _lastIsSaved = kept != null;
    _prefs.setString(_kLast, key);
    notifyListeners();
  }

  /// Whether [last] is in the collection: worked out (by identity: [last] is
  /// always the very flake the collection holds, see the constructor) only
  /// when it is not yet known, and kept up to date by [setLast], [save] and
  /// [remove], so screens asking on every rebuild cost nothing.
  bool? _lastIsSaved;

  bool get lastSaved {
    final l = last;
    if (l == null) return false;
    return _lastIsSaved ??= saved.any((f) => identical(f, l));
  }

  /// Adds [last] to the collection, unless it is there already.
  void saveLast() {
    final l = last;
    if (l != null && !lastSaved) save(l);
  }

  /// Takes [last] out of the collection, if it is there.
  void unsaveLast() {
    final l = last;
    if (l != null && lastSaved) remove(l);
  }

  void _storeCollection() => _prefs.setString(_kCollection, jsonEncode([for (final f in saved) f.toJson()]));

  /// What fills the home window, by pane index (row by row, left sash first):
  /// a flake, or null for a pane the player chose to leave clear. Panes not
  /// here are still to fill.
  final window = <int, SavedFlake?>{};

  /// Hangs [f] in [pane], or leaves the pane clear when [f] is null. A flake
  /// hangs in one pane at most.
  void hang(int pane, SavedFlake? f) {
    window[pane] = f;
    _storeWindow();
    notifyListeners();
  }

  /// Whether [f] hangs in some pane of the window.
  bool isHung(SavedFlake f) => window.values.any((w) => identical(w, f));

  void unhang(int pane) {
    window.remove(pane);
    _storeWindow();
    notifyListeners();
  }

  /// Panes as indices into [saved] (null = left clear); kept in step with it.
  void _storeWindow() => _prefs.setString(_kWindow, jsonEncode({
        for (final MapEntry(:key, :value) in window.entries) '$key': value == null ? null : saved.indexOf(value),
      }));
}
