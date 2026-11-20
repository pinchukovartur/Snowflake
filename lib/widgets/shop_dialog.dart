import 'dart:async';
import 'dart:math' as math;

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
                    cuts: [if (stencil != null) stencilShape(stencil, _stencilAt.dx, _stencilAt.dy, _stencilSize)],
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
          // The sets down at the foot, by the buttons there; scrolling if the
          // screen is too short for them.
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final (i, o) in offers.indexed) ...[
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
          if (shop.available) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Btn(tr('restore_purchases'), variant: Variant.light, size: BtnSize.s, block: true, onTap: shop.restore),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// One set: its name, the papers and stencils in it, and its button: the
/// price, or that it is the player's already. A tap on a paper or stencil
/// calls [onTry]; those [tried] on the demo flake are framed so.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.game, required this.offer, required this.tried, required this.onTry, required this.colour});
  final GameState game;
  final ({String id, List<_Item> items}) offer;
  final Set<String> tried;
  final ValueChanged<_Item> onTry;

  /// The colour its papers are shown in.
  final Color colour;

  /// Behind a paper or stencil on the demo flake: mustard.
  static const _triedTint = Color(0x59E1AD21);

  @override
  Widget build(BuildContext context) {
    final shop = Shop.instance, id = offer.id;
    final owned = game.owns(id), price = shop.price(id);
    // None once it is the player's: a tag on its corner says so instead.
    final Widget? button;
    if (owned) {
      button = null;
    } else if (shop.busy.contains(id)) {
      button = Btn('…', variant: Variant.reward, size: BtnSize.s, block: true, disabled: true);
    } else if (price != null) {
      button = Btn(tr('offer_buy', {'price': price}), variant: Variant.reward, size: BtnSize.s, block: true, onTap: () => shop.buy(id));
    } else if (shop.canBuy(id)) {
      button = Btn('${tr('offer_get')} (debug)', variant: Variant.reward, size: BtnSize.s, block: true, onTap: () => shop.buy(id));
    } else {
      button = Btn(tr('shop_unavailable'), size: BtnSize.s, block: true, disabled: true);
    }
    final card = Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: C.paper,
        borderRadius: BorderRadius.circular(R.m),
        boxShadow: const [BoxShadow(color: C.snow300, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr('offer_$id'), style: display(19, color: C.night800, height: 1.1)),
          const SizedBox(height: 10),
          // The set's papers and stencils in one frame together; the ones
          // on the demo flake tinted.
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(R.s + 4),
              border: Border.all(color: owned ? C.mint500 : C.sun500, width: 3),
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
                        child: RewardTile(reward: r, frame: null, colour: colour, background: tried.contains(r.id) ? _triedTint : C.paper),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Before buying, what it is (a one-time purchase) and how to buy
          // it; after, only room for the "owned" tag at the corner.
          if (button != null) ...[
            const SizedBox(height: 8),
            Text(tr('offer_note'), style: body(13, color: C.snow700, height: 1.2)),
            const SizedBox(height: 10),
            button,
          ] else
            const SizedBox(height: 18),
        ],
      ),
    );
    if (!owned) return card;
    return Stack(clipBehavior: Clip.none, children: [card, const Positioned(bottom: -10, right: -6, child: _OwnedTag())]);
  }
}

/// On the bottom corner of a set the player has: a slanted bright green tag, a tick
/// and "Owned!" on it.
class _OwnedTag extends StatelessWidget {
  const _OwnedTag();

  static const _green = Color(0xFF3FEA6E);

  @override
  Widget build(BuildContext context) => Stack(children: [
        // The tag leaning forward, as its italics do; the words on it in
        // the game's own face, italic, not leant.
        Positioned.fill(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-.2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [BoxShadow(color: Color(0x40101A3F), offset: Offset(0, 2), blurRadius: 3)],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.check, size: 18, color: C.night800),
            const SizedBox(width: 4),
            Text(tr('offer_owned'), style: display(16, weight: FontWeight.w900, color: C.night800, height: 1).copyWith(fontStyle: FontStyle.italic)),
          ]),
        ),
      ]);
}

/// What [child] looks like while it is still to be bought: as ever, a lock
/// on its top right corner.
class Locked extends StatelessWidget {
  const Locked({super.key, required this.child, this.locked = true, this.lockSize = 14});
  final Widget child;
  final bool locked;
  final double lockSize;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        child,
        // A touch out past the corner.
        Positioned(top: -2, right: -2, child: LockIcon(size: lockSize)),
      ],
    );
  }
}
