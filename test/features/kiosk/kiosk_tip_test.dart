import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_tip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(KioskSession.instance.reset);
  tearDown(KioskSession.instance.reset);

  test('a tip is never applied until a positive percent is chosen', () {
    expect(kioskTipAmount(16.09, 0), 0);
    expect(kioskTipAmount(16.09, 5), isNot(0));
    expect(kioskTotalWithTip(16.09, 0), 16.09);
  });

  test('percentages match the Figma tiles: 0 / 5 / 10 / 15', () {
    expect(kKioskTipPercents, [0, 5, 10, 15]);
  });

  test('amounts round to 2 dp so the tile and the total stay identical', () {
    // The Figma preview uses an €8.80 subtotal: 5% → €0.44, 10% → €0.88.
    expect(kioskTipAmount(8.80, 5), 0.44);
    expect(kioskTipAmount(8.80, 10), 0.88);
    expect(kioskTipAmount(8.80, 15), 1.32);
    expect(kioskTotalWithTip(8.80, 10), 9.68);
  });

  test('locking a tip is only true after a positive percent', () {
    expect(KioskSession.instance.hasLockedInTip, isFalse);
    KioskSession.instance.applyTip(0);
    expect(KioskSession.instance.hasLockedInTip, isFalse);
    expect(KioskSession.instance.tipPercentOrZero, 0);

    KioskSession.instance.applyTip(10);
    expect(KioskSession.instance.hasLockedInTip, isTrue);
    expect(KioskSession.instance.tipPercentOrZero, 10);
  });

  test('reset clears a locked-in tip for the next customer', () {
    KioskSession.instance.applyTip(15);
    KioskSession.instance.reset();
    expect(KioskSession.instance.hasLockedInTip, isFalse);
    expect(KioskSession.instance.tipPercentOrZero, 0);
  });

  test('the order note records a chosen tip and leaves no-tip notes alone', () {
    expect(
      kioskOrderNote(name: 'Dylan', note: ''),
      'Kiosk order — Dylan',
    );
    expect(
      kioskOrderNote(
        name: 'Dylan',
        note: 'Oat milk',
        tipPercent: 10,
        tipAmount: 0.88,
      ),
      'Kiosk order — Dylan\nTip: 10% (0.88)\nOat milk',
    );
  });
}
