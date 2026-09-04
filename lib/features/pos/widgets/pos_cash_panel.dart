import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A quick-denomination button on the cash panel.
///
/// [exact] is the odd one out: it does not name a note, it means "tender the
/// total to the cent", which is what an operator picks when the customer pays
/// by the exact amount and there is no change to count back.
@immutable
class PosCashDenomination {
  /// Minor units, or null for [exact].
  final int? cents;
  final bool exact;

  const PosCashDenomination.note(int this.cents) : exact = false;
  const PosCashDenomination.exact()
      : cents = null,
        exact = true;

  @override
  bool operator ==(Object other) =>
      other is PosCashDenomination &&
      other.cents == cents &&
      other.exact == exact;

  @override
  int get hashCode => Object.hash(cents, exact);
}

/// Cash tender entry — Figma `cash-payment-panel` (**1641:3830**).
///
/// Amount field, quick denominations, keypad and the Change Due banner. Purely
/// presentational: the entry buffer and the selected chip are owned by the
/// payment screen, so this widget has no state of its own to fall out of step
/// with the total.
class PosCashPanel extends StatelessWidget {
  /// What the operator has keyed in.
  final PosCashEntry entry;

  /// The sale total, in minor units.
  final int totalCents;

  /// Highlighted chip, or null after any manual keypad entry.
  final PosCashDenomination? selectedDenomination;

  final List<PosCashDenomination> denominations;

  final ValueChanged<PosCashDenomination> onDenomination;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  /// The field's own clear control. Wipes the amount rather than deleting one
  /// character — the keypad already owns per-character deletion, and a till
  /// needs a single "start over" that does not take six taps.
  final VoidCallback onClear;

  const PosCashPanel({
    super.key,
    required this.entry,
    required this.totalCents,
    required this.selectedDenomination,
    required this.onDenomination,
    required this.onKey,
    required this.onBackspace,
    required this.onClear,
    this.denominations = defaultDenominations,
  });

  /// Figma's row: €5 / €10 / €20 / €50 / Exact.
  static const List<PosCashDenomination> defaultDenominations = [
    PosCashDenomination.note(500),
    PosCashDenomination.note(1000),
    PosCashDenomination.note(2000),
    PosCashDenomination.note(5000),
    PosCashDenomination.exact(),
  ];

  int get _changeCents => entry.cents - totalCents;

  bool get _covered => entry.cents >= totalCents;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _AmountField(entry: entry, onClear: onClear),
        const SizedBox(height: PosPaymentSpec.cashPanelGap),
        _DenominationRow(
          denominations: denominations,
          selected: selectedDenomination,
          totalCents: totalCents,
          onSelect: onDenomination,
        ),
        const SizedBox(height: PosPaymentSpec.cashPanelGap),
        PosKeypad(
          rows: PosKeypad.digitRows(decimal: ','),
          style: posCashKeypadStyle(
            backspaceAsset: Images.posKeyBackspaceSvg,
          ),
          onKey: onKey,
          onBackspace: onBackspace,
        ),
        const SizedBox(height: PosPaymentSpec.paymentCardGap),
        _ChangeDueBanner(cents: _changeCents, covered: _covered),
      ],
    );
  }
}

/// `tendered-field` (1641:3831).
class _AmountField extends StatelessWidget {
  final PosCashEntry entry;
  final VoidCallback onClear;

  const _AmountField({required this.entry, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Amount Tendered',
          style: loewBold.copyWith(
            fontSize: PosPaymentSpec.cashFieldLabelSize,
            height: PosPaymentSpec.cashFieldLabelHeight,
            color:
                PosHomeSpec.inkAlpha(PosPaymentSpec.cashFieldLabelOpacity),
          ),
        ),
        const SizedBox(height: PosPaymentSpec.cashFieldLabelGap),
        Container(
          padding: const EdgeInsets.all(PosPaymentSpec.cashFieldPadding),
          decoration: BoxDecoration(
            color: PosHomeSpec.tileBg,
            borderRadius:
                BorderRadius.circular(PosPaymentSpec.cashFieldRadius),
            border: Border.all(
              color: PosHomeSpec.ink,
              width: PosPaymentSpec.cashFieldBorder,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  // Rendered through the app's own price formatter, so a
                  // tendered amount reads identically to every other price on
                  // the screen. The ',' key is an input affordance; it does not
                  // change how money is displayed.
                  PosHomeSpec.formatPrice(
                    posCentsToMoney(entry.cents,
                        decimals: entry.decimals),
                    padZero: false,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewExtraBold.copyWith(
                    fontSize: PosPaymentSpec.cashAmountSize,
                    height: PosPaymentSpec.cashAmountHeight,
                    color: PosHomeSpec.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _ClearButton(enabled: !entry.isEmpty, onTap: onClear),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClearButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _ClearButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Clear amount tendered',
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: PosPaymentSpec.cashClearIconSize,
            height: PosPaymentSpec.cashClearIconSize,
            child: SvgPicture.asset(
              Images.posFieldClearSvg,
              width: PosPaymentSpec.cashClearIconSize,
              height: PosPaymentSpec.cashClearIconSize,
              placeholderBuilder: (_) => Icon(
                Icons.backspace_outlined,
                size: PosPaymentSpec.cashClearIconSize,
                color: PosHomeSpec.inkAlpha(0.67),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `quick-denominations` (1641:3838).
class _DenominationRow extends StatelessWidget {
  final List<PosCashDenomination> denominations;
  final PosCashDenomination? selected;
  final int totalCents;
  final ValueChanged<PosCashDenomination> onSelect;

  const _DenominationRow({
    required this.denominations,
    required this.selected,
    required this.totalCents,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < denominations.length; i++) ...[
          if (i > 0) const SizedBox(width: PosPaymentSpec.denomGap),
          Expanded(
            child: _DenominationChip(
              denomination: denominations[i],
              active: selected == denominations[i],
              onTap: () => onSelect(denominations[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _DenominationChip extends StatelessWidget {
  final PosCashDenomination denomination;
  final bool active;
  final VoidCallback onTap;

  const _DenominationChip({
    required this.denomination,
    required this.active,
    required this.onTap,
  });

  /// `€ 5`, not `€ 5.00` — these name notes, so the cents would be noise.
  String get _label {
    if (denomination.exact) return 'Exact';
    final String priced = PosHomeSpec.formatPrice(
      posCentsToMoney(denomination.cents!),
    );
    return priced.replaceFirst(RegExp(r'[.,]\d+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.denomRadius);
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? PosHomeSpec.ink : PosHomeSpec.tileBg,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: PosPaymentSpec.denomPadding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: active ? PosHomeSpec.ink : PosHomeSpec.hairline,
                width: PosPaymentSpec.denomBorder,
              ),
            ),
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(
                fontSize: PosPaymentSpec.denomLabelSize,
                height: PosPaymentSpec.denomLabelHeight,
                color: active ? Colors.white : PosHomeSpec.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `change-due-banner` (1641:3879).
///
/// Figma draws only the covered state. When the tender is short the banner
/// stays in place but goes neutral and reads zero: a negative "change" is a
/// number no till should ever print, and blanking the row instead would make
/// the panel jump every time the amount crosses the total.
class _ChangeDueBanner extends StatelessWidget {
  final int cents;
  final bool covered;

  const _ChangeDueBanner({required this.cents, required this.covered});

  @override
  Widget build(BuildContext context) {
    final Color accent =
        covered ? PosHomeSpec.discountGreen : PosHomeSpec.inkAlpha(0.35);

    return Container(
      padding: const EdgeInsets.all(PosPaymentSpec.changeBannerPadding),
      decoration: BoxDecoration(
        color: covered
            ? PosPaymentSpec.changeBannerFill
            : PosHomeSpec.inkAlpha(0.03),
        borderRadius:
            BorderRadius.circular(PosPaymentSpec.changeBannerRadius),
        border: Border.all(
          color: covered ? PosHomeSpec.discountGreen : PosHomeSpec.hairline,
          width: PosPaymentSpec.changeBannerBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Change Due',
            style: loewBold.copyWith(
              fontSize: PosPaymentSpec.changeLabelSize,
              height: PosPaymentSpec.changeLabelHeight,
              color: accent,
            ),
          ),
          Text(
            PosHomeSpec.formatPrice(
              posCentsToMoney(covered ? cents : 0),
              padZero: false,
            ),
            style: loewExtraBold.copyWith(
              fontSize: PosPaymentSpec.changeValueSize,
              height: PosPaymentSpec.changeValueHeight,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
