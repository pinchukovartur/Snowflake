import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snowflake/app_state.dart';

void main() {
  test('offers are the advent calendar\'s rewards, two papers and two stencils each', () {
    expect(offers, hasLength(2));
    for (final o in offers) {
      expect(o.items.where((r) => r.paper), hasLength(2));
      expect(o.items.where((r) => !r.paper), hasLength(2));
      for (final r in o.items) {
        expect(adventRewards, contains(r));
      }
    }
    expect({for (final o in offers) ...o.items}, hasLength(adventRewards.length));
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
