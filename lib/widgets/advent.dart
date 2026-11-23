import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../snowflake/geometry.dart';
import '../theme/tokens.dart';
import 'ds.dart';
import 'event_title.dart';
import 'glint.dart';
import 'lock_icon.dart';
import 'paper_dialog.dart';

/// The advent calendar's red, and the gold of its numbers.
const _red = Color(0xFFC0283B), _gold = Color(0xFFFFD34D);

/// The colour each advent or shop paper is shown in behind its door or in
/// its set, if not the shop's turn of colours.
const _paperShown = {'snowfall': Color(0xFF3E61B8), 'candy': Color(0xFFE0405E), 'chocolate': Color(0xFF713600), 'garland': Color(0xFF1E6B4F), 'tartan': Color(0xFF8E1F3A)};

/// The home screen's way into the advent calendar: a little blue door (the
/// calendar house's blue) with a red frame and a gift on it, and the count
/// of doors ready to open.
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
                // The calendar house's blue.
                color: _House._front,
                borderRadius: BorderRadius.circular(R.m),
                border: Border.all(color: _red, width: 4),
                boxShadow: const [BoxShadow(color: Color(0xFF18224A), offset: Offset(0, 5))],
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

/// Opens the advent calendar over the screen: its title over a little
/// house, what it is written on the house's front under the roof, its
/// doors under that; a tap beside it closes it.
Future<void> showAdvent(BuildContext context, GameState game) => showDsDialog(
  context,
  padding: const EdgeInsets.symmetric(horizontal: 16),
  builder: (ctx) => ListenableBuilder(
    listenable: game,
    // Up from the middle, its title high on the screen.
    builder: (_, _) => Align(
      alignment: const Alignment(0, -.22),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _House(game: game),
      ),
    ),
  ),
);

/// The advent calendar's house, its title over it: a snowy roof over a dark
/// blue front, what the calendar is written on that under the roof, its
/// eight doors under that four to a row, standing in a drift of snow.
class _House extends StatelessWidget {
  const _House({required this.game});
  final GameState game;

  /// The title's red, running down it: the shop's sets' and the Christmas
  /// event's.
  static const _titleFade = (Color(0xFFFFA49A), Color(0xFFD11011));

  /// The front's colour; the roof's snow, and its shade.
  static const _front = Color(0xFF26346A), _snow = Color(0xFFF5FAFF), _snowShade = Color(0xFFCFE3F5);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, box) {
        final w = box.maxWidth;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          // As the shop's sets are titled.
          EventTitle(tr('advent'), loud: true, size: 34, maxLines: 1, fade: _titleFade),
          const SizedBox(height: 10),
          // The roof, wider than the front, its eaves out either side.
          SizedBox(width: w, height: w * .34, child: const CustomPaint(painter: _RoofPainter())),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * .05),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 22),
              color: _front,
              child: Column(children: [
                Text(tr('advent_note'), textAlign: TextAlign.center, style: body(15, weight: FontWeight.w700, color: Colors.white, height: 1.25)),
                const SizedBox(height: 16),
                for (var row = 0; row < 2; row++) ...[
                  if (row > 0) const SizedBox(height: 12),
                  Row(children: [
                    for (var col = 0; col < 4; col++) ...[
                      if (col > 0) const SizedBox(width: 10),
                      Expanded(child: _Door(game: game, index: row * 4 + col)),
                    ],
                  ]),
                ],
              ]),
            ),
          ),
          // The drift it stands in.
          Container(
            width: w,
            height: 18,
            decoration: BoxDecoration(
              color: _snow,
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [BoxShadow(color: _snowShade, offset: Offset(0, 3))],
            ),
          ),
        ]);
      });
}

/// The house's roof across its box: a steep gable of the front's blue, under
/// a thick snowy roof running out past the front either side, its snow
/// shaded along the underside.
class _RoofPainter extends CustomPainter {
  const _RoofPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // The roof: a thick band from the ridge down to the eaves either side.
    final t = h * .2;
    // The gable, filling in all under the roof down to the front's top: its
    // top edge the roof's underside, out to the front's sides.
    double under(double x) => t + (h * .86 + t * .55 - t) * (x - .5).abs() / .5;
    canvas.drawPath(
      Path()..addPolygon([Offset(w * .5, t), Offset(w * .95, under(.95)), Offset(w * .95, h), Offset(w * .05, h), Offset(w * .05, under(.05))], true),
      Paint()..color = _House._front,
    );
    final roof = Path()
      ..moveTo(w * .5, 0)
      ..lineTo(w, h * .86)
      ..lineTo(w, h * .86 + t * .55)
      ..lineTo(w * .5, t)
      ..lineTo(0, h * .86 + t * .55)
      ..lineTo(0, h * .86)
      ..close();
    canvas.drawPath(roof.shift(Offset(0, t * .25)), Paint()..color = _House._snowShade);
    canvas.drawPath(roof, Paint()..color = _House._snow);
    // A round window in the gable, warm with light.
    canvas.drawCircle(Offset(w * .5, h * .6), h * .13, Paint()..color = const Color(0xFFFFE08A));
    canvas.drawCircle(
      Offset(w * .5, h * .6),
      h * .13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _House._snow,
    );
  }

  @override
  bool shouldRepaint(_RoofPainter old) => false;
}

/// One of the calendar's doors: a blue card outlined in dashes, its day on it
/// (and a lock under that, till its day comes); a tap on it once its day has
/// come opens it for good. Opening, a solid line runs round along the
/// dashes, as if they were being cut through, and the card cut out comes
/// away on what was behind it.
class _Door extends StatefulWidget {
  const _Door({required this.game, required this.index});
  final GameState game;
  final int index;

  @override
  State<_Door> createState() => _DoorState();
}

class _DoorState extends State<_Door> with SingleTickerProviderStateMixin {
  /// The whole opening: the cut running round, then the card coming away.
  late final _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..addListener(() => setState(() {}));

  /// Where the cut ends and the card starts coming away, as a share of
  /// [_open].
  static const _cutEnd = .65;

  /// The beat between the cut done and the card coming away, as a share of
  /// [_open]: a couple of frames.
  static const _beat = .03;

  /// How far the card cut out turns as it flies off, in radians.
  static const _flyTurn = .25;

  /// How far the card cut out flies off, up and to the left, as a share of
  /// its size each way.
  static const _fly = .6;

  /// How far into its flight the card cut out starts to fade.
  static const _fadeFrom = .5;

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _tap() {
    widget.game.openAdvent(widget.index);
    if (widget.game.adventOpened(widget.index)) _open.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game, index = widget.index;
    final open = game.adventOpened(index), ready = game.adventReady(index);
    final reward = adventRewards[index];
    final day = adventDay(index, game.adventToday).day;
    // Shut again (the calendar's cheat going back in time): as it was.
    if (!open && _open.value > 0) _open.value = 0;
    final opening = open && _open.isAnimating;
    final t = _open.value;
    double stage(double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);
    final cut = opening ? Curves.easeInOut.transform(stage(0, _cutEnd)) : 0.0;
    // Off quickly, easing as it goes; fading only over the latter half of it.
    // A beat after the cut is done before it comes away.
    const flyFrom = _cutEnd + _beat;
    final away = opening ? Curves.easeOutCubic.transform(stage(flyFrom, 1)) : 0.0;
    final gone = opening ? stage(flyFrom + (1 - flyFrom) * _fadeFrom, 1) : 0.0;
    final card = GestureDetector(
      // Locked doors too in debug builds (see [adventAnyDay]).
      onTap: !open && (ready || adventAnyDay) ? _tap : null,
      child: AspectRatio(
        aspectRatio: .78,
        child: open && !opening
            ? RewardTile(reward: reward)
            : Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
                if (open) RewardTile(reward: reward),
                // Cut out, the card coming away: flying off up and to the
                // left ([_fly] of its size each way), turning a little that
                // way and growing as it fades.
                Opacity(
                  opacity: 1 - gone,
                  child: FractionalTranslation(
                    translation: const Offset(-_fly, -_fly) * away,
                    child: Transform.rotate(
                      angle: -_flyTurn * away,
                      // Open now, so no longer "ready": shown as it was, its day come.
                      child: Transform.scale(scale: 1 + .15 * away, child: _Shut(day: day, ready: ready || opening, cut: cut)),
                    ),
                  ),
                ),
              ]),
      ),
    );
    return card;
  }
}

/// A shut door: a card of the house's blue outlined in gold dashes just
/// inside its rounded edge, its day on it, and before that day a big lock
/// under it. Flat. Opening: a solid line running round along the dashes
/// ([cut], 0 to 1, how far round), both whitening as it goes; the lock stays
/// on, coming away with the card.
class _Shut extends StatelessWidget {
  /// How tall a shut door's lock is, as a share of the door's width, and at
  /// most of its height.
  static const _lockShare = .8, _lockHeightShare = .5;

  /// A day still to come's number: the lock's pale blue.
  static const _lockedDay = Color(0xFFCDE8FF);

  const _Shut({required this.day, required this.ready, this.cut = 0});
  final int day;
  final bool ready;
  final double cut;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // The house's own blue.
      decoration: BoxDecoration(color: _House._front, borderRadius: BorderRadius.circular(R.s)),
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _CutLine(cut: cut)),
        // Its day: in the middle, or up top over the lock till it comes.
        LayoutBuilder(builder: (_, box) {
          // Gold once its day has come; pale blue, as its lock, till then.
          final number = Text('$day', style: display(box.maxWidth * .34, weight: FontWeight.w900, color: ready ? _gold : _lockedDay, height: 1));
          if (ready) return Center(child: number);
          return Padding(
            padding: EdgeInsets.only(top: box.maxHeight * .1, bottom: box.maxHeight * .07),
            child: Column(children: [
              number,
              Expanded(child: Center(child: LockIcon(size: math.min(box.maxWidth * _lockShare, box.maxHeight * _lockHeightShare), advent: true))),
            ]),
          );
        }),
      ]),
    );
  }
}

/// A door's outline just inside its rounded edge: in gold dashes, and over
/// them, [cut] of the way round from the middle of its top, a solid line, as
/// if the dashes were being cut through; both whitening the further round it
/// has got.
class _CutLine extends CustomPainter {
  const _CutLine({required this.cut});
  final double cut;

  /// The dashes' length and the gaps between, and the line's width.
  static const _dash = 6.0, _gap = 4.0, _width = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    const e = _width / 2, k = R.s - e;
    final w = size.width, h = size.height;
    // Round from the middle of its top, clockwise, back to there.
    final path = Path()
      ..moveTo(w / 2, e)
      ..lineTo(w - e - k, e)
      ..arcToPoint(Offset(w - e, e + k), radius: const Radius.circular(k))
      ..lineTo(w - e, h - e - k)
      ..arcToPoint(Offset(w - e - k, h - e), radius: const Radius.circular(k))
      ..lineTo(e + k, h - e)
      ..arcToPoint(Offset(e, h - e - k), radius: const Radius.circular(k))
      ..lineTo(e, e + k)
      ..arcToPoint(Offset(e + k, e), radius: const Radius.circular(k))
      ..close();
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(_gold, Colors.white, cut)!;
    drawDashed(canvas, path, line, _dash, _gap);
    if (cut > 0) {
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * cut), line);
      }
    }
  }

  @override
  bool shouldRepaint(_CutLine old) => old.cut != cut;
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

/// Stencil [id]'s outline (each of its parts) across the room given, as the
/// stencil shows on the cut board: a pale pink inside, a dashed red line round
/// it.
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
