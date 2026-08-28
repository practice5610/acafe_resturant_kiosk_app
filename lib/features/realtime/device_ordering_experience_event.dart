/// Socket payload for `device.ordering_experience.changed`.
///
/// Mirrors `App\Events\DeviceOrderingExperienceChanged::broadcastWith`.
class DeviceOrderingExperienceEvent {
  final int version;
  final String eventId;
  final int deviceId;
  final int branchId;
  final String orderingExperience;
  final String? occurredAt;

  const DeviceOrderingExperienceEvent({
    required this.version,
    required this.eventId,
    required this.deviceId,
    required this.branchId,
    required this.orderingExperience,
    this.occurredAt,
  });

  factory DeviceOrderingExperienceEvent.fromJson(Map<String, dynamic> json) {
    return DeviceOrderingExperienceEvent(
      version: int.tryParse('${json['v']}') ?? 1,
      eventId: json['event_id']?.toString() ?? '',
      deviceId: int.tryParse('${json['device_id']}') ?? 0,
      branchId: int.tryParse('${json['branch_id']}') ?? 0,
      orderingExperience: json['ordering_experience']?.toString() ?? '',
      occurredAt: json['occurred_at']?.toString(),
    );
  }
}
