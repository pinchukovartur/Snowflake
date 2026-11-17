import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snowflake/snowflake/geometry.dart';

/// A flake the game sets out (an event's, a boss's: any record with a
/// `preset:`) and its colour, as written in the source.
final _flake = RegExp(r"preset: '([^']+)'[^)]*?color: Color\(0x([0-9A-Fa-f]{8})\)");

void main() {
  test('flakes the game sets out are in colours the player can pick', () {
    final palette = {for (final p in paperColors) p.color.toARGB32()};
    final off = [
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')))
        for (final m in _flake.allMatches(f.readAsStringSync()))
          if (!palette.contains(int.parse(m[2]!, radix: 16))) '${f.path}: ${m[1]} 0x${m[2]}',
    ];
    expect(off, isEmpty, reason: 'Use a colour from paperColors (geometry.dart).');
  });
}
