import 'package:flutter/material.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationProvider extends ChangeNotifier {
  DioClient? dioClient;
  final SharedPreferences? sharedPreferences;

  LocalizationProvider({required this.sharedPreferences, required this.dioClient}) {
    _loadCurrentLanguage();
  }

  Locale _locale = const Locale('en', 'US');
  bool _isLtr = true;
  Locale get locale => _locale;
  bool get isLtr => _isLtr;

  Future<void> setLanguage(Locale locale, {bool isDataUpdate = true}) async {
    _locale = locale;
    if(_locale.languageCode == 'ar') {
      _isLtr = false;
    }else {
      _isLtr = true;
    }
    _saveLanguage(_locale);

   await dioClient!.updateHeader(getToken: sharedPreferences!.getString(AppConstants.token)).then((value){
     // Kiosk screens reload their own data on language change; no web home reload.
    });
    notifyListeners();
  }

  /// Kiosk language switch — updates headers + locale only. Does not run the
  /// consumer [HomeScreen.loadData] path (which would hit customer APIs with
  /// the device token and can trigger a forced kiosk logout on 401).
  Future<void> setKioskLanguage(Locale locale) async {
    _locale = locale;
    _isLtr = locale.languageCode != 'ar';
    await _saveLanguage(_locale);
    await dioClient!.updateHeader(
      getToken: sharedPreferences!.getString(AppConstants.token),
    );
    notifyListeners();
  }

  _loadCurrentLanguage() async {
    // Default to English on a fresh kiosk (no saved selection) regardless of
    // the order languages are listed in AppConstants.languages.
    _locale = Locale(
        sharedPreferences!.getString(AppConstants.languageCode) ??
            AppConstants.defaultLanguageCode,
        sharedPreferences!.getString(AppConstants.countryCode) ??
            AppConstants.defaultCountryCode);
    _isLtr = _locale.languageCode != 'ar';
    notifyListeners();
  }

  _saveLanguage(Locale locale) async {
    sharedPreferences!.setString(AppConstants.languageCode, locale.languageCode);
    sharedPreferences!.setString(AppConstants.countryCode, locale.countryCode!);
  }
}