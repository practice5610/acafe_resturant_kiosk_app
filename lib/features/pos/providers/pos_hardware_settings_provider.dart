import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings_repo.dart';
import 'package:flutter/foundation.dart';

/// Form state for Settings → Hardware.
///
/// Shape is deliberately identical to [PosGeneralSettingsProvider]: `_draft` vs
/// `_saved`, `isDirty`, an `errors` map cleared per-field on edit, and a
/// `save()` that validates first and only writes when dirty. Hardware is a
/// batch form with a preview, so it gets General's pattern rather than
/// Products' per-toggle auto-save.
class PosHardwareSettingsProvider extends ChangeNotifier {
  final PosHardwareSettingsRepo repo;

  /// Read-only window onto General → Store Information. Hardware never writes
  /// through this; it reads the store name for the "Use store name" toggle and
  /// the address/phone/locale for the receipt preview.
  final PosGeneralSettingsRepo generalRepo;

  PosHardwareSettingsProvider({
    required this.repo,
    required this.generalRepo,
  });

  PosGeneralSettings _general = PosGeneralSettings.fromConfig(null);
  late PosHardwareSettings _draft =
      PosHardwareSettings.initial(storeName: _general.storeName);
  late PosHardwareSettings _saved = _draft;

  Map<String, String> _errors = {};
  bool _saving = false;
  bool _hydrated = false;

  PosHardwareSettings get draft => _draft;
  PosHardwareSettings get saved => _saved;
  PosGeneralSettings get general => _general;
  Map<String, String> get errors => _errors;
  bool get isSaving => _saving;
  bool get isDirty => !_draft.sameAs(_saved);
  bool get isHydrated => _hydrated;

  /// The live store name from General — its saved override if the operator has
  /// edited it, otherwise the value the backend config supplies.
  String get storeName => _general.storeName;

  /// What the receipt header resolves to right now.
  String get effectiveHeader => _draft.effectiveHeader(storeName);

  void hydrate(ConfigModel? config, {String? languageCode}) {
    _general = generalRepo.loadSaved() ??
        PosGeneralSettings.fromConfig(config, languageCode: languageCode);

    final PosHardwareSettings initial =
        repo.loadSaved(storeName: storeName) ??
            PosHardwareSettings.initial(storeName: storeName);

    _draft = initial;
    _saved = initial;
    _errors = {};
    _hydrated = true;
    notifyListeners();
  }

  void setAutoPrintReceipts(bool v) => _patch(autoPrintReceipts: v);
  void setKitchenTicketPrinting(bool v) => _patch(kitchenTicketPrinting: v);
  void setOrderNumberPrefix(String v) => _patch(orderNumberPrefix: v);
  void setReceiptHeader(String v) => _patch(receiptHeader: v);
  void setReceiptFooter(String v) => _patch(receiptFooter: v);

  /// Switching the toggle on adopts the live store name as the header, so the
  /// field the operator sees and the value that prints can never disagree.
  /// Switching it off leaves that text in place as the starting point for an
  /// edit rather than blanking the field.
  void setUseStoreName(bool v) {
    _patch(
      useStoreName: v,
      receiptHeader: v ? storeName : _draft.effectiveHeader(storeName),
    );
  }

  void toggleKioskLanguage(String code) {
    final List<String> next = [..._draft.kioskLanguages];
    if (next.contains(code)) {
      // Guarded, not silently ignored: an empty offering would leave the kiosk
      // picker with nothing to show. Validation would also catch it, but
      // blocking the last removal is the clearer interaction.
      if (next.length == 1) return;
      next.remove(code);
    } else {
      next.add(code);
    }
    _patch(kioskLanguages: next);
  }

  bool isKioskLanguageSelected(String code) =>
      _draft.kioskLanguages.contains(code);

  void _patch({
    bool? autoPrintReceipts,
    bool? kitchenTicketPrinting,
    String? orderNumberPrefix,
    bool? useStoreName,
    String? receiptHeader,
    String? receiptFooter,
    List<String>? kioskLanguages,
  }) {
    _draft = _draft.copyWith(
      autoPrintReceipts: autoPrintReceipts,
      kitchenTicketPrinting: kitchenTicketPrinting,
      orderNumberPrefix: orderNumberPrefix,
      useStoreName: useStoreName,
      receiptHeader: receiptHeader,
      receiptFooter: receiptFooter,
      kioskLanguages: kioskLanguages,
    );
    if (orderNumberPrefix != null) _errors.remove('orderNumberPrefix');
    if (receiptHeader != null || useStoreName != null) {
      _errors.remove('receiptHeader');
    }
    if (receiptFooter != null) _errors.remove('receiptFooter');
    if (kioskLanguages != null) _errors.remove('kioskLanguages');
    notifyListeners();
  }

  Future<bool> save() async {
    final Map<String, String> next =
        PosHardwareSettingsValidation.validate(_draft);
    if (next.isNotEmpty) {
      _errors = next;
      notifyListeners();
      return false;
    }
    if (!isDirty) return true;

    _saving = true;
    notifyListeners();

    final PosHardwareSettings cleaned = _draft.copyWith(
      orderNumberPrefix: _draft.orderNumberPrefix.trim(),
      receiptHeader: _draft.receiptHeader.trim(),
      receiptFooter: _draft.receiptFooter.trim(),
    );

    final bool ok = await repo.save(cleaned);
    _saving = false;
    if (ok) {
      _draft = cleaned;
      _saved = cleaned;
      _errors = {};
    }
    notifyListeners();
    return ok;
  }
}
