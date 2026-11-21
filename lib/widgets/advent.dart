import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../snowflake/geometry.dart';
import '../theme/tokens.dart';
import 'ds.dart';
import 'glint.dart';
import 'lock_icon.dart';
import 'paper_dialog.dart';

/// The advent calendar's green and red, and the gold of its numbers.
const _green = Color(0xFF1E6B4F), _red = Color(0xFFC0283B), _gold = Color(0xFFFFD34D);

/// The colour each advent (or shop) paper is shown on behind its door or in
/// its set.
const _paperShown = {'snowfall': Color(0xFF3E61B8), 'candy': Color(0xFFE0405E), 'chocolate': Color(0xFF713600), 'garland': Color(0xFF1E6B4F), 'tartan': Color(0xFF8E1F3A)};

/// The home screen's way into the advent calendar: a little green door with a
/// red frame and a gift on it, and the count of doors ready to open.
class AdventButton extends StatelessWidget {
  const AdventButton({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final waiting = game.adventWaiting;
    return Semantics(
      button: true,
      label: tr('advent'),
      child: GestureDetector(
        onTap: () => showAdvent(context, game),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(R.m),
                border: Border.all(color: _red, width: 4),
                boxShadow: const [BoxShadow(color: Color(0xFF14503A), offset: Offset(0, 5))],
              ),
              child: const Icon(LucideIcons.gift, size: 30, color: _gold),
            ),
            // Light running over it while a door is ready to open.
            if (waiting > 0) const Positioned.fill(child: Glint(radius: R.m)),
            if (waiting > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.berry500,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text('$waiting', style: display(12, height: 1)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Debug builds' cheat over the calendar's button: arrows stepping the day
/// taken as today (see [GameState.adventCheatDay]) from 18 to 25 December
/// and back; "—" for today as it is.
class AdventCheat extends StatelessWidget {
  const AdventCheat({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final i = game.adventCheatDay;
    void step(int by) => game.setAdventCheatDay(i == null ? (by > 0 ? 0 : adventRewards.length - 1) : (i + by).clamp(0, adventRewards.length - 1));
    Widget arrow(IconData icon, int by) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => step(by),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: const Color(0x99101A3F), borderRadius: BorderRadius.circular(R.s)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          arrow(LucideIcons.chevronLeft, -1),
          // A tap on the day goes back to today as it is.
          GestureDetector(
            onTap: () => game.setAdventCheatDay(null),
            child: SizedBox(
              width: 28,
              child: Text(i == null ? '—' : '${adventDay(i, DateTime.now()).day}', textAlign: TextAlign.center, style: display(16, height: 1)),
            ),
          ),
          arrow(LucideIcons.chevronRight, 1),
        ],
      ),
    );
  }
}

/// Opens the advent calendar over the screen.
Future<void> showAdvent(BuildContext context, GameState game) => showDsDialog(
  context,
  builder: (ctx) => ListenableBuilder(
    listenable: game,
    builder: (_, _) => DsDialog(
      title: tr('advent'),
      onClose: () => Navigator.pop(ctx),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr('advent_note'),
            textAlign: TextAlign.center,
            style: body(15, color: C.night800),
          ),
          const SizedBox(height: 16),
          // Its eight doors, four to a row.
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              children: [
                for (var col = 0; col < 4; col++) ...[
                  if (col > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _Door(game: game, index: row * 4 + col),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  ),
);

/// One of the calendar's doors: shut, its day on it (dim, with a lock, till
/// that day comes); a tap on it once its day has come opens it for good,
/// showing what was behind it.
class _Door extends StatelessWidget {
  const _Door({required this.game, required this.index});
  final GameState game;
  final int index;

  @override
  Widget build(BuildContext context) {
    final open = game.adventOpened(index), ready = game.adventReady(index);
    final reward = adventRewards[index];
    final day = adventDay(index, game.adventToday).day;
    return GestureDetector(
      // Locked doors too in debug builds (see [adventAnyDay]).
      onTap: ready || (adventAnyDay && !open) ? () => game.openAdvent(index) : null,
      child: AspectRatio(
        aspectRatio: .78,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, a) => ScaleTransition(
            scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
            child: child,
          ),
          child: open ? RewardTile(key: const ValueKey(true), reward: reward) : _Shut(key: const ValueKey(false), day: day, ready: ready),
        ),
      ),
    );
  }
}

/// A shut door: green in a red frame, its day in gold; before its day, a
/// big lock under the day.
class _Shut extends StatelessWidget {
  /// How tall a shut door's lock is, as a share of the door's width.
  static const _lockShare = .8;

  const _Shut({super.key, required this.day, required this.ready});
  final int day;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(R.s),
        border: Border.all(color: _red, width: 3),
        boxShadow: const [BoxShadow(color: Color(0xFF14503A), offset: Offset(0, 4))],
      ),
      alignment: Alignment.center,
      // Its day up top; before it comes, a big lock under it, filling the
      // rest of the door.
      child: ready
          ? Text(
              '$day',
              style: display(26, weight: FontWeight.w900, color: _gold, height: 1),
            )
          : LayoutBuilder(
              builder: (_, box) => Padding(
                padding: EdgeInsets.only(top: box.maxHeight * .07, bottom: box.maxHeight * .05),
                child: Column(
                  children: [
                    Text(
                      '$day',
                      style: display(26, weight: FontWeight.w900, color: _gold, height: 1),
                    ),
                    Expanded(
                      child: Center(child: LockIcon(size: math.min(box.maxWidth * _lockShare, box.maxHeight * .55), advent: true)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A paper or stencil from the calendar, and what it is: behind an open
/// door, framed in [frame], or in one of the shop's sets, framed with the
/// rest of its set (no [frame] of its own) on [background]. A paper is shown
/// in [colour], or its own (see [_paperShown]).
class RewardTile extends StatelessWidget {
  const RewardTile({super.key, required this.reward, this.frame = _red, this.background = C.paper, this.colour});
  final ({bool paper, String id}) reward;
  final Color? frame;
  final Color background;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final id = reward.id;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(R.s),
        border: frame == null ? null : Border.all(color: frame!, width: 3),
      ),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: reward.paper
                  ? AnimatedSwitcher(
                      // A new colour fading in over the last, as the shop's turn;
                      // the last solid under it till it is gone (each colour's
                      // swatch drawn once, only faded).
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => child.key == ValueKey(colour) ? FadeTransition(opacity: anim, child: child) : child,
                      child: PaperSwatch(key: ValueKey(colour), color: colour ?? _paperShown[id] ?? Colors.white, pattern: id, flat: true),
                    )
                  : AspectRatio(aspectRatio: 1, child: CustomPaint(painter: _StencilPainter(id))),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(tr(reward.paper ? 'pattern_$id' : 'stencil_$id'), style: display(12, color: C.night800)),
          ),
        ],
      ),
    );
  }
}

/// Stencil [id]'s outline, filled, across the room given.
class _StencilPainter extends CustomPainter {
  const _StencilPainter(this.id);
  final String id;

  /// The dashes' length, the gaps between and the line's width, as shares of
  /// the room given.
  static const _dash = .07, _gap = .05, _line = .04;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final outline = Path();
    for (final part in stencilParts(id, size.width / 2, size.height / 2, s * .42)) {
      outline.addPolygon(part, true);
    }
    // As the stencil shows on the cut board: a pale pink inside, a dashed red
    // line round it.
    canvas.drawPath(outline, Paint()..color = const Color(0x2EE0405E));
    drawDashed(
      canvas,
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * _line
        ..strokeCap = StrokeCap.round
        ..color = C.berry600,
      s * _dash,
      s * _gap,
    );
  }

  @override
  bool shouldRepaint(_StencilPainter old) => old.id != id;
}
