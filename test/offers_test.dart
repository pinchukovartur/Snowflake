import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snowflake/app_state.dart';

void main() {
  test('offers hold papers and stencils, none in two of them', () {
    expect(offers, hasLength(2));
    for (final o in offers) {
      expect(o.items.where((r) => r.paper), isNotEmpty);
      expect(o.items.where((r) => !r.paper), isNotEmpty);
    }
    final all = [for (final o in offers) ...o.items];
    expect(all.toSet(), hasLength(all.length));
  });

  test('what only the shop sells is shut till bought, as the calendar\'s is', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameState(await SharedPreferences.getInstance());
    final shopOnly = [
      for (final o in offers)
        for (final r in o.items)
          if (!adventRewards.contains(r)) r.id,
    ];
    expect(shopOnly, isNotEmpty);
    expect(shopOnly.any(game.unlocked), isFalse);
  });

  test('a bought offer unlocks what it holds, and only that', () async {
    SharedPreferences.setMockInitialValues({});
    final game = GameState(await SharedPreferences.getInstance());
    final first = offers.first, second = offers.last;
    expect(first.items.any((r) => game.unlocked(r.id)), isFalse);
    game.grant(first.id);
    expect(first.items.every((r) => game.unlocked(r.id)), isTrue);
    expect(second.items.any((r) => game.unlocked(r.id)), isFalse);
    expect(game.unlocked('star'), isTrue);
  });

  test('resetting purchases locks the sets again', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final game = GameState(prefs)..grant(offers.first.id);
    game.resetPurchases();
    expect(game.owns(offers.first.id), isFalse);
    expect(offers.first.items.any((r) => game.unlocked(r.id)), isFalse);
    expect(GameState(prefs).owns(offers.first.id), isFalse);
  });
}
