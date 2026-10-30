import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_summary_panel.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One selectable employee for the Open Employee Tab picker — the id travels so
/// a pick survives two members sharing a name.
class PosEmployeeOption {
  final String id;
  final String name;

  const PosEmployeeOption({required this.id, required this.name});
}

/// The payment-summary column for **Open Employee Tab**.
///
/// An employee tab collects no money (it is a staff comp), so this pane replaces
/// the keypad + "Add tip" row entirely — tipping has no meaning here. In its
/// place it shows who the comp is for (a picker drawn from the branch's staff
/// roster) and, below, the value they are consuming, labelled as an **expense**
/// rather than an amount due: the client's rule is that this value never enters
/// the day's sales, only the employee's own consumption record and the stock.
class PosEmployeeTabPanel extends StatelessWidget {
  /// The ticket's value — what the employee is consuming. Shown as the expense,
  /// never charged.
  final double expense;

  /// Branch staff to choose from (the sign-in roster). Empty while it loads.
  final List<PosEmployeeOption> employees;

  /// The picked employee's id, or null when none is chosen yet.
  final String? selectedId;

  /// The picked employee's name, shown while the roster is still loading and
  /// [selectedId] has no matching option yet (e.g. the signed-in employee is
  /// pre-selected before the roster arrives). Ignored once the option resolves.
  final String? selectedName;

  final ValueChanged<String> onSelect;

  /// True while the roster is still being fetched, so the field reads "Loading…"
  /// instead of "No staff".
  final bool loading;

  const PosEmployeeTabPanel({
    super.key,
    required this.expense,
    required this.employees,
    required this.selectedId,
    this.selectedName,
    required this.onSelect,
    this.loading = false,
  });

  /// Key of the employee picker trigger (for tests).
  static const Key pickerKey = Key('pos-employee-tab-picker');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(),
        const PosPaySummaryDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PosPaymentSpec.v2SummaryPaddingH,
            vertical: PosPaymentSpec.v2ReceivedPaddingV,
          ),
          child: _picker(context),
        ),
      ],
    );
  }

  /// Caption + the consumed value, drawn like the Card/Cash header but with the
  /// "no payment" wording and an "Employee expense" label instead of "Amount
  /// due".
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosPaymentSpec.v2SummaryPaddingH,
        PosPaymentSpec.v2SummaryHeaderPaddingTop,
        PosPaymentSpec.v2SummaryPaddingH,
        PosPaymentSpec.v2SummaryHeaderPaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'EMPLOYEE TAB',
            style: loewBold.copyWith(
              fontSize: PosPaymentSpec.v2SummaryCaptionSize,
              letterSpacing: PosPaymentSpec.v2SummaryCaptionTracking,
              color:
                  PosHomeSpec.inkAlpha(PosPaymentSpec.v2SummaryCaptionOpacity),
            ),
          ),
          const SizedBox(height: PosPaymentSpec.v2SummaryCaptionGap),
          Text(
            'No payment — staff comp',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: swiss721Light.copyWith(
              fontSize: PosPaymentSpec.v2SummarySubtitleSize,
              height: PosPaymentSpec.figmaLeading(
                  PosPaymentSpec.v2SummarySubtitleSize),
              color: PosHomeSpec.inkAlpha(
                  PosPaymentSpec.v2SummarySubtitleOpacity),
            ),
          ),
          const SizedBox(height: PosPaymentSpec.v2SummaryAmountGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              PosHomeSpec.formatPrice(expense, padZero: false),
              maxLines: 1,
              style: loewExtraBold.copyWith(
                fontSize: PosPaymentSpec.v2SummaryAmountSize,
                color: PosHomeSpec.ink,
              ),
            ),
          ),
          const SizedBox(height: PosPaymentSpec.v2SummaryCaptionGap),
          Text(
            'Employee expense',
            style: swiss721Light.copyWith(
              fontSize: PosPaymentSpec.v2SummaryDueLabelSize,
              height: PosPaymentSpec.figmaLeading(
                  PosPaymentSpec.v2SummaryDueLabelSize),
              color: PosHomeSpec.inkAlpha(PosPaymentSpec.v2MutedInkOpacity),
            ),
          ),
        ],
      ),
    );
  }

  Widget _picker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'EMPLOYEE',
          style: loewBold.copyWith(
            fontSize: PosSettingsSpec.labelSize,
            letterSpacing: PosSettingsSpec.labelTracking,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.labelGap),
        PosDropdown<String>(
          enabled: employees.isNotEmpty,
          value: selectedId ?? '',
          onChanged: onSelect,
          options: [
            for (final PosEmployeeOption e in employees)
              PosDropdownOption<String>(value: e.id, label: e.name),
          ],
          triggerBuilder: (context, selected, isOpen, toggle) {
            // A pre-selected name (the signed-in employee) is shown even before
            // the roster resolves it to an option.
            final String? preselected =
                (selectedId != null && (selectedName?.isNotEmpty ?? false))
                    ? selectedName
                    : null;
            final String text = selected?.label ??
                preselected ??
                (loading
                    ? 'Loading staff…'
                    : employees.isEmpty
                        ? 'No staff available'
                        : 'Select employee');
            final bool placeholder = selected == null && preselected == null;
            return Material(
              key: pickerKey,
              color: PosSettingsSpec.fieldFill,
              borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
              child: InkWell(
                onTap: employees.isEmpty ? null : toggle,
                borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
                child: Container(
                  width: double.infinity,
                  padding: PosSettingsSpec.fieldPadding,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(PosSettingsSpec.fieldRadius),
                    border: Border.all(
                      color: PosSettingsSpec.fieldBorder,
                      width: PosSettingsSpec.fieldBorderWidth,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: loewBold.copyWith(
                            fontSize: PosSettingsSpec.fieldTextSize,
                            color: placeholder
                                ? PosHomeSpec.inkAlpha(
                                    PosPaymentSpec.v2MutedInkOpacity)
                                : PosSettingsSpec.ink,
                            height: 1.2,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 140),
                        child: SvgPicture.asset(
                          Images.posChevronDownSvg,
                          width: PosSettingsSpec.chevronSize,
                          height: PosSettingsSpec.chevronSize,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
