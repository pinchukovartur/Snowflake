import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// The game's sound effects, played through SoLoud (kept loaded in memory,
/// so a sound starts with the touch that calls for it).
class Sfx {
  Sfx._();

  /// Where the scissors' sounds lie, and what marks the names of those that
  /// sound a cut: one snip, "туда" (not "туда_сюда", there and back).
  static const _folder = 'assets/sounds/';
  static final _cutMark = RegExp(r'_туда(?!_сюда)');

  /// The cut sounds in order of their names, and the next one to play: each
  /// cut takes the next, round and round.
  static final _cuts = <AudioSource>[];
  static var _next = 0;

  /// Starts the engine and loads the sounds. A device that can't play them
  /// just stays silent.
  static Future<void> init() async {
    try {
      await SoLoud.instance.init();
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final keys = [
        for (final k in manifest.listAssets())
          if (k.startsWith(_folder) && _cutMark.hasMatch(k)) k,
      ]..sort();
      for (final k in keys) {
        _cuts.add(await SoLoud.instance.loadAsset(k));
      }
    } catch (e) {
      debugPrint('Sounds not loaded: $e');
    }
  }

  /// A cut's sound: the next in turn.
  static void cut() {
    if (_cuts.isEmpty || !SoLoud.instance.isInitialized) return;
    SoLoud.instance.play(_cuts[_next]);
    _next = (_next + 1) % _cuts.length;
  }
}
