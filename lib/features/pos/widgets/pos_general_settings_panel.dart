import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/providers/pos_general_settings_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_text_field.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
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
    final String previousLanguage = provider.saved.language;
    final bool ok = await provider.save();
    if (!mounted) return;

    if (ok) {
      final String language = provider.saved.language;
      if (language != previousLanguage) {
        final localization = context.read<LocalizationProvider>();
        await localization.setKioskLanguage(
          Locale(
            language,
            PosGeneralSettings.countryCodeForLanguage(language),
          ),
        );
      }
      if (!mounted) return;
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
                      height: 1.1,
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
              dirty: provider.isDirty,
              onPressed: _onSave,
            ),
          ],
        ),
        const SizedBox(height: PosSettingsSpec.sectionGap),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide =
                  constraints.maxWidth >= PosSettingsSpec.wideBreakpoint;
              return SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsSection(
                      title: 'Store Information',
                      child: Column(
                        children: [
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
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: PosSettingsTextField(
                                    label: 'Contact Phone',
                                    controller: _phone,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    errorText: errors['contactPhone'],
                                    onChanged: provider.setContactPhone,
                                  ),
                                ),
                                const SizedBox(
                                    width: PosSettingsSpec.fieldRowGap),
                                Expanded(
                                  child: PosSettingsTextField(
                                    label: 'Contact Email',
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    errorText: errors['contactEmail'],
                                    onChanged: provider.setContactEmail,
                                  ),
                                ),
                              ],
                            )
                          else ...[
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
                          ],
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
                        ],
                      ),
                    ),
                    const SizedBox(height: PosSettingsSpec.sectionGap),
                    _SettingsSection(
                      title: 'Regional Settings',
                      child: Column(
                        children: [
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: PosSettingsDropdown(
                                    label: 'Language',
                                    value: draft.language,
                                    options:
                                        PosGeneralSettings.languageOptions,
                                    onChanged: provider.setLanguage,
                                  ),
                                ),
                                const SizedBox(
                                    width: PosSettingsSpec.fieldRowGap),
                                Expanded(
                                  child: PosSettingsDropdown(
                                    label: 'Currency',
                                    value: draft.currency,
                                    options:
                                        PosGeneralSettings.currencyOptions,
                                    onChanged: provider.setCurrency,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            PosSettingsDropdown(
                              label: 'Language',
                              value: draft.language,
                              options: PosGeneralSettings.languageOptions,
                              onChanged: provider.setLanguage,
                            ),
                            const SizedBox(height: PosSettingsSpec.fieldGap),
                            PosSettingsDropdown(
                              label: 'Currency',
                              value: draft.currency,
                              options: PosGeneralSettings.currencyOptions,
                              onChanged: provider.setCurrency,
                            ),
                          ],
                          const SizedBox(height: PosSettingsSpec.fieldGap),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: PosSettingsDropdown(
                                    label: 'Tax Model',
                                    value: draft.taxModel,
                                    options:
                                        PosGeneralSettings.taxModelOptions,
                                    onChanged: provider.setTaxModel,
                                  ),
                                ),
                                const SizedBox(
                                    width: PosSettingsSpec.fieldRowGap),
                                Expanded(
                                  child: PosSettingsDropdown(
                                    label: 'Date Format',
                                    value: draft.dateFormat,
                                    options:
                                        PosGeneralSettings.dateFormatOptions,
                                    onChanged: provider.setDateFormat,
                                  ),
                                ),
                              ],
                            )
                          else ...[
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
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosSettingsSpec.panelBg,
        borderRadius:
            BorderRadius.circular(PosSettingsSpec.sectionBlockRadius),
        border: Border.all(color: PosSettingsSpec.fieldBorder),
      ),
      child: Padding(
        padding: PosSettingsSpec.sectionBlockPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: PosSettingsSpec.ink,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: loewBold.copyWith(
                    fontSize: PosSettingsSpec.sectionTitleSize,
                    letterSpacing: PosSettingsSpec.sectionTitleTracking,
                    color: PosSettingsSpec.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SaveChangesButton extends StatefulWidget {
  final bool loading;
  final bool dirty;
  final VoidCallback onPressed;

  const _SaveChangesButton({
    required this.loading,
    required this.dirty,
    required this.onPressed,
  });

  @override
  State<_SaveChangesButton> createState() => _SaveChangesButtonState();
}

class _SaveChangesButtonState extends State<_SaveChangesButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.loading ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: widget.dirty || widget.loading ? 1 : 0.72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: PosSettingsSpec.ink,
                borderRadius:
                    BorderRadius.circular(PosSettingsSpec.saveRadius),
                boxShadow: PosSettingsSpec.saveShadow,
              ),
              child: Padding(
                padding: PosSettingsSpec.savePadding,
                child: widget.loading
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
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
