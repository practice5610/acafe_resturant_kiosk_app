class CatalogEvent {
  final int version;
  final String eventId;
  final String action;
  final int productId;
  final int branchId;
  final int revision;
  final String? occurredAt;

  const CatalogEvent({
    required this.version,
    required this.eventId,
    required this.action,
    required this.productId,
    required this.branchId,
    required this.revision,
    this.occurredAt,
  });

  bool get isDelete => action == 'deleted';
  bool get isRefresh => action == 'refresh';
  bool get isAvailability => action == 'availability';

  factory CatalogEvent.fromJson(Map<String, dynamic> json) {
    return CatalogEvent(
      version: int.tryParse('${json['v']}') ?? 1,
      eventId: json['event_id']?.toString() ?? '',
      action: json['action']?.toString() ?? 'updated',
      productId: int.tryParse('${json['product_id']}') ?? 0,
      branchId: int.tryParse('${json['branch_id']}') ?? 0,
      revision: int.tryParse('${json['revision']}') ?? 0,
      occurredAt: json['occurred_at']?.toString(),
    );
  }
}
