import 'dart:convert';

import 'package:acafe_customer/features/realtime/catalog_event.dart';
import 'package:acafe_customer/features/realtime/device_ordering_experience_event.dart';

class CatalogSocketFrame {
  static String eventName(dynamic message) {
    final payload = _asMap(message);
    return payload?['event']?.toString() ?? '';
  }

  static bool isProtocolPing(dynamic message) =>
      eventName(message) == 'pusher:ping';

  static bool isConnectionEstablished(dynamic message) =>
      eventName(message) == 'pusher:connection_established';

  static int activityTimeoutSeconds(dynamic connectionData, {int fallback = 30}) {
    try {
      final decoded = connectionData is String
          ? jsonDecode(connectionData)
          : connectionData;
      if (decoded is Map && decoded['activity_timeout'] != null) {
        return int.tryParse('${decoded['activity_timeout']}') ?? fallback;
      }
    } catch (_) {}
    return fallback;
  }

  static CatalogEvent? productChanged(dynamic message) {
    try {
      final payload = _asMap(message);
      if (payload == null) {
        return null;
      }
      final name = payload['event']?.toString() ?? '';
      if (!_isProductChanged(name)) {
        return null;
      }
      final dynamic raw = payload['data'] is String
          ? jsonDecode(payload['data'] as String)
          : payload['data'];
      if (raw is! Map) {
        return null;
      }
      return CatalogEvent.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static CatalogEvent? dealChanged(dynamic message) {
    try {
      final payload = _asMap(message);
      if (payload == null) {
        return null;
      }
      final name = payload['event']?.toString() ?? '';
      if (!_isNamed(name, 'deal.changed')) {
        return null;
      }
      final dynamic raw = payload['data'] is String
          ? jsonDecode(payload['data'] as String)
          : payload['data'];
      if (raw is! Map) {
        return null;
      }
      return CatalogEvent.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  static DeviceOrderingExperienceEvent? deviceOrderingExperienceChanged(
      dynamic message) {
    try {
      final payload = _asMap(message);
      if (payload == null) {
        return null;
      }
      final name = payload['event']?.toString() ?? '';
      if (!_isNamed(name, 'device.ordering_experience.changed')) {
        return null;
      }
      final dynamic raw = payload['data'] is String
          ? jsonDecode(payload['data'] as String)
          : payload['data'];
      if (raw is! Map) {
        return null;
      }
      return DeviceOrderingExperienceEvent.fromJson(
          Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  /// Reverb sends `product.changed`. Echo-style clients use a leading dot.
  static bool _isProductChanged(String name) =>
      _isNamed(name, 'product.changed');

  static bool _isNamed(String name, String expected) {
    final normalized = name.startsWith('.') ? name.substring(1) : name;
    return normalized == expected;
  }

  static Map<String, dynamic>? _asMap(dynamic message) {
    try {
      final decoded = message is String ? jsonDecode(message) : message;
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
}
