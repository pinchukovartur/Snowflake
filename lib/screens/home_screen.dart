import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import '../widgets/ds.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.game, required this.onPlay, required this.onGallery});
  final GameState game;
  final VoidCallback onPlay, onGallery;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final _ticker = AnimationController(vsync: this, duration: const Duration(hours: 1))..forward();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _openSettings() {
    showDsDialog(
      context,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: widget.game,
          builder: (ctx, _) {
            final g = widget.game;
            return DsDialog(
              title: 'Настройки',
              onClose: () => Navigator.pop(ctx),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DsSwitch(
                    label: 'Музыка',
                    checked: g.music,
                    onChanged: (v) => g.setSetting(music: v),
                  ),
                  const SizedBox(height: 16),
                  DsSwitch(
                    label: 'Звуки',
                    checked: g.sfx,
                    onChanged: (v) => g.setSetting(sfx: v),
                  ),
                  const SizedBox(height: 16),
                  DsSwitch(
                    label: 'Вибрация',
                    checked: g.vibration,
                    onChanged: (v) => g.setSetting(vibration: v),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    return SkyBackground(
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: _FallingFlakes(saved: g.saved, ticker: _ticker),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(screenPad, 8, screenPad, 8),
                  child: Row(
                    children: [
                      CurrencyPill(amount: g.coins),
                      const Spacer(),
                      RoundBtn(LucideIcons.settings, label: 'Настройки', variant: Variant.ghost, size: BtnSize.s, onTap: _openSettings),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Снежинки',
                        style: display(56, weight: FontWeight.w900, height: 1, shadows: drop(5)).copyWith(letterSpacing: -.56),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Сложи. Вырежи. Раскрой.',
                        style: body(17, weight: FontWeight.w800, color: C.ice200),
                      ),
                      const SizedBox(height: 28),
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _ticker,
                          builder: (_, child) {
                            final sec = _ticker.lastElapsedDuration?.inMicroseconds ?? 0;
                            final t = sec / 1e6;
                            final float = -4 + 4 * math.cos(t / 4 * 2 * math.pi); // 0 → -8 → 0 over 4s
                            return Transform.translate(
                              offset: Offset(0, float),
                              child: Transform.rotate(angle: (t % 40) / 40 * 2 * math.pi, child: child),
                            );
                          },
                          child: const SnowflakeView(preset: 'lace', size: 250),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
                  child: Column(
                    children: [
                      Btn('Играть', size: BtnSize.l, icon: LucideIcons.play, block: true, onTap: widget.onPlay),
                      const SizedBox(height: 12),
                      Btn('Моя коллекция', variant: Variant.light, icon: LucideIcons.image, block: true, onTap: widget.onGallery),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Flake {
  _Flake(math.Random r, this.item)
    : left = r.nextDouble(),
      size = (18 + r.nextDouble() * 22).roundToDouble(),
      dur = 9 + r.nextDouble() * 8,
      delay = -r.nextDouble() * 16,
      sway = 3 + r.nextDouble() * 3,
      op = .55 + r.nextDouble() * .4;
  final SavedFlake item;
  final double left, size, dur, delay, sway, op;
}

/// The player's saved flakes drifting down behind the Home screen.
class _FallingFlakes extends StatefulWidget {
  const _FallingFlakes({required this.saved, required this.ticker});
  final List<SavedFlake> saved;
  final AnimationController ticker;

  @override
  State<_FallingFlakes> createState() => _FallingFlakesState();
}

class _FallingFlakesState extends State<_FallingFlakes> {
  late final List<_Flake> _flakes;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    final s = widget.saved;
    _flakes = s.isEmpty ? [] : List.generate(14, (i) => _Flake(r, s[i % s.length]));
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (_, c) {
          final children = [
            for (final f in _flakes)
              RepaintBoundary(
                child: SnowflakeView(
                  cuts: f.item.cuts,
                  preset: f.item.preset,
                  folds: f.item.folds,
                  color: f.item.color,
                  pattern: f.item.pattern,
                  size: f.size,
                  glow: false,
                ),
              ),
          ];
          return AnimatedBuilder(
            animation: widget.ticker,
            builder: (_, _) {
              final t = (widget.ticker.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6;
              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final (i, f) in _flakes.indexed)
                    Builder(
                      builder: (_) {
                        final ph = ((t - f.delay) / f.dur) % 1;
                        final y = -60 + (c.maxHeight + 60) * ph;
                        final x = f.left * c.maxWidth - 14 * math.cos(t / f.sway * 2 * math.pi);
                        return Positioned(
                          left: x,
                          top: y,
                          child: Opacity(
                            opacity: f.op,
                            child: Transform.rotate(angle: ph * 2 * math.pi, child: children[i]),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
