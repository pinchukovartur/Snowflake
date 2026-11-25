import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:snowflake/app_state.dart';

void main() {
  // The prize as the game has it now: other cuts, folds and paper than when
  // it was won.
  const now = SavedFlake(
    cuts: [
      [Offset(0, -.5), Offset(.1, -.4), Offset(-.1, -.4)],
    ],
    folds: 4,
    color: Color(0xFF2FB37E),
    pattern: 'crystal',
    prize: 'classic',
  );
  setUp(() => SavedFlake.prizes = (id) => id == 'classic' ? now : null);
  tearDown(() => SavedFlake.prizes = null);

  const won = SavedFlake(
    cuts: [
      [Offset(0, -.9), Offset(.2, -.7), Offset(-.2, -.7)],
    ],
    color: Color(0xFFFFFFFF),
    fav: true,
    prize: 'classic',
  );

  test('a prize comes back as the game has it now', () {
    final back = SavedFlake.fromJson(won.toJson())!;
    expect(back.cuts, now.cuts);
    expect(back.folds, 4);
    expect(back.color, now.color);
    expect(back.pattern, 'crystal');
    expect(back.fav, isTrue);
    expect(back.prize, 'classic');
  });

  test('a prize on the player\'s own paper keeps it, its shape new', () {
    const mine = SavedFlake(
      cuts: [
        [Offset(0, -.9), Offset(.2, -.7), Offset(-.2, -.7)],
      ],
      color: Color(0xFFE0405E),
      pattern: 'knit',
      prize: 'classic',
      ownPaper: true,
    );
    final back = SavedFlake.fromJson(mine.toJson())!;
    expect(back.cuts, now.cuts);
    expect(back.color, const Color(0xFFE0405E));
    expect(back.pattern, 'knit');
  });

  test('a prize the game has no more comes back as stored', () {
    const gone = SavedFlake(
      cuts: [
        [Offset(0, -.9), Offset(.2, -.7), Offset(-.2, -.7)],
      ],
      prize: 'retired',
    );
    final back = SavedFlake.fromJson(gone.toJson())!;
    expect(back.cuts.single.first, const Offset(0, -.9));
  });
}
