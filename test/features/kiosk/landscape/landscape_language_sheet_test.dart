import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_language_sheet.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the card directly. The full [showLandscapeLanguageSheet] flow needs
/// LocalizationProvider + CategoryProvider (and a network prefetch), so these
/// cover what Figma `2305:3628` actually specifies: which row is highlighted,
/// which are dimmed, and that a tap reports the right language.
void main() {
  Widget harness({
    required String current,
    required void Function(String code) onSelect,
    bool saving = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LandscapeLanguageCard(
            s: 1,
            current: current,
            saving: saving,
            onSelect: (l) => onSelect(l.languageCode!),
          ),
        ),
      ),
    );
  }

  testWidgets('lists every kiosk language', (tester) async {
    await tester.pumpWidget(harness(current: 'en', onSelect: (_) {}));

    for (final language in AppConstants.languages) {
      expect(find.text(language.languageName!), findsOneWidget);
    }
  });

  testWidgets('falls back to readable text, never a raw key', (tester) async {
    await tester.pumpWidget(harness(current: 'en', onSelect: (_) {}));

    expect(find.text('SELECT LANGUAGE'), findsOneWidget);
    expect(find.text('SELECT_LANGUAGE'), findsNothing);
    expect(find.text('Choose your preferred language'), findsOneWidget);
    expect(find.text('choose_your_preferred_language'), findsNothing);
  });

  testWidgets('highlights the current language and dims the rest',
      (tester) async {
    await tester.pumpWidget(harness(current: 'nl', onSelect: (_) {}));

    final borders = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration as BoxDecoration?)
        .where((d) => d?.border != null)
        .map((d) => d!.border as Border)
        .where((b) => b.top.color == Colors.black || b.top.width > 1)
        .toList();
    // One row border is pure black (selected); the rest use the idle hairline.
    expect(borders.where((b) => b.top.color == Colors.black), hasLength(1));

    final opacities =
        tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity);
    expect(opacities.where((o) => o == 1.0), hasLength(1));
    expect(opacities.where((o) => o < 1.0),
        hasLength(AppConstants.languages.length - 1));
  });

  testWidgets('tapping a row reports that language', (tester) async {
    final List<String> picked = [];
    await tester.pumpWidget(harness(current: 'en', onSelect: picked.add));

    await tester.tap(find.text('Français'));
    await tester.pump();

    expect(picked, ['fr']);
  });

  testWidgets('rows are inert while a selection is being applied',
      (tester) async {
    final List<String> picked = [];
    await tester.pumpWidget(
        harness(current: 'en', onSelect: picked.add, saving: true));

    await tester.tap(find.text('Deutsch'));
    await tester.pump();

    expect(picked, isEmpty,
        reason: 'a second tap mid-save would race two locales into the cache');
  });
}
