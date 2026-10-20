import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';

/// One answer from a POS ⇄ Kiosk endpoint. [statusCode] is null when the server
/// was never reached -- which must not be read as a refusal.
class DeviceModeResponse {
  final int? statusCode;
  final Map<String, dynamic>? data;

  const DeviceModeResponse(this.statusCode, this.data);

  bool get ok => statusCode == 200;

  /// The first entry of the API's `{"errors":[{code, message, ...}]}` shape.
  Map<String, dynamic> get error {
    final Object? errors = data?['errors'];
    if (errors is List && errors.isNotEmpty && errors.first is Map) {
      return Map<String, dynamic>.from(errors.first as Map);
    }
    return const {};
  }

  String? get errorCode => error['code']?.toString();
  String? get errorMessage => error['message']?.toString();
}

/// The till's two mode endpoints (POS_KIOSK_MODE_PHASE1.md §4.4). Both run on
/// the device token; the staff token rides along through the staff session's
/// interceptor, which is what the server checks the permission against.
class DeviceModeRepo {
  final DioClient? dioClient;

  DeviceModeRepo({required this.dioClient});

  /// 4xx come back as answers, not exceptions: a wrong PIN is a 422, and the
  /// app's global handler must never treat it as a reason to sign out.
  static final Options _answers =
      Options(validateStatus: (status) => status != null && status < 500);

  Future<DeviceModeResponse> enterKiosk() =>
      _post(AppConstants.kioskDeviceModeKioskUri, const {});

  Future<DeviceModeResponse> exitKiosk(String pin) =>
      _post(AppConstants.kioskDeviceModePosUri, {'pin': pin});

  Future<DeviceModeResponse> _post(String uri, Map<String, dynamic> body) async {
    final DioClient? client = dioClient;
    if (client == null) return const DeviceModeResponse(null, null);
    try {
      final Response response = await client.post(uri, data: body, options: _answers);
      final Object? data = response.data;
      return DeviceModeResponse(
        response.statusCode,
        data is Map ? Map<String, dynamic>.from(data) : null,
      );
    } catch (_) {
      return const DeviceModeResponse(null, null);
    }
  }
}
