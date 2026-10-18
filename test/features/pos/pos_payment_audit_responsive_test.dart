import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pos_payment_audit_golden_test.dart';

/// Every audited frame of the "POS payment" layer (Figma 1915:9314) at the
/// window sizes a till, a tablet and a browser give it: nothing may overflow
/// or throw. Plus stress states — long names, many lines, large totals.
void main() {
  setUpAll(loadPaymentFonts);
  setUp(() => PosSaleSession.instance.reset());
  tearDown(() {
    PosSaleSession.instance.reset();
    auditSize = const Size(1366, 1024);
  });

  const sizes = <Size>[
    Size(1366, 1024),
    Size(1024, 768),
    Size(1280, 800),
    Size(1920, 1080),
    Size(768, 1024),
    Size(900, 600),
  ];

  for (final size in sizes) {
    for (final entry in auditFrames.entries) {
      testWidgets('${entry.key} at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        auditSize = size;
        await entry.value(tester);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('screen (card) at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      auditSize = size;
      await pumpPaymentScreen(tester);
      expect(tester.takeException(), isNull);
    });
    testWidgets('screen (cash) at ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      auditSize = size;
      await pumpPaymentScreen(tester, method: PosPaymentMethod.cash);
      expect(tester.takeException(), isNull);
    });
  }

  List<CartModel> longTicket() => [
        for (int i = 0; i < 14; i++)
          figmaLine(
            i.isEven
                ? 'Ceremonial Grade Uji Matcha Latte with Oat Milk and Extra Vanilla Foam $i'
                : 'Iced Matcha $i',
            1234.56,
            added: const ['Oat milk', 'Vanilla syrup', 'Honey drizzle'],
            removed: const ['Whipped cream'],
            id: i + 1,
          ),
      ];

  testWidgets('stress: 14 long lines and a five-figure total (card)',
      (tester) async {
    PosSaleSession.instance.customerName.text =
        'Alexandria Montgomery-Vanderbilt of the Northern Office';
    await pumpPaymentScreen(tester, lines: longTicket());
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/payment_audit/stress_card.png'));
  });

  testWidgets('stress: 14 long lines and a five-figure total (cash)',
      (tester) async {
    await pumpPaymentScreen(tester,
        lines: longTicket(), method: PosPaymentMethod.cash);
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('goldens/payment_audit/stress_cash.png'));
  });

  testWidgets('stress: empty cart', (tester) async {
    await pumpPaymentScreen(tester, lines: const []);
    expect(tester.takeException(), isNull);
  });
}
