import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../shop.dart';
import '../theme/tokens.dart';
import 'advent.dart';
import 'ds.dart';

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
/// its price, and a way to restore what was bought before.
Future<void> showShop(BuildContext context, GameState game) {
  final shop = Shop.instance;
  return showDsDialog(
    context,
    builder: (ctx) => ListenableBuilder(
      listenable: Listenable.merge([game, shop]),
      builder: (_, _) => DsDialog(
        title: tr('shop'),
        onClose: () => Navigator.pop(ctx),
        actions: [
          // For testing: every set back to be bought.
          if (kDebugMode) Btn('${tr('reset_purchases')} (debug)', variant: Variant.clear, size: BtnSize.s, block: true, onTap: game.resetPurchases),
          if (shop.available) Btn(tr('restore_purchases'), variant: Variant.clear, size: BtnSize.s, block: true, onTap: shop.restore),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, o) in offers.indexed) ...[if (i > 0) const SizedBox(height: 16), _OfferCard(game: game, offer: o)],
            if (shop.failed != null) ...[const SizedBox(height: 12), Text(tr('purchase_failed'), style: body(14, color: C.berry700))],
          ],
        ),
      ),
    ),
  );
}

/// One set: its name, the papers and stencils in it, and its button: the
/// price, or that it is the player's already.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.game, required this.offer});
  final GameState game;
  final ({String id, List<({bool paper, String id})> items}) offer;

  @override
  Widget build(BuildContext context) {
    final shop = Shop.instance, id = offer.id;
    final owned = game.owns(id), price = shop.price(id);
    final Widget button;
    if (owned) {
      button = Btn(tr('offer_owned'), variant: Variant.success, size: BtnSize.s, icon: LucideIcons.check, block: true);
    } else if (shop.busy.contains(id)) {
      button = Btn('…', variant: Variant.reward, size: BtnSize.s, block: true, disabled: true);
    } else if (price != null) {
      button = Btn(tr('offer_buy', {'price': price}), variant: Variant.reward, size: BtnSize.s, block: true, onTap: () => shop.buy(id));
    } else if (shop.canBuy(id)) {
      button = Btn('${tr('offer_get')} (debug)', variant: Variant.reward, size: BtnSize.s, block: true, onTap: () => shop.buy(id));
    } else {
      button = Btn(tr('shop_unavailable'), size: BtnSize.s, block: true, disabled: true);
    }
    return Container(
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
          const SizedBox(height: 4),
          Text(tr('offer_note'), style: body(13, color: C.snow700, height: 1.2)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (i, r) in offer.items.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: .78,
                    child: RewardTile(reward: r, frame: owned ? C.mint500 : C.sun500),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          button,
        ],
      ),
    );
  }
}

/// What [child] looks like while it is still to be bought: grey, faded, a
/// lock on it (in the corner given, or centred).
class Locked extends StatelessWidget {
  const Locked({super.key, required this.child, this.locked = true, this.lockSize = 14, this.corner = true});
  final Widget child;
  final bool locked, corner;
  final double lockSize;

  static const _grey = ColorFilter.matrix([
    .2126, .7152, .0722, 0, 0, //
    .2126, .7152, .0722, 0, 0,
    .2126, .7152, .0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    final lock = Container(
      padding: EdgeInsets.all(lockSize * .28),
      decoration: const BoxDecoration(
        color: C.night800,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x33101A3F), offset: Offset(0, 1.5), blurRadius: 2)],
      ),
      child: Icon(LucideIcons.lock, size: lockSize, color: C.sun300),
    );
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Opacity(
          opacity: .5,
          child: ColorFiltered(colorFilter: _grey, child: child),
        ),
        if (corner) Positioned(top: 0, right: 0, child: lock) else lock,
      ],
    );
  }
}
