import 'package:flutter/material.dart';

/// The game's lock, on whatever is still shut (assets/Lock.png): a bauble with
/// a keyhole, [size] high, as wide as its picture is for that.
class LockIcon extends StatelessWidget {
  const LockIcon({super.key, required this.size});
  final double size;

  static const _asset = 'assets/Lock.png';

  /// The picture's width over its height.
  static const _aspect = 589 / 628;

  @override
  Widget build(BuildContext context) => Image.asset(
        _asset,
        width: size * _aspect,
        height: size,
        // Decoded at the size it shows, not the source's.
        cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      );
}
