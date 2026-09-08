/// One `order.changed` frame off `branch.{id}.orders`.
///
/// Carries an id and a status and nothing else — the channel is public, exactly
/// like `branch.{id}.products`, so customer names, addresses and amounts never
/// ride on it. This is a "something moved, go refetch" ping; the board pulls the
/// real row over the authenticated device endpoint.
class OrderChangedEvent {
  final int version;
  final String eventId;
  final int orderId;
  final int branchId;
  final String orderStatus;
  final String? occurredAt;

  const OrderChangedEvent({
    required this.version,
    required this.eventId,
    required this.orderId,
    required this.branchId,
    required this.orderStatus,
    this.occurredAt,
  });

  factory OrderChangedEvent.fromJson(Map<String, dynamic> json) {
    return OrderChangedEvent(
      version: int.tryParse('${json['v']}') ?? 1,
      eventId: json['event_id']?.toString() ?? '',
      orderId: int.tryParse('${json['order_id']}') ?? 0,
      branchId: int.tryParse('${json['branch_id']}') ?? 0,
      orderStatus: json['order_status']?.toString() ?? '',
      occurredAt: json['occurred_at']?.toString(),
    );
  }
}
