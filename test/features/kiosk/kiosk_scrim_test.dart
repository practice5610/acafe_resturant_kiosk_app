import 'dart:ui';

import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The scrim replaced three hand-rolled BackdropFilters that had drifted apart
/// (sigma 6/6/8, none animated, none scaling with screen size). These lock in
/// the three properties that fixed.
void main() {
  Future<void> pumpAt(WidgetTester tester, Size size,
      {required Animation<double> animation}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: KioskScrim(animation: animation),
      ),
    ));
  }

  double sigmaOf(WidgetTester tester) {
    final filter =
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).filter;
    // ImageFilter exposes no sigma getter; its toString is
    // `ImageFilter.blur(24.0, 24.0, unspecified)`.
    final match = RegExp(r'blur\(([0-9.]+)').firstMatch(filter.toString());
    return double.parse(match!.group(1)!);
  }

  testWidgets('blur scales with screen width, so it looks the same everywhere',
      (tester) async {
    await pumpAt(tester, const Size(600, 1024),
        animation: kAlwaysCompleteAnimation);
    final small = sigmaOf(tester);

    await pumpAt(tester, const Size(2572, 3840),
        animation: kAlwaysCompleteAnimation);
    final full = sigmaOf(tester);

    expect(full, greaterThan(small),
        reason: 'a fixed sigma would read as heavy on a small window '
            'and invisible on a 2572px kiosk');
    expect(full, closeTo(24, 0.01), reason: 'full artboard scale');
    expect(small, greaterThanOrEqualTo(8),
        reason: 'floor keeps a small window convincingly blurred');
  });

  testWidgets('blur ramps in rather than snapping', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 280),
    );
    addTearDown(controller.dispose);

    await pumpAt(tester, const Size(2572, 3840), animation: controller);
    final atStart = sigmaOf(tester);

    controller.value = 1.0;
    await tester.pump();
    final atEnd = sigmaOf(tester);

    expect(atStart, lessThan(1.0), reason: 'starts effectively clear');
    expect(atStart, greaterThan(0.0),
        reason: 'never exactly zero — a 0-sigma blur flickers on frame one');
    expect(atEnd, closeTo(24, 0.01));
  });

  testWidgets('an inert scrim ignores taps', (tester) async {
    // Used mid-save, where dismissing would strand a half-applied change.
    await pumpAt(tester, const Size(1080, 1920),
        animation: kAlwaysCompleteAnimation);
    await tester.tapAt(const Offset(10, 10));
    expect(tester.takeException(), isNull);
  });
}
