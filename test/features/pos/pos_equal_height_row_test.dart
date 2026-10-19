import 'dart:io';

import 'package:acafe_customer/features/pos/widgets/pos_equal_height_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not registered until a test loads it, so text set in it lays out in the
/// test font first — the stand-in for a web fallback font that CanvasKit only
/// downloads after the first frame.
const String _lateFamily = 'PosEqualHeightRowLateFont';

/// A report-style card: a min-size column with its slack at the bottom.
Widget _card(String key, int lines) => Container(
      key: Key(key),
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFFFFFFF),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < lines; i++)
            // Short enough to stay on one line in either font, so loading
            // the late font changes only the line height.
            const Text(
              'Settings → Staff',
              style: TextStyle(fontFamily: _lateFamily, fontSize: 12),
            ),
        ],
      ),
    );

Future<void> _pumpRow(
  WidgetTester tester, {
  required int columns,
  required List<Widget> children,
  TextDirection direction = TextDirection.ltr,
}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 800,
          child: PosEqualHeightRow(
            columns: columns,
            spacing: 16,
            children: children,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('every cell takes the tallest cell\'s height and its column width',
      (tester) async {
    await _pumpRow(tester, columns: 4, children: <Widget>[
      _card('a', 1),
      _card('b', 5),
      _card('c', 2),
      _card('d', 3),
    ]);

    final double tallest = tester.getSize(find.byKey(const Key('b'))).height;
    for (final String key in <String>['a', 'b', 'c', 'd']) {
      expect(tester.getSize(find.byKey(Key(key))), Size(188, tallest));
    }
    expect(tester.getTopLeft(find.byKey(const Key('d'))).dx, 3 * (188 + 16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short last row keeps its column width instead of stretching',
      (tester) async {
    await _pumpRow(tester, columns: 4, children: <Widget>[_card('a', 1)]);

    expect(tester.getSize(find.byKey(const Key('a'))).width, 188);
    expect(tester.getTopLeft(find.byKey(const Key('a'))).dx, 0);
  });

  testWidgets('right-to-left puts the first cell on the right', (tester) async {
    await _pumpRow(
      tester,
      columns: 2,
      direction: TextDirection.rtl,
      children: <Widget>[_card('a', 1), _card('b', 1)],
    );

    expect(tester.getTopLeft(find.byKey(const Key('a'))).dx, 408);
    expect(tester.getTopLeft(find.byKey(const Key('b'))).dx, 0);
  });

  // The Report's Staff Shifts & Tips overflow on web. `IntrinsicHeight` sizes
  // its row from `RenderParagraph`'s intrinsic measurement, which Flutter does
  // not refresh when a font arrives after the first frame
  // (`systemFontsDidChange` resets the paragraph's painter but not its
  // `_textIntrinsicsCache`) — so the row kept its old height while the
  // tallest card grew, and that card overflowed. This exact setup overflows
  // an `IntrinsicHeight(Row(stretch))` by 15px.
  testWidgets('a font that arrives after the first frame grows the row',
      (tester) async {
    await _pumpRow(tester, columns: 2, children: <Widget>[
      _card('short', 1),
      _card('tall', 5),
    ]);
    final double before = tester.getSize(find.byType(PosEqualHeightRow)).height;

    // Real I/O, so outside the fake-async zone. Loading sends the engine's
    // `fontsChange` message, exactly as a downloaded web fallback font does.
    await tester.runAsync(() async {
      final Uint8List bytes =
          await File('assets/fonts/Inter-Regular.ttf').readAsBytes();
      final FontLoader loader = FontLoader(_lateFamily)
        ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
      await loader.load();
    });
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'the tall card overflowed a row that kept its stale height');

    final double after = tester.getSize(find.byType(PosEqualHeightRow)).height;
    expect(after, greaterThan(before),
        reason: 'Inter sets 12px taller than the test font, so the row must grow');
    expect(tester.getSize(find.byKey(const Key('short'))).height, after);
    expect(tester.getSize(find.byKey(const Key('tall'))).height, after);
  });
}
