import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings_repo.dart';
import 'package:flutter/foundation.dart';

/// Form state for Settings → Payments.
///
/// Deliberately **not** General's `_draft` / `_saved` / Save-button shape. The
/// Figma frame has no Save button, and every control on it is a switch or a
/// single field whose meaning is complete the moment it changes — so this
/// writes through on every edit and there is no dirty state to lose.
///
/// Three stores meet here, and Payments owns only one of them:
///
///  * [repo] — this screen's own settings. Owned outright.
///  * [generalRepo] — Default Currency is the *same setting* as General →
///    Regional Settings. Rather than keep a second copy that could drift, this
///    reads and writes General's record directly, touching only the currency
///    field and preserving everything else in it.
///  * [hardwareRepo] — Receipt Auto-Print already exists as
///    `PosHardwareSettings.autoPrintReceipts`, and is already wired to fire
///    after a completed sale. Same reasoning: shared record, not a copy.
class PosPaymentSettingsProvider extends ChangeNotifier {
  final PosPaymentSettingsRepo repo;

  /// Read-write, but **only** for `currency`. Every other General field is
  /// carried through untouched on save.
  final PosGeneralSettingsRepo generalRepo;

  /// Read-write, but **only** for `autoPrintReceipts`.
  final PosHardwareSettingsRepo hardwareRepo;

  PosPaymentSettingsProvider({
    required this.repo,
    required this.generalRepo,
    required this.hardwareRepo,
  });

  PosPaymentSettings _settings = PosPaymentSettings.initial();
  PosGeneralSettings _general = PosGeneralSettings.fromConfig(null);
  late PosHardwareSettings _hardware =
      PosHardwareSettings.initial(storeName: '');
  bool _hydrated = false;

  PosPaymentSettings get settings => _settings;
  bool get isHydrated => _hydrated;

  /// The live currency from General — its saved override if the operator has
  /// edited it, otherwise whatever the backend config supplies.
  String get currency => _general.currency;

  bool get autoPrintReceipts => _hardware.autoPrintReceipts;

  void hydrate(ConfigModel? config, {String? languageCode}) {
    _general = generalRepo.loadSaved() ??
        PosGeneralSettings.fromConfig(config, languageCode: languageCode);
    _hardware = hardwareRepo.loadSaved(storeName: _general.storeName) ??
        PosHardwareSettings.initial(storeName: _general.storeName);
    _settings = repo.load();
    _hydrated = true;
    notifyListeners();
  }

  // ── Tenders ────────────────────────────────────────────────────────────

  /// Last-tender guard. Turning off the only method left would leave the
  /// terminal unable to take money at all, so the request is refused rather
  /// than applied — the UI also renders that toggle non-interactive, and this
  /// is the backstop behind it.
  void setCashEnabled(bool v) {
    if (!v && !_settings.cardEnabled) return;
    _patch(_settings.copyWith(cashEnabled: v));
  }

  void setCardEnabled(bool v) {
    if (!v && !_settings.cashEnabled) return;
    _patch(_settings.copyWith(cardEnabled: v));
  }

  void setMobilePayEnabled(bool v) =>
      _patch(_settings.copyWith(mobilePayEnabled: v));

  void setGiftCardsEnabled(bool v) =>
      _patch(_settings.copyWith(giftCardsEnabled: v));

  void setTippingEnabled(bool v) =>
      _patch(_settings.copyWith(tippingEnabled: v));

  /// Display-only. Nothing reads this back out to compute a total — tax is
  /// per-product in this system, and there is no store-level rate for it to
  /// override. See [PosPaymentSettings].
  void setDefaultTaxRate(String v) =>
      _patch(_settings.copyWith(defaultTaxRate: v));

  void _patch(PosPaymentSettings next) {
    if (next.sameAs(_settings)) return;
    _settings = next;
    notifyListeners();
    repo.save(next);
  }

  // ── Shared records ─────────────────────────────────────────────────────

  /// Writes through to General's record, so the two screens can never show
  /// different currencies. Only the currency field moves; the store name,
  /// address, language, tax model and date format are carried through as-is.
  void setCurrency(String value) {
    if (value == _general.currency) return;
    _general = _general.copyWith(currency: value);
    notifyListeners();
    generalRepo.save(_general);
  }

  /// Writes through to Hardware's record — the same flag Hardware's own
  /// "Auto-Print Receipts" row edits, and the one the payment flow already
  /// checks before printing.
  void setAutoPrintReceipts(bool value) {
    if (value == _hardware.autoPrintReceipts) return;
    _hardware = _hardware.copyWith(autoPrintReceipts: value);
    notifyListeners();
    hardwareRepo.save(_hardware);
  }
}
