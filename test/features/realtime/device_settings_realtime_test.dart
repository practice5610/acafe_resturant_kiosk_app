@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_ordering_experience.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/realtime/catalog_socket_frame.dart';
import 'package:acafe_customer/features/realtime/device_settings_event.dart';
import 'package:acafe_customer/features/realtime/device_settings_policy.dart';
import 'package:acafe_customer/features/realtime/product_realtime_gateway.dart';
import 'package:acafe_customer/features/realtime/websocket_config.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reverb stand-in: Pusher handshake, subscribe capture, acks, pushes, and the
/// ability to drop a connection so reconnect behaviour can be exercised.
class _FakeReverb {
  _FakeReverb({this.ackSubscriptions = true});

  final bool ackSubscriptions;
  late final HttpServer _server;
  final List<WebSocket> live = <WebSocket>[];
  final List<Map<String, dynamic>> frames = <Map<String, dynamic>>[];
  int connections = 0;

  int get port => _server.port;

  List<Map<String, dynamic>> get subscribeFrames => frames
      .where((frame) => frame['event'] == 'pusher:subscribe')
      .toList(growable: false);

  List<String> get subscribedChannels => subscribeFrames
      .map((frame) => ((frame['data'] as Map)['channel']).toString())
      .toList(growable: false);

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((HttpRequest request) async {
      final WebSocket socket = await WebSocketTransformer.upgrade(request);
      connections++;
      live.add(socket);
      socket.add(jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '1.1', 'activity_timeout': 30}),
      }));
      socket.listen(
        (dynamic message) {
          final decoded = jsonDecode(message as String);
          if (decoded is! Map) return;
          frames.add(Map<String, dynamic>.from(decoded));
          if (ackSubscriptions && decoded['event'] == 'pusher:subscribe') {
            final channel = (decoded['data'] as Map)['channel'];
            socket.add(jsonEncode({
              'event': 'pusher_internal:subscription_succeeded',
              'channel': channel,
              'data': '{}',
            }));
          }
        },
        onDone: () => live.remove(socket),
        onError: (_) => live.remove(socket),
      );
    });
  }

  Future<void> pushSettings({
    required int deviceId,
    String action = 'updated',
    int branchId = 1,
    String category = 'kiosk',
    String status = 'active',
    String name = 'Kiosk 1',
    String orderingExperience = 'version_b',
    String eventId = 'ds-1',
    String channel = 'device.1.settings',
  }) async {
    expect(live, isNotEmpty);
    for (final socket in live) {
      socket.add(jsonEncode({
        'event': 'device.settings.changed',
        'channel': channel,
        'data': jsonEncode({
          'v': 1,
          'event_id': eventId,
          'action': action,
          'device_id': deviceId,
          'branch_id': branchId,
          'category': category,
          'status': status,
          'name': name,
          'ordering_experience': orderingExperience,
          'occurred_at': '2026-09-01T12:00:00+00:00',
        }),
      }));
    }
  }

  /// Kill every live socket without closing the server: the wifi-drop case.
  Future<void> dropConnections() async {
    for (final socket in List<WebSocket>.from(live)) {
      await socket.close();
    }
    live.clear();
  }

  Future<void> stop() async {
    await dropConnections();
    await _server.close(force: true);
  }
}

/// Stand-in for `GET /api/v1/kiosk/device/me`.
class _FakeDeviceApi {
  late final HttpServer _server;
  int status = 200;
  int calls = 0;
  Map<String, dynamic> branch = <String, dynamic>{'id': 1, 'name': 'Amsterdam'};
  Map<String, dynamic>? device = <String, dynamic>{
    'id': 1,
    'name': 'Kiosk 1',
    'category': 'kiosk',
    'status': 'active',
    'ordering_experience': 'version_a',
  };

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((HttpRequest request) async {
      calls++;
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'branch': branch,
        if (device != null) 'device': device,
      }));
      await request.response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);
}

DeviceSettingsEvent _event({
  int deviceId = 1,
  int branchId = 1,
  String action = 'updated',
  String category = 'kiosk',
  String status = 'active',
  String eventId = 'e1',
}) =>
    DeviceSettingsEvent(
      version: 1,
      eventId: eventId,
      action: action,
      deviceId: deviceId,
      branchId: branchId,
      category: category,
      status: status,
      name: 'Kiosk 1',
      orderingExperience: 'version_b',
    );

void main() {
  group('DeviceSettingsPolicy', () {
    test('applies a settings change for this device', () {
      expect(
        DeviceSettingsPolicy.decide(
          event: _event(),
          currentDeviceId: 1,
          currentBranchId: 1,
          duplicateEventId: false,
        ),
        DeviceSettingsClientAction.apply,
      );
    });

    test('ignores an event addressed to a different device', () {
      // The branch channel carries every device's settings, so this is the
      // normal case on a kiosk subscribed to both channels -- not an edge case.
      expect(
        DeviceSettingsPolicy.decide(
          event: _event(deviceId: 2),
          currentDeviceId: 1,
          currentBranchId: 1,
          duplicateEventId: false,
        ),
        DeviceSettingsClientAction.ignore,
      );
    });

    test('ignores a duplicate delivery', () {
      // The same event is broadcast on the device channel AND the branch
      // channel by design; a kiosk on both receives it twice.
      expect(
        DeviceSettingsPolicy.decide(
          event: _event(),
          currentDeviceId: 1,
          currentBranchId: 1,
          duplicateEventId: true,
        ),
        DeviceSettingsClientAction.ignore,
      );
    });

    test('rebinds when the device was moved to another branch', () {
      expect(
        DeviceSettingsPolicy.decide(
          event: _event(branchId: 9),
          currentDeviceId: 1,
          currentBranchId: 1,
          duplicateEventId: false,
        ),
        DeviceSettingsClientAction.applyAndRebind,
      );
    });

    test('signs out on a deactivated device', () {
      expect(
        DeviceSettingsPolicy.decide(
          event: _event(action: 'deactivated', status: 'inactive'),
          currentDeviceId: 1,
          currentBranchId: 1,
          duplicateEventId: false,
        ),
        DeviceSettingsClientAction.signOut,
      );
    });

    test('signs out on a deleted device', () {
      expect(
        DeviceSettingsPolicy.decide(
          event: _event(action: 'deleted'),
          currentDeviceId: 1,
          currentBranchId: 1,
          duplicateEventId: false,
        ),
        DeviceSettingsClientAction.signOut,
      );
    });
  });

  group('CatalogSocketFrame', () {
    Map<String, dynamic> frame(String event, Map<String, dynamic> data) =>
        {'event': event, 'data': jsonEncode(data)};

    test('parses device.settings.changed', () {
      final parsed = CatalogSocketFrame.deviceSettingsChanged(jsonEncode(
        frame('device.settings.changed', {
          'v': 1,
          'event_id': 'e1',
          'action': 'updated',
          'device_id': 4,
          'branch_id': 2,
          'category': 'pos',
          'status': 'active',
          'ordering_experience': 'version_b',
        }),
      ));

      expect(parsed, isNotNull);
      expect(parsed!.deviceId, 4);
      expect(parsed.category, 'pos');
      expect(parsed.branchId, 2);
    });

    test('accepts the Echo-style leading dot', () {
      expect(
        CatalogSocketFrame.deviceSettingsChanged(
          jsonEncode(frame('.device.settings.changed', {'device_id': 4})),
        ),
        isNotNull,
      );
    });

    test('ignores unrelated events and malformed payloads', () {
      expect(
        CatalogSocketFrame.deviceSettingsChanged(
            jsonEncode(frame('product.changed', {'id': 1}))),
        isNull,
      );
      expect(CatalogSocketFrame.deviceSettingsChanged('not json'), isNull);
    });

    test('recognises subscription acks and protocol errors', () {
      final ack = jsonEncode({
        'event': 'pusher_internal:subscription_succeeded',
        'channel': 'branch.1.products',
        'data': '{}',
      });
      expect(CatalogSocketFrame.isSubscriptionSucceeded(ack), isTrue);
      expect(CatalogSocketFrame.subscribedChannel(ack), 'branch.1.products');

      final err = jsonEncode({
        'event': 'pusher:error',
        'data': jsonEncode({'code': 4001, 'message': 'app key not found'}),
      });
      expect(CatalogSocketFrame.isProtocolError(err), isTrue);
      expect(CatalogSocketFrame.protocolErrorMessage(err), 'app key not found');
    });
  });

  group('ProductRealtimeGateway device settings', () {
    late _FakeReverb server;
    late ProductRealtimeGateway gateway;

    WebsocketConfig configFor(_FakeReverb server) => WebsocketConfig(
          enabled: true,
          key: 'test-key',
          host: '127.0.0.1',
          port: server.port,
          scheme: 'http',
        );

    setUp(() async {
      server = _FakeReverb();
      await server.start();
      gateway = ProductRealtimeGateway();
    });

    tearDown(() async {
      await gateway.disconnect();
      await server.stop();
    });

    test('delivers device.settings.changed to the callback', () async {
      final completer = Completer<DeviceSettingsEvent>();
      gateway.onDeviceSettingsEvent = completer.complete;

      await gateway.connect(config: configFor(server), branchId: 1, deviceId: 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await server.pushSettings(deviceId: 1, category: 'pos');

      final event = await completer.future.timeout(const Duration(seconds: 2));
      expect(event.deviceId, 1);
      expect(event.category, 'pos');
      expect(event.isSignOut, isFalse);
    });

    test('subscribes to each channel exactly once per connection', () async {
      await gateway.connect(config: configFor(server), branchId: 1, deviceId: 1);
      // Long enough to cover both the connection_established path and the
      // 400ms fallback that used to fire a second full set of frames.
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(server.subscribedChannels, ['branch.1.products', 'device.1.settings']);
    });

    test('reports connected only once the server acknowledges', () async {
      await gateway.connect(config: configFor(server), branchId: 1, deviceId: 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(gateway.isConnected, isTrue);
    });

    test('still reports connected against a server that never acks', () async {
      final silent = _FakeReverb(ackSubscriptions: false);
      await silent.start();
      addTearDown(silent.stop);
      final quiet = ProductRealtimeGateway();
      addTearDown(quiet.disconnect);

      await quiet.connect(config: configFor(silent), branchId: 1, deviceId: 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      // Before the grace period lapses it is honestly "not yet subscribed"...
      expect(quiet.isConnected, isFalse);

      await Future<void>.delayed(const Duration(seconds: 5));
      // ...and after it, the client degrades to optimistic rather than staying
      // stuck and never reconciling.
      expect(quiet.isConnected, isTrue);
    }, timeout: const Timeout(Duration(seconds: 20)));

    test('reconnects and reports it after the connection drops', () async {
      int reconnects = 0;
      gateway.onReconnect = () => reconnects++;
      final events = <DeviceSettingsEvent>[];
      gateway.onDeviceSettingsEvent = events.add;

      await gateway.connect(config: configFor(server), branchId: 1, deviceId: 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(server.connections, 1);
      expect(reconnects, 0, reason: 'first connect is not a reconnect');

      await server.dropConnections();
      // First backoff step is 2s + up to 30% jitter.
      await Future<void>.delayed(const Duration(seconds: 4));

      expect(server.connections, greaterThan(1));
      expect(reconnects, greaterThan(0));
      expect(gateway.isConnected, isTrue);

      // And the resubscribed socket still delivers.
      await server.pushSettings(deviceId: 1, eventId: 'after-reconnect');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(events, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('reconnectNow re-dials immediately for an app resume', () async {
      await gateway.connect(config: configFor(server), branchId: 1, deviceId: 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(server.connections, 1);

      await gateway.reconnectNow();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(server.connections, 2);
      expect(gateway.isConnected, isTrue);
    });

    test('a disconnected gateway stops retrying', () async {
      await gateway.connect(config: configFor(server), branchId: 1, deviceId: 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await gateway.disconnect();
      final int connectionsAtStop = server.connections;

      await Future<void>.delayed(const Duration(seconds: 3));

      expect(server.connections, connectionsAtStop);
      expect(gateway.isConnected, isFalse);
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  group('KioskAuthProvider.applyDeviceSettingsFromRealtime', () {
    late SharedPreferences prefs;
    late KioskAuthProvider auth;

    Future<void> buildProvider() async {
      prefs = await SharedPreferences.getInstance();
      final dio = DioClient(
        'http://127.0.0.1:1',
        null,
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: prefs,
      );
      auth = KioskAuthProvider(
        kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        AppConstants.token: 'tok',
        AppConstants.branch: 1,
        AppConstants.kioskDeviceId: 1,
        AppConstants.kioskDeviceName: 'Kiosk 1',
        AppConstants.kioskDeviceCategory: 'kiosk',
        AppConstants.kioskOrderingExperience: 'version_a',
      });
      await buildProvider();
    });

    test('applies a device type change', () async {
      var notified = 0;
      auth.addListener(() => notified++);

      final outcome = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 1,
        branchId: 1,
        category: 'pos',
        status: 'active',
        name: 'Kiosk 1',
        orderingExperience: 'version_a',
      );

      expect(outcome, KioskDeviceSettingsOutcome.applied);
      expect(auth.category, 'pos');
      expect(auth.isPosDevice, isTrue);
      expect(notified, greaterThan(0));
    });

    test('applies an ordering experience change', () async {
      final outcome = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 1,
        branchId: 1,
        category: 'kiosk',
        orderingExperience: 'version_b',
        name: 'Kiosk 1',
      );

      expect(outcome, KioskDeviceSettingsOutcome.applied);
      expect(auth.orderingExperience, KioskOrderingExperience.versionB);
    });

    test('is a no-op when nothing actually changed', () async {
      final outcome = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 1,
        branchId: 1,
        category: 'kiosk',
        name: 'Kiosk 1',
        orderingExperience: 'version_a',
      );

      expect(outcome, KioskDeviceSettingsOutcome.ignored);
    });

    test('ignores settings for another device', () async {
      final outcome = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 99,
        branchId: 1,
        category: 'pos',
      );

      expect(outcome, KioskDeviceSettingsOutcome.ignored);
      expect(auth.category, 'kiosk');
    });

    test('a branch move rebinds and drops the old branch caches', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.token: 'tok',
        AppConstants.branch: 1,
        AppConstants.kioskDeviceId: 1,
        AppConstants.kioskDeviceName: 'Kiosk 1',
        AppConstants.kioskDeviceCategory: 'kiosk',
        AppConstants.kioskOrderingExperience: 'version_a',
        AppConstants.kioskMenuCacheKey: '{"cached":"branch-1-menu"}',
        AppConstants.kioskDealsCacheKey: '{"cached":"branch-1-deals"}',
      });
      await buildProvider();

      final outcome = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 1,
        branchId: 9,
        category: 'kiosk',
        name: 'Kiosk 1',
        orderingExperience: 'version_a',
      );

      expect(outcome, KioskDeviceSettingsOutcome.reboundBranch);
      expect(auth.branchId, 9);
      // Branch 1's menu must not survive onto branch 9.
      expect(prefs.getString(AppConstants.kioskMenuCacheKey), isNull);
      expect(prefs.getString(AppConstants.kioskDealsCacheKey), isNull);
    });

    test('a deactivation wipes the session', () async {
      final outcome = await auth.applyDeviceSettingsFromRealtime(
        deviceId: 1,
        branchId: 1,
        status: 'inactive',
        signOut: true,
      );

      expect(outcome, KioskDeviceSettingsOutcome.signedOut);
      expect(auth.isLoggedIn(), isFalse);
      expect(prefs.getString(AppConstants.token), isNull);
    });

    test('ignores a push when no device is logged in', () async {
      SharedPreferences.setMockInitialValues({});
      await buildProvider();

      expect(
        await auth.applyDeviceSettingsFromRealtime(deviceId: 1, category: 'pos'),
        KioskDeviceSettingsOutcome.ignored,
      );
    });
  });

  group('KioskAuthProvider offline and revocation handling', () {
    late _FakeDeviceApi api;
    late SharedPreferences prefs;
    late KioskAuthProvider auth;

    Future<void> buildProvider(String baseUrl) async {
      prefs = await SharedPreferences.getInstance();
      final dio = DioClient(
        baseUrl,
        null,
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: prefs,
      );
      auth = KioskAuthProvider(
        kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
      );
    }

    setUp(() async {
      api = _FakeDeviceApi();
      await api.start();
      SharedPreferences.setMockInitialValues({
        AppConstants.token: 'tok',
        AppConstants.branch: 1,
        AppConstants.kioskDeviceId: 1,
        AppConstants.kioskDeviceName: 'Kiosk 1',
        AppConstants.kioskDeviceCategory: 'kiosk',
        AppConstants.kioskOrderingExperience: 'version_a',
      });
      await buildProvider(api.baseUrl);
    });

    tearDown(() => api.stop());

    test('reconnect reconciliation picks up a category change', () async {
      api.device!['category'] = 'pos';

      expect(await auth.refreshDeviceSettings(),
          KioskDeviceSettingsOutcome.applied);
      expect(auth.category, 'pos');
    });

    test('reconnect reconciliation picks up a branch move', () async {
      api.branch = {'id': 9, 'name': 'Rotterdam'};

      expect(await auth.refreshDeviceSettings(),
          KioskDeviceSettingsOutcome.reboundBranch);
      expect(auth.branchId, 9);
    });

    test('a revoked token on reconnect signs the kiosk out', () async {
      api.status = 401;

      expect(await auth.refreshDeviceSettings(),
          KioskDeviceSettingsOutcome.signedOut);
      expect(auth.isLoggedIn(), isFalse);
    });

    test('an inactive device reported on reconnect signs the kiosk out',
        () async {
      api.device!['status'] = 'inactive';

      expect(await auth.refreshDeviceSettings(),
          KioskDeviceSettingsOutcome.signedOut);
      expect(auth.isLoggedIn(), isFalse);
    });

    test('being offline never signs the kiosk out', () async {
      // Nothing listening on this port: the transport fails outright, which is
      // exactly what a dropped uplink looks like.
      await buildProvider('http://127.0.0.1:1');

      expect(await auth.refreshDeviceSettings(),
          KioskDeviceSettingsOutcome.ignored);
      expect(auth.isLoggedIn(), isTrue);
    });

    test('validateSession keeps the session when the network is down',
        () async {
      await buildProvider('http://127.0.0.1:1');

      // A kiosk booting with the uplink down used to be thrown to a login
      // screen it had no way to complete, discarding a perfectly good token.
      expect(await auth.validateSession(), isTrue);
      expect(auth.isLoggedIn(), isTrue);
      expect(prefs.getString(AppConstants.token), 'tok');
    });

    test('validateSession still wipes a rejected token', () async {
      api.status = 401;

      expect(await auth.validateSession(), isFalse);
      expect(auth.isLoggedIn(), isFalse);
    });

    test('validateSession refreshes settings on a healthy boot', () async {
      api.device!['category'] = 'pos';
      api.device!['ordering_experience'] = 'version_b';

      expect(await auth.validateSession(), isTrue);
      expect(auth.category, 'pos');
      expect(auth.orderingExperience, KioskOrderingExperience.versionB);
    });
  });
}
