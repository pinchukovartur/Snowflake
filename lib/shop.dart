import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';

/// Debug builds' stand-in for the store when it has no such product (an
/// emulator, a build AppGallery doesn't know): "buy" hands the set over at
/// once. A release never has it, whatever this says.
const fakePurchases = true && kDebugMode && !storeShots;

/// For testing the settings: their "restore purchases" button shown even
/// with no store to reach (an emulator), where a tap does nothing. Debug
/// builds only, as [fakePurchases].
const showRestoreAlways = true && kDebugMode && !storeShots;

/// The shop of the AppGallery build (branch huawei): the [offers] as Huawei
/// IAP has them (their prices), buying them, and what was bought before
/// coming back through restoring, which it asks for at launch. Each one
/// bought or restored goes to [GameState.grant].
///
/// Google Play Billing (the in_app_purchase plugin, used on main) does not
/// exist on Huawei phones, so this talks to HMS IAP through the native
/// `snowflake/iap` channel (android/.../HuaweiBilling.kt). The sets are
/// non-consumables: bought once, owned for good.
class Shop extends ChangeNotifier {
  Shop._();
  static final instance = Shop._();

  static const _channel = MethodChannel('snowflake/iap');

  late GameState _game;

  /// Whether the store can be reached at all.
  bool available = false;

  /// The offers' prices as the store gives them, by id: shown in the shop,
  /// and only those here can be bought.
  final prices = <String, String>{};

  /// Offers whose purchase is under way (the store's sheet up), by id.
  final busy = <String>{};

  /// The last purchase that failed, by offer id, for the shop to say so;
  /// cleared on the next try.
  String? failed;

  Future<void> init(GameState game) async {
    _game = game;
    try {
      available = await _channel.invokeMethod<bool>('ready') ?? false;
      if (!available) return;
      final got = await _channel.invokeMapMethod<String, String>('prices', {
        'ids': [for (final o in offers) o.id],
      });
      prices.addAll(got ?? const {});
      await restore();
    } catch (e) {
      // A store that can't be reached must not stop the game.
      debugPrint('Shop not ready: $e');
    } finally {
      notifyListeners();
    }
  }

  /// The offer's price as the store gives it, in the player's currency.
  String? price(String offer) => prices[offer];

  /// Whether [offer] can be bought here and now.
  bool canBuy(String offer) => !_game.owns(offer) && !busy.contains(offer) && (prices.containsKey(offer) || fakePurchases);

  Future<void> buy(String offer) async {
    if (!canBuy(offer)) return;
    failed = null;
    if (!prices.containsKey(offer)) {
      // Only [fakePurchases] gets here (see [canBuy]).
      _game.grant(offer);
      notifyListeners();
      return;
    }
    busy.add(offer);
    notifyListeners();
    try {
      final res = await _channel.invokeMapMethod<String, Object?>('buy', {'id': offer});
      final reason = res?['reason'];
      if (res?['ok'] == true) {
        _grant(res?['id'] as String? ?? offer);
      } else if (reason == 'owned' || reason == 'pending') {
        // Bought before (or paid, settling later): the owned list has it.
        await restore();
      } else if (reason != 'cancelled') {
        debugPrint('Purchase failed: $reason');
        failed = offer;
      }
    } catch (e) {
      debugPrint('Purchase not started: $e');
      failed = offer;
    } finally {
      busy.remove(offer);
      notifyListeners();
    }
  }

  /// Asks the store for everything bought before.
  Future<void> restore() async {
    if (!available) return;
    try {
      final ids = await _channel.invokeListMethod<String>('owned') ?? const [];
      ids.forEach(_grant);
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
    notifyListeners();
  }

  void _grant(String id) {
    if (offers.any((o) => o.id == id)) _game.grant(id);
  }
}
