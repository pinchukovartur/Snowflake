import 'package:flutter/material.dart';

/// Something standing on the floor in front of the home window's door (a fir
/// tree, say), drawn from [image], in a box the home screen lays out for it
/// as wide as [aspect] times its height: taking taps inside its [outline]
/// there.
class WindowDecor {
  const WindowDecor({required this.image, required this.aspect, required this.outline});

  final String image;
  final double aspect;
  final Path Function(Size box) outline;
}

/// What stands in front of the door in this build, set by hand for each
/// release; null for the door alone.
// ignore: unnecessary_nullable_for_final_variable_declarations
const WindowDecor? windowDecor = WindowDecor(image: 'assets/Christmass_Tree.png', aspect: 1035 / 1519, outline: _treeOutline);

/// The ice fir tree's outline in a box [size], roughly: its tip, the skirt
/// of its lowest branches, down to its foot.
Path _treeOutline(Size size) => Path()
  ..addPolygon([
    for (final (x, y) in const [(.5, 0.0), (.8, .5), (1.0, .9), (1.0, 1.0), (0.0, 1.0), (0.0, .9), (.2, .5)]) Offset(size.width * x, size.height * y),
  ], true);
