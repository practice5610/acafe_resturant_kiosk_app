import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// One selectable option in a General settings dropdown.
class PosSettingsOption {
  final String value;
  final String label;

  const PosSettingsOption({required this.value, required this.label});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosSettingsOption &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Editable General settings snapshot — store identity + locale prefs.
class PosGeneralSettings {
  final String storeName;
  final String address;
  final String contactPhone;
  final String contactEmail;
  final String website;
  final String language;
  final String currency;
  final String taxModel;
  final String dateFormat;

  const PosGeneralSettings({
    required this.storeName,
    required this.address,
    required this.contactPhone,
    required this.contactEmail,
    required this.website,
    required this.language,
    required this.currency,
    required this.taxModel,
    required this.dateFormat,
  });

  static const String defaultLanguage = 'nl';
  static const String defaultTaxModel = 'include';
  static const String defaultDateFormat = 'dd/MM/yyyy';

  /// POS Settings offers the venue trio only (Dutch / English / French).
  /// German stays available on the kiosk guest picker via [AppConstants.languages].
  static const List<String> posLanguageCodes = ['nl', 'en', 'fr'];

  static List<PosSettingsOption> get languageOptions {
    final List<PosSettingsOption> out = [];
    for (final LanguageModel lang in AppConstants.languages) {
      final String code = lang.languageCode ?? '';
      if (!posLanguageCodes.contains(code)) continue;
      out.add(PosSettingsOption(
        value: code,
        label: lang.languageName ?? code.toUpperCase(),
      ));
    }
    return out;
  }

  static const List<PosSettingsOption> taxModelOptions = [
    PosSettingsOption(value: 'include', label: 'Prices include tax'),
    PosSettingsOption(value: 'exclude', label: 'Prices exclude tax'),
  ];

  static const List<PosSettingsOption> dateFormatOptions = [
    PosSettingsOption(value: 'dd/MM/yyyy', label: 'DD/MM/YYYY'),
    PosSettingsOption(value: 'MM/dd/yyyy', label: 'MM/DD/YYYY'),
    PosSettingsOption(value: 'yyyy-MM-dd', label: 'YYYY-MM-DD'),
  ];

  /// Currencies for the POS language markets only:
  /// Dutch/French → EUR, English → GBP + USD.
  static const List<PosSettingsOption> currencyOptions = [
    PosSettingsOption(value: 'EUR', label: 'EUR (€)'),
    PosSettingsOption(value: 'GBP', label: 'GBP (£)'),
    PosSettingsOption(value: 'USD', label: 'USD (\$)'),
  ];

  /// Locale defaults when the operator picks a terminal language.
  static ({String currency, String dateFormat}) localeDefaultsFor(
    String languageCode,
  ) {
    switch (languageCode) {
      case 'en':
        return (currency: 'GBP', dateFormat: 'dd/MM/yyyy');
      case 'fr':
        return (currency: 'EUR', dateFormat: 'dd/MM/yyyy');
      case 'nl':
      default:
        return (currency: 'EUR', dateFormat: 'dd/MM/yyyy');
    }
  }

  static String currencyForLanguage(String languageCode) =>
      localeDefaultsFor(languageCode).currency;

  static String dateFormatForLanguage(String languageCode) =>
      localeDefaultsFor(languageCode).dateFormat;

  PosGeneralSettings copyWith({
    String? storeName,
    String? address,
    String? contactPhone,
    String? contactEmail,
    String? website,
    String? language,
    String? currency,
    String? taxModel,
    String? dateFormat,
  }) {
    return PosGeneralSettings(
      storeName: storeName ?? this.storeName,
      address: address ?? this.address,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      website: website ?? this.website,
      language: language ?? this.language,
      currency: currency ?? this.currency,
      taxModel: taxModel ?? this.taxModel,
      dateFormat: dateFormat ?? this.dateFormat,
    );
  }

  Map<String, dynamic> toJson() => {
        'store_name': storeName,
        'address': address,
        'contact_phone': contactPhone,
        'contact_email': contactEmail,
        'website': website,
        'language': language,
        'currency': currency,
        'tax_model': taxModel,
        'date_format': dateFormat,
      };

  factory PosGeneralSettings.fromJson(Map<String, dynamic> json) {
    final String language = _normalizeLanguage(
      (json['language'] as String?)?.trim(),
    );
    return PosGeneralSettings(
      storeName: (json['store_name'] as String?)?.trim() ?? '',
      address: (json['address'] as String?)?.trim() ?? '',
      contactPhone: (json['contact_phone'] as String?)?.trim() ?? '',
      contactEmail: (json['contact_email'] as String?)?.trim() ?? '',
      website: (json['website'] as String?)?.trim() ?? '',
      language: language,
      currency: _normalizeCurrency(
        (json['currency'] as String?)?.trim(),
        fallbackLanguage: language,
      ),
      taxModel: (json['tax_model'] as String?)?.trim() ?? defaultTaxModel,
      dateFormat: (json['date_format'] as String?)?.trim() ?? defaultDateFormat,
    );
  }

  /// Seed from live restaurant config + optional active locale.
  factory PosGeneralSettings.fromConfig(
    ConfigModel? config, {
    String? languageCode,
  }) {
    final String language = _normalizeLanguage(languageCode);
    final String symbol = (config?.currencySymbol ?? '€').trim();
    final String fromSymbol = currencyCodeForSymbol(symbol);
    return PosGeneralSettings(
      storeName: (config?.restaurantName ?? '').trim(),
      address: (config?.restaurantAddress ?? '').trim(),
      contactPhone: (config?.restaurantPhone ?? '').trim(),
      contactEmail: (config?.restaurantEmail ?? '').trim(),
      website: _websiteFromConfig(config),
      language: language,
      currency: _normalizeCurrency(fromSymbol, fallbackLanguage: language),
      taxModel: defaultTaxModel,
      dateFormat: dateFormatForCountry(config?.countryCode) ??
          dateFormatForLanguage(language),
    );
  }

  static String _normalizeLanguage(String? code) {
    final String c = (code ?? '').toLowerCase();
    if (posLanguageCodes.contains(c)) return c;
    return defaultLanguage;
  }

  static String _normalizeCurrency(
    String? code, {
    required String fallbackLanguage,
  }) {
    final String c = (code ?? '').toUpperCase();
    for (final PosSettingsOption o in currencyOptions) {
      if (o.value == c) return c;
    }
    return currencyForLanguage(fallbackLanguage);
  }

  static String _websiteFromConfig(ConfigModel? config) {
    final links = config?.socialMediaLink;
    if (links == null) return '';
    for (final SocialMediaLink link in links) {
      final String name = (link.name ?? '').toLowerCase();
      final String href = (link.link ?? '').trim();
      if (href.isEmpty) continue;
      if (name.contains('website') ||
          name.contains('web') ||
          name == 'site') {
        return _stripUrlScheme(href);
      }
    }
    return '';
  }

  static String _stripUrlScheme(String url) {
    return url
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .replaceFirst(RegExp(r'/+$'), '');
  }

  static String currencyCodeForSymbol(String symbol) {
    switch (symbol) {
      case '€':
        return 'EUR';
      case '\$':
      case 'US\$':
        return 'USD';
      case '£':
        return 'GBP';
      default:
        for (final PosSettingsOption o in currencyOptions) {
          if (o.label.contains(symbol)) return o.value;
        }
        return 'EUR';
    }
  }

  static String? dateFormatForCountry(String? countryCode) {
    final String code = (countryCode ?? '').toUpperCase();
    if (code.isEmpty) return null;
    if (code == 'US') return 'MM/dd/yyyy';
    return defaultDateFormat;
  }

  static String countryCodeForLanguage(String languageCode) {
    for (final LanguageModel lang in AppConstants.languages) {
      if (lang.languageCode == languageCode) {
        return lang.countryCode ?? 'NL';
      }
    }
    return 'NL';
  }

  static String labelForLanguage(String value) {
    for (final PosSettingsOption o in languageOptions) {
      if (o.value == value) return o.label;
    }
    return value;
  }

  static String labelForCurrency(String value) {
    for (final PosSettingsOption o in currencyOptions) {
      if (o.value == value) return o.label;
    }
    return value;
  }

  static String labelForTaxModel(String value) {
    for (final PosSettingsOption o in taxModelOptions) {
      if (o.value == value) return o.label;
    }
    return value;
  }

  static String labelForDateFormat(String value) {
    for (final PosSettingsOption o in dateFormatOptions) {
      if (o.value == value) return o.label;
    }
    return value;
  }

  bool sameAs(PosGeneralSettings other) =>
      storeName == other.storeName &&
      address == other.address &&
      contactPhone == other.contactPhone &&
      contactEmail == other.contactEmail &&
      website == other.website &&
      language == other.language &&
      currency == other.currency &&
      taxModel == other.taxModel &&
      dateFormat == other.dateFormat;
}

/// Field-level validation for the General form.
class PosGeneralSettingsValidation {
  PosGeneralSettingsValidation._();

  static final RegExp _email = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
  );

  static final RegExp _phone = RegExp(r'^\+?[\d\s\-().]{7,}$');

  static final RegExp _website = RegExp(
    r'^(https?:\/\/)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(/.*)?$',
  );

  static Map<String, String> validate(PosGeneralSettings s) {
    final Map<String, String> errors = {};

    if (s.storeName.trim().isEmpty) {
      errors['storeName'] = 'Store name is required';
    }
    if (s.address.trim().isEmpty) {
      errors['address'] = 'Address is required';
    }
    if (s.contactPhone.trim().isEmpty) {
      errors['contactPhone'] = 'Contact phone is required';
    } else if (!_phone.hasMatch(s.contactPhone.trim())) {
      errors['contactPhone'] = 'Enter a valid phone number';
    }
    if (s.contactEmail.trim().isEmpty) {
      errors['contactEmail'] = 'Contact email is required';
    } else if (!_email.hasMatch(s.contactEmail.trim())) {
      errors['contactEmail'] = 'Enter a valid email address';
    }
    final String site = s.website.trim();
    if (site.isNotEmpty && !_website.hasMatch(site)) {
      errors['website'] = 'Enter a valid website';
    }
    return errors;
  }
}
