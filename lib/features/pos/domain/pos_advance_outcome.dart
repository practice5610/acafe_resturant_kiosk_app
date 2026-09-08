/// What happened when a POS surface asked to advance an order.
///
/// The board card and the Order Detail overlay both go through one gated
/// method, and that method can now end three different ways — a plain
/// `String?` error could not tell "the operator cancelled the confirmation"
/// apart from "it worked", and the overlay treats those very differently: one
/// closes it, the other must leave it exactly where it was.
enum PosAdvanceOutcome {
  /// The transition was applied (optimistically, then reconciled).
  advanced,

  /// The operator declined the confirmation, or there was no rung to advance
  /// to. Nothing was sent and nothing changed.
  cancelled,

  /// The request was made and rejected. [PosAdvanceResult.message] says why.
  failed,
}

class PosAdvanceResult {
  final PosAdvanceOutcome outcome;

  /// Only set when [outcome] is [PosAdvanceOutcome.failed].
  final String? message;

  const PosAdvanceResult._(this.outcome, [this.message]);

  const PosAdvanceResult.advanced() : this._(PosAdvanceOutcome.advanced);
  const PosAdvanceResult.cancelled() : this._(PosAdvanceOutcome.cancelled);
  const PosAdvanceResult.failed(String message)
      : this._(PosAdvanceOutcome.failed, message);

  bool get isAdvanced => outcome == PosAdvanceOutcome.advanced;
  bool get isFailed => outcome == PosAdvanceOutcome.failed;
}
