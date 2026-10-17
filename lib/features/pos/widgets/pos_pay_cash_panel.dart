import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_cash_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_summary_panel.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The payment-summary column for the **Cash** method — `payment-summary-card`
/// (Figma **1915:10234**, "POS payment" layer 1915:9314).
///
/// Same shell as the Card summary (amount header + inert tip row, reused from
/// [PosPaySummaryHeader] / [PosPayTipRow]) but the middle section is the cash
/// tender: the Amount Tendered field, a Change Due banner, the €5/€10/€20/€50/
/// Exact denomination row and the numeric keypad.
///
/// All wiring is the screen's existing cash path, unchanged — this widget owns
/// no state and only re-skins it to the new frame. The tip row is inert.
class PosPayCashSummaryPanel extends StatelessWidget {
  final double total;
  final PosCashEntry entry;
  final int totalCents;
  final PosCashDenomination? selectedDenomination;
  final ValueChanged<PosCashDenomination> onDenomination;
  final ValueChanged<String> onKey;
  final ValueChanged<String> onTyped;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  /// Tip applied, shown on the tip row. 0 = none.
  final double tip;

  /// Opens the tip modal. Null when tipping is disabled → the row is inert.
  final VoidCallback? onTipTap;

  /// When true the panel is inside a bounded pane (fill column). It uses a
  /// [LayoutBuilder] to scale the keypad so everything fits without scrolling.
  final bool fill;

  const PosPayCashSummaryPanel({
    super.key,
    required this.total,
    required this.entry,
    required this.totalCents,
    required this.selectedDenomination,
    required this.onDenomination,
    required this.onKey,
    required this.onTyped,
    required this.onBackspace,
    required this.onClear,
    this.tip = 0,
    this.onTipTap,
    this.fill = false,
  });

  // Natural keypad height: 4 rows × 78px + 3 gaps × 12px.
  static const double _kNaturalKeypad = 348.0;

  @override
  Widget build(BuildContext context) => fill ? _bodyFill() : _body();

  /// Non-fill: natural-height column.
  Widget _body() {
    const double gap = PosPaymentSpec.v2CashPanelGap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PosPaySummaryHeader(total: total, subtitle: 'Overview for partial payments'),
        const PosPaySummaryDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PosPaymentSpec.v2CashPanelPaddingH,
            vertical: PosPaymentSpec.v2CashPanelPaddingV,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TenderedField(entry: entry, onTyped: onTyped, onClear: onClear),
              const SizedBox(height: gap),
              _ChangeDueBanner(cents: entry.cents - totalCents, covered: entry.cents >= totalCents),
              const SizedBox(height: gap),
              _DenominationRow(denominations: PosCashPanel.defaultDenominations, selected: selectedDenomination, onSelect: onDenomination),
              const SizedBox(height: gap),
              PosKeypad(
                rows: PosKeypad.digitRows(decimal: ','),
                style: posCashKeypadStyleV2(backspaceAsset: Images.posKeyBackspaceSvg),
                onKey: onKey,
                onBackspace: onBackspace,
              ),
            ],
          ),
        ),
        const PosPaySummaryDivider(),
        PosPayTipRow(amount: tip, onTap: onTipTap),
      ],
    );
  }

  /// Fill mode: fixed fields above, keypad takes remaining slack via [Expanded].
  Widget _bodyFill() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        PosPaySummaryHeader(total: total, subtitle: 'Overview for partial payments', amountFontSize: 32),
        const PosPaySummaryDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PosPaymentSpec.v2CashPanelPaddingH,
            PosPaymentSpec.v2CashPanelPaddingV,
            PosPaymentSpec.v2CashPanelPaddingH,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TenderedField(entry: entry, onTyped: onTyped, onClear: onClear),
              const SizedBox(height: PosPaymentSpec.v2CashPanelGap),
              _ChangeDueBanner(cents: entry.cents - totalCents, covered: entry.cents >= totalCents),
              const SizedBox(height: PosPaymentSpec.v2CashPanelGap),
              _DenominationRow(denominations: PosCashPanel.defaultDenominations, selected: selectedDenomination, onSelect: onDenomination),
            ],
          ),
        ),
        const SizedBox(height: PosPaymentSpec.v2CashPanelGap),
        // Keypad takes all remaining space; scale = available / natural so the
        // keypad exactly fills whatever Expanded gives — no minimum clamp so it
        // never grows past its allocation and never overlaps the tip row.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PosPaymentSpec.v2CashPanelPaddingH),
            child: LayoutBuilder(
              builder: (context, c) {
                final double s = (c.maxHeight / _kNaturalKeypad).clamp(0.0, 1.0);
                return PosKeypad(
                  rows: PosKeypad.digitRows(decimal: ','),
                  style: posCashKeypadStyleV2(backspaceAsset: Images.posKeyBackspaceSvg),
                  scale: s,
                  onKey: onKey,
                  onBackspace: onBackspace,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: PosPaymentSpec.v2CashPanelPaddingV),
        const PosPaySummaryDivider(),
        PosPayTipRow(amount: tip, onTap: onTipTap),
      ],
    );
  }
}

/// `tendered-field` (node 1915:10245): label + a 2px-ink-bordered box carrying
/// the tendered amount and a clear control.
///
/// The box is a real text input, so a tap focuses it and a keyboard — physical
/// or the on-screen one on a tablet or phone — types straight into it. Typed
/// text is handed to [onTyped], which runs it through the same rules as the
/// keypad; the keypad writes back through [entry], which re-syncs the text.
class _TenderedField extends StatefulWidget {
  final PosCashEntry entry;
  final ValueChanged<String> onTyped;
  final VoidCallback onClear;

  const _TenderedField({
    required this.entry,
    required this.onTyped,
    required this.onClear,
  });

  @override
  State<_TenderedField> createState() => _TenderedFieldState();
}

class _TenderedFieldState extends State<_TenderedField> {
  late final TextEditingController _controller =
      TextEditingController(text: _displayFor(widget.entry));
  late final FocusNode _focus = FocusNode()..addListener(_sync);

  /// Editing shows the digits as typed; at rest it shows the formatted amount,
  /// the same way the keypad has always displayed it.
  String _displayFor(PosCashEntry entry) => _focus.hasFocus
      ? entry.raw
      : PosHomeSpec.formatPrice(
          posCentsToMoney(entry.cents, decimals: entry.decimals),
          padZero: false,
        );

  void _sync() {
    final String next = _displayFor(widget.entry);
    if (_controller.text == next) return;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  void didUpdateWidget(covariant _TenderedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle amountStyle = loewExtraBold.copyWith(
      fontSize: PosPaymentSpec.cashAmountSize, // 22
      color: PosHomeSpec.ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Amount Tendered',
          style: loewBold.copyWith(
            fontSize: PosPaymentSpec.cashFieldLabelSize, // 13
            color: PosHomeSpec.inkAlpha(PosPaymentSpec.cashFieldLabelOpacity),
          ),
        ),
        const SizedBox(height: PosPaymentSpec.cashFieldLabelGap), // 8
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PosPaymentSpec.cashFieldPadding,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: PosHomeSpec.tileBg,
            borderRadius:
                BorderRadius.circular(PosPaymentSpec.cashFieldRadius), // 12
            border: Border.all(
              color: PosHomeSpec.ink,
              width: PosPaymentSpec.cashFieldBorder, // 2
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: widget.onTyped,
                  style: amountStyle,
                  cursorColor: PosHomeSpec.ink,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintText: '0.00',
                    hintStyle: amountStyle.copyWith(
                      color: PosHomeSpec.inkAlpha(0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _ClearButton(enabled: !widget.entry.isEmpty, onTap: widget.onClear),
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
    const double size = PosPaymentSpec.cashClearIconSize; // 20
    return Semantics(
      button: true,
      label: 'Clear amount tendered',
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: size,
            height: size,
            child: SvgPicture.asset(
              Images.posFieldClearSvg,
              width: size,
              height: size,
              placeholderBuilder: (_) => Icon(
                Icons.backspace_outlined,
                size: size,
                color: PosHomeSpec.inkAlpha(0.67),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `change-due-banner` (node 1915:10252). Figma draws only the covered (green)
/// state; when the tender is short the banner stays in place but goes neutral
/// and reads zero — a negative "change" is a number no till should print, and
/// blanking the row would make the panel jump as the amount crosses the total.
class _ChangeDueBanner extends StatelessWidget {
  final int cents;
  final bool covered;

  const _ChangeDueBanner({required this.cents, required this.covered});

  @override
  Widget build(BuildContext context) {
    final Color accent =
        covered ? PosHomeSpec.discountGreen : PosHomeSpec.inkAlpha(0.35);
    return Container(
      padding: const EdgeInsets.all(PosPaymentSpec.changeBannerPadding), // 16
      decoration: BoxDecoration(
        color: covered
            ? PosPaymentSpec.changeBannerFill // #EBF9F1
            : PosHomeSpec.inkAlpha(0.03),
        borderRadius:
            BorderRadius.circular(PosPaymentSpec.changeBannerRadius), // 12
        border: Border.all(
          color: covered ? PosHomeSpec.discountGreen : PosHomeSpec.hairline,
          width: PosPaymentSpec.changeBannerBorder, // 1
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Change Due',
            style: loewBold.copyWith(
              fontSize: PosPaymentSpec.changeLabelSize, // 15
              color: accent,
            ),
          ),
          Text(
            PosHomeSpec.formatPrice(
              posCentsToMoney(covered ? cents : 0),
              padZero: false,
            ),
            style: loewExtraBold.copyWith(
              fontSize: PosPaymentSpec.changeValueSize, // 20
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// `quick-denominations` (node 1915:10255): €5 / €10 / €20 / €50 / Exact.
class _DenominationRow extends StatelessWidget {
  final List<PosCashDenomination> denominations;
  final PosCashDenomination? selected;
  final ValueChanged<PosCashDenomination> onSelect;

  const _DenominationRow({
    required this.denominations,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < denominations.length; i++) ...[
          if (i > 0) const SizedBox(width: PosPaymentSpec.denomGap), // 8
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
    final String priced =
        PosHomeSpec.formatPrice(posCentsToMoney(denomination.cents!));
    return priced.replaceFirst(RegExp(r'[.,]\d+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.denomRadius); // 10
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
            padding: const EdgeInsets.symmetric(
              horizontal: PosPaymentSpec.denomPaddingH, // 16
              vertical: PosPaymentSpec.denomPaddingV, // 12
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: active ? PosHomeSpec.ink : PosHomeSpec.hairline,
                width: PosPaymentSpec.denomBorder, // 1.5
              ),
            ),
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: loewBold.copyWith(
                fontSize: PosPaymentSpec.denomLabelSize, // 14
                color: active ? Colors.white : PosHomeSpec.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
