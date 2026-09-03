import 'package:acafe_customer/common/models/config_model.dart';

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

/// Editable General settings snapshot — store identity + regional prefs.
class PosGeneralSettings {
  final String storeName;
  final String address;
  final String contactPhone;
  final String contactEmail;
  final String website;
  final String currency;
  final String taxModel;
  final String dateFormat;

  const PosGeneralSettings({
    required this.storeName,
    required this.address,
    required this.contactPhone,
    required this.contactEmail,
    required this.website,
    required this.currency,
    required this.taxModel,
    required this.dateFormat,
  });

  static const String defaultTaxModel = 'include';
  static const String defaultDateFormat = 'dd/MM/yyyy';

  static const List<PosSettingsOption> taxModelOptions = [
    PosSettingsOption(value: 'include', label: 'Prices include tax'),
    PosSettingsOption(value: 'exclude', label: 'Prices exclude tax'),
  ];

  static const List<PosSettingsOption> dateFormatOptions = [
    PosSettingsOption(value: 'dd/MM/yyyy', label: 'DD/MM/YYYY'),
    PosSettingsOption(value: 'MM/dd/yyyy', label: 'MM/DD/YYYY'),
    PosSettingsOption(value: 'yyyy-MM-dd', label: 'YYYY-MM-DD'),
  ];

  /// Common restaurant currencies. Labels match the Figma select style
  /// (`EUR (€)`). The active value is matched from [ConfigModel.currencySymbol]
  /// when hydrating.
  static const List<PosSettingsOption> currencyOptions = [
    PosSettingsOption(value: 'EUR', label: 'EUR (€)'),
    PosSettingsOption(value: 'USD', label: 'USD (\$)'),
    PosSettingsOption(value: 'GBP', label: 'GBP (£)'),
    PosSettingsOption(value: 'CHF', label: 'CHF (Fr)'),
    PosSettingsOption(value: 'AED', label: 'AED (د.إ)'),
    PosSettingsOption(value: 'SAR', label: 'SAR (﷼)'),
    PosSettingsOption(value: 'TRY', label: 'TRY (₺)'),
    PosSettingsOption(value: 'INR', label: 'INR (₹)'),
  ];

  PosGeneralSettings copyWith({
    String? storeName,
    String? address,
    String? contactPhone,
    String? contactEmail,
    String? website,
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
        'currency': currency,
        'tax_model': taxModel,
        'date_format': dateFormat,
      };

  factory PosGeneralSettings.fromJson(Map<String, dynamic> json) {
    return PosGeneralSettings(
      storeName: (json['store_name'] as String?)?.trim() ?? '',
      address: (json['address'] as String?)?.trim() ?? '',
      contactPhone: (json['contact_phone'] as String?)?.trim() ?? '',
      contactEmail: (json['contact_email'] as String?)?.trim() ?? '',
      website: (json['website'] as String?)?.trim() ?? '',
      currency: (json['currency'] as String?)?.trim() ?? 'EUR',
      taxModel: (json['tax_model'] as String?)?.trim() ?? defaultTaxModel,
      dateFormat: (json['date_format'] as String?)?.trim() ?? defaultDateFormat,
    );
  }

  /// Seed from live restaurant config. Local prefs (if any) overlay later.
  factory PosGeneralSettings.fromConfig(ConfigModel? config) {
    final String symbol = (config?.currencySymbol ?? '€').trim();
    return PosGeneralSettings(
      storeName: (config?.restaurantName ?? '').trim(),
      address: (config?.restaurantAddress ?? '').trim(),
      contactPhone: (config?.restaurantPhone ?? '').trim(),
      contactEmail: (config?.restaurantEmail ?? '').trim(),
      website: _websiteFromConfig(config),
      currency: currencyCodeForSymbol(symbol),
      taxModel: defaultTaxModel,
      dateFormat: dateFormatForCountry(config?.countryCode),
    );
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
      case 'Fr':
      case 'CHF':
        return 'CHF';
      case 'د.إ':
        return 'AED';
      case '﷼':
        return 'SAR';
      case '₺':
        return 'TRY';
      case '₹':
        return 'INR';
      default:
        for (final PosSettingsOption o in currencyOptions) {
          if (o.label.contains(symbol)) return o.value;
        }
        return 'EUR';
    }
  }

  static String dateFormatForCountry(String? countryCode) {
    final String code = (countryCode ?? '').toUpperCase();
    if (code == 'US') return 'MM/dd/yyyy';
    return defaultDateFormat;
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
      currency == other.currency &&
      taxModel == other.taxModel &&
      dateFormat == other.dateFormat;
}

/// Field-level validation for the General form. Returns null when valid.
class PosGeneralSettingsValidation {
  PosGeneralSettingsValidation._();

  static final RegExp _email = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
  );

  /// Loose phone: digits, spaces, +, -, (), at least 7 digits.
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
