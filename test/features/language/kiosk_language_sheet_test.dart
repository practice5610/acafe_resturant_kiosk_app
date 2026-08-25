import 'package:acafe_customer/features/kiosk/widgets/kiosk_language_sheet.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the sheet's card directly. The full [openKioskLanguageSheet] flow
/// needs LocalizationProvider + CategoryProvider (and a network prefetch), so
/// these cover what the design actually specifies: which row is highlighted,
/// which are greyed out, and that a tap reports the right language.
void main() {
  Widget harness({
    required String current,
    required void Function(String code) onSelect,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: KioskLanguageCard(
            // The scale a ~800px-wide surface produces, matching what the
            // sheet computes from KioskResponsive.scale at runtime.
            s: 800 / 2572,
            current: current,
            onSelect: (l) => onSelect(l.languageCode!),
          ),
        ),
      ),
    );
  }

  testWidgets('lists every kiosk language, in picker order', (tester) async {
    await tester.pumpWidget(harness(current: 'en', onSelect: (_) {}));

    for (final language in AppConstants.languages) {
      expect(find.text(language.languageName!), findsOneWidget);
    }
    expect(find.text('Dutch'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
  });

  testWidgets('falls back to readable text, never a raw key', (tester) async {
    // Without a localization delegate `getTranslated` echoes the key back, which
    // is what rendered "SELECT_LANGUAGE" on the kiosk. The card must show the
    // human fallback instead.
    await tester.pumpWidget(harness(current: 'en', onSelect: (_) {}));

    expect(find.text('SELECT LANGUAGE'), findsOneWidget);
    expect(find.text('SELECT_LANGUAGE'), findsNothing);
    expect(find.text('Choose your preferred language'), findsOneWidget);
    expect(find.text('choose_your_preferred_language'), findsNothing);
  });

  testWidgets('highlights the current language and greys out the rest',
      (tester) async {
    await tester.pumpWidget(harness(current: 'nl', onSelect: (_) {}));
    await tester.pumpAndSettle();

    // The selected row is the only one drawn with the ink border. Asserted by
    // colour, not width: the width scales with the artboard, so a pixel value
    // here would break every time the sheet is rendered at a different size.
    const Color ink = Color(0xFF1E1E1E);
    final borders = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) => (c.decoration as BoxDecoration?)?.border as Border?)
        .whereType<Border>()
        .toList();

    expect(borders, hasLength(AppConstants.languages.length));
    expect(borders.where((b) => b.top.color == ink), hasLength(1),
        reason: 'exactly one row should be highlighted');

    // Every other flag is dimmed.
    final opacities = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .map((o) => o.opacity)
        .toList();
    expect(opacities.where((o) => o == 1.0), hasLength(1));
    expect(opacities.where((o) => o < 1.0),
        hasLength(AppConstants.languages.length - 1));
  });

  testWidgets('card holds the Figma footprint: 81% of the screen, top-anchored',
      (tester) async {
    // Figma `language-selector-screen`: Width Fixed 2078 on the 2572 kiosk
    // artboard. Pinned here because the first build sized the card as a
    // fraction of the window instead, which rendered it far too small.
    const double artboard = 2572;
    const double figmaCardWidth = 2078;

    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final double screen in [800.0, 1200.0, 2572.0]) {
      final double s = (screen / artboard).clamp(0.24, 1.0);
      // The card is artboard-sized, so the surface has to be the screen under
      // test — otherwise the default 800px test window silently clamps it.
      await tester.binding.setSurfaceSize(Size(screen, 2000));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: KioskLanguageCard(
              s: s,
              current: 'en',
              onSelect: (_) {},
            ),
          ),
        ),
      ));

      final Size card = tester.getSize(find.byType(KioskLanguageCard));
      expect(card.width, closeTo(figmaCardWidth * s, 0.5),
          reason: 'card should be 2078 artboard px at every screen size');
      expect(card.width / screen, closeTo(figmaCardWidth / artboard, 0.02),
          reason: 'card should stay ~81% of the screen width');
    }
  });

  testWidgets('tapping a row reports that language', (tester) async {
    final List<String> picked = [];
    await tester.pumpWidget(
        harness(current: 'en', onSelect: picked.add));

    await tester.tap(find.text('Français'));
    await tester.pump();

    expect(picked, ['fr']);
  });

  testWidgets('rows are inert while a selection is being applied',
      (tester) async {
    final List<String> picked = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: KioskLanguageCard(
              s: 800 / 2572,
              current: 'en',
              saving: true,
              onSelect: (l) => picked.add(l.languageCode!),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Deutsch'));
    await tester.pump();

    expect(picked, isEmpty,
        reason: 'a second tap mid-save would race two locales into the cache');
  });
}
