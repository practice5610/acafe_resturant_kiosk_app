import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Orders detail overlay's item rows read [KioskAuthProvider.showImages]
/// (the per-device Show Images toggle). The overlay tests predate that toggle
/// and never mounted the provider, so every item row threw
/// `ProviderNotFoundException`. Mount this beside the other test providers.
///
/// Built on the mocked [SharedPreferences] the caller already set up; an unset
/// flag reads as "show images", which is what the goldens were drawn with.
ChangeNotifierProvider<KioskAuthProvider> testKioskAuthProvider(
  SharedPreferences prefs,
) {
  return ChangeNotifierProvider<KioskAuthProvider>(
    create: (_) => KioskAuthProvider(
      kioskAuthRepo: KioskAuthRepo(
        dioClient: DioClient(
          AppConstants.baseUrl,
          null,
          loggingInterceptor: LoggingInterceptor(),
          sharedPreferences: prefs,
        ),
        sharedPreferences: prefs,
      ),
    ),
  );
}
