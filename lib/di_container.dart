import 'package:dio/dio.dart';
import 'package:acafe_customer/common/providers/data_sync_provider.dart';
import 'package:acafe_customer/common/reposotories/data_sync_repo.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/features/auth/domain/reposotories/auth_repo.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/coupon/domain/reposotories/coupon_repo.dart';
import 'package:acafe_customer/features/order/domain/reposotories/order_repo.dart';
import 'package:acafe_customer/features/language/domain/reposotories/language_repo.dart';
import 'package:acafe_customer/features/search/domain/reposotories/search_repo.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/order/providers/order_provider.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/features/language/providers/language_provider.dart';
import 'package:acafe_customer/features/search/providers/search_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/common/providers/theme_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/datasource/remote/dio/dio_client.dart';
import 'data/datasource/remote/dio/logging_interceptor.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Core
  sl.registerLazySingleton(() => DioClient(AppConstants.baseUrl, sl(), loggingInterceptor: sl(), sharedPreferences: sl()));

  // Repository
  sl.registerLazySingleton(() => DataSyncRepo(dioClient: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => SplashRepo(sharedPreferences: sl(), dioClient: sl()));
  sl.registerLazySingleton(() => CategoryRepo(dioClient: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => ProductRepo(dioClient: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => LanguageRepo());
  sl.registerLazySingleton(() => AuthRepo(dioClient: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => CartRepo(sharedPreferences: sl()));
  sl.registerLazySingleton(() => OrderRepo(dioClient: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => SearchRepo(dioClient: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => CouponRepo(dioClient: sl()));
  sl.registerLazySingleton(() => KioskAuthRepo(dioClient: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => KioskOrderRepo(dioClient: sl()));
  sl.registerLazySingleton(() => KioskManagerRepo(dioClient: sl(), sharedPreferences: sl()));

  // Provider
  sl.registerLazySingleton(() => DataSyncProvider());
  sl.registerLazySingleton(() => ThemeProvider(sharedPreferences: sl()));
  sl.registerLazySingleton(() => SplashProvider(splashRepo: sl()));
  sl.registerLazySingleton(() => LocalizationProvider(sharedPreferences: sl(), dioClient: sl()));
  sl.registerLazySingleton(() => LanguageProvider(languageRepo: sl()));
  sl.registerLazySingleton(() => CategoryProvider(categoryRepo: sl()));
  sl.registerLazySingleton(() => AuthProvider(authRepo: sl()));
  sl.registerLazySingleton(() => ProductProvider(productRepo: sl()));
  sl.registerLazySingleton(() => CartProvider(cartRepo: sl()));
  sl.registerLazySingleton(() => OrderProvider(orderRepo: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => CouponProvider(couponRepo: sl()));
  sl.registerLazySingleton(() => SearchProvider(searchRepo: sl()));
  sl.registerLazySingleton(() => BranchProvider(splashRepo: sl()));
  sl.registerLazySingleton(() => KioskAuthProvider(kioskAuthRepo: sl()));
  sl.registerLazySingleton(() => KioskManagerProvider(kioskManagerRepo: sl()));


  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => LoggingInterceptor());
}
