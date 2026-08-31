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
import 'package:acafe_customer/features/realtime/device_ordering_experience_event.dart';
import 'package:acafe_customer/features/realtime/product_realtime_gateway.dart';
import 'package:acafe_customer/features/realtime/websocket_config.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal Reverb stand-in: Pusher handshake + subscribe capture + push.
class _FakeReverb {
  late final HttpServer _server;
  final List<WebSocket> live = <WebSocket>[];
  final List<Map<String, dynamic>> frames = <Map<String, dynamic>>[];

  int get port => _server.port;

  List<Map<String, dynamic>> get subscribeFrames => frames
      .where((frame) => frame['event'] == 'pusher:subscribe')
      .toList(growable: false);

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((HttpRequest request) async {
      final WebSocket socket = await WebSocketTransformer.upgrade(request);
      live.add(socket);
      socket.add(jsonEncode({
        'event': 'pusher:connection_established',
        'data': jsonEncode({'socket_id': '1.1', 'activity_timeout': 30}),
      }));
      socket.listen(
        (dynamic message) {
          final decoded = jsonDecode(message as String);
          if (decoded is Map) {
            frames.add(Map<String, dynamic>.from(decoded));
          }
        },
        onDone: () => live.remove(socket),
        onError: (_) => live.remove(socket),
      );
    });
  }

  Future<void> pushOrderingExperience({
    required int deviceId,
    required String experience,
    String channel = 'device.1.settings',
  }) async {
    expect(live, isNotEmpty);
    for (final socket in live) {
      socket.add(jsonEncode({
        'event': 'device.ordering_experience.changed',
        'channel': channel,
        'data': jsonEncode({
          'v': 1,
          'event_id': 'ox-test-$deviceId-$experience',
          'device_id': deviceId,
          'branch_id': 1,
          'ordering_experience': experience,
          'occurred_at': '2026-08-28T12:00:00+00:00',
        }),
      }));
    }
  }

  Future<void> stop() async {
    for (final socket in List<WebSocket>.from(live)) {
      await socket.close();
    }
    live.clear();
    await _server.close(force: true);
  }
}


/// Minimal stand-in for `GET /api/v1/kiosk/device/me`.
class _FakeDeviceApi {
  late final HttpServer _server;
  int status = 200;
  Map<String, dynamic>? device = <String, dynamic>{
    'id': 1,
    'name': 'kiosk@gmail.com',
    'category': 'kiosk',
    'ordering_experience': 'version_b',
  };
  int calls = 0;

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((HttpRequest request) async {
      calls++;
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'branch': {'id': 1, 'name': 'Acafe/Amsterdam'},
        if (device != null) 'device': device,
      }));
      await request.response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  group('ProductRealtimeGateway ordering experience', () {
    late _FakeReverb server;
    late ProductRealtimeGateway gateway;

    setUp(() async {
      server = _FakeReverb();
      await server.start();
      gateway = ProductRealtimeGateway();
    });

    tearDown(() async {
      await gateway.disconnect();
      await server.stop();
    });

    WebsocketConfig configFor(_FakeReverb server) => WebsocketConfig(
          enabled: true,
          key: 'test-key',
          host: '127.0.0.1',
          port: server.port,
          scheme: 'http',
        );

    test('subscribes to branch products and device settings', () async {
      await gateway.connect(
        config: configFor(server),
        branchId: 1,
        deviceId: 1,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final channels = server.subscribeFrames
          .map((frame) => (frame['data'] as Map)['channel'])
          .toList();
      expect(channels, containsAll(['branch.1.products', 'device.1.settings']));
    });

    test('delivers device.ordering_experience.changed to the callback', () async {
      final completer = Completer<DeviceOrderingExperienceEvent>();
      gateway.onDeviceOrderingExperienceEvent = completer.complete;

      await gateway.connect(
        config: configFor(server),
        branchId: 1,
        deviceId: 1,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      await server.pushOrderingExperience(
        deviceId: 1,
        experience: 'version_b',
      );

      final event = await completer.future.timeout(const Duration(seconds: 2));
      expect(event.deviceId, 1);
      expect(event.orderingExperience, 'version_b');
    });
  });

  group('KioskAuthProvider.applyOrderingExperienceFromRealtime', () {
    late SharedPreferences prefs;
    late KioskAuthProvider auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        AppConstants.token: 'tok',
        AppConstants.branch: 1,
        AppConstants.kioskDeviceId: 1,
        AppConstants.kioskOrderingExperience: 'version_a',
      });
      prefs = await SharedPreferences.getInstance();
      final dio = DioClient(
        'http://localhost',
        null,
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: prefs,
      );
      auth = KioskAuthProvider(
        kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
      );
    });

    test('updates cached experience and notifies listeners', () async {
      var notified = 0;
      auth.addListener(() => notified++);

      final changed = await auth.applyOrderingExperienceFromRealtime(
        deviceId: 1,
        orderingExperience: 'version_b',
      );

      expect(changed, isTrue);
      expect(auth.orderingExperience, KioskOrderingExperience.versionB);
      expect(prefs.getString(AppConstants.kioskOrderingExperience), 'version_b');
      expect(notified, greaterThan(0));
    });

    test('ignores events for a different device', () async {
      final changed = await auth.applyOrderingExperienceFromRealtime(
        deviceId: 99,
        orderingExperience: 'version_b',
      );

      expect(changed, isFalse);
      expect(auth.orderingExperience, KioskOrderingExperience.versionA);
    });

    test('is a no-op when experience is already current', () async {
      final changed = await auth.applyOrderingExperienceFromRealtime(
        deviceId: 1,
        orderingExperience: 'version_a',
      );
      expect(changed, isFalse);
    });

    test('adopts device id when the session never stored one', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.token: 'tok',
        AppConstants.branch: 1,
        AppConstants.kioskOrderingExperience: 'version_a',
      });
      prefs = await SharedPreferences.getInstance();
      final dio = DioClient(
        'http://localhost',
        null,
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: prefs,
      );
      auth = KioskAuthProvider(
        kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
      );

      final changed = await auth.applyOrderingExperienceFromRealtime(
        deviceId: 7,
        orderingExperience: 'version_b',
      );

      expect(changed, isTrue);
      expect(auth.deviceId, 7);
      expect(auth.orderingExperience, KioskOrderingExperience.versionB);
    });
  });

  group('KioskAuthProvider.refreshDeviceSettings', () {
    late _FakeDeviceApi api;
    late SharedPreferences prefs;
    late KioskAuthProvider auth;

    Future<void> buildProvider() async {
      prefs = await SharedPreferences.getInstance();
      final dio = DioClient(
        api.baseUrl,
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
        AppConstants.kioskOrderingExperience: 'version_a',
      });
      await buildProvider();
    });

    tearDown(() => api.stop());

    test('adopts the experience the server reports after a socket gap', () async {
      var notified = 0;
      auth.addListener(() => notified++);

      final changed = await auth.refreshDeviceSettings();

      expect(changed, isTrue);
      expect(auth.orderingExperience, KioskOrderingExperience.versionB);
      expect(prefs.getString(AppConstants.kioskOrderingExperience), 'version_b');
      expect(notified, greaterThan(0));
    });

    test('is a no-op when the server already agrees', () async {
      api.device!['ordering_experience'] = 'version_a';

      expect(await auth.refreshDeviceSettings(), isFalse);
      expect(auth.orderingExperience, KioskOrderingExperience.versionA);
    });

    test('keeps the session on a failed request', () async {
      api.status = 500;

      expect(await auth.refreshDeviceSettings(), isFalse);
      // A reconnect is when transient failures are likeliest -- this path must
      // never log the kiosk out the way validateSession() does.
      expect(auth.isLoggedIn(), isTrue);
      expect(prefs.getString(AppConstants.token), 'tok');
    });

    test('does not downgrade to Version A when the field is absent', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.token: 'tok',
        AppConstants.branch: 1,
        AppConstants.kioskDeviceId: 1,
        AppConstants.kioskOrderingExperience: 'version_b',
      });
      await buildProvider();
      api.device!.remove('ordering_experience');

      expect(await auth.refreshDeviceSettings(), isFalse);
      expect(auth.orderingExperience, KioskOrderingExperience.versionB);
    });

    test('skips the request entirely when no device is logged in', () async {
      SharedPreferences.setMockInitialValues({});
      await buildProvider();

      expect(await auth.refreshDeviceSettings(), isFalse);
      expect(api.calls, 0);
    });
  });
}
