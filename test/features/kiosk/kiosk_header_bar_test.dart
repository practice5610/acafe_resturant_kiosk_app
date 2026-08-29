import 'dart:io';

import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
  };
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => b.buffer.asByteData()),
      );
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  /// Landscape cart uses rowHeight 100 with titleFontSize 120 — the logo
  /// used to clip at the top of the header row on large landscape devices.
  testWidgets('landscape cart header keeps A/CAFÉ inside the row',
      (tester) async {
    const size = Size(1920, 1080);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const double s = 0.5;
    const double rowHeight = 100;
    const double titleFontSize = 120;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: KioskHeaderBar(
              s: s,
              fallback: RouterHelper.getKioskMenuRoute,
              verticalPadding: 28,
              rowHeight: rowHeight,
              titleFontSize: titleFontSize,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final titleFinder = find.text('A/CAFÉ');
    expect(titleFinder, findsOneWidget);

    // FittedBox scales via transform — assert the FittedBox itself fits the
    // row, not the unscaled Text metrics.
    final fitted = find.descendant(
      of: find.byType(KioskHeaderBar),
      matching: find.byType(FittedBox),
    );
    expect(fitted, findsOneWidget);
    final RenderBox fittedBox = tester.renderObject(fitted);
    expect(fittedBox.size.height, lessThanOrEqualTo(rowHeight * s + 0.5),
        reason: 'scaled title must fit inside the fixed header row height');

    // No render-flex / overflow indicators from the header row.
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait header title still renders at design size when it fits',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const double s = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KioskHeaderBar(s: s),
        ),
      ),
    );
    await tester.pump();

    final titleFinder = find.text('A/CAFÉ');
    expect(titleFinder, findsOneWidget);

    final Text title = tester.widget<Text>(titleFinder);
    expect(title.style?.fontSize, 120 * s);
  });
}
