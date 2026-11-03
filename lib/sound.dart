import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// The game's sound effects, played through SoLoud (kept loaded in memory,
/// so a sound starts with the touch that calls for it).
class Sfx {
  Sfx._();

  /// Where the scissors' sounds lie, and what marks their names: one snip,
  /// "forth", for a cut; there and back, "forth_back", for a stencil.
  static const _folder = 'assets/sounds/';
  static final _cutMark = RegExp(r'_forth(?!_back)'), _stencilMark = RegExp(r'_forth_back');

  /// Each kind's sounds in order of their names: each cut takes the next of
  /// its kind, round and round.
  static final _cuts = _Turns(), _stencils = _Turns();

  /// Starts the engine and loads the sounds. A device that can't play them
  /// just stays silent.
  static Future<void> init() async {
    try {
      await SoLoud.instance.init();
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final keys = [for (final k in manifest.listAssets()) if (k.startsWith(_folder)) k]..sort();
      for (final k in keys) {
        final turns = _stencilMark.hasMatch(k) ? _stencils : _cutMark.hasMatch(k) ? _cuts : null;
        turns?.sounds.add(await SoLoud.instance.loadAsset(k));
      }
    } catch (e) {
      debugPrint('Sounds not loaded: $e');
    }
  }

  /// A cut's sound, a stencil's if [stencil]: the next of its kind in turn.
  static void cut({bool stencil = false}) => (stencil ? _stencils : _cuts).play();
}

/// Sounds played one after the other, round and round.
class _Turns {
  final sounds = <AudioSource>[];
  var _next = 0;

  void play() {
    if (sounds.isEmpty || !SoLoud.instance.isInitialized) return;
    SoLoud.instance.play(sounds[_next]);
    _next = (_next + 1) % sounds.length;
  }
}
