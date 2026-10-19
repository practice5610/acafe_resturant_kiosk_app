import 'dart:io';

import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_category_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real rail font, so label widths are the ones a device measures.
Future<void> _loadLoew() async {
  final loader = FontLoader('Loew');
  for (final String weight in ['Medium', 'Bold']) {
    loader.addFont(File('assets/fonts/Loew-$weight.ttf')
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
}

List<CategoryModel> _cats() => [
      CategoryModel(id: 1, name: 'Coffee'),
      CategoryModel(id: 2, name: 'Macha'),
    ];

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onPunch,
  double width = PosHomeSpec.sidebarWidth,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PosCategorySidebar(
          categories: _cats(),
          selectedId: '1',
          onSelect: (_) {},
          onPunch: onPunch,
          width: width,
          scale: scale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadLoew);

  testWidgets('shows the Punch In / Out action when a handler is given',
      (tester) async {
    await _pump(tester, onPunch: () {});

    expect(find.byKey(const Key('pos-sidebar-punch')), findsOneWidget);
    expect(find.text('Punch In / Out'), findsOneWidget);
  });

  testWidgets('tapping the action fires the handler', (tester) async {
    var taps = 0;
    await _pump(tester, onPunch: () => taps++);

    await tester.tap(find.byKey(const Key('pos-sidebar-punch')));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('omits the action for callers that pass no handler',
      (tester) async {
    await _pump(tester); // existing callers / tests construct it without onPunch

    expect(find.byKey(const Key('pos-sidebar-punch')), findsNothing);
    // The categories still render as before.
    expect(find.text('COFFEE'), findsOneWidget);
  });

  testWidgets('defaults to the flat Figma item and label sizes',
      (tester) async {
    await _pump(tester, onPunch: () {});

    expect(tester.getSize(find.byType(PosCategoryItem).first).height,
        PosHomeSpec.sidebarItemHeight);
    expect(tester.widget<Text>(find.text('COFFEE')).style!.fontSize,
        PosHomeSpec.sidebarLabelSize);
    expect(tester.getSize(find.byKey(const Key('pos-sidebar-punch'))).height,
        PosHomeSpec.punchHeight);
  });

  testWidgets('a one-word label too wide for the rail shrinks, never splits',
      (tester) async {
    // 1366 frame geometry: MERCHANDISE at 16px is a hair wider than the
    // 134px the rail leaves it, which used to break it as MERCHANDIS / E.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosCategorySidebar(
            categories: [CategoryModel(id: 1, name: 'Merchandise')],
            selectedId: null,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    final RenderParagraph label =
        tester.renderObject<RenderParagraph>(find.text('MERCHANDISE'));
    expect(
        label.size.height,
        closeTo(
            label.text.style!.fontSize! * PosHomeSpec.sidebarLabelHeight, 0.5),
        reason: 'MERCHANDISE wrapped onto a second line');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a multi-word label still wraps at the space at full size',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosCategorySidebar(
            categories: [CategoryModel(id: 1, name: 'Other drinks')],
            selectedId: null,
            onSelect: (_) {},
            width: 144,
          ),
        ),
      ),
    );

    expect(
        tester.widget<Text>(find.text('OTHER DRINKS')).style!.fontSize,
        PosHomeSpec.sidebarLabelSize);
  });

  testWidgets('scale grows the items, labels and punch action with the pane',
      (tester) async {
    const double scale = 1.25;
    await _pump(
      tester,
      onPunch: () {},
      width: PosHomeSpec.sidebarWidth * scale,
      scale: scale,
    );

    expect(tester.getSize(find.byType(PosCategoryItem).first).height,
        closeTo(PosHomeSpec.sidebarItemHeight * scale, 0.01));
    expect(tester.widget<Text>(find.text('COFFEE')).style!.fontSize,
        closeTo(PosHomeSpec.sidebarLabelSize * scale, 0.01));
    expect(tester.getSize(find.byKey(const Key('pos-sidebar-punch'))).height,
        closeTo(PosHomeSpec.punchHeight * scale, 0.01));
    expect(tester.takeException(), isNull);
  });

  // The rail's scale range: the 1024 floor (0.75), the 1366 frame (1) and the
  // 1.30 cap. The pane and the pill scale together, so the label must sit at
  // its full size at every one of them — never squeezed by its FittedBox.
  for (final double scale in [0.75, 1.0, 1.30]) {
    testWidgets('punch pill spans the category column with its label '
        'unshrunk at scale $scale', (tester) async {
      final double width = PosHomeSpec.sidebarWidth * scale;
      await _pump(tester, onPunch: () {}, width: width, scale: scale);

      final Rect pill =
          tester.getRect(find.byKey(const Key('pos-sidebar-punch')));
      final double edge = PosHomeSpec.punchFooterPadding.left * scale;
      expect(pill.left, closeTo(edge, 0.01));
      expect(pill.right,
          closeTo(width - PosHomeSpec.paneBorder - edge, 0.01));

      final Finder label = find.text('Punch In / Out');
      expect(tester.getRect(label).width,
          closeTo(tester.getSize(label).width, 0.01),
          reason: 'label was scaled down to fit the pill');
      expect(tester.getRect(label).right, lessThanOrEqualTo(pill.right));
      expect(tester.takeException(), isNull);
    });
  }
}
