import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_text_field.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Terminal Profile for Settings → PROFILE (Approach A).
///
/// Binds to the real device session + branch payload. There is no staff user
/// after PIN unlock, so name/role/avatar reflect the till — not a person.
/// Password / passcode changes are admin-managed; Update explains that.
class PosProfileSettingsPanel extends StatefulWidget {
  const PosProfileSettingsPanel({super.key});

  @override
  State<PosProfileSettingsPanel> createState() =>
      _PosProfileSettingsPanelState();
}

class _PosProfileSettingsPanelState extends State<PosProfileSettingsPanel> {
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  /// Display labels matching the Preferences card in Figma.
  static const List<PosSettingsOption> _languageOptions = [
    PosSettingsOption(value: 'nl', label: 'Nederlands (Dutch)'),
    PosSettingsOption(value: 'en', label: 'English'),
    PosSettingsOption(value: 'fr', label: 'Français (French)'),
  ];

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<KioskAuthProvider>();
    final config = context.read<SplashProvider>().configModel;
    _fullName.text = _displayName(auth);
    _email.text = _displayEmail(auth, config?.restaurantEmail);
    _phone.text = _displayPhone(auth, config?.restaurantPhone);
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  static String _displayName(KioskAuthProvider auth) {
    if (auth.deviceName.trim().isNotEmpty) return auth.deviceName.trim();
    if (auth.branchName.trim().isNotEmpty) return auth.branchName.trim();
    return auth.username.trim();
  }

  static String _displayEmail(KioskAuthProvider auth, String? fallback) {
    if (auth.branchEmail.trim().isNotEmpty) return auth.branchEmail.trim();
    return (fallback ?? '').trim();
  }

  static String _displayPhone(KioskAuthProvider auth, String? fallback) {
    if (auth.branchPhone.trim().isNotEmpty) return auth.branchPhone.trim();
    return (fallback ?? '').trim();
  }

  static String _roleLabel(KioskAuthProvider auth) {
    return auth.isPosDevice ? 'POS Terminal' : 'Kiosk Terminal';
  }

  static String _initial(KioskAuthProvider auth) {
    final String source = _displayName(auth);
    return source.isEmpty ? 'A' : source.characters.first.toUpperCase();
  }

  String _languageCode(LocalizationProvider localization) {
    final String code = localization.locale.languageCode;
    if (PosGeneralSettings.posLanguageCodes.contains(code)) return code;
    return PosGeneralSettings.defaultLanguage;
  }

  Future<void> _onLanguageChanged(String code) async {
    final localization = context.read<LocalizationProvider>();
    await localization.setKioskLanguage(
      Locale(code, PosGeneralSettings.countryCodeForLanguage(code)),
    );
    if (!mounted) return;
    showCustomSnackBarHelper('Language updated', isError: false);
  }

  void _showAdminManagedDialog({
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PosSettingsSpec.panelBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
        ),
        title: Text(
          title,
          style: loewExtraBold.copyWith(
            fontSize: 16,
            color: PosSettingsSpec.ink,
          ),
        ),
        content: Text(
          body,
          style: loewRegular.copyWith(
            fontSize: 14,
            color: PosSettingsSpec.inkMuted(),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: loewBold.copyWith(color: PosSettingsSpec.ink),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<KioskAuthProvider>();
    final localization = context.watch<LocalizationProvider>();
    final config = context.watch<SplashProvider>().configModel;

    final String name = _displayName(auth);
    final String role = _roleLabel(auth);
    final String? imageUrl = auth.branchImageUrl.trim().isEmpty
        ? null
        : auth.branchImageUrl.trim();

    // Keep controllers in sync when auth refreshes (e.g. /device/me).
    final String nextName = name;
    final String nextEmail = _displayEmail(auth, config?.restaurantEmail);
    final String nextPhone = _displayPhone(auth, config?.restaurantPhone);
    if (_fullName.text != nextName) _fullName.text = nextName;
    if (_email.text != nextEmail) _email.text = nextEmail;
    if (_phone.text != nextPhone) _phone.text = nextPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'PROFILE',
          style: loewExtraBold.copyWith(
            fontSize: PosSettingsSpec.titleSize,
            color: PosSettingsSpec.ink,
            letterSpacing: 0.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.headerGap),
        Text(
          'Personal account settings and preferences',
          style: loewRegular.copyWith(
            fontSize: PosSettingsSpec.subtitleSize,
            color: PosSettingsSpec.inkMuted(),
          ),
        ),
        const SizedBox(height: 28),
        _AvatarBlock(
          name: name.toUpperCase(),
          role: role,
          initial: _initial(auth),
          imageUrl: imageUrl,
          onChangePhoto: () => _showAdminManagedDialog(
            title: 'Change photo',
            body:
                'Terminal photos are managed in the admin branch settings. '
                'This till does not have a personal staff profile.',
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide =
                  constraints.maxWidth >= PosSettingsSpec.wideBreakpoint;
              final Widget personal = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PosSettingsTextField(
                    label: 'Full Name',
                    controller: _fullName,
                    readOnly: true,
                  ),
                  const SizedBox(height: PosSettingsSpec.fieldGap),
                  PosSettingsTextField(
                    label: 'Email Address',
                    controller: _email,
                    readOnly: true,
                  ),
                  const SizedBox(height: PosSettingsSpec.fieldGap),
                  PosSettingsTextField(
                    label: 'Phone Number',
                    controller: _phone,
                    readOnly: true,
                  ),
                ],
              );

              final Widget side = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabeledCard(
                    label: 'Security',
                    child: Column(
                      children: [
                        _SecureRow(
                          label: 'POS Password',
                          mask: '••••••••',
                          onUpdate: () => _showAdminManagedDialog(
                            title: 'Update POS password',
                            body:
                                'Device login passwords are set in the admin '
                                'panel. This terminal cannot change them.',
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SecureRow(
                          label: 'POS Passcode',
                          mask: '••••',
                          onUpdate: () => _showAdminManagedDialog(
                            title: 'Update POS passcode',
                            body:
                                'The shift PIN (configuration code) is managed '
                                'in admin device settings. Ask a manager to '
                                'update it there.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _LabeledCard(
                    label: 'Preferences',
                    child: PosSettingsDropdown(
                      label: 'Language',
                      value: _languageCode(localization),
                      options: _languageOptions,
                      onChanged: _onLanguageChanged,
                    ),
                  ),
                ],
              );

              if (wide) {
                return SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: personal),
                      const SizedBox(width: 28),
                      Expanded(child: side),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    personal,
                    const SizedBox(height: 28),
                    side,
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

class _AvatarBlock extends StatelessWidget {
  final String name;
  final String role;
  final String initial;
  final String? imageUrl;
  final VoidCallback onChangePhoto;

  const _AvatarBlock({
    required this.name,
    required this.role,
    required this.initial,
    required this.imageUrl,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PosAvatar(
          initial: initial,
          imageUrl: imageUrl,
          size: 72,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'TERMINAL' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: loewBold.copyWith(
                  fontSize: 16,
                  letterSpacing: 0.4,
                  color: PosSettingsSpec.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                role,
                style: loewRegular.copyWith(
                  fontSize: 13,
                  color: PosSettingsSpec.inkMuted(),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onChangePhoto,
                child: Text(
                  'Change photo',
                  style: loewMedium.copyWith(
                    fontSize: 13,
                    color: PosSettingsSpec.inkMuted(0.75),
                    decoration: TextDecoration.underline,
                    decorationColor: PosSettingsSpec.inkMuted(0.75),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledCard extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: loewBold.copyWith(
            fontSize: PosSettingsSpec.labelSize,
            letterSpacing: PosSettingsSpec.labelTracking,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(PosSettingsSpec.fieldRadius),
            border: Border.all(color: PosSettingsSpec.fieldBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _SecureRow extends StatelessWidget {
  final String label;
  final String mask;
  final VoidCallback onUpdate;

  const _SecureRow({
    required this.label,
    required this.mask,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: loewBold.copyWith(
            fontSize: PosSettingsSpec.labelSize,
            letterSpacing: PosSettingsSpec.labelTracking,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.labelGap),
        Row(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: PosSettingsSpec.panelBg,
                  borderRadius:
                      BorderRadius.circular(PosSettingsSpec.fieldRadius),
                  border: Border.all(color: PosSettingsSpec.fieldBorder),
                ),
                child: Padding(
                  padding: PosSettingsSpec.fieldPadding,
                  child: Text(
                    mask,
                    style: loewBold.copyWith(
                      fontSize: PosSettingsSpec.fieldTextSize,
                      color: PosSettingsSpec.ink,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(PosSettingsSpec.fieldRadius),
              child: InkWell(
                onTap: onUpdate,
                borderRadius:
                    BorderRadius.circular(PosSettingsSpec.fieldRadius),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(PosSettingsSpec.fieldRadius),
                    border: Border.all(
                      color: PosSettingsSpec.ink,
                      width: 1.25,
                    ),
                  ),
                  child: Text(
                    'Update',
                    style: loewBold.copyWith(
                      fontSize: 13,
                      color: PosSettingsSpec.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
