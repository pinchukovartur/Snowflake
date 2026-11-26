import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'app_state.dart';

/// Debug builds' stand-in for the store when it has no such product (an
/// emulator, a build Play doesn't know): "buy" hands the set over at once.
/// A release never has it, whatever this says.
const fakePurchases = true && kDebugMode && !storeShots;

/// For testing the settings: their "restore purchases" button shown even
/// with no store to reach (an emulator), where a tap does nothing. Debug
/// builds only, as [fakePurchases].
const showRestoreAlways = true && kDebugMode && !storeShots;

/// The shop: the [offers] as Google Play has them (their prices), buying
/// them, and what was bought before coming back (on this device or another)
/// through restoring, which it asks for at launch. Each one bought or
/// restored goes to [GameState.grant].
class Shop extends ChangeNotifier {
  Shop._();
  static final instance = Shop._();

  late GameState _game;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Whether the store can be reached at all.
  bool available = false;

  /// The offers' products as the store has them, by id: their prices are
  /// shown, and only those here can be bought.
  final products = <String, ProductDetails>{};

  /// Offers whose purchase is under way (the store's sheet up, or a payment
  /// pending), by id.
  final busy = <String>{};

  /// The last purchase that failed, by offer id, for the shop to say so;
  /// cleared on the next try.
  String? failed;

  Future<void> init(GameState game) async {
    _game = game;
    final iap = InAppPurchase.instance;
    try {
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (Object e) => debugPrint('Purchases: $e'));
      available = await iap.isAvailable();
      if (!available) return;
      final res = await iap.queryProductDetails({for (final o in offers) o.id});
      if (res.notFoundIDs.isNotEmpty) debugPrint('Not in the store: ${res.notFoundIDs}');
      products.addAll({for (final p in res.productDetails) p.id: p});
      await iap.restorePurchases();
    } catch (e) {
      // A store that can't be reached must not stop the game.
      debugPrint('Shop not ready: $e');
    }
    notifyListeners();
  }

  /// The offer's price as the store gives it, in the player's currency.
  String? price(String offer) => products[offer]?.price;

  /// Whether [offer] can be bought here and now.
  bool canBuy(String offer) => !_game.owns(offer) && !busy.contains(offer) && (products.containsKey(offer) || fakePurchases);

  Future<void> buy(String offer) async {
    if (!canBuy(offer)) return;
    failed = null;
    final product = products[offer];
    if (product == null) {
      // Only [fakePurchases] gets here (see [canBuy]).
      _game.grant(offer);
      notifyListeners();
      return;
    }
    busy.add(offer);
    notifyListeners();
    try {
      final started = await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      if (!started) busy.remove(offer);
    } catch (e) {
      debugPrint('Purchase not started: $e');
      busy.remove(offer);
      failed = offer;
    }
    notifyListeners();
  }

  /// Asks the store for everything bought before.
  Future<void> restore() async {
    if (!available) return;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      final id = p.productID;
      switch (p.status) {
        case PurchaseStatus.pending:
          busy.add(id);
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          busy.remove(id);
          if (offers.any((o) => o.id == id)) _game.grant(id);
        case PurchaseStatus.error:
          busy.remove(id);
          failed = id;
          debugPrint('Purchase failed: ${p.error}');
        case PurchaseStatus.canceled:
          busy.remove(id);
      }
      // Unacknowledged, Play refunds it in three days.
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (e) {
          debugPrint('Purchase not completed: $e');
        }
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
