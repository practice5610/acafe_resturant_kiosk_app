/// Smallest / largest per-category products-per-row override the kiosk will
/// honour. Mirrors the backend's `Device::CATEGORY_COLUMNS_MIN/MAX` and the
/// kiosk's own `KioskResponsive.maxProductColumns`.
const int kCategoryColumnsMin = 1;
const int kCategoryColumnsMax = 6;

/// Parse a `category_columns` payload (object of `categoryId -> columns`, as
/// sent by `/device/login`, `/device/me` and the `device.settings.changed`
/// frame) into a clean `Map<int, int>`. Keys arrive as strings over JSON; only
/// positive ids mapped to an in-range column count survive, so a malformed or
/// out-of-range entry can never push a bad column count to the grid. An empty
/// map ({} on the wire) parses to an empty map -- a valid "no overrides" state,
/// distinct from the field being absent (which the caller treats as null).
Map<int, int> parseCategoryColumnsMap(dynamic raw) {
  if (raw is! Map) {
    return <int, int>{};
  }
  final result = <int, int>{};
  raw.forEach((key, value) {
    final int? id = key is int ? key : int.tryParse('$key');
    final int? cols = value is int ? value : int.tryParse('$value');
    if (id != null &&
        id > 0 &&
        cols != null &&
        cols >= kCategoryColumnsMin &&
        cols <= kCategoryColumnsMax) {
      result[id] = cols;
    }
  });
  return result;
}

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

  /// Per-device "Show Product Images" flag. Null when the frame did not carry
  /// it (older server build) -- that means "leave the local value alone", not
  /// "turn images off", so a kiosk never silently drops into picture-less mode.
  final bool? showImages;

  /// A POS till serving as a kiosk. Null when the frame did not carry it
  /// (older server build): leave the local mode alone rather than read it as
  /// "back to POS".
  final bool? kioskMode;

  /// Per-category products-per-row overrides (categoryId -> columns). Null when
  /// the frame did not carry `category_columns` (older server build) -- that
  /// means "leave the local map alone". An empty map means "no overrides" and
  /// IS applied, so clearing every override on the admin form reaches the kiosk.
  final Map<int, int>? categoryColumns;
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
    this.showImages,
    this.kioskMode,
    this.categoryColumns,
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
      showImages:
          json.containsKey('show_images') ? json['show_images'] == true : null,
      kioskMode:
          json.containsKey('kiosk_mode') ? json['kiosk_mode'] == true : null,
      categoryColumns: json.containsKey('category_columns')
          ? parseCategoryColumnsMap(json['category_columns'])
          : null,
      occurredAt: json['occurred_at']?.toString(),
    );
  }
}
