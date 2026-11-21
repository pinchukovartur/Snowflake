import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Lays [child] out as on the screen it was designed on, [designDpr] device
/// pixels to the logical pixel, and scales it to this one: the same size in
/// device pixels on any screen, however dense, so a picture drawn a pixel
/// of it to a pixel of the screen (as at [designDpr]) keeps in step with
/// everything else. If that would not fit, smaller till it does: no wider
/// than [width] logical pixels across, nor taller than [height] down
/// besides the screen's insets.
///
/// Its child sees the screen as it is laid out in: its size, insets and
/// pixel ratio all in those units. Taps land where they show.
class DesignScale extends StatelessWidget {
  const DesignScale({super.key, required this.designDpr, required this.width, required this.height, required this.child});

  final double designDpr, width, height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final s = math.min(designDpr / mq.devicePixelRatio, math.min(size.width / width, (size.height - mq.padding.vertical) / height));
    final inner = size / s;
    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: inner.width,
      maxWidth: inner.width,
      minHeight: inner.height,
      maxHeight: inner.height,
      child: Transform.scale(
        scale: s,
        alignment: Alignment.topLeft,
        child: MediaQuery(
          data: mq.copyWith(
            size: inner,
            devicePixelRatio: mq.devicePixelRatio * s,
            padding: mq.padding / s,
            viewPadding: mq.viewPadding / s,
            viewInsets: mq.viewInsets / s,
            systemGestureInsets: mq.systemGestureInsets / s,
          ),
          child: child,
        ),
      ),
    );
  }
}
