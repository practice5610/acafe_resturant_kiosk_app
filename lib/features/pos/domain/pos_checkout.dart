import 'package:acafe_customer/di_container.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_payment_service.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
// kiosk_session re-exports kiosk_cart_totals, which is where kioskPayableTotal lives.
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Where a confirm attempt has got to.
///
/// The two halves of a card sale look identical from outside — both are "an
/// await" — but they are not the same to an operator. Waiting on the terminal
/// is the customer's turn and can be cancelled; posting the order is the
/// server's turn and cannot. The screen needs to tell them apart to render
/// Figma 1641:4203, so [posConfirmPayment] reports the boundary rather than
/// making the caller infer it from timing.
enum PosCheckoutPhase {
  /// Card only: the terminal has the amount and the customer is presenting.
  awaitingTerminal,

  /// Payment settled (or was never needed); the order is being posted.
  placingOrder,
}

/// What happened when the operator hit Confirm Payment.
enum PosCheckoutStatus {
  /// Charged (where a charge applies) and the order posted.
  placed,

  /// The card terminal declined or errored. Nothing was ordered.
  paymentFailed,

  /// The operator stopped the terminal payment. Nothing was ordered.
  paymentCanceled,

  /// Payment went through but `order/place` did not. Money may have moved —
  /// this is the case the operator has to be told about explicitly.
  orderFailed,
}

class PosCheckoutResult {
  final PosCheckoutStatus status;
  final String? orderId;
  final String? message;

  const PosCheckoutResult(this.status, {this.orderId, this.message});

  bool get isSuccess => status == PosCheckoutStatus.placed;
}

/// Takes payment for the current POS sale and posts the order.
///
/// Reuses the two pieces that already exist rather than inventing a POS
/// payment path:
///
///  * [KioskPaymentService] — the card-terminal abstraction registered in
///    `di_container`. Its only implementation today is the simulator, exactly
///    as the kiosk uses it; wiring a real terminal replaces that binding and
///    nothing here.
///  * [placeKioskOrder] — the same `POST /api/v1/customer/order/place` call the
///    kiosk makes, already tagging the order `order_type: 'pos'` for a POS
///    device and placing it as a guest.
///
/// Cash needs no terminal round-trip: the drawer took the money before the
/// operator pressed Confirm, so the sale goes straight to the order post.
/// [tenderedAmount] is what the customer handed over — passed through to the
/// order's `bring_change_amount`, an existing field the backend already
/// persists for `cash_on_delivery`. Change is derivable from it and the total,
/// so the tender is the figure worth keeping.
///
/// Cancelling is deliberately *not* a parameter here. A cancel arrives while
/// this future is already in flight, so it goes straight to the service —
/// [posCancelTerminalPayment] — and surfaces as a `canceled` result on the
/// same future. That keeps one path through payment rather than two.
///
/// The wire `payment_method` is left as the kiosk sends it. `OrderController`
/// branches on that string — anything other than `cash_on_delivery` posts the
/// order as already `paid` and `preparing`, skipping the `new` state the
/// kitchen app filters on — so carrying the cash/card choice to the backend is
/// an API contract change, not a field rename.
Future<PosCheckoutResult> posConfirmPayment(
  BuildContext context, {
  required PosPaymentMethod method,
  required String idempotencyKey,
  double? tenderedAmount,
  ValueChanged<PosCheckoutPhase>? onPhase,
}) async {
  final CartProvider cart = context.read<CartProvider>();
  final CouponProvider coupon = context.read<CouponProvider>();
  final PosSaleSession sale = PosSaleSession.instance;

  final double amount =
      kioskPayableTotal(cart.cartList, coupon.discount ?? 0);

  // The order note and the customer_name field are both fed from KioskSession
  // by placeKioskOrder. Hand it the name the operator typed on the receipt so
  // the ticket the kitchen prints carries it.
  KioskSession.instance.customerName = sale.customerName.text.trim();

  String? paymentRef;
  if (method == PosPaymentMethod.card) {
    onPhase?.call(PosCheckoutPhase.awaitingTerminal);
    final KioskPaymentResult payment = await sl<KioskPaymentService>().pay(
      amount: amount,
      idempotencyKey: idempotencyKey,
    );
    switch (payment.status) {
      case KioskPaymentStatus.paid:
        paymentRef = payment.paymentRef;
      case KioskPaymentStatus.failed:
        return PosCheckoutResult(PosCheckoutStatus.paymentFailed,
            message: payment.message);
      case KioskPaymentStatus.canceled:
        return const PosCheckoutResult(PosCheckoutStatus.paymentCanceled);
    }
  }

  if (!context.mounted) {
    return const PosCheckoutResult(PosCheckoutStatus.orderFailed);
  }

  onPhase?.call(PosCheckoutPhase.placingOrder);
  final KioskPlaceResult placed = await placeKioskOrder(
    context,
    amount: amount,
    paymentRef: paymentRef,
    bringChangeAmount: tenderedAmount,
  );

  if (!placed.success) {
    return PosCheckoutResult(PosCheckoutStatus.orderFailed,
        message: placed.message);
  }

  // Clears the cart, the coupon and the kiosk-side session in one call — the
  // same teardown the kiosk runs after a successful order.
  endKioskCustomerSession(
    context.mounted ? context : null,
    cart: cart,
    coupon: coupon,
  );
  // endKioskCustomerSession resets KioskSession, not the till's own ticket.
  sale.reset();

  return PosCheckoutResult(PosCheckoutStatus.placed, orderId: placed.orderId);
}

/// Asks the terminal to abandon the payment in flight.
///
/// Routes to the same [KioskPaymentService] singleton the payment is running
/// on, so the pending `pay()` future resolves `canceled` rather than being
/// orphaned. Deliberately thin: the service owns what cancelling means.
///
/// Note for whoever wires a real terminal — today's
/// `SimulatedKioskPaymentService.cancel()` only sets a flag; the `pay()` future
/// still waits out its remaining delay before reporting `canceled`. A real
/// implementation should complete the future promptly, or the operator watches
/// a disabled button for as long as the terminal takes to notice.
Future<void> posCancelTerminalPayment() => sl<KioskPaymentService>().cancel();
