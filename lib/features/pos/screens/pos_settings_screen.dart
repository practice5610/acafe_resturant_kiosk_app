import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_general_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_section.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/providers/pos_general_settings_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_hardware_settings_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_general_settings_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_hardware_settings_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_addons_settings_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_products_settings_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_profile_settings_panel.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_payment_settings_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payments_settings_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_sidebar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_settings_panel.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// POS Settings shell — sidebar + section content (Figma 1641:3896).
///
/// Top nav lives in [PosScaffold]; this screen owns only the settings body.
class PosSettingsScreen extends StatefulWidget {
  /// Test seam. Production resolves prefs from GetIt.
  final SharedPreferences? sharedPreferences;

  const PosSettingsScreen({super.key, this.sharedPreferences});

  @override
  State<PosSettingsScreen> createState() => _PosSettingsScreenState();
}

class _PosSettingsScreenState extends State<PosSettingsScreen> {
  PosSettingsSection _section = PosSettingsSection.general;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PosSettingsSidebar(
          selected: _section,
          onSelect: (PosSettingsSection next) {
            if (next == _section) return;
            setState(() => _section = next);
          },
        ),
        Expanded(
          child: ColoredBox(
            color: PosSettingsSpec.pageBg,
            child: Padding(
              padding: PosSettingsSpec.panelPadding,
              child: switch (_section) {
                PosSettingsSection.general => _GeneralSectionHost(
                    sharedPreferences: widget.sharedPreferences,
                  ),
                PosSettingsSection.profile => const PosProfileSettingsPanel(),
                PosSettingsSection.staff => const PosStaffSettingsPanel(),
                PosSettingsSection.products => const PosProductsSettingsPanel(),
                PosSettingsSection.addOns => const PosAddonsSettingsPanel(),
                PosSettingsSection.payments => _PaymentsSectionHost(
                    sharedPreferences: widget.sharedPreferences,
                  ),
                PosSettingsSection.hardware => _HardwareSectionHost(
                    sharedPreferences: widget.sharedPreferences,
                  ),
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Scopes the General form provider to this tab so draft state does not leak
/// across the rest of the app, and hydrates once from live config + prefs.
class _GeneralSectionHost extends StatelessWidget {
  final SharedPreferences? sharedPreferences;

  const _GeneralSectionHost({this.sharedPreferences});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PosGeneralSettingsProvider>(
      create: (context) {
        final provider = PosGeneralSettingsProvider(
          repo: PosGeneralSettingsRepo(
            sharedPreferences: sharedPreferences ?? di.sl<SharedPreferences>(),
          ),
        );
        provider.hydrate(
          context.read<SplashProvider>().configModel,
          languageCode:
              context.read<LocalizationProvider>().locale.languageCode,
        );
        return provider;
      },
      child: const PosGeneralSettingsPanel(),
    );
  }
}

/// Scopes the Hardware form provider to this tab, exactly as General does, and
/// hydrates once from live config + prefs. General's repo is passed in read-only
/// so the store name and locale reach the receipt preview without Hardware
/// keeping a second copy of them.
class _HardwareSectionHost extends StatelessWidget {
  final SharedPreferences? sharedPreferences;

  const _HardwareSectionHost({this.sharedPreferences});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PosHardwareSettingsProvider>(
      create: (context) {
        final SharedPreferences prefs =
            sharedPreferences ?? di.sl<SharedPreferences>();
        final provider = PosHardwareSettingsProvider(
          repo: PosHardwareSettingsRepo(sharedPreferences: prefs),
          generalRepo: PosGeneralSettingsRepo(sharedPreferences: prefs),
        );
        provider.hydrate(
          context.read<SplashProvider>().configModel,
          languageCode:
              context.read<LocalizationProvider>().locale.languageCode,
        );
        return provider;
      },
      child: const PosHardwareSettingsPanel(),
    );
  }
}

/// Scopes the Payments provider to this tab, as General and Hardware do.
///
/// Payments is the one section that shares records with its siblings, so both
/// neighbouring repos are passed in: General's holds the currency this screen
/// edits, and Hardware's holds the auto-print flag. Neither is copied — the
/// same record is read and written, so the screens cannot disagree.
class _PaymentsSectionHost extends StatelessWidget {
  final SharedPreferences? sharedPreferences;

  const _PaymentsSectionHost({this.sharedPreferences});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PosPaymentSettingsProvider>(
      create: (context) {
        final SharedPreferences prefs =
            sharedPreferences ?? di.sl<SharedPreferences>();
        final provider = PosPaymentSettingsProvider(
          repo: PosPaymentSettingsRepo(sharedPreferences: prefs),
          generalRepo: PosGeneralSettingsRepo(sharedPreferences: prefs),
          hardwareRepo: PosHardwareSettingsRepo(sharedPreferences: prefs),
        );
        provider.hydrate(
          context.read<SplashProvider>().configModel,
          languageCode:
              context.read<LocalizationProvider>().locale.languageCode,
        );
        return provider;
      },
      child: const PosPaymentsSettingsPanel(),
    );
  }
}

