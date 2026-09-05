import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Bordered settings block with the ink tick + uppercase title.
///
/// Lifted verbatim out of `pos_general_settings_panel.dart`, where it was
/// file-private, so General and Hardware share one card. [trailing] is the one
/// addition — Hardware's "Receipt Header" block carries no trailing content,
/// but the affordance keeps the widget usable for Payments/Add-ons later
/// without another fork. Passing nothing renders exactly what General rendered.
class PosSettingsSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const PosSettingsSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

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
                Expanded(
                  child: Text(
                    title,
                    style: loewBold.copyWith(
                      fontSize: PosSettingsSpec.sectionTitleSize,
                      letterSpacing: PosSettingsSpec.sectionTitleTracking,
                      color: PosSettingsSpec.ink,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
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
