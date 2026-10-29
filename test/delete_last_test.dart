import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snowflake/app_state.dart';

SavedFlake _flake(double x) => SavedFlake(cuts: [
      [Offset(x, -.5), const Offset(.1, -.6), const Offset(0, -.7)],
    ]);

Future<GameState> _game() async {
  SharedPreferences.setMockInitialValues({});
  return GameState(await SharedPreferences.getInstance());
}

void main() {
  test('deleting the last flake unfolded no longer offers it back', () async {
    final g = await _game();
    g.setLast(_flake(.2));
    g.saveLast();
    expect(g.lastSaved, isTrue);
    g.delete(g.last!);
    expect(g.saved, isEmpty);
    expect(g.last, isNull, reason: 'no "add the last one" after deleting it');
  });

  test('"Done"\'s toggle can still take it out and put it back', () async {
    final g = await _game();
    g.setLast(_flake(.2));
    g.saveLast();
    g.unsaveLast();
    expect(g.lastSaved, isFalse);
    expect(g.last, isNotNull);
    g.saveLast();
    expect(g.lastSaved, isTrue);
  });

  test('deleting another flake keeps the last one', () async {
    final g = await _game();
    final other = _flake(.3);
    g.save(other);
    g.setLast(_flake(.2));
    g.delete(other);
    expect(g.last, isNotNull);
    expect(g.lastSaved, isFalse);
  });

  test('undoing a delete puts the flake back where it was, hanging and last', () async {
    final g = await _game();
    final a = _flake(.1), b = _flake(.3);
    g.save(a);
    g.setLast(b);
    g.saveLast();
    g.hang(4, b);
    g.delete(b);
    expect(g.isHung(b), isFalse);
    expect(g.last, isNull);
    g.undoDelete();
    expect(g.saved, [b, a]);
    expect(g.window[4], same(b));
    expect(g.last, same(b));
    expect(g.lastSaved, isTrue);
    expect(g.deleted, isNull);
  });
}
