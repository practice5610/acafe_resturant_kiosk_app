import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/providers/pos_general_settings_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_text_field.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings → General form body (Figma 1641:3920).
class PosGeneralSettingsPanel extends StatefulWidget {
  const PosGeneralSettingsPanel({super.key});

  @override
  State<PosGeneralSettingsPanel> createState() =>
      _PosGeneralSettingsPanelState();
}

class _PosGeneralSettingsPanelState extends State<PosGeneralSettingsPanel> {
  late final TextEditingController _storeName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _storeName = TextEditingController();
    _address = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _website = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final PosGeneralSettings draft =
        context.read<PosGeneralSettingsProvider>().draft;
    _storeName.text = draft.storeName;
    _address.text = draft.address;
    _phone.text = draft.contactPhone;
    _email.text = draft.contactEmail;
    _website.text = draft.website;
    _seeded = true;
  }

  @override
  void dispose() {
    _storeName.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final PosGeneralSettingsProvider provider =
        context.read<PosGeneralSettingsProvider>();
    final bool ok = await provider.save();
    if (!mounted) return;
    if (ok) {
      showCustomSnackBarHelper('Settings saved', isError: false);
    } else if (provider.errors.isNotEmpty) {
      showCustomSnackBarHelper(
        provider.errors.values.first,
        isError: true,
      );
    } else {
      showCustomSnackBarHelper('Could not save settings', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PosGeneralSettingsProvider provider =
        context.watch<PosGeneralSettingsProvider>();
    final PosGeneralSettings draft = provider.draft;
    final Map<String, String> errors = provider.errors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General',
                    style: loewExtraBold.copyWith(
                      fontSize: PosSettingsSpec.titleSize,
                      color: PosSettingsSpec.ink,
                    ),
                  ),
                  const SizedBox(height: PosSettingsSpec.headerGap),
                  Text(
                    'Store identity & locale settings',
                    style: loewRegular.copyWith(
                      fontSize: PosSettingsSpec.subtitleSize,
                      color: PosSettingsSpec.inkMuted(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _SaveChangesButton(
              loading: provider.isSaving,
              onPressed: _onSave,
            ),
          ],
        ),
        const SizedBox(height: PosSettingsSpec.sectionGap),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Store Information',
                  style: loewBold.copyWith(
                    fontSize: PosSettingsSpec.sectionTitleSize,
                    color: PosSettingsSpec.ink,
                  ),
                ),
                const SizedBox(height: PosSettingsSpec.fieldGap),
                PosSettingsTextField(
                  label: 'Store Name',
                  controller: _storeName,
                  textInputAction: TextInputAction.next,
                  errorText: errors['storeName'],
                  onChanged: provider.setStoreName,
                ),
                const SizedBox(height: PosSettingsSpec.fieldGap),
                PosSettingsTextField(
                  label: 'Address',
                  controller: _address,
                  textInputAction: TextInputAction.next,
                  errorText: errors['address'],
                  onChanged: provider.setAddress,
                ),
                const SizedBox(height: PosSettingsSpec.fieldGap),
                PosSettingsTextField(
                  label: 'Contact Phone',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  errorText: errors['contactPhone'],
                  onChanged: provider.setContactPhone,
                ),
                const SizedBox(height: PosSettingsSpec.fieldGap),
                PosSettingsTextField(
                  label: 'Contact Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  errorText: errors['contactEmail'],
                  onChanged: provider.setContactEmail,
                ),
                const SizedBox(height: PosSettingsSpec.fieldGap),
                PosSettingsTextField(
                  label: 'Website',
                  optionalLabel: 'optional',
                  controller: _website,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  errorText: errors['website'],
                  onChanged: provider.setWebsite,
                ),
                const SizedBox(height: PosSettingsSpec.sectionGap),
                const ColoredBox(
                  color: PosSettingsSpec.divider,
                  child: SizedBox(height: 1, width: double.infinity),
                ),
                const SizedBox(height: PosSettingsSpec.sectionGap),
                Text(
                  'Regional Settings',
                  style: loewBold.copyWith(
                    fontSize: PosSettingsSpec.sectionTitleSize,
                    color: PosSettingsSpec.ink,
                  ),
                ),
                const SizedBox(height: PosSettingsSpec.fieldGap),
                PosSettingsDropdown(
                  label: 'Currency',
                  value: draft.currency,
                  options: PosGeneralSettings.currencyOptions,
                  onChanged: provider.setCurrency,
                ),
                const SizedBox(height: PosSettingsSpec.fieldGap),
                PosSettingsDropdown(
                  label: 'Tax Model',
                  value: draft.taxModel,
                  options: PosGeneralSettings.taxModelOptions,
                  onChanged: provider.setTaxModel,
                ),
                const SizedBox(height: PosSettingsSpec.fieldGap),
                PosSettingsDropdown(
                  label: 'Date Format',
                  value: draft.dateFormat,
                  options: PosGeneralSettings.dateFormatOptions,
                  onChanged: provider.setDateFormat,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveChangesButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _SaveChangesButton({
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosSettingsSpec.ink,
        borderRadius: BorderRadius.circular(PosSettingsSpec.saveRadius),
        boxShadow: PosSettingsSpec.saveShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onPressed,
          borderRadius: BorderRadius.circular(PosSettingsSpec.saveRadius),
          child: Padding(
            padding: PosSettingsSpec.savePadding,
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PosSettingsSpec.pageBg,
                    ),
                  )
                : Text(
                    'Save Changes',
                    style: loewBold.copyWith(
                      fontSize: PosSettingsSpec.saveLabelSize,
                      color: PosSettingsSpec.pageBg,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
