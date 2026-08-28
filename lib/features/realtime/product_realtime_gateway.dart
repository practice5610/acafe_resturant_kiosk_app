import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:acafe_customer/features/realtime/catalog_event.dart';
import 'package:acafe_customer/features/realtime/catalog_socket_frame.dart';
import 'package:acafe_customer/features/realtime/device_ordering_experience_event.dart';
import 'package:acafe_customer/features/realtime/websocket_config.dart';

/// Thin Reverb transport (Pusher protocol, public channels only).
/// UI must not import this.
class ProductRealtimeGateway {
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  WebsocketConfig? _config;
  List<String> _channelNames = const [];
  int? _branchId;
  int? _deviceId;
  bool _wantConnected = false;
  bool _connectedOnce = false;
  bool _closing = false;
  bool _subscribed = false;

  void Function(CatalogEvent event)? onEvent;
  void Function(CatalogEvent event)? onDealEvent;
  void Function(DeviceOrderingExperienceEvent event)?
      onDeviceOrderingExperienceEvent;
  VoidCallback? onReconnect;

  int? get branchId => _branchId;
  int? get deviceId => _deviceId;
  List<String> get channelNames => List<String>.unmodifiable(_channelNames);
  bool get isConnected =>
      _socket != null && _channelNames.isNotEmpty && _subscribed;

  Future<void> connect({
    required WebsocketConfig config,
    required int branchId,
    int? deviceId,
  }) async {
    if (!config.isUsable || branchId <= 0) {
      return;
    }
    final channels = <String>[config.channelName(branchId)];
    if (deviceId != null && deviceId > 0) {
      channels.add(config.deviceSettingsChannelName(deviceId));
    }

    // The endpoint has to match too. isConnected can read true while nothing
    // is actually connected -- _subscribed is set optimistically by the 400ms
    // fallback in _open() -- so against a host that hangs rather than refuses,
    // comparing the branch alone would skip the reconnect a corrected config
    // needs.
    if (_wantConnected &&
        _branchId == branchId &&
        _deviceId == deviceId &&
        _config?.socketUri == config.socketUri &&
        _listEquals(_channelNames, channels) &&
        isConnected) {
      return;
    }

    _config = config;
    _branchId = branchId;
    _deviceId = deviceId;
    _channelNames = channels;
    _wantConnected = true;
    await _open();
  }

  Future<void> _open() async {
    await _closeSocket();
    final config = _config;
    if (!_wantConnected || config == null || _channelNames.isEmpty) {
      return;
    }

    final uri = config.socketUri;
    if (uri == null) {
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('ProductRealtimeGateway connecting $uri');
      }
      final socket = WebSocketChannel.connect(uri);
      _socket = socket;
      _socketSub = socket.stream.listen(
        _onMessage,
        onError: (Object error, StackTrace stack) {
          debugPrint('ProductRealtimeGateway error: $error');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
      );
      // Reverb can deliver connection_established in the same packet as the
      // handshake. If that frame is missed, still subscribe so live updates work.
      Timer(const Duration(milliseconds: 400), () {
        if (_wantConnected && !_subscribed && identical(_socket, socket)) {
          _subscribe(null);
        }
      });
    } catch (e) {
      debugPrint('ProductRealtimeGateway connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    if (CatalogSocketFrame.isConnectionEstablished(message)) {
      final payload = message is String ? jsonDecode(message) : message;
      _subscribe(payload is Map ? payload['data'] : null);
      return;
    }
    if (CatalogSocketFrame.isProtocolPing(message)) {
      _send({'event': 'pusher:pong', 'data': {}});
      return;
    }
    final dealEvent = CatalogSocketFrame.dealChanged(message);
    if (dealEvent != null) {
      if (kDebugMode) {
        debugPrint(
          'ProductRealtimeGateway deal.changed '
          'id=${dealEvent.dealId} action=${dealEvent.action}',
        );
      }
      onDealEvent?.call(dealEvent);
      return;
    }
    final orderingEvent =
        CatalogSocketFrame.deviceOrderingExperienceChanged(message);
    if (orderingEvent != null) {
      if (kDebugMode) {
        debugPrint(
          'ProductRealtimeGateway device.ordering_experience.changed '
          'device=${orderingEvent.deviceId} '
          'experience=${orderingEvent.orderingExperience}',
        );
      }
      onDeviceOrderingExperienceEvent?.call(orderingEvent);
      return;
    }
    final event = CatalogSocketFrame.productChanged(message);
    if (event != null) {
      if (kDebugMode) {
        debugPrint(
          'ProductRealtimeGateway product.changed '
          'id=${event.productId} action=${event.action} rev=${event.revision}',
        );
      }
      onEvent?.call(event);
    }
  }

  void _subscribe(dynamic data) {
    for (final channelName in _channelNames) {
      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName},
      });
    }
    if (_subscribed) {
      return;
    }
    _subscribed = true;
    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeGateway subscribed ${_channelNames.join(', ')}',
      );
    }

    int timeoutSeconds =
        CatalogSocketFrame.activityTimeoutSeconds(data);
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: timeoutSeconds), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });

    if (_connectedOnce) {
      onReconnect?.call();
    }
    _connectedOnce = true;
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _socket?.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_closing || !_wantConnected) {
      return;
    }
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_wantConnected) {
        unawaited(_open());
      }
    });
  }

  Future<void> _closeSocket() async {
    _closing = true;
    _subscribed = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _socket?.sink.close();
    } catch (_) {}
    _socket = null;
    _closing = false;
  }

  Future<void> disconnect() async {
    _wantConnected = false;
    // _connectedOnce deliberately survives a disconnect. The gateway is a
    // session-long singleton, so the flag means "already subscribed once this
    // session" -- the predicate for reconciling a gap on the next subscribe.
    // Clearing it made every pause/resume look like a first connect and
    // silently skipped the syncMenu reconciliation.
    _channelNames = const [];
    _branchId = null;
    _deviceId = null;
    _config = null;
    await _closeSocket();
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
