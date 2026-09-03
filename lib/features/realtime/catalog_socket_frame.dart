import 'dart:convert';

import 'package:acafe_customer/features/realtime/catalog_event.dart';
import 'package:acafe_customer/features/realtime/device_ordering_experience_event.dart';
import 'package:acafe_customer/features/realtime/device_settings_event.dart';

class CatalogSocketFrame {
  static String eventName(dynamic message) {
    final payload = _asMap(message);
    return payload?['event']?.toString() ?? '';
  }

  static bool isProtocolPing(dynamic message) =>
      eventName(message) == 'pusher:ping';

  static bool isConnectionEstablished(dynamic message) =>
      eventName(message) == 'pusher:connection_established';

  /// Reverb's per-channel ack. The gateway used to assume its subscribe frame
  /// worked, so a rejected channel still reported as connected -- and the
  /// reconnect reconciliation that depends on that flag never ran.
  static bool isSubscriptionSucceeded(dynamic message) =>
      eventName(message) == 'pusher_internal:subscription_succeeded';

  /// Channel named by a subscription ack, or '' when the frame is not one.
  static String subscribedChannel(dynamic message) {
    final payload = _asMap(message);
    if (payload == null) return '';
    if (payload['event']?.toString() != 'pusher_internal:subscription_succeeded') {
      return '';
    }
    return payload['channel']?.toString() ?? '';
  }

  /// Protocol-level error frame (bad app key, unknown channel, over quota).
  /// Reverb closes the socket after some of these and not others, so the
  /// gateway has to treat one as a reconnect trigger in its own right.
  static bool isProtocolError(dynamic message) =>
      eventName(message) == 'pusher:error';

  static String protocolErrorMessage(dynamic message) {
    try {
      final payload = _asMap(message);
      if (payload == null) return '';
      final dynamic raw = payload['data'] is String
          ? jsonDecode(payload['data'] as String)
          : payload['data'];
      if (raw is! Map) return '';
      return raw['message']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

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

  static CatalogEvent? couponChanged(dynamic message) {
    try {
      final payload = _asMap(message);
      if (payload == null) {
        return null;
      }
      final name = payload['event']?.toString() ?? '';
      if (!_isNamed(name, 'coupon.changed')) {
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

  static DeviceSettingsEvent? deviceSettingsChanged(dynamic message) {
    try {
      final payload = _asMap(message);
      if (payload == null) {
        return null;
      }
      final name = payload['event']?.toString() ?? '';
      if (!_isNamed(name, 'device.settings.changed')) {
        return null;
      }
      final dynamic raw = payload['data'] is String
          ? jsonDecode(payload['data'] as String)
          : payload['data'];
      if (raw is! Map) {
        return null;
      }
      return DeviceSettingsEvent.fromJson(Map<String, dynamic>.from(raw));
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
