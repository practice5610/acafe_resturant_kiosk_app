import 'package:dio/dio.dart';
import 'package:acafe_customer/common/providers/data_sync_provider.dart';
import 'package:acafe_customer/common/reposotories/data_sync_repo.dart';
import 'package:acafe_customer/common/reposotories/product_repo.dart';
import 'package:acafe_customer/features/auth/domain/reposotories/auth_repo.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/device_mode_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_invoice_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_change_method_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_reopen_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_save_changes_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_send_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_standalone_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_payment_service.dart';
import 'package:acafe_customer/features/kiosk/providers/device_mode_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session_repo.dart';
import 'package:acafe_customer/features/realtime/product_realtime_controller.dart';
import 'package:acafe_customer/features/realtime/product_realtime_gateway.dart';
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
  sl.registerLazySingleton(() => PosSplitRepo(dioClient: sl()));
  sl.registerLazySingleton(() => PosSplitByItemRepo(dioClient: sl()));
  sl.registerLazySingleton(() => PosInvoiceRepo(dioClient: sl()));
  sl.registerLazySingleton(() => PosStandaloneRepo(dioClient: sl()));
  sl.registerLazySingleton(() => PosReceiptChangeMethodRepo(dioClient: sl()));
  sl.registerLazySingleton(() => PosReceiptReopenRepo(dioClient: sl()));
  sl.registerLazySingleton(() => PosReceiptSaveChangesRepo(dioClient: sl()));
  sl.registerLazySingleton(() => PosReceiptSendRepo(dioClient: sl()));
  sl.registerLazySingleton(() => PosRefundRepo(dioClient: sl()));
  sl.registerLazySingleton(() => KioskManagerRepo(dioClient: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => KioskDealRepo(dioClient: sl(), sharedPreferences: sl()));
  sl.registerLazySingleton(() => PosOrdersRepo(dioClient: sl()));
  // Card terminal. Still the simulator — there is no Mollie integration in this
  // repo yet (kiosk_payment_service.dart is an interface plus a fake). Registered
  // here so POS resolves the same instance the real one will replace; the kiosk
  // payment screen keeps its own inline instance and is untouched.
  sl.registerLazySingleton<KioskPaymentService>(
      () => SimulatedKioskPaymentService());

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
  sl.registerLazySingleton(() => PosSessionProvider(kioskManagerRepo: sl()));
  // Staff PIN sign-in for branches that switch it on. Registered for every
  // device; it only ever does anything on a POS device whose branch asks.
  sl.registerLazySingleton(() => PosStaffSessionProvider(
        repo: PosStaffSessionRepo(dioClient: sl()),
        tokenStore: const SecurePosStaffTokenStore(),
        dioClient: sl(),
      ));
  sl.registerLazySingleton(() => KioskDealProvider(dealRepo: sl()));
  sl.registerLazySingleton(() => ProductRealtimeGateway());
  sl.registerLazySingleton(() => ProductRealtimeController(
        productRepo: sl(),
        gateway: sl(),
        // A POS ⇄ Kiosk switch this till did not ask for (the panel's Return
        // to POS, or a lost response): bring the till in line first.
        onDeviceModeChanged: () => sl<DeviceModeProvider>().afterRemoteSwitch(),
      ));
  // POS ⇄ Kiosk. The server holds the mode; this asks it to switch and brings
  // the till in line. A staff endpoint refusing the till as not-a-POS means the
  // screen missed a switch, so the realtime layer re-reads the mode.
  sl.registerLazySingleton(() => DeviceModeProvider(
        repo: DeviceModeRepo(dioClient: sl()),
        auth: sl(),
        staff: sl(),
        posSession: sl(),
        kioskManager: sl(),
        cart: sl(),
        dioClient: sl(),
        onStaleMode: () => sl<ProductRealtimeController>().reconcileDeviceSettings(),
      ));


  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => Dio());
  sl.registerLazySingleton(() => LoggingInterceptor());
}
