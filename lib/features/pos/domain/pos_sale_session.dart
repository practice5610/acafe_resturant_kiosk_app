import 'package:flutter/widgets.dart';

/// Whether the sale is eaten in or taken away.
///
/// Presentation only for now: every order this app places already carries
/// `order_type: 'pos'`, and sending anything else is an API contract change.
///
/// Declared here rather than beside the receipt panel because [PosSaleSession]
/// has to hold it, and `domain/` must not depend on `widgets/`. The panel
/// re-exports it, so every existing import site is unchanged.
enum PosOrderType { dineIn, takeAway }

/// How the counter is taking the money for this sale.
///
/// Client-side only today. `OrderController` keys payment/order status off the
/// `payment_method` string — anything other than `cash_on_delivery` posts an
/// order as already `paid` and `preparing` — so switching the wire value with
/// this enum would change fulfilment behaviour, not just reporting. Until that
/// contract is agreed, both methods post as the kiosk does.
enum PosPaymentMethod { cash, card }

/// The sale in progress at this terminal.
///
/// The counter screen and the payment screen are separate routes: `/pos-payment`
/// sits outside the shell, so navigating to it disposes [PosHomeCartScreen] and
/// with it any `TextEditingController` that screen owned. The cart itself
/// survives (it lives in `CartProvider`), but the customer name and table would
/// not — the operator would type "Dylan / B1" and watch it vanish on Pay.
///
/// So the two fields the receipt shows but the cart does not store are held
/// here, controllers included, for the lifetime of the terminal. This mirrors
/// [KioskSession], which does the same job for the self-service flow.
///
/// Controllers are deliberately never disposed: the singleton outlives every
/// route, and disposing one would break the screen that is still using it.
class PosSaleSession {
  PosSaleSession._();

  static final PosSaleSession instance = PosSaleSession._();

  final TextEditingController customerName = TextEditingController();
  final TextEditingController table = TextEditingController();

  PosOrderType orderType = PosOrderType.dineIn;

  /// Figma paints Card as the active method on the payment frame, so a sale
  /// starts there and Confirm is never a dead button.
  PosPaymentMethod paymentMethod = PosPaymentMethod.card;

  /// Backend order number, once the sale has actually been placed. Null before
  /// that — the number is assigned by the server, not by the till, so the
  /// receipt header falls back to its design placeholder until then.
  String? orderNumber;

  /// Clear the ticket after a completed (or abandoned) sale.
  void reset() {
    customerName.clear();
    table.clear();
    orderType = PosOrderType.dineIn;
    paymentMethod = PosPaymentMethod.card;
    orderNumber = null;
  }
}
