class WebsocketConfig {
  final bool enabled;
  final String? key;
  final String? host;
  final int port;
  final String scheme;

  const WebsocketConfig({
    this.enabled = false,
    this.key,
    this.host,
    this.port = 443,
    this.scheme = 'https',
  });

  bool get isUsable =>
      enabled &&
      (key?.isNotEmpty ?? false) &&
      (host?.isNotEmpty ?? false);

  bool get useTls =>
      scheme.toLowerCase() == 'https' || scheme.toLowerCase() == 'wss';

  String channelName(int branchId) => 'branch.$branchId.products';

  /// Per-device settings channel (Ordering Experience and future device pushes).
  String deviceSettingsChannelName(int deviceId) => 'device.$deviceId.settings';

  Uri? get socketUri {
    if (!isUsable) return null;
    return Uri(
      scheme: useTls ? 'wss' : 'ws',
      host: host,
      port: port,
      path: '/app/$key',
      queryParameters: const {
        'protocol': '7',
        'client': 'js',
        'version': '8.3.0',
        'flash': 'false',
      },
    );
  }

  factory WebsocketConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const WebsocketConfig();
    return WebsocketConfig(
      enabled: json['enabled'] == true || '${json['enabled']}' == '1',
      key: json['key']?.toString(),
      host: json['host']?.toString(),
      port: int.tryParse('${json['port']}') ?? 443,
      scheme: json['scheme']?.toString() ?? 'https',
    );
  }
}
