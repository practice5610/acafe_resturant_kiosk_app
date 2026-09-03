import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings_repo.dart';
import 'package:flutter/foundation.dart';

/// Form state for Settings → General.
///
/// Hydrates from [ConfigModel] (server) with an optional SharedPreferences
/// overlay for values the POS has saved. Typing only mutates local draft
/// state — no network until [save].
class PosGeneralSettingsProvider extends ChangeNotifier {
  final PosGeneralSettingsRepo repo;

  PosGeneralSettingsProvider({required this.repo});

  PosGeneralSettings _draft = const PosGeneralSettings(
    storeName: '',
    address: '',
    contactPhone: '',
    contactEmail: '',
    website: '',
    currency: 'EUR',
    taxModel: PosGeneralSettings.defaultTaxModel,
    dateFormat: PosGeneralSettings.defaultDateFormat,
  );
  PosGeneralSettings _saved = const PosGeneralSettings(
    storeName: '',
    address: '',
    contactPhone: '',
    contactEmail: '',
    website: '',
    currency: 'EUR',
    taxModel: PosGeneralSettings.defaultTaxModel,
    dateFormat: PosGeneralSettings.defaultDateFormat,
  );

  Map<String, String> _errors = {};
  bool _saving = false;
  bool _hydrated = false;

  PosGeneralSettings get draft => _draft;
  PosGeneralSettings get saved => _saved;
  Map<String, String> get errors => _errors;
  bool get isSaving => _saving;
  bool get isDirty => !_draft.sameAs(_saved);

  void hydrate(ConfigModel? config) {
    final PosGeneralSettings fromConfig =
        PosGeneralSettings.fromConfig(config);
    final PosGeneralSettings? local = repo.loadSaved();
    final PosGeneralSettings initial = local ?? fromConfig;
    _draft = initial;
    _saved = initial;
    _errors = {};
    _hydrated = true;
    notifyListeners();
  }

  bool get isHydrated => _hydrated;

  void setStoreName(String v) => _patch(storeName: v);
  void setAddress(String v) => _patch(address: v);
  void setContactPhone(String v) => _patch(contactPhone: v);
  void setContactEmail(String v) => _patch(contactEmail: v);
  void setWebsite(String v) => _patch(website: v);
  void setCurrency(String v) => _patch(currency: v);
  void setTaxModel(String v) => _patch(taxModel: v);
  void setDateFormat(String v) => _patch(dateFormat: v);

  void _patch({
    String? storeName,
    String? address,
    String? contactPhone,
    String? contactEmail,
    String? website,
    String? currency,
    String? taxModel,
    String? dateFormat,
  }) {
    _draft = _draft.copyWith(
      storeName: storeName,
      address: address,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      website: website,
      currency: currency,
      taxModel: taxModel,
      dateFormat: dateFormat,
    );
    // Clear field error as the user edits that field.
    if (storeName != null) _errors.remove('storeName');
    if (address != null) _errors.remove('address');
    if (contactPhone != null) _errors.remove('contactPhone');
    if (contactEmail != null) _errors.remove('contactEmail');
    if (website != null) _errors.remove('website');
    notifyListeners();
  }

  /// Validates and persists. Returns true on success.
  Future<bool> save() async {
    final Map<String, String> next =
        PosGeneralSettingsValidation.validate(_draft);
    if (next.isNotEmpty) {
      _errors = next;
      notifyListeners();
      return false;
    }
    if (!isDirty) return true;

    _saving = true;
    notifyListeners();

    final PosGeneralSettings cleaned = PosGeneralSettings(
      storeName: _draft.storeName.trim(),
      address: _draft.address.trim(),
      contactPhone: _draft.contactPhone.trim(),
      contactEmail: _draft.contactEmail.trim(),
      website: _draft.website.trim(),
      currency: _draft.currency,
      taxModel: _draft.taxModel,
      dateFormat: _draft.dateFormat,
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
