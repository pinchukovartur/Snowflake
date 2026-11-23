import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../shop.dart';
import '../snowflake/geometry.dart';
import '../snowflake/snowflake_view.dart';
import '../theme/tokens.dart';
import 'advent.dart';
import 'ds.dart';
import 'event_title.dart';
import 'glint.dart';
import 'lock_icon.dart';

/// The home screen's way into the shop: a gold bag on berry, the calendar's
/// size, with a star on it while some set is still to be had.
class ShopButton extends StatelessWidget {
  const ShopButton({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final left = offers.any((o) => !game.owns(o.id));
    return Semantics(
      button: true,
      label: tr('shop'),
      child: GestureDetector(
        onTap: () => showShop(context, game),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: C.berry600,
                borderRadius: BorderRadius.circular(R.m),
                border: Border.all(color: C.sun500, width: 4),
                boxShadow: const [BoxShadow(color: C.berry800, offset: Offset(0, 5))],
              ),
              child: const Icon(LucideIcons.shoppingBag, size: 30, color: C.sun300),
            ),
            // Light running over it while there is a set to be had.
            if (left) const Positioned.fill(child: Glint(radius: R.m)),
            if (left)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.sun500,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(LucideIcons.star, size: 13, color: C.night800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the shop over the screen: each of the [offers], what it holds and
/// its price, and a way to restore what was bought before; over it, a flake
/// to try what the sets hold on (see [_ShopView]), with [trying] on it
/// already: the locked paper or stencil tapped to come here; its papers in
/// [colour] first, if that is the paper's colour the player came with.
Future<void> showShop(BuildContext context, GameState game, {({bool paper, String id})? trying, Color? colour}) =>
    // Laid out to the screen's edges itself: its top bar as the screens' own.
    showDsDialog(
      context,
      padding: EdgeInsets.zero,
      builder: (ctx) => _ShopView(game: game, trying: trying, colour: colour),
    );

/// A paper or stencil from a set.
typedef _Item = ({bool paper, String id});

/// The shop's window: a demo flake up top, and under it the shop itself. A
/// tap on a paper in a set lays it on the flake; a tap on a stencil cuts it
/// out of the middle of the flake's cone, in place of the one cut before.
class _ShopView extends StatefulWidget {
  const _ShopView({required this.game, this.trying, this.colour});
  final GameState game;

  /// On the demo flake from the start, if given.
  final _Item? trying;

  /// The paper colour the player came with, shown first in the turn of
  /// colours (see [_ShopViewState._colors]) unless it is white.
  final Color? colour;

  @override
  State<_ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends State<_ShopView> {
  /// The paper and the stencil on the demo flake: none at first, but what
  /// the shop was opened to try.
  late String? _paper = widget.trying?.paper == true ? widget.trying!.id : null;
  late String? _stencil = widget.trying?.paper == false ? widget.trying!.id : null;

  /// The colours the papers are shown in, by turns (see [_turn]): white,
  /// then the palette's bright ones.
  static final _turnColors = [
    for (final id in const ['white', 'red', 'orange', 'green', 'blue', 'violet']) paperColors.firstWhere((c) => c.id == id).color,
  ];

  /// The turn of colours here: [_turnColors], led by the colour the player
  /// came with (out of its place among them, if it is one), white aside.
  late final _colors = switch (widget.colour) {
    final c? when c.toARGB32() != 0xFFFFFFFF => [c, for (final t in _turnColors) if (t != c) t],
    _ => _turnColors,
  };

  /// The sets in the order shown: those still to buy first, those bought
  /// under them. Settled as the shop opens and kept while it is open, so a
  /// set bought here stays where it was till the shop is opened again.
  late final _offers = [
    for (final o in offers)
      if (!widget.game.owns(o.id)) o,
    for (final o in offers)
      if (widget.game.owns(o.id)) o,
  ];

  /// How far the sets fade out at the scroll's top and bottom edges.
  static const _scrollFade = 24.0;

  /// How long each of [_colors] is shown before the next.
  static const _turn = Duration(seconds: 5);

  /// Which of [_colors] the papers are in now, on the demo flake and in the
  /// sets alike.
  var _colour = 0;
  late final Timer _turner;

  /// How long one colour takes to fade into the next.
  static const _fade = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _turner = Timer.periodic(_turn, (_) => setState(() => _colour = (_colour + 1) % _colors.length));
  }

  @override
  void dispose() {
    _turner.cancel();
    super.dispose();
  }

  /// The room between the buttons in the top bar.
  static const _barGap = 10.0;

  /// How big the demo flake is across.
  static const _flakeSize = 220.0;

  /// Where the stencil is cut, in wedge units (the apex at the origin, the
  /// cone pointing up, its rim a unit off): on its middle line, nearer the
  /// rim than the apex, and its size there.
  static const _stencilAt = Offset(0, -.72), _stencilSize = .15;

  void _try(_Item item) => setState(() => item.paper ? _paper = item.id : _stencil = item.id);

  @override
  Widget build(BuildContext context) {
    final game = widget.game, shop = Shop.instance;
    final paper = _paper, stencil = _stencil;
    // The screen's inset at its foot, as the dialog stops short of it.
    final footInset = MediaQueryData.fromView(View.of(context)).padding.bottom;
    return ListenableBuilder(
      listenable: Listenable.merge([game, shop]),
      // No card behind it: the sets straight on the scrim; up top, as on a
      // screen's top bar (see the duel's), the title in the middle (its top
      // where the duel's progress bar's is) and the way out at the right;
      // the flake under them; the store's own buttons at the foot.
      builder: (ctx, _) => Column(
        children: [
          TopBar(
            // As wide as what is at the right, so the title keeps to the middle.
            left: const SizedBox(width: kDebugMode ? 2 * 44 + _barGap : 44),
            title: tr('shop'),
            // As tall as the duel's progress bar, so the bar sits as the
            // duel's does; the title, a little taller, running on below.
            heading: SizedBox(
              height: 48,
              child: OverflowBox(alignment: Alignment.topCenter, minWidth: 0, maxHeight: 52, child: DsDialogTitle(tr('shop'))),
            ),
            right: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // For testing: every set back to be bought (as the board's
                // restart, in the tutorial skip's orange).
                if (kDebugMode) ...[
                  RoundBtn(LucideIcons.rotateCcw, label: '${tr('reset_purchases')} (debug)', variant: Variant.orange, size: BtnSize.s, onTap: game.resetPurchases),
                  const SizedBox(width: _barGap),
                ],
                // Placed as the duel's back button is, in a dialog's red.
                RoundBtn(LucideIcons.x, label: tr('close'), variant: Variant.primary, size: BtnSize.s, onTap: () => Navigator.pop(ctx)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // The flake, and "Try it!" at its upper left, in italics, tilted up 5°.
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              const SizedBox(width: double.infinity),
              FlakeShadow(
                size: _flakeSize,
                // Each colour fading in over the last, which stays solid
                // under it till it is gone: the same blend as the colour
                // itself running into the next, but each colour's flake
                // drawn once and only faded, not drawn again for every shade
                // between.
                child: AnimatedSwitcher(
                  duration: _fade,
                  transitionBuilder: (child, anim) => child.key == ValueKey(_colour) ? FadeTransition(opacity: anim, child: child) : child,
                  child: SnowflakeView(
                    key: ValueKey(_colour),
                    cuts: [if (stencil != null) ...stencilParts(stencil, _stencilAt.dx, _stencilAt.dy, _stencilSize)],
                    size: _flakeSize,
                    color: _colors[_colour],
                    pattern: paper ?? 'plain',
                  ),
                ),
              ),
              Positioned(
                left: 36,
                top: 4,
                child: Transform.rotate(
                  angle: -5 * math.pi / 180,
                  child: Text(
                    tr('try_it'),
                    style: display(24, shadows: drop(3)).copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // The sets down at the foot, scrolling if the screen is too short
          // for them: fading out at the top rather than cut off there, and
          // running on down under the screen's inset at its foot, to its
          // very edge (the dialog stops short of it, see [showDsDialog]).
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) => OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: box.maxHeight + footInset,
                child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (r) {
                final f = r.height <= 0 ? 0.0 : (_scrollFade / r.height).clamp(0.0, 1.0);
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0x00000000), Color(0xFF000000)],
                  stops: [0, f],
                ).createShader(r);
              },
              child: SingleChildScrollView(
                // Room at the top as deep as the fade, so scrolled right up
                // the first set shows whole; at the foot, clear of the
                // screen's inset and as far from it as ever.
                padding: EdgeInsets.fromLTRB(24, _scrollFade, 24, footInset + 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: math.max(0, box.maxHeight - _scrollFade - 24)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final (i, o) in _offers.indexed) ...[
                        if (i > 0) const SizedBox(height: 16),
                        _OfferCard(game: game, offer: o, tried: {?paper, ?stencil}, onTry: _try, colour: _colors[_colour]),
                      ],
                      if (shop.failed != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          tr('purchase_failed'),
                          textAlign: TextAlign.center,
                          style: body(14, color: Colors.white),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
                ),
              ),
            ),
          ),
          // Restoring purchases is in the settings (see the home screen's).
        ],
      ),
    );
  }
}

/// One set: its name, the papers and stencils in it, and its button: the
/// price, or that it is the player's already. A tap on a paper or stencil
/// calls [onTry]; those [tried] on the demo flake are framed so.
class _OfferCard extends StatelessWidget {
  /// The set's title's red, running down it: the Christmas event's (Help
  /// Santa's).
  static const _titleFade = (Color(0xFFFFA49A), Color(0xFFD11011));

  const _OfferCard({required this.game, required this.offer, required this.tried, required this.onTry, required this.colour});
  final GameState game;
  final ({String id, List<_Item> items}) offer;
  final Set<String> tried;
  final ValueChanged<_Item> onTry;

  /// The colour its papers are shown in.
  final Color colour;

  /// Behind a paper or stencil on the demo flake: warm cream.
  static const _triedTint = Color(0xFFFFF7EC);

  /// Each set's card, so the sets tell apart: the winter treats' warm beige,
  /// the holiday's berry. A set not here on paper white. Flat, no lip under it.
  static const _grounds = {
    'pack_snow_day': ui.Color.fromARGB(255, 255, 236, 211),
    'pack_holiday': C.berry100,
  };

  /// The ground under a set's papers and stencils, by set; a set not here
  /// gets its card's colour a little darker (see [_wellShade]).
  static const _wells = {'pack_snow_day': Color(0xFFDFC1A4)};

  /// How much darker than its card the ground under a set's papers and
  /// stencils is, if not given: its card's colour this far towards the night
  /// ink.
  static const _wellShade = .07;

  /// The sets with a candy cane border: the winter treats.
  static const _canes = {'pack_snow_day'};

  /// A sprig behind a set's buy button, by set: green leaves with a red bow,
  /// for the winter treats.
  static const _sprigs = {'pack_snow_day': 'assets/Christmas/Christmas_Offer1_Leafs.png'};

  /// How wide a sprig is, and its picture's height over width.
  static const _sprigWidth = 230.0, _sprigAspect = 164 / 517;

  @override
  Widget build(BuildContext context) {
    final shop = Shop.instance, id = offer.id;
    final owned = game.owns(id), price = shop.price(id);
    // None once it is the player's: a tag on its corner says so instead.
    // As wide as its words, in the middle, not the card's whole width.
    final Widget? button;
    if (owned) {
      button = null;
    } else if (shop.busy.contains(id)) {
      button = Btn('…', variant: Variant.reward, size: BtnSize.s, disabled: true);
    } else if (price != null) {
      button = Btn(tr('offer_buy', {'price': price}), variant: Variant.reward, size: BtnSize.s, onTap: () => shop.buy(id));
    } else if (shop.canBuy(id)) {
      button = Btn('${tr('offer_get')} (debug)', variant: Variant.reward, size: BtnSize.s, onTap: () => shop.buy(id));
    } else {
      button = Btn(tr('shop_unavailable'), size: BtnSize.s, disabled: true);
    }
    final ground = _grounds[id] ?? C.paper;
    final sprig = _sprigs[id];
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(R.m),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Set as the Christmas event's title is, Help Santa's red.
          EventTitle(tr('offer_$id'), loud: true, size: 24, maxLines: 1, fade: _titleFade),
          const SizedBox(height: 10),
          // The set's papers and stencils together on a ground a little
          // darker than the card; the ones on the demo flake tinted.
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _wells[id] ?? Color.lerp(ground, C.night800, _wellShade),
              borderRadius: BorderRadius.circular(R.s + 4),
            ),
            child: Row(
              children: [
                for (final (i, r) in offer.items.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: .78,
                      child: GestureDetector(
                        onTap: () => onTry(r),
                        child: RewardTile(reward: r, frame: null, colour: colour, background: tried.contains(r.id) ? _triedTint : Colors.transparent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Before buying, how to buy it and, under that, what it is (a
          // one-time purchase); after, only room for the "owned" tag at the
          // corner.
          if (button != null) ...[
            SizedBox(height: sprig == null ? 12 : 18),
            // Behind the button, taking no room of their own: the set's
            // sprig, if it has one, its leaves out at the button's sides, and
            // over it a glow round the button.
            Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              if (sprig != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: OverflowBox(
                      maxWidth: _sprigWidth,
                      maxHeight: _sprigWidth * _sprigAspect,
                      child: Image.asset(sprig, width: _sprigWidth, cacheWidth: (_sprigWidth * MediaQuery.devicePixelRatioOf(context)).round()),
                    ),
                  ),
                ),
              const Positioned.fill(child: IgnorePointer(child: _ButtonGlow())),
              button,
            ]),
            // Under the sprig's leaves, not over them.
            SizedBox(height: sprig == null ? 6 : 20),
            Text(tr('offer_note'), style: body(13, color: C.snow700, height: 1.2)),
          ] else
            const SizedBox(height: 18),
        ],
      ),
    );
    // The sets with a candy cane round them (see [_canes]), its stripes over
    // the card's edge.
    final framed = _canes.contains(id) ? CustomPaint(foregroundPainter: const _CaneBorder(radius: R.m), child: card) : card;
    if (!owned) return framed;
    return Stack(clipBehavior: Clip.none, children: [framed, const Positioned(bottom: -10, right: -6, child: _OwnedTag())]);
  }
}

/// A soft glow round a set's buy button, in its shape: its rounded box,
/// light cream, blurred out past its edge. Drawn once with the card, not
/// animated.
class _ButtonGlow extends StatelessWidget {
  const _ButtonGlow();

  /// The small button's corner radius (see [BtnSize.s]); how far the glow
  /// spreads out past it and how soft it is.
  static const _radius = 14.0, _spread = 5.0, _blur = 6.0;

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(_radius)),
          boxShadow: [BoxShadow(color: ui.Color.fromARGB(255, 255, 248, 236), spreadRadius: _spread, blurRadius: _blur)],
        ),
      );
}

/// A candy cane round a card of corner [radius]: a thick border along its
/// edge, striped slantwise red and green by turns, white between each, the
/// stripes running on round it. One stroke with a repeating gradient.
class _CaneBorder extends CustomPainter {
  const _CaneBorder({required this.radius});
  final double radius;

  /// How thick the border is, and how wide each stripe across it.
  static const _width = 6.0, _stripe = 7.0;

  static const _red = Color(0xFFE0405E), _white = Color(0xFFFFFFFF), _green = Color(0xFF2FB37E);

  @override
  void paint(Canvas canvas, Size size) {
    // Four stripes to a round (red, white, green, white), measured along
    // the diagonal.
    const step = _stripe * 4 / math.sqrt2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width
      ..shader = ui.Gradient.linear(
        Offset.zero,
        const Offset(step, step),
        const [_red, _red, _white, _white, _green, _green, _white, _white],
        const [0, .25, .25, .5, .5, .75, .75, 1],
        TileMode.repeated,
      );
    // Its stroke wholly on the card, its outer edge the card's.
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).deflate(_width / 2);
    canvas.drawRRect(r, paint);
  }

  @override
  bool shouldRepaint(_CaneBorder old) => old.radius != radius;
}

/// On the bottom corner of a set the player has: a bright green tag, a tick
/// and "Owned!" on it, upright.
class _OwnedTag extends StatelessWidget {
  const _OwnedTag();

  static const _green = Color(0xFF3FEA6E);

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: _green,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Color(0x40101A3F), offset: Offset(0, 2), blurRadius: 3)],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.check, size: 18, color: C.night800),
            const SizedBox(width: 4),
            Text(tr('offer_owned'), style: display(16, weight: FontWeight.w900, color: C.night800, height: 1)),
          ]),
        ),
      );
}

/// What [child] looks like while it is still to be bought: as ever, a lock
/// on its top right corner.
class Locked extends StatelessWidget {
  const Locked({super.key, required this.child, this.locked = true, this.lockSize = 14, this.advent = false});
  final Widget child;
  final bool locked;
  final double lockSize;

  /// Only the advent calendar's: its blue lock (see [LockIcon.advent]).
  final bool advent;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        child,
        // A touch out past the corner.
        Positioned(top: -2, right: -2, child: LockIcon(size: lockSize, advent: advent)),
      ],
    );
  }
}
