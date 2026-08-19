import 'package:acafe_customer/features/realtime/websocket_config.dart';

class ConfigModel {
  String? _restaurantName;
  String? _restaurantLogo;
  String? _restaurantAddress;
  String? _restaurantPhone;
  String? _restaurantEmail;
  BaseUrls? _baseUrls;
  String? _currencySymbol;
  bool? _cashOnDelivery;
  bool? _digitalPayment;
  String? _termsAndConditions;
  String? _privacyPolicy;
  String? _aboutUs;
  bool? _emailVerification;
  bool? _phoneVerification;
  String? _currencySymbolPosition;
  String? _countryCode;
  bool? _selfPickup;
  bool? _homeDelivery;
  RestaurantLocationCoverage? _restaurantLocationCoverage;
  double? _minimumOrderValue;
  List<Branches?>? _branches;
  PlayStoreConfig? _playStoreConfig;
  AppStoreConfig? _appStoreConfig;
  List<SocialMediaLink>? _socialMediaLink;
  String? _softwareVersion;
  String? _footerCopyright;
  String? _timeZone;
  int? _decimalPointSettings;
  List<RestaurantScheduleTime>? _restaurantScheduleTime;
  int? _scheduleOrderSlotDuration;
  String? _timeFormat;
  SocialStatus? _socialLoginStatus;
  double? _loyaltyPointItemPurchasePoint;
  bool? _loyaltyPointStatus;
  double?  _loyaltyPointMinimumPoint;
  double? _loyaltyPointExchangeRate;
  bool? _referEarningStatus;
  bool? _customerReferredDiscountStatus;
  bool? _walletStatus;
  Whatsapp? _whatsapp;
  CookiesManagement? _cookiesManagement;
  int? _otpResendTime;
  bool? _isVegNonVegActive;
  List<PaymentMethod>? _activePaymentMethodList;
  bool? _isOfflinePayment;
  bool? _isGuestCheckout;
  bool? _isPartialPayment;
  bool? _isAddFundToWallet;
  String? _partialPaymentCombineWith;
  DigitalPaymentInfo? _digitalPaymentInfo;
  AppleLogin? _appleLogin;
  bool? _isFirebaseOTPVerification;
  CustomerVerification? _customerVerification;
  String? _footerDescription;
  bool? _cutleryStatus;
  MaintenanceMode? _maintenanceMode;
  CustomerLogin? _customerLogin;
  int? _googleMapStatus;
  int? _halalTagStatus;
  WebsocketConfig? _websocket;


  ConfigModel(
      {String? restaurantName,
        String? restaurantLogo,
        String? restaurantAddress,
        String? restaurantPhone,
        String? restaurantEmail,
        BaseUrls? baseUrls,
        String? currencySymbol,
        bool? cashOnDelivery,
        bool? digitalPayment,
        String? termsAndConditions,
        String? privacyPolicy,
        String? aboutUs,
        bool? emailVerification,
        bool? phoneVerification,
        String? currencySymbolPosition,
        String? countryCode,
        RestaurantLocationCoverage? restaurantLocationCoverage,
        double? minimumOrderValue,
        List<Branches?>? branches,
        bool? selfPickup,
        bool? homeDelivery,

        PlayStoreConfig? playStoreConfig,
        AppStoreConfig? appStoreConfig,
        List<SocialMediaLink>? socialMediaLink,
        String? softwareVersion,
        String? footerCopyright,
        String? timeZone,
        int? decimalPointSettings,
        List<RestaurantScheduleTime>? restaurantScheduleTime,
        int? scheduleOrderSlotDuration,
        String? timeFormat,
        SocialStatus? socialLoginStatus,
        double? loyaltyPointItemPurchasePoint,
        bool? loyaltyPointStatus,
        double? loyaltyPointMinimumPoint,
        double? loyaltyPointExchangeRate,
        bool? referEarningStatus,
        bool? customerReferredDiscountStatus,
        bool? walletStatus,
        Whatsapp? whatsapp,
        CookiesManagement? cookiesManagement,
        int? otpResendTime,
        bool? isVegNonVegActive,
        List<PaymentMethod>? activePaymentMethodList,
        bool? isOfflinePayment,
        bool? isGuestCheckout,
        bool? isPartialPayment,
        bool? isAddFundToWallet,
        String? partialPaymentCombineWith,
        DigitalPaymentInfo? digitalPaymentInfo,
        AppleLogin? appleLogin,
        bool? isFirebaseOTPVerification,
        CustomerVerification? customerVerification,
        String? footerDescription,
        bool? cutleryStatus,
        MaintenanceMode? maintenanceMode,
        CustomerLogin? customerLogin,
        int? googleMapStatus,
        int? halalTagStatus
      }) {
    _restaurantName = restaurantName;
    _restaurantLogo = restaurantLogo;
    _restaurantAddress = restaurantAddress;
    _restaurantPhone = restaurantPhone;
    _restaurantEmail = restaurantEmail;
    _baseUrls = baseUrls;
    _currencySymbol = currencySymbol;
    _cashOnDelivery = cashOnDelivery;
    _digitalPayment = digitalPayment;
    _termsAndConditions = termsAndConditions;
    _aboutUs = aboutUs;
    _privacyPolicy = privacyPolicy;
    _restaurantLocationCoverage = restaurantLocationCoverage;
    _minimumOrderValue = minimumOrderValue;
    _branches = branches;
    _emailVerification = emailVerification;
    _phoneVerification = phoneVerification;
    _currencySymbolPosition = currencySymbolPosition;
    _countryCode = countryCode;
    _selfPickup = selfPickup;
    _homeDelivery = homeDelivery;
    if (playStoreConfig != null) {
      _playStoreConfig = playStoreConfig;
    }
    if (appStoreConfig != null) {
      _appStoreConfig = appStoreConfig;
    }
    if (socialMediaLink != null) {
      _socialMediaLink = socialMediaLink;
    }
    if (maintenanceMode != null) {
      _maintenanceMode = maintenanceMode;
    }
    if(customerLogin != null){
      _customerLogin = customerLogin;
    }
    _softwareVersion = softwareVersion ?? '';
    _footerCopyright = footerCopyright ?? '';
    _timeZone = timeZone ?? '';
    _decimalPointSettings = decimalPointSettings ?? 1;
    _restaurantScheduleTime = restaurantScheduleTime;
    _scheduleOrderSlotDuration = scheduleOrderSlotDuration;
    _timeFormat = timeFormat;
    _activePaymentMethodList = activePaymentMethodList;
    _loyaltyPointItemPurchasePoint = loyaltyPointItemPurchasePoint;
    _loyaltyPointStatus = _loyaltyPointStatus;
    _loyaltyPointMinimumPoint = loyaltyPointMinimumPoint;
    _loyaltyPointExchangeRate = loyaltyPointExchangeRate;
    _referEarningStatus = referEarningStatus;
    _customerReferredDiscountStatus = customerReferredDiscountStatus;
    _walletStatus = walletStatus;
    _whatsapp = whatsapp;
    _cookiesManagement = cookiesManagement;
    _otpResendTime = otpResendTime;
    _isVegNonVegActive = isVegNonVegActive;
    _activePaymentMethodList = activePaymentMethodList;
    _isOfflinePayment = isOfflinePayment;
    _isGuestCheckout = isGuestCheckout;
    _isPartialPayment = isPartialPayment;
    _isAddFundToWallet = isAddFundToWallet;
    _partialPaymentCombineWith = partialPaymentCombineWith;
    _digitalPaymentInfo = digitalPaymentInfo;
    _appleLogin = appleLogin;
    _isFirebaseOTPVerification = isFirebaseOTPVerification;
    _customerVerification = customerVerification;
    _footerDescription = footerDescription;
    _cutleryStatus = cutleryStatus;
    _googleMapStatus = googleMapStatus;
    _halalTagStatus = halalTagStatus;

  }

  String? get restaurantName => _restaurantName;
  String? get restaurantLogo => _restaurantLogo;
  String? get restaurantAddress => _restaurantAddress;
  String? get restaurantPhone => _restaurantPhone;
  String? get restaurantEmail => _restaurantEmail;
  BaseUrls? get baseUrls => _baseUrls;
  String? get currencySymbol => _currencySymbol;
  bool? get cashOnDelivery => _cashOnDelivery;
  bool? get digitalPayment => _digitalPayment;
  String? get termsAndConditions => _termsAndConditions;
  String? get aboutUs=> _aboutUs;
  String? get privacyPolicy=> _privacyPolicy;
  RestaurantLocationCoverage? get restaurantLocationCoverage => _restaurantLocationCoverage;
  double? get minimumOrderValue => _minimumOrderValue;
  List<Branches?>? get branches => _branches;
  bool? get emailVerification => _emailVerification;
  bool? get phoneVerification => _phoneVerification;
  String? get currencySymbolPosition => _currencySymbolPosition;

  String? get countryCode => _countryCode;
  bool? get selfPickup => _selfPickup;
  bool? get homeDelivery => _homeDelivery;
  PlayStoreConfig? get playStoreConfig => _playStoreConfig;
  AppStoreConfig? get appStoreConfig => _appStoreConfig;
  List<SocialMediaLink>? get socialMediaLink => _socialMediaLink;
  String? get softwareVersion => _softwareVersion;
  String? get footerCopyright => _footerCopyright;
  String? get timeZone  => _timeZone;
  int? get decimalPointSettings => _decimalPointSettings;
  List<RestaurantScheduleTime>? get restaurantScheduleTime => _restaurantScheduleTime;
  int? get scheduleOrderSlotDuration => _scheduleOrderSlotDuration;
  String? get timeFormat => _timeFormat;
  SocialStatus? get socialLoginStatus => _socialLoginStatus;
  double? get loyaltyPointItemPurchasePoint => _loyaltyPointItemPurchasePoint;
  bool? get loyaltyPointStatus => _loyaltyPointStatus;
  double? get loyaltyPointMinimumPoint => _loyaltyPointMinimumPoint;
  double? get loyaltyPointExchangeRate => _loyaltyPointExchangeRate;
  bool? get referEarnStatus => _referEarningStatus;
  bool? get customerReferredDiscountStatus => _customerReferredDiscountStatus;
  bool? get walletStatus => _walletStatus;
  Whatsapp? get whatsapp => _whatsapp;
  CookiesManagement? get cookiesManagement => _cookiesManagement;
  int? get otpResendTime => _otpResendTime;
  bool? get isVegNonVegActive => _isVegNonVegActive;
  List<PaymentMethod>? get activePaymentMethodList => _activePaymentMethodList;
  bool? get isOfflinePayment => _isOfflinePayment;
  bool? get isGuestCheckout => _isGuestCheckout;
  bool? get isPartialPayment => _isPartialPayment;
  bool? get isAddFundToWallet => _isAddFundToWallet;
  String? get partialPaymentCombineWith => _partialPaymentCombineWith;
  DigitalPaymentInfo? get digitalPaymentInfo => _digitalPaymentInfo;
  AppleLogin? get appleLogin => _appleLogin;
  bool? get isFirebaseOTPVerification => _isFirebaseOTPVerification;
  CustomerVerification? get customerVerification => _customerVerification;
  String? get footerDescription => _footerDescription;
  bool? get cutleryStatus => _cutleryStatus;
  MaintenanceMode? get maintenanceMode => _maintenanceMode;
  CustomerLogin? get customerLogin => _customerLogin;
  int? get googleMapStatus => _googleMapStatus;
  int? get halalTagStatus => _halalTagStatus;
  WebsocketConfig? get websocket => _websocket;





  ConfigModel.fromJson(Map<String, dynamic> json) {
    _restaurantName = json['restaurant_name'];
    _restaurantLogo = json['restaurant_logo'];
    _restaurantAddress = json['restaurant_address'];
    _restaurantPhone = json['restaurant_phone'];
    _restaurantEmail = json['restaurant_email'];
    _baseUrls = json['base_urls'] != null
        ? BaseUrls.fromJson(json['base_urls'])
        : null;
    _currencySymbol = json['currency_symbol'];
    _cashOnDelivery = '${json['cash_on_delivery']}' == 'true';
    _digitalPayment = '${json['digital_payment']}' == 'true';
    _termsAndConditions = json['terms_and_conditions'];
    _privacyPolicy = json['privacy_policy'];
    _aboutUs = json['about_us'];
    _emailVerification = json['email_verification'];
    _phoneVerification = json['phone_verification'];
    _currencySymbolPosition = json['currency_symbol_position'];
    _countryCode = json['country'];
    _selfPickup = json['self_pickup'];
    _homeDelivery = json['delivery'];
    _restaurantLocationCoverage = json['restaurant_location_coverage'] != null
        ? RestaurantLocationCoverage.fromJson(json['restaurant_location_coverage']) : null;
    _minimumOrderValue = json['minimum_order_value'] != null ? json['minimum_order_value'].toDouble() : 0;
    if (json['branches'] != null) {
      _branches = [];
      json['branches'].forEach((v) {
        _branches!.add(Branches.fromJson(v));
      });
    }
    _playStoreConfig = json['play_store_config'] != null
        ? PlayStoreConfig.fromJson(json['play_store_config'])
        : null;
    _maintenanceMode = json['advance_maintenance_mode'] != null
        ? MaintenanceMode.fromJson(json['advance_maintenance_mode'])
        : null;

    _customerLogin = json['customer_login'] != null
        ? CustomerLogin.fromJson(json['customer_login'])
        : null;
    _appStoreConfig = json['app_store_config'] != null
        ? AppStoreConfig.fromJson(json['app_store_config'])
        : null;

    if (json['social_media_link'] != null) {
      _socialMediaLink = <SocialMediaLink>[];
      json['social_media_link'].forEach((v) {
        _socialMediaLink!.add(SocialMediaLink.fromJson(v));
      });
    }
    if(json['software_version'] !=null){
      _softwareVersion = json['software_version'];
    }
    if(json['footer_copyright_text']!=null){
      _footerCopyright = json['footer_copyright_text'];
    }
    _timeZone = json['time_zone'];
    _decimalPointSettings = json['decimal_point_settings'] ?? 1;

    _restaurantScheduleTime = List<RestaurantScheduleTime>.from(json["restaurant_schedule_time"].map((x) => RestaurantScheduleTime.fromJson(x)));

    try {
      _scheduleOrderSlotDuration = json['schedule_order_slot_duration'] ?? 30;
    }catch(_){
      _scheduleOrderSlotDuration = int.tryParse(json['schedule_order_slot_duration'] ?? 30 as String);
    }

    _timeFormat =  json['time_format'].toString();

    if(json['social_login'] != null) {
      _socialLoginStatus = SocialStatus.fromJson(json['social_login']) ;
    }

   if(json['loyalty_point_item_purchase_point'] != null) {
     _loyaltyPointItemPurchasePoint = double.parse('${json['loyalty_point_item_purchase_point']}');
   }
   _loyaltyPointStatus = '${json['loyalty_point_status']}' == '1';
    _loyaltyPointMinimumPoint = double.tryParse('${json['loyalty_point_minimum_point']}');
    _loyaltyPointExchangeRate = double.tryParse('${json['loyalty_point_exchange_rate']}');
    _referEarningStatus = '${json['ref_earning_status']}' == '1';
    _customerReferredDiscountStatus = '${json['customer_referred_discount_status']}' == '1';
    _walletStatus = '${json['wallet_status']}' == '1';
    _whatsapp = json['whatsapp'] != null
        ? Whatsapp.fromJson(json['whatsapp'])
        : null;
    _cookiesManagement = json['cookies_management'] != null
        ? CookiesManagement.fromJson(json['cookies_management'])
        : null;

    _otpResendTime =  int.tryParse('${json['otp_resend_time']}');
    _isVegNonVegActive = '${json['is_veg_non_veg_active']}'.contains('1');
    if (json['active_payment_method_list'] != null) {
      _activePaymentMethodList = <PaymentMethod>[];
      json['active_payment_method_list'].forEach((v) {
        activePaymentMethodList!.add(PaymentMethod.fromJson(v));
      });
    }

    _isOfflinePayment = json['offline_payment'] == 'true';
    _isGuestCheckout = '${json['guest_checkout']}'.contains('1');
    _isPartialPayment = '${json['partial_payment']}'.contains('1');
    _isAddFundToWallet = '${json['add_fund_to_wallet']}'.contains('1');
    _partialPaymentCombineWith = json['partial_payment_combine_with'];
    _digitalPaymentInfo = json['digital_payment_info'] != null ? DigitalPaymentInfo.fromJson(json['digital_payment_info']) : null;
    _appleLogin = AppleLogin.fromJson(json['apple_login']);
    _isFirebaseOTPVerification = '${json['firebase_otp_verification_status']}'.contains('1');
    _customerVerification = CustomerVerification.fromJson(json['customer_verification']);
    _footerDescription = json['footer_description_text'];
    _cutleryStatus = '${json['cutlery_status']}'.contains('1');
    _googleMapStatus = json['google_map_status'];
    _halalTagStatus = int.tryParse(json['halal_tag_status'].toString());
    _websocket = WebsocketConfig.fromJson(
      json['websocket'] is Map<String, dynamic>
          ? json['websocket'] as Map<String, dynamic>
          : json['websocket'] is Map
              ? Map<String, dynamic>.from(json['websocket'] as Map)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['restaurant_name'] = _restaurantName;
    data['restaurant_logo'] = _restaurantLogo;
    data['restaurant_address'] = _restaurantAddress;
    data['restaurant_phone'] = _restaurantPhone;
    data['restaurant_email'] = _restaurantEmail;
    if (_baseUrls != null) {
      data['base_urls'] = _baseUrls!.toJson();
    }
    data['currency_symbol'] = _currencySymbol;
    data['cash_on_delivery'] = _cashOnDelivery;
    data['digital_payment'] = _digitalPayment;
    data['terms_and_conditions'] = _termsAndConditions;
    data['privacy_policy'] = privacyPolicy;
    data['about_us'] = aboutUs;
    data['email_verification'] = emailVerification;
    data['phone_verification'] = phoneVerification;
    data['currency_symbol_position'] = currencySymbolPosition;
    if (maintenanceMode != null) {
      data['advance_maintenance_mode'] = maintenanceMode!.toJson();
    }
    data['country'] = countryCode;
    data['self_pickup'] = selfPickup;
    data['delivery'] = homeDelivery;
    if (_restaurantLocationCoverage != null) {
      data['restaurant_location_coverage'] = _restaurantLocationCoverage!.toJson();
    }
    data['minimum_order_value'] = _minimumOrderValue;
    if (_branches != null) {
      data['branches'] = _branches!.map((v) => v!.toJson()).toList();
    }
    if (_playStoreConfig != null) {
      data['play_store_config'] = _playStoreConfig!.toJson();
    }
    if (_appStoreConfig != null) {
      data['app_store_config'] = _appStoreConfig!.toJson();
    }
    if (_socialMediaLink != null) {
      data['social_media_link'] =
          _socialMediaLink!.map((v) => v.toJson()).toList();
    }
    data['software_version'] = _softwareVersion;
    data['footer_copyright_text'] = _footerCopyright;
    data['time_zone'] = _timeZone;
    data['restaurant_schedule_time'] = _restaurantScheduleTime;
    data['loyalty_point_item_purchase_point'] = _loyaltyPointItemPurchasePoint;
    data['loyalty_point_exchange_rate'] = _loyaltyPointExchangeRate;
    data['loyalty_point_minimum_point'] = _loyaltyPointMinimumPoint;
    data['ref_earning_status'] = _referEarningStatus;
    data['customer_referred_discount_status'] = _customerReferredDiscountStatus;
    data['wallet_status'] = _walletStatus;
    if (_whatsapp != null) {
      data['whatsapp'] = _whatsapp!.toJson();
    }
    data['otp_resend_time'] = _otpResendTime;
    data['customer_verification'] = _customerVerification?.toJson();
    data['cutlery_status'] = _cutleryStatus;
    if (customerLogin != null) {
      data['customer_login'] = customerLogin!.toJson();
    }
    data['google_map_status'] = _googleMapStatus;
    data['halal_tag_status'] = _halalTagStatus;

    return data;
  }
}


class BaseUrls {
  String? _productImageUrl;
  String? _addonImageUrl;
  String? _customerImageUrl;
  String? _bannerImageUrl;
  String? _categoryImageUrl;
  String? _categoryBannerImageUrl;
  String? _notificationImageUrl;
  String? _restaurantImageUrl;
  String? _deliveryManImageUrl;
  String? _chatImageUrl;
  String? _branchImageUrl;
  String? _getWayIMageUrl;

  BaseUrls(
      {String? productImageUrl,
        String? addonImageUrl,
        String? customerImageUrl,
        String? bannerImageUrl,
        String? categoryImageUrl,
        String? categoryBannerImageUrl,
        String? notificationImageUrl,
        String? restaurantImageUrl,
        String? deliveryManImageUrl,
        String? chatImageUrl,
        String? branchImageUrl,
        String? getWayImageUrl,
      }) {
    _productImageUrl = productImageUrl;
    _addonImageUrl = addonImageUrl;
    _customerImageUrl = customerImageUrl;
    _bannerImageUrl = bannerImageUrl;
    _categoryImageUrl = categoryImageUrl;
    _categoryBannerImageUrl = categoryBannerImageUrl;
    _notificationImageUrl = notificationImageUrl;
    _restaurantImageUrl = restaurantImageUrl;
    _deliveryManImageUrl = deliveryManImageUrl;
    _chatImageUrl = chatImageUrl;
    _branchImageUrl = branchImageUrl;
    _getWayIMageUrl = getWayImageUrl;
  }

  String? get productImageUrl => _productImageUrl;
  String? get addonImageUrl => _addonImageUrl;
  String? get customerImageUrl => _customerImageUrl;
  String? get bannerImageUrl => _bannerImageUrl;
  String? get categoryImageUrl => _categoryImageUrl;
  String? get categoryBannerImageUrl => _categoryBannerImageUrl;
  String? get notificationImageUrl => _notificationImageUrl;
  String? get restaurantImageUrl => _restaurantImageUrl;
  String? get deliveryManImageUrl => _deliveryManImageUrl;
  String? get chatImageUrl => _chatImageUrl;
  String? get branchImageUrl => _branchImageUrl;
  String? get getWayImageUrl => _getWayIMageUrl;

  BaseUrls.fromJson(Map<String, dynamic> json) {
    _productImageUrl = json['product_image_url'] ?? '';
    _addonImageUrl = json['addon_image_url'] ?? json['product_image_url'] ?? '';
    _customerImageUrl = json['customer_image_url'] ?? '';
    _bannerImageUrl = json['banner_image_url'] ?? '';
    _categoryImageUrl = json['category_image_url'] ?? '';
    _categoryBannerImageUrl = json['category_banner_image_url'];
    _notificationImageUrl = json['notification_image_url'];
    _restaurantImageUrl = json['restaurant_image_url'] ?? '';
    _deliveryManImageUrl = json['delivery_man_image_url'] ?? '';
    _chatImageUrl = json['chat_image_url'] ?? '';
    _branchImageUrl = json['branch_image_url'] ?? '';
    _getWayIMageUrl = json['gateway_image_url'] ?? '';
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['product_image_url'] = _productImageUrl;
    data['addon_image_url'] = _addonImageUrl;
    data['customer_image_url'] = _customerImageUrl;
    data['banner_image_url'] = _bannerImageUrl;
    data['category_image_url'] = _categoryImageUrl;
    data['notification_image_url'] = _notificationImageUrl;
    data['restaurant_image_url'] = _restaurantImageUrl;
    data['delivery_man_image_url'] = _deliveryManImageUrl;
    data['chat_image_url'] = _chatImageUrl;
    data['branch_image_url'] = _branchImageUrl;
    data['gateway_image_url'] = _getWayIMageUrl;
    return data;
  }
}

class RestaurantLocationCoverage {
  String? _longitude;
  String? _latitude;
  double? _coverage;

  RestaurantLocationCoverage(
      {String? longitude, String? latitude, double? coverage}) {
    _longitude = longitude;
    _latitude = latitude;
    _coverage = coverage;
  }

  String? get longitude => _longitude;
  String? get latitude => _latitude;
  double? get coverage => _coverage;

  RestaurantLocationCoverage.fromJson(Map<String, dynamic> json) {
    _longitude = json['longitude'];
    _latitude = json['latitude'];
    _coverage = json['coverage'].toDouble();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['longitude'] = _longitude;
    data['latitude'] = _latitude;
    data['coverage'] = _coverage;
    return data;
  }
}

class Branches {
  int? _id;
  String? _name;
  String? _email;
  double? _longitude;
  double? _latitude;
  String? _address;
  double? _coverage;
  String? _coverImage;
  String? _image;
  bool? _status;
  int? _preparationTime;

  Branches(
      {int? id,
        String? name,
        String? email,
        double? longitude,
        double? latitude,
        String? address,
        double? coverage,
        String? coverImage,
        String? image,
        bool? status,
        int? preparationTime,
      }) {
    _id = id;
    _name = name;
    _email = email;
    _longitude = longitude;
    _latitude = latitude;
    _address = address;
    _coverage = coverage;
    _coverImage = coverImage;
    _image = image;
    _preparationTime = preparationTime;
  }

  int? get id => _id;
  String? get name => _name;
  String? get email => _email;
  double? get longitude => _longitude;
  double? get latitude => _latitude;
  String? get address => _address;
  double? get coverage => _coverage;
  String? get coverImage => _coverImage;
  String? get image => _image;
  bool? get status => _status;
  int? get preparationTime => _preparationTime;

  Branches.fromJson(Map<String, dynamic> json) {
    _id = json['id'];
    _name = json['name'];
    _email = json['email'];
    _longitude = double.tryParse(json['longitude'].toString());
    _latitude = double.tryParse(json['latitude'].toString());
    _address = json['address'];
    _coverage = json['coverage'].toDouble();
    _image = json['image'];
    _status = '${json['status']}'.contains('1');
    _coverImage = json['cover_image'];
    _preparationTime = json['preparation_time'];

  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = _id;
    data['name'] = _name;
    data['email'] = _email;
    data['longitude'] = _longitude;
    data['latitude'] = _latitude;
    data['address'] = _address;
    data['coverage'] = _coverage;
    data['image'] = _image;
    data['status'] = _status;
    data['preparation_time'] = _preparationTime;
    return data;
  }
}
class BranchValue {
  final Branches? branches;
  final double distance;

  BranchValue(this.branches, this.distance);
}



class PlayStoreConfig{
  bool? _status;
  String? _link;
  double? _minVersion;

  PlayStoreConfig({bool? status, String? link, double? minVersion}){
    _status = status;
    _link = link;
    _minVersion = minVersion;
  }
  bool? get status => _status;
  String? get link => _link;
  double? get minVersion =>_minVersion;

  PlayStoreConfig.fromJson(Map<String, dynamic> json) {
    _status = json['status'];
    if(json['link'] != null){
      _link = json['link'];
    }
    if(json['min_version'] != null && json['min_version'] != '' ){
      _minVersion = double.parse(json['min_version']);
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = _status;
    data['link'] = _link;
    data['min_version'] = _minVersion;

    return data;
  }
}

class AppStoreConfig{
  bool? _status;
  String? _link;
  double? _minVersion;

  AppStoreConfig({bool? status, String? link, double? minVersion}){
    _status = status;
    _link = link;
    _minVersion = minVersion;
  }

  bool? get status => _status;
  String? get link => _link;
  double? get minVersion =>_minVersion;


  AppStoreConfig.fromJson(Map<String, dynamic> json) {
    _status = json['status'];
    if(json['link'] != null){
      _link = json['link'];
    }
    if(json['min_version'] !=null  && json['min_version'] != ''){
      _minVersion = double.parse(json['min_version']);
    }

  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = _status;
    data['link'] = _link;
    data['min_version'] = _minVersion;

    return data;
  }
}

class SocialMediaLink {
  int? id;
  String? name;
  String? link;
  int? status;
  String? updatedAt;

  SocialMediaLink(
      {this.id,
        this.name,
        this.link,
        this.status,
        this.updatedAt});

  SocialMediaLink.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    link = json['link'];
    status = json['status'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['link'] = link;
    data['status'] = status;
    data['updated_at'] = updatedAt;
    return data;
  }
}

class RestaurantScheduleTime {
  RestaurantScheduleTime({
    this.day,
    this.openingTime,
    this.closingTime,
  });

  String? day;
  String? openingTime;
  String? closingTime;

  factory RestaurantScheduleTime.fromJson(Map<String, dynamic> json) => RestaurantScheduleTime(
    day: json["day"].toString(),
    openingTime: json["opening_time"].toString(),
    closingTime: json["closing_time"].toString(),
  );

  Map<String, dynamic> toJson() => {
    "day": day,
    "opening_time": openingTime,
    "closing_time": closingTime,
  };
}

class SocialStatus{
  bool? isGoogle;
  bool? isFacebook;

  SocialStatus(this.isGoogle, this.isFacebook);

  SocialStatus.fromJson(Map<String, dynamic> json){
    isGoogle = '${json['google']}' == '1';
    isFacebook = '${json['facebook']}' == '1';
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['google'] = isGoogle;
    data['facebook'] = isFacebook;
    return data;
  }
}

class Whatsapp {
  bool? status;
  String? number;

  Whatsapp({this.status, this.number});

  Whatsapp.fromJson(Map<String, dynamic> json) {
    status = '${json['status']}' == '1';
    number = json['number'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['number'] = number;
    return data;
  }
}

class AppleLogin {
  bool? status;
  String? medium;
  String? clientId;

  AppleLogin({this.status, this.medium});

  AppleLogin.fromJson(Map<String, dynamic> json) {
    status = '${json['status']}' == '1';
    medium = json['login_medium'];
    clientId = json['client_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['login_medium'] = medium;
    data['client_id'] = clientId;

    return data;
  }
}


class CookiesManagement {
  bool? status;
  String? content;

  CookiesManagement({this.status, this.content});

  CookiesManagement.fromJson(Map<String, dynamic> json) {
    status = '${json['status']}'.contains('1');
    content = json['text'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['text'] = content;
    return data;
  }
}

class PaymentMethod {
  String? getWay;
  String? getWayTitle;
  String? getWayImage;
  String? type;
  bool? isOffline;

  PaymentMethod({this.getWay, this.getWayTitle, this.getWayImage, this.type, this.isOffline});

  PaymentMethod copyWith(String type, {bool isOffline = false}){
    this.type = type;
    this.isOffline = isOffline;
    return this;
  }

  PaymentMethod.fromJson(Map<String, dynamic> json) {
    getWay = json['gateway'];
    getWayTitle = json['gateway_title'];
    getWayImage = json['gateway_image'];
    isOffline = json['is_offline'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['gateway'] = getWay;
    data['gateway_title'] = getWayTitle;
    data['gateway_image'] = getWayImage;
    data['is_offline'] = isOffline;
    return data;
  }
}


class DigitalPaymentInfo {
  bool? digitalPayment;
  bool? pluginPaymentGateways;
  bool? defaultPaymentGateways;

  DigitalPaymentInfo({this.digitalPayment, this.pluginPaymentGateways, this.defaultPaymentGateways});

  DigitalPaymentInfo.fromJson(Map<String, dynamic> json) {
    digitalPayment =  '${json['digital_payment']}'.contains('true');
    pluginPaymentGateways = '${json['plugin_payment_gateways']}'.contains('true');
    defaultPaymentGateways = '${json['default_payment_gateways']}'.contains('true');
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['digital_payment'] = digitalPayment;
    data['plugin_payment_gateways'] = pluginPaymentGateways;
    data['default_payment_gateways'] = defaultPaymentGateways;
    return data;
  }
}


class CustomerVerification{
  bool? status;
  int? phone;
  int? email;
  int? firebase;

  CustomerVerification(this.status, this.phone, this.email, this.firebase);

  CustomerVerification.fromJson(Map<String, dynamic> json) {
    status = '${json['status']}' == '1';
    phone = json['phone'];
    email = json['email'];
    firebase = json['firebase'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['phone'] = phone;
    data['email'] = email;
    data['firebase'] = firebase;

    return data;
  }
}


class MaintenanceMode {
  int? maintenanceStatus;
  SelectedMaintenanceSystem? selectedMaintenanceSystem;
  MaintenanceMessages? maintenanceMessages;
  MaintenanceTypeAndDuration? maintenanceTypeAndDuration;

  MaintenanceMode(
      {this.maintenanceStatus,
        this.selectedMaintenanceSystem,
        this.maintenanceMessages, this.maintenanceTypeAndDuration});

  MaintenanceMode.fromJson(Map<String, dynamic> json) {
    maintenanceStatus = json['maintenance_status'];
    selectedMaintenanceSystem = json['selected_maintenance_system'] != null
        ? SelectedMaintenanceSystem.fromJson(
        json['selected_maintenance_system'])
        : null;
    maintenanceMessages = json['maintenance_messages'] != null
        ? MaintenanceMessages.fromJson(json['maintenance_messages'])
        : null;

    maintenanceTypeAndDuration = json['maintenance_type_and_duration'] != null
        ? MaintenanceTypeAndDuration.fromJson(
        json['maintenance_type_and_duration'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['maintenance_status'] = maintenanceStatus;
    if (selectedMaintenanceSystem != null) {
      data['selected_maintenance_system'] =
          selectedMaintenanceSystem!.toJson();
    }
    if (maintenanceMessages != null) {
      data['maintenance_messages'] = maintenanceMessages!.toJson();
    }
    if (maintenanceTypeAndDuration != null) {
      data['maintenance_type_and_duration'] =
          maintenanceTypeAndDuration!.toJson();
    }
    return data;
  }
}

class SelectedMaintenanceSystem {
  int? branchPanel;
  int? customerApp;
  int? webApp;
  int? deliverymanApp;

  SelectedMaintenanceSystem(
      {this.branchPanel, this.customerApp, this.webApp, this.deliverymanApp});

  SelectedMaintenanceSystem.fromJson(Map<String, dynamic> json) {
    branchPanel = json['branch_panel'];
    customerApp = json['customer_app'];
    webApp = json['web_app'];
    deliverymanApp = json['deliveryman_app'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['branch_panel'] = branchPanel;
    data['customer_app'] = customerApp;
    data['web_app'] = webApp;
    data['deliveryman_app'] = deliverymanApp;
    return data;
  }
}

class MaintenanceMessages {
  int? businessNumber;
  int? businessEmail;
  String? maintenanceMessage;
  String? messageBody;

  MaintenanceMessages(
      {this.businessNumber,
        this.businessEmail,
        this.maintenanceMessage,
        this.messageBody});

  MaintenanceMessages.fromJson(Map<String, dynamic> json) {
    businessNumber = json['business_number'];
    businessEmail = json['business_email'];
    maintenanceMessage = json['maintenance_message'];
    messageBody = json['message_body'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['business_number'] = businessNumber;
    data['business_email'] = businessEmail;
    data['maintenance_message'] = maintenanceMessage;
    data['message_body'] = messageBody;
    return data;
  }
}

class MaintenanceTypeAndDuration {
  String? maintenanceDuration;
  String? startDate;
  String? endDate;

  MaintenanceTypeAndDuration({this.maintenanceDuration, this.startDate, this.endDate});

  MaintenanceTypeAndDuration.fromJson(Map<String, dynamic> json)
      : maintenanceDuration = json['maintenance_duration'],
        startDate = json['start_date'],
        endDate = json['end_date'];

  Map<String, dynamic> toJson() => {
    'maintenance_duration': maintenanceDuration,
    'start_date': startDate,
    'end_date': endDate,
  };
}


class CustomerLogin {
  LoginOption? loginOption;
  SocialMediaLoginOptions? socialMediaLoginOptions;

  CustomerLogin({this.loginOption, this.socialMediaLoginOptions});

  CustomerLogin.fromJson(Map<String, dynamic> json) {
    loginOption = json['login_option'] != null
        ? LoginOption.fromJson(json['login_option'])
        : null;
    socialMediaLoginOptions = json['social_media_login_options'] != null
        ? SocialMediaLoginOptions.fromJson(
        json['social_media_login_options'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (loginOption != null) {
      data['login_option'] = loginOption!.toJson();
    }
    if (socialMediaLoginOptions != null) {
      data['social_media_login_options'] =
          socialMediaLoginOptions!.toJson();
    }
    return data;
  }
}

class LoginOption {
  int? manualLogin;
  int? otpLogin;
  int? socialMediaLogin;

  LoginOption({this.manualLogin, this.otpLogin, this.socialMediaLogin});

  LoginOption.fromJson(Map<String, dynamic> json) {
    manualLogin = json['manual_login'];
    otpLogin = json['otp_login'];
    socialMediaLogin = json['social_media_login'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['manual_login'] = manualLogin;
    data['otp_login'] = otpLogin;
    data['social_media_login'] = socialMediaLogin;
    return data;
  }
}

class SocialMediaLoginOptions {
  int? google;
  int? facebook;
  int? apple;

  SocialMediaLoginOptions({this.google, this.facebook, this.apple});

  SocialMediaLoginOptions.fromJson(Map<String, dynamic> json) {
    google = json['google'];
    facebook = json['facebook'];
    apple = json['apple'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['google'] = google;
    data['facebook'] = facebook;
    data['apple'] = apple;
    return data;
  }
}