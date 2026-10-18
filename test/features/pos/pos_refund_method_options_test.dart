import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pos_payment_audit_golden_test.dart';

/// Frame 26's refund-method options that depend on data the backend does not
/// send yet (ui-audit/backend-needs.md B5): the card's last four digits and
/// store credit. Shown only from real data, hidden otherwise.
void main() {
  group('PosReceiptDetail parses only real values', () {
    PosReceiptDetail parse(Map<String, dynamic> extra) =>
        PosReceiptDetail.fromJson({'id': 1, 'details': const [], ...extra});

    test('absent (today) → no last four, no store credit', () {
      final d = parse({});
      expect(d.cardLast4, isNull);
      expect(d.storeCreditAvailable, isFalse);
    });

    test('card_last4 must be exactly four digits', () {
      expect(parse({'card_last4': '4242'}).cardLast4, '4242');
      expect(parse({'card_last4': 4242}).cardLast4, '4242');
      for (final bad in ['424', '42424', '42a2', '', '•••• 4242', null]) {
        expect(parse({'card_last4': bad}).cardLast4, isNull, reason: '$bad');
      }
    });

    test('store_credit_available must be literally true', () {
      expect(parse({'store_credit_available': true}).storeCreditAvailable,
          isTrue);
      for (final v in ['true', 1, false, null]) {
        expect(parse({'store_credit_available': v}).storeCreditAvailable,
            isFalse,
            reason: '$v');
      }
    });
  });

  group('refund method step (frame 26)', () {
    setUpAll(loadPaymentFonts);
    setUp(() => PosSaleSession.instance.reset());
    tearDown(() {
      PosRefundSession.instance.reset();
      PosSaleSession.instance.reset();
    });

    testWidgets('without the data: "Card", no Store credit', (tester) async {
      await auditFrames['26_refund_method']!(tester);
      expect(find.text('Card'), findsWidgets);
      expect(find.textContaining('••••'), findsNothing);
      expect(find.text('Store credit'), findsNothing);
      expect(find.text('Add to customer balance'), findsNothing);
    });

    testWidgets('with the data: "Card •••• 4242" and Store credit',
        (tester) async {
      await auditFrames['26b_refund_method_last4_credit']!(tester);
      // The option's subtitle and the "Refund to" value.
      expect(find.text('Card •••• 4242'), findsNWidgets(2));
      expect(find.text('Store credit'), findsOneWidget);

      await tester.tap(find.text('Store credit'));
      await tester.pumpAndSettle();
      expect(PosRefundSession.instance.refundMethod.value, 'store_credit');
      // "Refund to" follows the choice.
      expect(find.text('Store credit'), findsNWidgets(2));
      expect(find.text('Card •••• 4242'), findsOneWidget);
    });
  });
}
