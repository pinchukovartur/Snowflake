import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../snowflake/geometry.dart';
import '../snowflake/snowflake_view.dart';
import '../widgets/ds.dart';
import '../widgets/flake_turn_zoom.dart';

/// A flake from the collection on its own, on the reveal's sky: turn it and
/// zoom it, then go back.
class FlakeScreen extends StatefulWidget {
  const FlakeScreen({super.key, required this.flake, required this.onBack});
  final SavedFlake flake;
  final VoidCallback onBack;

  @override
  State<FlakeScreen> createState() => _FlakeScreenState();
}

class _FlakeScreenState extends State<FlakeScreen> with TickerProviderStateMixin, FlakeTurnZoom {
  @override
  double get flakeRadius => 160;

  @override
  void initState() {
    super.initState();
    if (shimmers(widget.flake.pattern)) startTwinkle();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.flake;
    return SkyBackground(
      child: SafeArea(
        child: Stack(children: [
          turnZoomGestures(),
          Center(
            child: turnZoomFlake(
              (turn) => SnowflakeView(cuts: f.cuts, folds: f.folds, color: f.color, pattern: f.pattern, size: 320, spin: turn, twinkle: twinkleAt),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: Btn('Назад', icon: LucideIcons.arrowLeft, variant: Variant.light, block: true, onTap: widget.onBack),
          ),
        ]),
      ),
    );
  }
}
