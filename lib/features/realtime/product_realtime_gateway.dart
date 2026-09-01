import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:acafe_customer/features/realtime/catalog_event.dart';
import 'package:acafe_customer/features/realtime/catalog_socket_frame.dart';
import 'package:acafe_customer/features/realtime/device_ordering_experience_event.dart';
import 'package:acafe_customer/features/realtime/device_settings_event.dart';
import 'package:acafe_customer/features/realtime/websocket_config.dart';

/// Thin Reverb transport (Pusher protocol, public channels only).
/// UI must not import this.
///
/// Connection lifecycle handled here, deliberately and explicitly, because
/// "the socket is up" is the assumption every realtime feature rests on:
///
///  * **subscribe once per connection** — the ack, not a hopeful flag, is what
///    marks the channel live;
///  * **half-open detection** — a kiosk on hotel wifi loses the socket without
///    ever getting `onDone`; an unanswered ping is what catches that;
///  * **backoff with jitter** — a dead endpoint used to be hammered every 2s
///    forever by every kiosk in the estate, in lockstep;
///  * **reconnect signalling** — `onReconnect` fires only on a re-subscribe,
///    never on the first one, since it is what triggers the client's
///    reconcile-the-gap pass.
class ProductRealtimeGateway {
  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _pingTimer;
  Timer? _pongDeadline;
  Timer? _subscribeFallback;
  Timer? _reconnectTimer;
  WebsocketConfig? _config;
  List<String> _channelNames = const [];
  final Set<String> _confirmedChannels = <String>{};
  int? _branchId;
  int? _deviceId;
  bool _wantConnected = false;
  bool _connectedOnce = false;
  bool _closing = false;
  bool _subscribeSent = false;
  bool _subscribed = false;
  int _attempt = 0;
  int _activityTimeoutSeconds = 30;

  /// Reconnect backoff. First retry is quick because the common case is a
  /// blip; the ceiling keeps a fleet of kiosks from beating on a server that
  /// is genuinely down.
  static const Duration _minBackoff = Duration(seconds: 2);
  static const Duration _maxBackoff = Duration(seconds: 30);

  /// How long to wait for `pusher_internal:subscription_succeeded` before
  /// assuming the server does not ack. Reverb does ack, but a proxy that
  /// strips the frame must not leave the client permanently "connecting".
  static const Duration _subscribeAckGrace = Duration(seconds: 5);

  final Random _random = Random();

  void Function(CatalogEvent event)? onEvent;
  void Function(CatalogEvent event)? onDealEvent;
  void Function(DeviceOrderingExperienceEvent event)?
      onDeviceOrderingExperienceEvent;
  void Function(DeviceSettingsEvent event)? onDeviceSettingsEvent;
  VoidCallback? onReconnect;

  /// Fired on every transition of the live connection, for UI that wants to
  /// show an offline hint. Not required by any current screen.
  void Function(bool connected)? onConnectionChanged;

  int? get branchId => _branchId;
  int? get deviceId => _deviceId;
  List<String> get channelNames => List<String>.unmodifiable(_channelNames);

  /// True only once the server has acknowledged the subscription (or the ack
  /// grace period lapsed on a server that does not send one).
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

    // The endpoint has to match too: comparing the branch alone would skip the
    // reconnect that a corrected config needs against a host that hangs rather
    // than refuses.
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
    _attempt = 0;
    await _open();
  }

  /// Drop the current socket and immediately dial again, keeping the same
  /// channels. Used when the app returns to the foreground: a socket that went
  /// silent while the tab was hidden reports no error at all, so the only safe
  /// move is to re-establish and let the reconnect path reconcile.
  Future<void> reconnectNow() async {
    if (!_wantConnected || _config == null || _channelNames.isEmpty) {
      return;
    }
    _attempt = 0;
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
        (dynamic message) {
          // Any inbound byte proves the pipe is alive.
          _noteActivity();
          _onMessage(message);
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('ProductRealtimeGateway error: $error');
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
      );
      // Reverb can deliver connection_established in the same packet as the
      // handshake. If that frame is missed, still subscribe so live updates work.
      _subscribeFallback?.cancel();
      _subscribeFallback = Timer(const Duration(milliseconds: 400), () {
        if (_wantConnected && !_subscribeSent && identical(_socket, socket)) {
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
    if (CatalogSocketFrame.isSubscriptionSucceeded(message)) {
      final channel = CatalogSocketFrame.subscribedChannel(message);
      if (channel.isNotEmpty) {
        _confirmedChannels.add(channel);
      }
      // The branch channel alone is enough to call the connection live; the
      // device channel may legitimately be absent (device id unknown).
      if (_confirmedChannels.isNotEmpty) {
        _markSubscribed();
      }
      return;
    }
    if (CatalogSocketFrame.isProtocolError(message)) {
      debugPrint(
        'ProductRealtimeGateway protocol error: '
        '${CatalogSocketFrame.protocolErrorMessage(message)}',
      );
      _scheduleReconnect();
      return;
    }
    final settingsEvent = CatalogSocketFrame.deviceSettingsChanged(message);
    if (settingsEvent != null) {
      if (kDebugMode) {
        debugPrint(
          'ProductRealtimeGateway device.settings.changed '
          'device=${settingsEvent.deviceId} action=${settingsEvent.action} '
          'category=${settingsEvent.category} status=${settingsEvent.status}',
        );
      }
      onDeviceSettingsEvent?.call(settingsEvent);
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
    // Guard BEFORE sending. The old order let the 400ms fallback and a late
    // connection_established each send a full set of subscribe frames on the
    // same socket.
    if (_subscribeSent) {
      return;
    }
    _subscribeSent = true;
    _subscribeFallback?.cancel();
    _subscribeFallback = null;

    for (final channelName in _channelNames) {
      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName},
      });
    }
    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeGateway subscribe sent ${_channelNames.join(', ')}',
      );
    }

    _activityTimeoutSeconds = CatalogSocketFrame.activityTimeoutSeconds(data);
    _startHeartbeat();

    // Servers that never ack must not leave the client stuck "connecting" --
    // isConnected gates the reconnect reconciliation.
    _subscribeFallback = Timer(_subscribeAckGrace, () {
      if (_wantConnected && !_subscribed) {
        _markSubscribed();
      }
    });
  }

  void _markSubscribed() {
    if (_subscribed) {
      return;
    }
    _subscribed = true;
    _attempt = 0; // a healthy connection resets the backoff ladder
    _subscribeFallback?.cancel();
    _subscribeFallback = null;
    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeGateway subscribed ${_channelNames.join(', ')}',
      );
    }
    onConnectionChanged?.call(true);

    if (_connectedOnce) {
      onReconnect?.call();
    }
    _connectedOnce = true;
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: _activityTimeoutSeconds), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
      // A silently dead socket answers nothing. Without this deadline the
      // kiosk sits on a dead pipe indefinitely: no onDone, no onError, no
      // events, and isConnected still true.
      _pongDeadline?.cancel();
      _pongDeadline = Timer(
        Duration(seconds: max(5, _activityTimeoutSeconds ~/ 2)),
        () {
          debugPrint('ProductRealtimeGateway ping timed out — reconnecting');
          _scheduleReconnect(immediate: true);
        },
      );
    });
  }

  void _noteActivity() {
    _pongDeadline?.cancel();
    _pongDeadline = null;
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _socket?.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  /// Backoff: 2s, 4s, 8s, 16s, 30s, 30s... each with up to 30% jitter so a
  /// room full of kiosks does not retry in lockstep after a server restart.
  Duration _backoff() {
    final int exponent = _attempt.clamp(0, 6);
    final int base = _minBackoff.inMilliseconds * (1 << exponent);
    final int capped = min(base, _maxBackoff.inMilliseconds);
    final int jitter = _random.nextInt((capped * 0.3).round() + 1);
    return Duration(milliseconds: capped + jitter);
  }

  void _scheduleReconnect({bool immediate = false}) {
    if (_closing || !_wantConnected) {
      return;
    }
    if (_subscribed) {
      onConnectionChanged?.call(false);
    }
    _subscribed = false;
    _subscribeSent = false;
    _confirmedChannels.clear();
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongDeadline?.cancel();
    _pongDeadline = null;
    _subscribeFallback?.cancel();
    _subscribeFallback = null;
    _reconnectTimer?.cancel();

    final Duration delay = immediate ? Duration.zero : _backoff();
    _attempt++;
    if (kDebugMode) {
      debugPrint(
        'ProductRealtimeGateway reconnect in ${delay.inMilliseconds}ms '
        '(attempt $_attempt)',
      );
    }
    _reconnectTimer = Timer(delay, () {
      if (_wantConnected) {
        unawaited(_open());
      }
    });
  }

  Future<void> _closeSocket() async {
    _closing = true;
    if (_subscribed) {
      onConnectionChanged?.call(false);
    }
    _subscribed = false;
    _subscribeSent = false;
    _confirmedChannels.clear();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongDeadline?.cancel();
    _pongDeadline = null;
    _subscribeFallback?.cancel();
    _subscribeFallback = null;
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
    _attempt = 0;
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
