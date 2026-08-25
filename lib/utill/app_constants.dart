import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/common/enums/app_mode_enum.dart';
import 'package:acafe_customer/utill/images.dart';

class AppConstants {
  static const String appName = 'Acafe';
  static const String appVersion = '11.5';

  /// Web push (FCM) — from Firebase Console → Project settings → Cloud Messaging → Web Push certificates
  static const String firebaseWebVapidKey =
      'BD3YRqZOIB9AO9XeAzdSbY6E4RTd6Y70wrzZ-ZKuQcB2uUSvOWiPlNeLl_dsOBDfPw-ClJHe1Le8_bVZztv-4rI';

  /// Flutter SDK 3.32.5
  static const AppMode appMode = AppMode.release;
  static const String _localBaseUrl = 'http://127.0.0.1:8000';
  static const String _productionBaseUrl = 'https://admin.acafepos.com';

  /// Local only in debug web; release always hits production API. Mirrors the
  /// kitchen app so both talk to the SAME backend when running locally —
  /// otherwise kiosk orders land in prod while the kitchen reads local.
  static String get baseUrl {
    if (kIsWeb && kDebugMode) return _localBaseUrl;
    return _productionBaseUrl;
  }

  static const String categoryUri = '/api/v1/categories';
  static const String bannerUri = '/api/v1/banners';
  static const String latestProductUri = '/api/v1/products/latest';
  static const String popularProductUri = '/api/v1/products/popular';
  static const String subCategoryUri = '/api/v1/categories/childes/';
  static const String categoryProductUri = '/api/v1/categories/products/';
  static const String configUri = '/api/v1/config';
  // Kiosk device auth + branch-scoped catalog (branch derived server-side from token)
  static const String kioskDeviceLoginUri = '/api/v1/kiosk/device/login';
  static const String kioskDeviceMeUri = '/api/v1/kiosk/device/me';
  // Customization A/B telemetry (batched, fire-and-forget).
  static const String kioskCustomizeEventsUri =
      '/api/v1/kiosk/customize-events';
  static const String kioskProductsUri = '/api/v1/kiosk/products';
  static const String trackUri = '/api/v1/customer/order/track?order_id=';
  static const String messageUri = '/api/v1/customer/message/get';
  static const String sendMessageUri = '/api/v1/customer/message/send';
  static const String forgetPasswordUri = '/api/v1/auth/forgot-password';
  static const String verifyTokenUri = '/api/v1/auth/verify-token';
  static const String resetPasswordUri = '/api/v1/auth/reset-password';
  static const String checkPhoneUri = '/api/v1/auth/check-phone?phone=';
  static const String verifyPhoneUri = '/api/v1/auth/verify-phone';
  static const String verifyOtpUri = '/api/v1/auth/verify-otp';
  static const String verifyProfileInfo =
      '/api/v1/customer/verify-profile-info';
  static const String checkEmailUri = '/api/v1/auth/check-email';
  static const String verifyEmailUri = '/api/v1/auth/verify-email';
  static const String registerUri = '/api/v1/auth/registration';
  static const String loginUri = '/api/v1/auth/login';
  static const String tokenUri = '/api/v1/customer/cm-firebase-token';
  static const String placeOrderUri = '/api/v1/customer/order/place';
  static const String addressListUri = '/api/v1/customer/address/list';
  static const String removeAddressUri =
      '/api/v1/customer/address/delete?address_id=';
  static const String addAddressUri = '/api/v1/customer/address/add';
  static const String updateAddressUri = '/api/v1/customer/address/update/';
  static const String setMenuUri = '/api/v1/products/set-menu';
  static const String customerInfoUri = '/api/v1/customer/info';
  static const String couponUri = '/api/v1/coupon/list';
  static const String couponApplyUri = '/api/v1/coupon/apply?code=';
  static const String orderListUri = '/api/v1/customer/order/list';
  static const String orderCancelUri = '/api/v1/customer/order/cancel';
  static const String orderDetailsUri =
      '/api/v1/customer/order/details?order_id=';
  static const String wishListGetUri = '/api/v1/customer/wish-list';
  static const String addWishListUri = '/api/v1/customer/wish-list/add';
  static const String removeWishListUri = '/api/v1/customer/wish-list/remove';
  static const String notificationUri = '/api/v1/notifications';
  static const String notificationReadUri = '/api/v1/notifications/read';
  static const String pushNotificationUri =
      'https://fcm.googleapis.com/fcm/send';
  static const String updateProfileUri = '/api/v1/customer/update-profile';
  static const String searchUri = '/api/v1/products/search';
  static const String productDetailsUri = '/api/v1/products/details/';
  static const String productSyncUri = '/api/v1/products/sync';
  static const String lastLocationUri =
      '/api/v1/delivery-man/last-location?deliveryman_id=';
  static const String distanceMatrixUri = '/api/v1/mapapi/distance-api';
  static const String searchLocationUri =
      '/api/v1/mapapi/place-api-autocomplete';
  static const String placeDetailsUri = '/api/v1/mapapi/place-api-details';
  static const String geocodeUri = '/api/v1/mapapi/geocode-api';
  static const String getImagesUrl = '/api/v1/customer/message/chat-images';
  static const String getDeliverymanMessageUri =
      '/api/v1/customer/message/get-order-message';
  static const String getAdminMessageUrl =
      '/api/v1/customer/message/get-admin-message';
  static const String sendMessageToAdminUrl =
      '/api/v1/customer/message/send-admin-message';
  static const String sendMessageToDeliveryManUrl =
      '/api/v1/customer/message/send/customer';
  static const String emailSubscribeUri = '/api/v1/subscribe-newsletter';
  static const String customerRemove = '/api/v1/customer/remove-account';
  static const String policyPage = '/api/v1/pages';
  static const String socialLogin = '/api/v1/auth/social-customer-login';
  static const String walletTransactionUrl =
      '/api/v1/customer/wallet-transactions';
  static const String loyaltyTransactionUrl =
      '/api/v1/customer/loyalty-point-transactions';
  static const String loyaltyPointTransferUrl =
      '/api/v1/customer/transfer-point-to-wallet';
  static const String walletBonusListUrl = '/api/v1/customer/bonus/list';
  static const String addGuest = '/api/v1/guest/add';
  static const String offlinePaymentMethod =
      '/api/v1/offline-payment-method/list';
  static const String guestTrackUrl = '/api/v1/customer/order/guest-track';
  static const String guestOrderDetailsUrl =
      '/api/v1/customer/order/details-guest';
  static const String firebaseAuthVerify = '/api/v1/auth/firebase-auth-verify';
  static const String recommendedProductUri = '/api/v1/products/recommended';
  static const String getDeliveryInfo = '/api/v1/config/delivery-fee';

  static const String allConversationList =
      '/api/v1/customer/message/deliveryman-conversation-list';
  static const String lastOrderedAddress =
      '/api/v1/customer/last-ordered-address';
  static const String frequentlyBoughtApi =
      '/api/v1/products/frequently-bought';
  static const String getReorderProducts = '/api/v1/products/re-order';

  static const String registerWithOtp = '/api/v1/auth/registration-with-otp';
  static const String registerWithSocialMedia =
      '/api/v1/auth/registration-with-social-media';
  static const String existingAccountCheck =
      '/api/v1/auth/existing-account-check';
  static const String subscribeToTopic = '/api/v1/fcm-subscribe-to-topic';
  static const String searchRecommended = '/api/v1/products/search-recommended';
  static const String searchSuggestion = '/api/v1/products/search-suggestion';
  static const String updateReferralInfoShowStatusUri =
      '/api/v1/customer/update-referral-check';

  // Shared Key
  static const String theme = 'theme';
  static const String token = 'token';
  static const String languageCode = 'language_code';
  static const String countryCode = 'country_code';

  /// Locale a kiosk starts in when nobody has picked one yet.
  ///
  /// Deliberately NOT `languages[0]` — that list is ordered for the language
  /// picker (German first), and seeding from it made a fresh kiosk come up in
  /// German. Both the persisted seed (SplashRepo.initSharedData) and the
  /// in-memory default (LocalizationProvider) read these, so the two can never
  /// disagree and flip the language on the next reload.
  static const String defaultLanguageCode = 'en';
  static const String defaultCountryCode = 'US';
  static const String cartList = 'cart_list';
  static const String userPassword = 'user_password';
  static const String userAddress = 'user_address';
  static const String userNumber = 'user_number';
  static const String userLogData = 'user_log_data';
  static const String searchAddress = 'search_address';
  static const String topic = 'notify';
  static const String onBoardingSkip = 'on_boarding_skip';
  static const String placeOrderData = 'place_order_data';
  static const String branch = 'branch';
  static const String cookiesManagement = 'cookies_management';
  static const String guestId = 'guest_id';
  static const String walletToken = 'wallet_token';
  // Kiosk device session keys
  static const String kioskBranchName = 'kiosk_branch_name';
  static const String kioskDeviceName = 'kiosk_device_name';
  static const String kioskUsername = 'kiosk_username';
  static const String kioskDeviceId = 'kiosk_device_id';
  static const String kioskDeviceCategory = 'kiosk_device_category';
  static const String kioskOrderingExperience = 'kiosk_ordering_experience';
  static const String kioskMenuCacheKey = 'kiosk_menu_cache_v1';
  static const String kioskManagerStockCacheKey = 'kiosk_manager_stock_cache_v2';
  static const String currentAddress = 'current_address';
  static const String lastOrderPaymentMethod = 'last_order_payment_method';
  static const String appleLoginEmail = 'apple_login_email';

  /// Languages the kiosk offers, in the order the picker shows them.
  ///
  /// Deliberately short: the kiosk is a café terminal, not the consumer app, so
  /// it ships only the four locales the venue actually serves. Adding one here
  /// also requires `assets/language/<code>.json` — [kiosk_languages_test]
  /// enforces that pairing.
  static List<LanguageModel> languages = [
    LanguageModel(
        imageUrl: Images.netherlands,
        languageName: 'Dutch',
        countryCode: 'NL',
        languageCode: 'nl'),
    LanguageModel(
        imageUrl: Images.unitedKingdom,
        languageName: 'English',
        countryCode: 'US',
        languageCode: 'en'),
    LanguageModel(
        imageUrl: Images.france,
        languageName: 'Français',
        countryCode: 'FR',
        languageCode: 'fr'),
    LanguageModel(
        imageUrl: Images.germany,
        languageName: 'Deutsch',
        countryCode: 'DE',
        languageCode: 'de'),
  ];

  static const int balanceInputLen = 10;

  static final List<Map<String, String>> walletTransactionSortingList = [
    {'title': 'all_transactions', 'value': 'all'},
    {'title': 'order_transactions', 'value': 'order_place'},
    {
      'title': 'converted_from_loyalty_point',
      'value': 'loyalty_point_to_wallet'
    },
    {'title': 'added_via_payment_method', 'value': 'add_fund'},
    {'title': 'earned_by_referral', 'value': 'referral_order_place'},
    {'title': 'earned_by_bonus', 'value': 'add_fund_bonus'},
    {'title': 'added_by_admin', 'value': 'add_fund_by_admin'},
  ];
}
