import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'snowflake/geometry.dart';

/// For testing tutorials: set to true to make every launch the first one, the
/// tutorials all showing again (the stored "seen" marks are cleared at start).
/// Debug builds only: a release never has it, whatever this says.
const forceFirstLaunch = true && kDebugMode;

/// The first launch's tutorial, step 1: the game opens on the cut board, the
/// scissors all there is till the player's first cut.
const firstCutTutorial = 'first_cut';

/// The tutorial's step 2: an arrow to the stencils, then a stencil to move,
/// turn and cut out.
const firstStencilTutorial = 'first_stencil';

/// The tutorial's step 3: an arrow to the paper, whose dialog is to be opened
/// and closed.
const firstPaperTutorial = 'first_paper';

/// The tutorial's end: all there is to know told, the unfold button beckons
/// till the flake is unfolded. Till then the game opens on the cut board.
const firstUnfoldTutorial = 'first_unfold';

/// The second tutorial, on the first flake unfolded: an arrow to "to the
/// collection", saving it opening the home screen, where a bubble asks for a
/// flake hung in the window, the window held still and its pluses bouncing;
/// done once one is hung.
const firstWindowTutorial = 'first_window';

/// The second tutorial's end, after [firstWindowTutorial]: an arrow to the
/// home screen's collection button, then the collection, told what it is
/// for, and back to cutting.
const firstCollectionTutorial = 'first_collection';

/// The advent calendar's doors, 18 to 25 December: behind each a new
/// paper pattern or stencil, papers and stencils by turns. Each, till its
/// door is opened, is not to be had (see [GameState.unlocked]).
const adventRewards = <({bool paper, String id})>[
  (paper: true, id: 'snowfall'),
  (paper: false, id: 'skate'),
  (paper: true, id: 'tartan'),
  (paper: false, id: 'elfhat'),
  (paper: true, id: 'frost'),
  (paper: false, id: 'angel'),
  (paper: true, id: 'candy'),
  (paper: false, id: 'deer'),
];

/// The sets of papers and stencils sold in the shop, some of them the
/// advent calendar's too (chocolate, the garland, the gingerbread man and
/// the cane only here; snowfall, tartan, the skate, the elf hat, the angel
/// and the deer only in the calendar; candy and the sparkle lattice in
/// both): [id] is the product's id in Google Play (a one-time purchase),
/// its name `offer_<id>` in the
/// strings. What a set holds is the player's once it is bought, its doors in
/// the calendar or not (see [GameState.unlocked]).
const offers = <({String id, List<({bool paper, String id})> items})>[
  (id: 'pack_snow_day', items: [(paper: true, id: 'candy'), (paper: true, id: 'chocolate'), (paper: false, id: 'gingerman'), (paper: false, id: 'cane')]),
  (id: 'pack_holiday', items: [(paper: true, id: 'garland'), (paper: true, id: 'frost'), (paper: false, id: 'snowman'), (paper: false, id: 'ornament')]),
];

/// Whether paper pattern or stencil [id] is to be had only behind one of the
/// advent calendar's doors, no set in the shop holding it.
bool adventOnly(String id) => adventRewards.any((r) => r.id == id) && !offers.any((o) => o.items.any((r) => r.id == id));

/// For testing the advent calendar: a tap opens any door, its day come or
/// not (shown as ever: locked till then). Debug builds only.
const adventAnyDay = true && kDebugMode;

/// Door [i]'s day in the season [now] is in: 18 December on, the last on
/// Christmas Day (January counting with the December before it).
DateTime adventDay(int i, DateTime now) => DateTime(now.month == 1 ? now.year - 1 : now.year, 12, 18 + i);

/// For testing the Halloween duel: a tap on the boss's flake knocks a cone
/// off it, as if the next flake had been cut. Debug builds only: a release
/// never has it, whatever this says.
const duelCheat = true && kDebugMode;

/// For testing: a "Skip" button on the first launch's cut board, marking
/// all the tutorials seen at once (see [GameState.skipTutorials]). Debug
/// builds only, as [duelCheat].
const tutorialSkip = true && kDebugMode;

/// For testing events: a button beside the tools cutting the event's flake
/// out just as it is. Debug builds only, as [duelCheat].
const eventCheat = true && kDebugMode;

/// For testing what falls off a flake: the cut board shows how the last cut
/// weighed the paper's pieces (see [lastWeighing]), those that fell in red
/// and the one that stayed in green. Debug builds only, as [duelCheat].
const detachReadout = true && kDebugMode;

/// A duel's flake done: which duel (its event's id) and which of its flakes
/// (by preset).
typedef DuelHit = ({String duel, String preset});

/// A flake the player cut and kept.
class SavedFlake {
  const SavedFlake({required this.cuts, this.folds = 6, this.color, this.pattern = 'plain', this.fav = false, this.prize, this.ownPaper = false});
  final List<Cut> cuts;
  final int folds;
  final Color? color;
  final String pattern;
  final bool fav;

  /// The event prize this flake is (the boss flake's preset, see
  /// [prizes]), if it is one: restored as the game has it now, so it
  /// changes with it.
  final String? prize;

  /// Whether the player has put a prize on other paper (see
  /// [GameState.recolor]): its colour and pattern then theirs, kept.
  final bool ownPaper;

  /// The event prize [prize] as the game has it now, or null if it has no
  /// such prize (any more). Set at launch, before the collection is
  /// restored.
  static SavedFlake? Function(String prize)? prizes;

  Map<String, Object?> toJson() => {
        'cuts': [for (final c in cuts) [for (final p in c) [_r(p.dx), _r(p.dy)]]],
        'folds': folds,
        if (color != null) 'color': color!.toARGB32(),
        'pattern': pattern,
        'fav': fav,
        if (prize != null) 'prize': prize,
        if (ownPaper) 'ownPaper': true,
      };

  /// Null for a record without cuts: one of the built-in presets that used to
  /// be kept in the collection. A prize comes back as the game has it now
  /// (see [prizes]), on the player's own paper if they chose it; its cuts as
  /// stored only if the game has it no more.
  static SavedFlake? fromJson(Map<String, Object?> j) {
    final cuts = j['cuts'] as List?;
    if (cuts == null) return null;
    final prize = j['prize'] as String?, ownPaper = j['ownPaper'] as bool? ?? false;
    final color = j['color'] == null ? null : Color(j['color'] as int);
    final pattern = j['pattern'] as String? ?? 'plain';
    final fav = j['fav'] as bool? ?? false;
    final now = prize == null ? null : prizes?.call(prize);
    if (now != null) {
      return SavedFlake(
        cuts: now.cuts,
        folds: now.folds,
        color: ownPaper ? color : now.color,
        pattern: ownPaper ? pattern : now.pattern,
        fav: fav,
        prize: prize,
        ownPaper: ownPaper,
      );
    }
    return SavedFlake(
      cuts: [for (final c in cuts) [for (final p in c as List) Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble())]],
      folds: j['folds'] as int? ?? 6,
      color: color,
      pattern: pattern,
      fav: fav,
      prize: prize,
      ownPaper: ownPaper,
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
    if (forceFirstLaunch) _prefs.remove(_kTutorials);
    _tutorialsSeen.addAll(_prefs.getStringList(_kTutorials) ?? const []);
    // Started afresh along with the tutorials, for trying it out again.
    if (forceFirstLaunch) {
      for (final k in _prefs.getKeys().where((k) => k.startsWith('duel.')).toList()) {
        _prefs.remove(k);
      }
      _prefs.remove(_kAdvent);
      // Real purchases come back with the shop's restore at launch.
      _prefs.remove(_kOwned);
    }
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
    // Windows stored as eight rows deep (16 panes each) keep their panes
    // where they were, the new rows coming in empty under them.
    final oldWin = _prefs.getString(_kWindow) == null ? _prefs.getString(_kWindowV1) : null;
    final win = _prefs.getString(_kWindow) ?? oldWin;
    if (win != null) {
      try {
        (jsonDecode(win) as Map).forEach((k, v) {
          var pane = int.parse(k as String);
          if (oldWin != null) pane = pane ~/ 16 * panesPerWindow + pane % 16;
          final i = v as int?;
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
    if (oldWin != null) {
      _storeWindow();
      _prefs.remove(_kWindowV1);
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
  static const _kWindow = 'window.v2';
  static const _kWindowV1 = 'window.v1';

  /// Panes in each of the home screen's windows: two sashes of twelve rows.
  static const panesPerWindow = 24;
  static const _kLast = 'last.v1';
  static const _kTutorials = 'tutorials.seen.v1';
  static const _kAdvent = 'advent.opened.v1';
  static const _kOwned = 'shop.owned.v1';
  /// Each duel's flakes done, by its event's id ('duel.halloween.v1', …).
  static String _kDuel(String duel) => 'duel.$duel.v1';

  int coins = 128;

  bool sfx = true, vibration = true;

  /// The home screen has shown the game's title since launch; coming back to
  /// it leaves the window clear.
  bool titleShown = false;

  /// The tutorials the player has been through, by id, kept for good: each
  /// shows until marked, and then never again (see [forceFirstLaunch]).
  final _tutorialsSeen = <String>{};

  bool tutorialSeen(String id) => _tutorialsSeen.contains(id);

  /// The cut board's demo (a hand showing how to cut) has been touched away
  /// this launch. Not stored: each launch shows it again till touched.
  bool cutDemoTouched = false;

  /// Each duel (by its event's id): the event flakes (by preset) the player
  /// has done, each one taking a cone off the boss's flake; cutting one again
  /// doesn't. Read from storage the first time asked for.
  final _duelHits = <String, Set<String>>{};
  final _duelSeen = <String, int>{};

  Set<String> duelHits(String duel) => _duelHits.putIfAbsent(duel, () => {...?_prefs.getStringList(_kDuel(duel))});

  /// How many of [duel]'s hits its window has shown landing: the rest still
  /// to knock their cones off as it opens. Not stored: at launch, all of them.
  int duelSeen(String duel) => _duelSeen[duel] ?? duelHits(duel).length;
  void setDuelSeen(String duel, int n) => _duelSeen[duel] = n;

  /// The flake just done for the first time, whose blow its duel's window is
  /// to show landing; cleared once it has. Not stored.
  DuelHit? duelFresh;

  void duelHit(DuelHit hit) {
    final hits = duelHits(hit.duel);
    // Those before it already seen, as they were.
    _duelSeen.putIfAbsent(hit.duel, () => hits.length);
    if (!hits.add(hit.preset)) return;
    duelFresh = hit;
    _prefs.setStringList(_kDuel(hit.duel), [...hits]);
    notifyListeners();
  }

  /// The advent calendar's doors opened, by their place in [adventRewards];
  /// kept for good.
  late final _adventOpened = <int>{...?_prefs.getStringList(_kAdvent)?.map(int.tryParse).whereType<int>()};

  bool adventOpened(int i) => _adventOpened.contains(i);

  /// For testing (debug builds' cheat over the calendar's button): the
  /// calendar's day taken as today, by its door's place, or null for today
  /// as it is. Not stored.
  int? adventCheatDay;

  /// Takes the calendar to day [i] (see [adventCheatDay]). Back in time,
  /// the doors of the days after it shut again, what was behind them taken
  /// back (unless a set bought holds it), as if never opened.
  void setAdventCheatDay(int? i) {
    adventCheatDay = i;
    if (i != null && _adventOpened.any((k) => k > i)) {
      _adventOpened.removeWhere((k) => k > i);
      _prefs.setStringList(_kAdvent, [for (final k in _adventOpened) '$k']);
    }
    notifyListeners();
  }

  /// Today, as far as the calendar goes (see [adventCheatDay]).
  DateTime get adventToday => switch (adventCheatDay) {
        final i? => adventDay(i, DateTime.now()),
        null => DateTime.now(),
      };

  /// Whether door [i] may be opened now: shut, and its day come.
  bool adventReady(int i) {
    final now = adventToday;
    return !adventOpened(i) && !now.isBefore(adventDay(i, now));
  }

  /// How many doors may be opened now.
  int get adventWaiting => [for (var i = 0; i < adventRewards.length; i++) if (adventReady(i)) i].length;

  void openAdvent(int i) {
    if (adventOpened(i) || !(adventReady(i) || adventAnyDay)) return;
    _adventOpened.add(i);
    _prefs.setStringList(_kAdvent, [for (final k in _adventOpened) '$k']);
    notifyListeners();
  }

  /// The [offers] bought, by id; kept for good (and restored from the store
  /// at launch, see Shop).
  late final _owned = <String>{...?_prefs.getStringList(_kOwned)};

  bool owns(String offer) => _owned.contains(offer);

  /// Whether any offer is the player's: then no interstitials (see the shop).
  bool get boughtAny => _owned.isNotEmpty;

  /// Offer [offer] is the player's: bought, or restored from the store.
  void grant(String offer) {
    if (!_owned.add(offer)) return;
    _prefs.setStringList(_kOwned, [..._owned]);
    notifyListeners();
  }

  /// For testing the shop (debug builds' cheat in it): every offer bought
  /// forgotten here. Purchases made in Play come back with the next restore.
  void resetPurchases() {
    if (_owned.isEmpty) return;
    _owned.clear();
    _prefs.remove(_kOwned);
    notifyListeners();
  }

  /// Whether paper pattern or stencil [id] is the player's: all are but the
  /// advent calendar's and the shop's, each once its door is open or a set
  /// holding it is bought.
  bool unlocked(String id) {
    final i = adventRewards.indexWhere((r) => r.id == id);
    final sold = offers.any((o) => o.items.any((r) => r.id == id));
    if (i < 0 && !sold) return true;
    return (i >= 0 && adventOpened(i)) || offers.any((o) => owns(o.id) && o.items.any((r) => r.id == id));
  }

  /// Every tutorial marked seen at once (see [tutorialSkip]).
  void skipTutorials() {
    _tutorialsSeen.addAll(const [firstCutTutorial, firstStencilTutorial, firstPaperTutorial, firstUnfoldTutorial, firstWindowTutorial, firstCollectionTutorial]);
    _prefs.setStringList(_kTutorials, [..._tutorialsSeen]);
    notifyListeners();
  }

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

  /// Adds [f] to the collection, unless one just like it is there already.
  void keep(SavedFlake f) {
    if (_inCollection(f, jsonEncode(f.toJson())) == null) save(f);
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

  /// [f] on other paper, the cuts the same: in its place in the collection,
  /// in the panes it hangs in, and as [last] if it is. Returns the flake as
  /// it is now.
  SavedFlake recolor(SavedFlake f, Paper paper) {
    final i = saved.indexWhere((s) => identical(s, f));
    if (i < 0) return f;
    final n = SavedFlake(cuts: f.cuts, folds: f.folds, color: paper.color, pattern: paper.pattern, fav: f.fav, prize: f.prize, ownPaper: f.prize != null);
    saved[i] = n;
    for (final e in window.entries.toList()) {
      if (identical(e.value, f)) window[e.key] = n;
    }
    if (identical(f, last)) {
      last = n;
      _prefs.setString(_kLast, jsonEncode(n.toJson()));
    }
    _storeCollection();
    _storeWindow();
    notifyListeners();
    return n;
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
