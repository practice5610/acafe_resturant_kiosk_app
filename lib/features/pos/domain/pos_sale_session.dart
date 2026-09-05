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

/// Resolves the tender a sale should start on, given what Settings → Payments
/// leaves enabled on this terminal.
///
/// Figma paints Card as the active method, and that stays the preference — but
/// an operator who has turned Card off must not land on a method they cannot
/// select, so Cash takes over. Both-off is unreachable (the Payments screen
/// disables the last remaining tender, and [PosPaymentSettings.fromJson]
/// restores Cash if a stored payload ever says otherwise), and Card is kept as
/// the final fallback rather than throwing.
PosPaymentMethod posDefaultPaymentMethod({
  required bool cashEnabled,
  required bool cardEnabled,
}) {
  if (cardEnabled) return PosPaymentMethod.card;
  if (cashEnabled) return PosPaymentMethod.cash;
  return PosPaymentMethod.card;
}

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

  /// The tender this sale is being taken on.
  ///
  /// Seeded to Card to match Figma, then re-resolved against the terminal's
  /// enabled tenders by [applyEnabledTenders] — the session lives in `domain/`
  /// and must not reach for SharedPreferences itself, so the screen that has
  /// the settings in hand pushes them in.
  PosPaymentMethod paymentMethod = PosPaymentMethod.card;

  /// Which tenders Settings → Payments leaves available, remembered so
  /// [reset] can resolve the next sale's default without another prefs read.
  bool cashEnabled = true;
  bool cardEnabled = true;

  /// Point the sale at a tender the operator can actually pick.
  ///
  /// Called by the payment selector as it opens. Only moves [paymentMethod]
  /// when the current one has been turned off, so an operator who deliberately
  /// chose Cash on a terminal that also takes Card keeps their choice.
  void applyEnabledTenders({
    required bool cash,
    required bool card,
  }) {
    cashEnabled = cash;
    cardEnabled = card;
    final bool stillAvailable =
        paymentMethod == PosPaymentMethod.cash ? cash : card;
    if (stillAvailable) return;
    paymentMethod = posDefaultPaymentMethod(
      cashEnabled: cash,
      cardEnabled: card,
    );
  }

  /// Backend order number, once the sale has actually been placed. Null before
  /// that — the number is assigned by the server, not by the till, so the
  /// receipt header falls back to its design placeholder until then.
  String? orderNumber;

  /// Clear the ticket after a completed (or abandoned) sale.
  void reset() {
    customerName.clear();
    table.clear();
    orderType = PosOrderType.dineIn;
    // Resolved, not hardcoded back to Card: the next sale on a cash-only
    // terminal must not start on a tender the operator cannot select.
    paymentMethod = posDefaultPaymentMethod(
      cashEnabled: cashEnabled,
      cardEnabled: cardEnabled,
    );
    orderNumber = null;
  }
}
