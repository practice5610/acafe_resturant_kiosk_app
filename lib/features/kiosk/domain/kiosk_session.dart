import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_upsell_sheet.dart';

export 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';

/// Lightweight in-memory holder for the current kiosk checkout session.
///
/// Keeps the customer name and the last placed order number across the
/// checkout → payment → success screens without needing a global provider.
/// Reset on a fresh order / idle timeout.
class KioskSession {
  KioskSession._();
  static final KioskSession instance = KioskSession._();

  String customerName = '';
  String customerEmail = '';
  String? lastOrderNumber;
  String? lastOrderId;

  /// Tip percent locked in for this checkout. `null` until the customer
  /// either picks a percentage or taps "No, thank you!". A value of `0`
  /// means they declined. Only a value `> 0` skips the tip screen on a
  /// later Pay tap in the same flow.
  int? tipPercent;

  void reset() {
    customerName = '';
    customerEmail = '';
    lastOrderNumber = null;
    lastOrderId = null;
    tipPercent = null;
    // "We already asked this customer about a drink" must not carry over to
    // the next person to walk up to the kiosk. Nor must "this customer avoids
    // nuts" — leaking that would hide products from someone who never
    // declared anything, which is the one failure mode of an allergen filter
    // that a customer cannot detect for themselves.
    resetKioskUpsellMemory();
    resetKioskAllergenMemory();
  }

  /// True only after the customer picked a real tip (5 / 10 / 15%). Declining
  /// or dismissing does not lock the screen out — Pay shows it again.
  bool get hasLockedInTip => (tipPercent ?? 0) > 0;

  int get tipPercentOrZero => tipPercent ?? 0;

  void applyTip(int percent) {
    tipPercent = percent;
  }
}
