import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_search_field.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/text_legibility_audit.dart';

/// The placeholder colour is built at runtime from [PosSearchFieldStyle.hintAlpha],
/// which the source guard cannot evaluate, so each preset is rendered here.
void main() {
  const Map<String, PosSearchFieldStyle> presets = {
    'pill (product grid)': PosSearchFieldStyle.pill,
    'settings': PosSearchFieldStyle.settings,
    'orders board': PosSearchFieldStyle.orders,
  };

  for (final MapEntry<String, PosSearchFieldStyle> preset in presets.entries) {
    testWidgets('${preset.key} placeholder clears WCAG AA', (tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            // The darkest surface any of the three sits on (the Orders
            // board draws its transparent field straight on the page).
            backgroundColor: PosHomeSpec.pageBg,
            body: Center(
              child: SizedBox(
                width: 480,
                child: PosSearchField(
                  controller: controller,
                  onChanged: (_) {},
                  style: preset.value,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
          preset.value.hintAlpha, greaterThanOrEqualTo(TextTones.hintOpacity));
      expect(find.text('Search products..'), findsOneWidget);
      expectLegibleText(tester,
          defaultBackground: PosHomeSpec.pageBg,
          within: find.byType(PosSearchField));
    });
  }
}
