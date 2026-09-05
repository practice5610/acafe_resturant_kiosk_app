import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// Display-only order-number formatting.
///
/// The real order id is a bare integer primary key from
/// `Helpers::generate_order_id()` — used by every API, by receipt lookup and by
/// the KDS. **Nothing here changes it.** This is a presentation formatter and
/// only that: given an id and an operator-chosen prefix, it renders the string
/// an operator reads aloud. Callers that need the id itself keep using the int.
class PosOrderNumber {
  PosOrderNumber._();

  /// Figma's helper line reads `AC-0001` — four digits, zero-padded.
  static const int padTo = 4;

  /// Sample id behind the `Preview: AC-0001` helper. A literal 1 makes the
  /// helper a *format* demonstration rather than a claim about the next order.
  static const int sampleId = 1;

  static String format(int id, String prefix) {
    final String body = id.toString().padLeft(padTo, '0');
    final String p = prefix.trim();
    return p.isEmpty ? body : '$p$body';
  }

  /// What the "Preview:" helper under the prefix field shows.
  static String preview(String prefix) => format(sampleId, prefix);
}

/// Editable Hardware settings — printer behaviour, receipt format, kiosk
/// language offering.
class PosHardwareSettings {
  final bool autoPrintReceipts;
  final bool kitchenTicketPrinting;
  final String orderNumberPrefix;

  final bool useStoreName;
  final String receiptHeader;
  final String receiptFooter;

  /// Language codes the kiosk offers *customers*. Distinct in purpose from
  /// Profile's staff-interface language, but drawn from the same
  /// [AppConstants.languages] list.
  final List<String> kioskLanguages;

  const PosHardwareSettings({
    required this.autoPrintReceipts,
    required this.kitchenTicketPrinting,
    required this.orderNumberPrefix,
    required this.useStoreName,
    required this.receiptHeader,
    required this.receiptFooter,
    required this.kioskLanguages,
  });

  static const String defaultPrefix = 'AC-';
  static const String defaultFooter = 'Thank you for visiting A/CAFÉ!';

  /// Every locale that ships a translation file. Deliberately **not**
  /// [PosGeneralSettings.posLanguageCodes] — that trio (nl/en/fr) is the staff
  /// terminal's own language and drops German on purpose, while the kiosk guest
  /// picker has always offered all four. This row configures the guest picker,
  /// so it must cover what the guest picker can actually show.
  static List<PosSettingsOption> get kioskLanguageOptions {
    final List<PosSettingsOption> out = [];
    for (final LanguageModel lang in AppConstants.languages) {
      final String code = lang.languageCode ?? '';
      if (code.isEmpty) continue;
      out.add(PosSettingsOption(
        value: code,
        label: (lang.languageName ?? code).toUpperCase(),
      ));
    }
    return out;
  }

  static List<String> get allKioskLanguageCodes =>
      kioskLanguageOptions.map((o) => o.value).toList();

  /// Seeded from live config: the default offering is every installed locale,
  /// which is exactly what the kiosk picker does today. So a fresh terminal
  /// saves a setting that matches current behaviour rather than changing it.
  factory PosHardwareSettings.initial({required String storeName}) {
    return PosHardwareSettings(
      autoPrintReceipts: false,
      kitchenTicketPrinting: false,
      orderNumberPrefix: defaultPrefix,
      useStoreName: true,
      receiptHeader: storeName,
      receiptFooter: defaultFooter,
      kioskLanguages: allKioskLanguageCodes,
    );
  }

  PosHardwareSettings copyWith({
    bool? autoPrintReceipts,
    bool? kitchenTicketPrinting,
    String? orderNumberPrefix,
    bool? useStoreName,
    String? receiptHeader,
    String? receiptFooter,
    List<String>? kioskLanguages,
  }) {
    return PosHardwareSettings(
      autoPrintReceipts: autoPrintReceipts ?? this.autoPrintReceipts,
      kitchenTicketPrinting:
          kitchenTicketPrinting ?? this.kitchenTicketPrinting,
      orderNumberPrefix: orderNumberPrefix ?? this.orderNumberPrefix,
      useStoreName: useStoreName ?? this.useStoreName,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      kioskLanguages: kioskLanguages ?? this.kioskLanguages,
    );
  }

  Map<String, dynamic> toJson() => {
        'auto_print_receipts': autoPrintReceipts,
        'kitchen_ticket_printing': kitchenTicketPrinting,
        'order_number_prefix': orderNumberPrefix,
        'use_store_name': useStoreName,
        'receipt_header': receiptHeader,
        'receipt_footer': receiptFooter,
        'kiosk_languages': kioskLanguages,
      };

  factory PosHardwareSettings.fromJson(
    Map<String, dynamic> json, {
    required String storeName,
  }) {
    final PosHardwareSettings fallback =
        PosHardwareSettings.initial(storeName: storeName);

    final Object? rawLanguages = json['kiosk_languages'];
    final List<String> installed = allKioskLanguageCodes;
    List<String> languages = fallback.kioskLanguages;
    if (rawLanguages is List) {
      // Drop anything no longer installed: a locale can be removed from the
      // build after a terminal saved it, and an orphan code would render a
      // pill the kiosk cannot honour.
      languages = rawLanguages
          .map((e) => e.toString())
          .where(installed.contains)
          .toList();
      if (languages.isEmpty) languages = fallback.kioskLanguages;
    }

    return PosHardwareSettings(
      autoPrintReceipts:
          json['auto_print_receipts'] as bool? ?? fallback.autoPrintReceipts,
      kitchenTicketPrinting: json['kitchen_ticket_printing'] as bool? ??
          fallback.kitchenTicketPrinting,
      orderNumberPrefix: (json['order_number_prefix'] as String?) ??
          fallback.orderNumberPrefix,
      useStoreName: json['use_store_name'] as bool? ?? fallback.useStoreName,
      receiptHeader:
          (json['receipt_header'] as String?) ?? fallback.receiptHeader,
      receiptFooter:
          (json['receipt_footer'] as String?) ?? fallback.receiptFooter,
      kioskLanguages: languages,
    );
  }

  /// The header actually printed: the live store name wins while the toggle is
  /// on, so a rename in General → Store Information reaches the receipt without
  /// a second copy of the name being kept here.
  String effectiveHeader(String storeName) =>
      useStoreName ? storeName : receiptHeader;

  bool sameAs(PosHardwareSettings other) =>
      autoPrintReceipts == other.autoPrintReceipts &&
      kitchenTicketPrinting == other.kitchenTicketPrinting &&
      orderNumberPrefix == other.orderNumberPrefix &&
      useStoreName == other.useStoreName &&
      receiptHeader == other.receiptHeader &&
      receiptFooter == other.receiptFooter &&
      _sameCodes(kioskLanguages, other.kioskLanguages);

  static bool _sameCodes(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final List<String> x = [...a]..sort();
    final List<String> y = [...b]..sort();
    for (int i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }
}

/// Field-level validation for the Hardware form, mirroring
/// [PosGeneralSettingsValidation].
class PosHardwareSettingsValidation {
  PosHardwareSettingsValidation._();

  static const int prefixMaxLength = 8;
  static const int footerMaxLength = 120;
  static const int headerMaxLength = 60;

  /// Letters, digits and the separators that survive a thermal print head.
  static final RegExp _prefix = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\-_/#]*$');

  static Map<String, String> validate(PosHardwareSettings s) {
    final Map<String, String> errors = {};

    final String prefix = s.orderNumberPrefix.trim();
    if (prefix.isNotEmpty) {
      if (prefix.length > prefixMaxLength) {
        errors['orderNumberPrefix'] =
            'Keep the prefix to $prefixMaxLength characters or fewer';
      } else if (!_prefix.hasMatch(prefix)) {
        errors['orderNumberPrefix'] =
            'Use letters, digits, and - _ / # only';
      }
    }

    if (!s.useStoreName) {
      final String header = s.receiptHeader.trim();
      if (header.isEmpty) {
        errors['receiptHeader'] =
            'Receipt header is required, or switch on "Use store name"';
      } else if (header.length > headerMaxLength) {
        errors['receiptHeader'] =
            'Keep the header to $headerMaxLength characters or fewer';
      }
    }

    if (s.receiptFooter.trim().length > footerMaxLength) {
      errors['receiptFooter'] =
          'Keep the footer to $footerMaxLength characters or fewer';
    }

    if (s.kioskLanguages.isEmpty) {
      errors['kioskLanguages'] = 'Pick at least one kiosk language';
    }

    return errors;
  }
}
