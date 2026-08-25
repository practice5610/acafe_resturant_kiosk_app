import 'dart:async';

/// Result of a terminal payment attempt.
enum KioskPaymentStatus { paid, failed, canceled }

class KioskPaymentResult {
  final KioskPaymentStatus status;
  final String? paymentRef;
  final String? message;
  const KioskPaymentResult(this.status, {this.paymentRef, this.message});
}

/// Abstraction over the physical card terminal (Mollie A35).
///
/// The UI (payment screen + retry/stop modal) talks only to this interface, so
/// the real Mollie POS integration can be dropped in without touching widgets.
///
/// REAL IMPLEMENTATION TODO (wire to backend, mirror acafe_restaurant_user_web_app):
///   1. POST to your backend to create a Mollie *terminal* payment for this
///      device's MOLLIE_TERMINAL_ID with `amount` and an idempotency key.
///   2. The A35 then prompts tap/insert/swipe and shows the amount.
///   3. Poll your backend (or receive the Mollie webhook) until the payment is
///      `paid` / `failed` / `canceled` / `expired`, then complete the Future.
abstract class KioskPaymentService {
  /// Begins a terminal payment for [amount]. [idempotencyKey] must be stable
  /// across retries of the *same* checkout attempt to avoid double charges.
  Future<KioskPaymentResult> pay({
    required double amount,
    required String idempotencyKey,
  });

  /// Cancel an in-flight terminal payment (e.g. user pressed Stop).
  Future<void> cancel();
}

/// Simulated terminal for development before the Mollie integration is wired.
/// Succeeds after a short delay. Flip [forceFailure] to exercise the
/// failure → Retry / Stop flow shown in the reference screens.
class SimulatedKioskPaymentService implements KioskPaymentService {
  bool forceFailure;
  SimulatedKioskPaymentService({this.forceFailure = false});

  bool _canceled = false;

  @override
  Future<KioskPaymentResult> pay(
      {required double amount, required String idempotencyKey}) async {
    _canceled = false;
    await Future.delayed(const Duration(seconds: 4));
    if (_canceled) {
      return const KioskPaymentResult(KioskPaymentStatus.canceled);
    }
    if (forceFailure) {
      return const KioskPaymentResult(KioskPaymentStatus.failed,
          message: 'Payment failed');
    }
    return KioskPaymentResult(
      KioskPaymentStatus.paid,
      paymentRef: 'SIM-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  Future<void> cancel() async {
    _canceled = true;
  }
}
