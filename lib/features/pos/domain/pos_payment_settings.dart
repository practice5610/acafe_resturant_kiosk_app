/// Which tenders this terminal offers, plus the transaction-level preferences
/// on Settings → Payments (Figma node **1641:4235**).
///
/// **Per-terminal local state, not a synced store setting.** Same constraint
/// [PosGeneralSettingsRepo] documents: there is no device-scoped endpoint to
/// write terminal preferences back to the server, so two terminals in the same
/// venue can legitimately disagree about which tenders they accept. For tender
/// availability that is arguably correct — a counter without a card reader and
/// one with it should not be forced to match.
///
/// ## What is real here and what is not
///
/// [cashEnabled] and [cardEnabled] are load-bearing: they gate which methods
/// the operator can pick on [PosPaymentSelectionScreen]. Nothing here touches
/// payment *processing* — the card terminal abstraction
/// (`KioskPaymentService`, still bound to the simulator) is not involved in
/// this decision at all.
///
/// [mobilePayEnabled] and [giftCardsEnabled] are **persisted but inert**.
/// Neither has an integration anywhere in the product: there is no Apple Pay /
/// Google Wallet / QR code path in the app or the backend, and the only gift
/// card reference is a no-op entry in the receipt context menu. Their toggles
/// render disabled so the screen never implies rails that do not exist.
///
/// [tippingEnabled] is likewise **persisted but inert on POS**. A real tip flow
/// exists on the kiosk (`kiosk_tip.dart`, backed by `orders.tip_amount`), but
/// the POS checkout has no tip step for this flag to switch on.
///
/// [defaultTaxRate] is a **display-only label**. Tax in this product is
/// per-product (`products.tax`, summed per cart line); there is no store-level
/// rate for anything to fall back to. Persisting this changes no order total,
/// and deliberately nothing reads it back out.
///
/// Receipt auto-print is **not** stored here. It already exists as
/// `PosHardwareSettings.autoPrintReceipts` and is already wired to fire after a
/// completed sale, so Payments reads and writes that same field rather than
/// keeping a second copy that could disagree with Hardware.
class PosPaymentSettings {
  final bool cashEnabled;
  final bool cardEnabled;
  final bool mobilePayEnabled;
  final bool giftCardsEnabled;
  final bool tippingEnabled;
  final String defaultTaxRate;

  const PosPaymentSettings({
    required this.cashEnabled,
    required this.cardEnabled,
    required this.mobilePayEnabled,
    required this.giftCardsEnabled,
    required this.tippingEnabled,
    required this.defaultTaxRate,
  });

  /// Figma's placeholder reads `21%` — the Dutch standard VAT rate, and the
  /// only sensible seed for a venue whose config defaults to NL/EUR.
  static const String defaultTaxRateLabel = '21%';

  /// A fresh terminal takes both tenders, which is exactly what the payment
  /// selector did before this screen existed. So installing this feature
  /// changes no behaviour until an operator actually turns something off.
  factory PosPaymentSettings.initial() => const PosPaymentSettings(
        cashEnabled: true,
        cardEnabled: true,
        mobilePayEnabled: false,
        giftCardsEnabled: false,
        tippingEnabled: false,
        defaultTaxRate: defaultTaxRateLabel,
      );

  /// True when exactly one of the two real tenders is left.
  ///
  /// Drives the last-tender guard: the surviving toggle goes non-interactive
  /// so an operator cannot strand themselves with no way to take money.
  bool get isLastTender => cashEnabled != cardEnabled;

  bool get cashLocked => cashEnabled && isLastTender;
  bool get cardLocked => cardEnabled && isLastTender;

  PosPaymentSettings copyWith({
    bool? cashEnabled,
    bool? cardEnabled,
    bool? mobilePayEnabled,
    bool? giftCardsEnabled,
    bool? tippingEnabled,
    String? defaultTaxRate,
  }) {
    return PosPaymentSettings(
      cashEnabled: cashEnabled ?? this.cashEnabled,
      cardEnabled: cardEnabled ?? this.cardEnabled,
      mobilePayEnabled: mobilePayEnabled ?? this.mobilePayEnabled,
      giftCardsEnabled: giftCardsEnabled ?? this.giftCardsEnabled,
      tippingEnabled: tippingEnabled ?? this.tippingEnabled,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
    );
  }

  Map<String, dynamic> toJson() => {
        'cash_enabled': cashEnabled,
        'card_enabled': cardEnabled,
        'mobile_pay_enabled': mobilePayEnabled,
        'gift_cards_enabled': giftCardsEnabled,
        'tipping_enabled': tippingEnabled,
        'default_tax_rate': defaultTaxRate,
      };

  factory PosPaymentSettings.fromJson(Map<String, dynamic> json) {
    final PosPaymentSettings fallback = PosPaymentSettings.initial();
    final bool cash = _bool(json['cash_enabled']) ?? fallback.cashEnabled;
    final bool card = _bool(json['card_enabled']) ?? fallback.cardEnabled;

    return PosPaymentSettings(
      // A stored payload with both tenders off would leave the terminal unable
      // to take money at all. The UI guard makes that unreachable, but a
      // hand-edited or partially-written payload must not be able to brick
      // checkout, so cash is restored as the floor.
      cashEnabled: (!cash && !card) ? true : cash,
      cardEnabled: card,
      mobilePayEnabled:
          _bool(json['mobile_pay_enabled']) ?? fallback.mobilePayEnabled,
      giftCardsEnabled:
          _bool(json['gift_cards_enabled']) ?? fallback.giftCardsEnabled,
      tippingEnabled:
          _bool(json['tipping_enabled']) ?? fallback.tippingEnabled,
      defaultTaxRate: (json['default_tax_rate'] as String?)?.trim().isNotEmpty ==
              true
          ? (json['default_tax_rate'] as String).trim()
          : fallback.defaultTaxRate,
    );
  }

  static bool? _bool(Object? v) {
    if (v is bool) return v;
    if (v is String) {
      if (v == 'true') return true;
      if (v == 'false') return false;
    }
    return null;
  }

  bool sameAs(PosPaymentSettings other) =>
      cashEnabled == other.cashEnabled &&
      cardEnabled == other.cardEnabled &&
      mobilePayEnabled == other.mobilePayEnabled &&
      giftCardsEnabled == other.giftCardsEnabled &&
      tippingEnabled == other.tippingEnabled &&
      defaultTaxRate == other.defaultTaxRate;
}
