import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:snowflake/widgets/ds.dart';

/// A row of small round buttons [gap] apart, as the cut screen lays them out,
/// each counting its own taps into [taps].
Widget _row(List<int> taps, double gap, {bool hitSlop = true}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(100),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < taps.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  RoundBtn(LucideIcons.undo2, label: 'b$i', size: BtnSize.s, hitSlop: hitSlop, onTap: () => taps[i]++),
                ],
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  // The small button is 44 wide: 2 short of 48 each side. Its lip makes it 48
  // tall, so only sideways does the zone grow. (Only where its parent lays out
  // room: a button at the very edge of its row gets none outside it.)
  testWidgets('a small button takes taps 2 out of its box sideways, and no further', (tester) async {
    final taps = [0, 0];
    await tester.pumpWidget(_row(taps, 10));
    final a = tester.getRect(find.byType(RoundBtn).first), b = tester.getRect(find.byType(RoundBtn).last);
    final y = a.center.dy;

    await tester.tapAt(Offset(a.right + 1.9, y));
    expect(taps, [1, 0], reason: 'just right of the first');
    await tester.tapAt(Offset(a.right + 2.1, y));
    expect(taps, [1, 0], reason: 'past the first button zone');
    await tester.tapAt(Offset(b.left - 1.9, y));
    expect(taps, [1, 1], reason: 'just left of the second');
    await tester.tapAt(Offset(b.left - 2.1, y));
    expect(taps, [1, 1], reason: 'past the second button zone');
  });

  testWidgets('the zones of buttons 10 apart do not meet', (tester) async {
    final taps = [0, 0, 0];
    await tester.pumpWidget(_row(taps, 10));
    final rects = [for (final e in find.byType(RoundBtn).evaluate()) tester.getRect(find.byWidget(e.widget))];
    final y = rects.first.center.dy;
    for (var i = 0; i + 1 < rects.length; i++) {
      // Their zones: 2 out each side. In the gap's middle, 5 from each, neither.
      final mid = (rects[i].right + rects[i + 1].left) / 2;
      final before = [...taps];
      await tester.tapAt(Offset(mid, y));
      expect(taps, before, reason: 'the gap between ${i + 1} and ${i + 2}');
      // And each side of it its own button's zone.
      await tester.tapAt(Offset(rects[i].right + 1.9, y));
      expect(taps[i], before[i] + 1);
      await tester.tapAt(Offset(rects[i + 1].left - 1.9, y));
      expect(taps[i + 1], before[i + 1] + 1);
    }
  });

  testWidgets('buttons 2 apart (a grid\'s cells) have no zone beyond their own boxes', (tester) async {
    final taps = [0, 0];
    await tester.pumpWidget(_row(taps, 2, hitSlop: false));
    final a = tester.getRect(find.byType(RoundBtn).first), b = tester.getRect(find.byType(RoundBtn).last);
    await tester.tapAt(Offset(a.right + 1, a.center.dy));
    expect(taps, [0, 0], reason: 'in the gap');
    await tester.tapAt(Offset(a.right - 1, a.center.dy));
    expect(taps, [1, 0]);
    await tester.tapAt(Offset(b.left + 1, b.center.dy));
    expect(taps, [1, 1]);
  });

  testWidgets('a button no smaller than 48 is hit as before', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(100),
            child: RoundBtn(LucideIcons.undo2, label: 'big', size: BtnSize.m, onTap: () => taps++),
          ),
        ),
      ),
    ));
    final r = tester.getRect(find.byType(RoundBtn));
    await tester.tapAt(Offset(r.left - 1, r.center.dy));
    expect(taps, 0);
    await tester.tapAt(Offset(r.left + 1, r.center.dy));
    expect(taps, 1);
  });
}
