/// A pending "Change payment method" on an existing receipt.
///
/// Built by the receipt dialog and carried to the payment screen, where it is
/// committed only when the operator confirms there. Nothing is written to the
/// order until then.
class PosMethodChange {
  final int orderId;
  final String fromMethod;
  final String toMethod;
  final String reason;
  final double total;

  const PosMethodChange({
    required this.orderId,
    required this.fromMethod,
    required this.toMethod,
    required this.reason,
    required this.total,
  });
}
