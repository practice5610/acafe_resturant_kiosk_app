import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/pos/domain/pos_general_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_section.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/providers/pos_general_settings_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_general_settings_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_sidebar.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/styles.dart';
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
              child: _section == PosSettingsSection.general
                  ? _GeneralSectionHost(
                      sharedPreferences: widget.sharedPreferences,
                    )
                  : _UpcomingSectionPanel(section: _section),
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
            sharedPreferences:
                sharedPreferences ?? di.sl<SharedPreferences>(),
          ),
        );
        provider.hydrate(context.read<SplashProvider>().configModel);
        return provider;
      },
      child: const PosGeneralSettingsPanel(),
    );
  }
}

/// Stub for sections that do not have Figma frames wired yet — keeps sidebar
/// navigation real without inventing fake business UI.
class _UpcomingSectionPanel extends StatelessWidget {
  final PosSettingsSection section;

  const _UpcomingSectionPanel({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: loewExtraBold.copyWith(
            fontSize: PosSettingsSpec.titleSize,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.headerGap),
        Text(
          section.subtitle,
          style: loewRegular.copyWith(
            fontSize: PosSettingsSpec.subtitleSize,
            color: PosSettingsSpec.inkMuted(),
          ),
        ),
        const SizedBox(height: PosSettingsSpec.sectionGap),
        Text(
          'This section is not available on this terminal yet.',
          style: loewRegular.copyWith(
            fontSize: PosSettingsSpec.subtitleSize,
            color: PosSettingsSpec.inkMuted(0.45),
          ),
        ),
      ],
    );
  }
}
