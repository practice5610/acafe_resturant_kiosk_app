import 'package:acafe_customer/features/pos/widgets/pos_fit_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [PosFitColumn]: the flex child gives way first, then the whole stack
/// scales — content is never cut off.
void main() {
  const Key flex = Key('flex');

  Future<RenderPosFitColumn> pump(WidgetTester tester, double? height,
      {VoidCallback? onTap}) async {
    final Widget column = PosFitColumn(
      flexIndex: 1,
      flexMin: 100,
      flexMax: 300,
      children: [
        const SizedBox(height: 200),
        const SizedBox(key: flex),
        SizedBox(
          height: 100,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const Text('bottom', textDirection: TextDirection.ltr),
          ),
        ),
      ],
    );
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: height,
          child: height == null ? SingleChildScrollView(child: column) : column,
        ),
      ),
    ));
    return tester.renderObject<RenderPosFitColumn>(find.byType(PosFitColumn));
  }

  testWidgets('room to spare: the flex child at its max, nothing scaled',
      (tester) async {
    final RenderPosFitColumn box = await pump(tester, 900);
    expect(tester.getSize(find.byKey(flex)).height, 300);
    expect(box.scale, 1);
  });

  testWidgets('short: the flex child shrinks, the rest keeps its size',
      (tester) async {
    final RenderPosFitColumn box = await pump(tester, 450);
    expect(tester.getSize(find.byKey(flex)).height, 150);
    expect(box.scale, 1);
    expect(tester.getBottomLeft(find.text('bottom')).dy, lessThanOrEqualTo(450));
  });

  testWidgets('shorter than the minimum: everything scales to fit',
      (tester) async {
    final RenderPosFitColumn box = await pump(tester, 320);
    // 200 + 100 (min) + 100 = 400 drawn into 320.
    expect(box.scale, closeTo(0.8, 0.001));
    expect(tester.getRect(find.byType(PosFitColumn)).height,
        closeTo(320, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scaled content stays tappable where it is drawn',
      (tester) async {
    int taps = 0;
    await pump(tester, 320, onTap: () => taps++);
    // The bottom box is drawn at 0.8: rows 240–320.
    await tester.tapAt(const Offset(50, 300));
    expect(taps, 1);
  });

  testWidgets('unbounded (a stacked scroll): the flex child at its max',
      (tester) async {
    await pump(tester, null);
    expect(tester.getSize(find.byKey(flex)).height, 300);
  });
}
