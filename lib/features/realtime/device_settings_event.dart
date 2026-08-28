/// One `device.settings.changed` frame: the back-office settings of THIS kiosk,
/// pushed the moment an admin saves the Device Update form.
///
/// The server sends a full snapshot rather than a diff, so applying the newest
/// event received is always correct — there is no sequence to replay and no
/// revision counter to keep in step.
class DeviceSettingsEvent {
  final int version;
  final String eventId;
  final String action;
  final int deviceId;
  final int branchId;
  final String orderingExperience;
  final String category;
  final String status;
  final String name;
  final String? occurredAt;

  const DeviceSettingsEvent({
    required this.version,
    required this.eventId,
    required this.action,
    required this.deviceId,
    required this.branchId,
    this.orderingExperience = '',
    this.category = '',
    this.status = 'active',
    this.name = '',
    this.occurredAt,
  });

  static const String actionUpdated = 'updated';
  static const String actionDeactivated = 'deactivated';
  static const String actionDeleted = 'deleted';

  /// The device was switched off or removed in admin. Its tokens are already
  /// revoked server-side, so the kiosk has to drop its session rather than wait
  /// to discover it on the next request.
  bool get isSignOut =>
      action == actionDeactivated ||
      action == actionDeleted ||
      (status.isNotEmpty && status != 'active');

  factory DeviceSettingsEvent.fromJson(Map<String, dynamic> json) {
    return DeviceSettingsEvent(
      version: int.tryParse('${json['v']}') ?? 1,
      eventId: json['event_id']?.toString() ?? '',
      action: json['action']?.toString() ?? actionUpdated,
      deviceId: int.tryParse('${json['device_id']}') ?? 0,
      branchId: int.tryParse('${json['branch_id']}') ?? 0,
      orderingExperience: json['ordering_experience']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      name: json['name']?.toString() ?? '',
      occurredAt: json['occurred_at']?.toString(),
    );
  }
}
