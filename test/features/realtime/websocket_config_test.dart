import 'package:acafe_customer/features/realtime/websocket_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isUsable requires enabled key and host', () {
    expect(const WebsocketConfig().isUsable, isFalse);
    expect(
      const WebsocketConfig(enabled: true, key: 'k', host: 'api.example.com')
          .isUsable,
      isTrue,
    );
    expect(
      const WebsocketConfig(enabled: true, key: '', host: 'api.example.com')
          .isUsable,
      isFalse,
    );
  });

  test('fromJson maps the public config payload', () {
    final config = WebsocketConfig.fromJson({
      'enabled': true,
      'key': 'app-key',
      'host': 'api.example.com',
      'port': '443',
      'scheme': 'https',
    });
    expect(config.isUsable, isTrue);
    expect(config.useTls, isTrue);
    expect(config.channelName(3), 'branch.3.products');
    expect(config.deviceSettingsChannelName(1), 'device.1.settings');
    expect(
      config.socketUri.toString(),
      'wss://api.example.com:443/app/app-key?protocol=7&client=js&version=8.3.0&flash=false',
    );
  });

  test('http scheme uses ws and does not build a uri when disabled', () {
    final config = WebsocketConfig.fromJson({
      'enabled': 1,
      'key': 'dev',
      'host': '127.0.0.1',
      'port': 8080,
      'scheme': 'http',
    });
    expect(config.useTls, isFalse);
    expect(config.socketUri?.scheme, 'ws');
    expect(config.socketUri?.port, 8080);
    expect(WebsocketConfig.fromJson(null).socketUri, isNull);
  });
}
