import 'package:acafe_customer/features/pos/domain/cash_change_calculator.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_denomination.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_denominations.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_summary_panel.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
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

  /// The quick-cash chips. The primary Cash pane feeds smart suggestions here
  /// (Exact + up to four values built from the amount due); split panes still
  /// pass the fixed [PosCashDenomination.defaults]. Defaulted so existing
  /// call sites keep the fixed row until they opt in.
  final List<PosCashDenomination> denominations;

  /// Notes and coins used to count change back, largest first (minor units).
  /// Only the primary Cash pane shows the breakdown line.
  final List<int> breakdownDenominations;

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

  /// When true the panel is inside a bounded pane (fill column). The keypad
  /// stays a fixed 348px; only the content above it scrolls if it overflows.
  final bool fill;

  const PosPayCashSummaryPanel({
    super.key,
    required this.total,
    required this.entry,
    required this.totalCents,
    this.denominations = PosCashDenomination.defaults,
    this.breakdownDenominations = PosCashDenominations.eurBreakdown,
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

  @override
  Widget build(BuildContext context) {
    // Figma's stack is 771px tall and the pane 834, so at the frame size it
    // sits at its natural height. A shorter pane scrolls the whole stack
    // rather than shrinking the type or the 78px keys.
    if (!fill) return _body();
    return SingleChildScrollView(child: _body());
  }

  /// `payment-summary-card` (1915:10234) top to bottom.
  Widget _body() {
    const double gap = PosPaymentSpec.v2CashTenderGap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Same header box as the Card pane (frame 01: 58px amount line,
        // pb-12) so "Amount due" does not move when switching methods — the
        // Cash frame's 47px line is overridden by design decision.
        PosPaySummaryHeader(
          total: total,
          subtitle: 'Overview for partial payments',
        ),
        // The frame stacks two 1px rules here (nodes 1915:10242 / 10243).
        const PosPaySummaryDivider(),
        const PosPaySummaryDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PosPaymentSpec.v2CashTenderPaddingH,
            vertical: PosPaymentSpec.v2CashTenderPaddingV,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TenderedField(entry: entry, onTyped: onTyped, onClear: onClear),
              const SizedBox(height: gap),
              _CashStatusSection(
                dueCents: totalCents,
                tenderedCents: entry.cents,
                breakdownDenominations: breakdownDenominations,
              ),
              const SizedBox(height: gap),
              PosPayDenominationRow(denominations: denominations, selected: selectedDenomination, onSelect: onDenomination),
              const SizedBox(height: gap),
              SizedBox(
                key: const Key('pad-box'),
                height: PosPaymentSpec.keypadHeight,
                child: PosKeypad(
                  rows: PosKeypad.digitRows(decimal: '.'),
                  style: posPaymentKeypadStyle(backspaceAsset: Images.posKeyBackspaceSvg),
                  onKey: onKey,
                  onBackspace: onBackspace,
                ),
              ),
            ],
          ),
        ),
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
        const SizedBox(height: PosPaymentSpec.cashFieldLabelGap),
        Container(
          // `amount-input-box` (1915:10247): 58 tall, p-16, 2px ink border.
          height: PosPaymentSpec.v2CashFieldHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: PosPaymentSpec.v2CashFieldPadding,
          ),
          alignment: Alignment.center,
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    hintText: '0.00',
                    hintStyle: amountStyle.copyWith(
                      color: TextTones.hint,
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
class PosPayChangeDueBanner extends StatelessWidget {
  final int cents;
  final bool covered;

  const PosPayChangeDueBanner(
      {super.key, required this.cents, required this.covered});

  @override
  Widget build(BuildContext context) {
    // Text colour for the "Change Due" label and amount.
    final Color accent = covered ? PosHomeSpec.discountGreen : TextTones.hint;
    return Container(
      key: const Key('change-due'),
      height: PosPaymentSpec.changeDueHeight,
      padding: const EdgeInsets.symmetric(horizontal: PosPaymentSpec.v2ChangeBannerPaddingH),
      decoration: BoxDecoration(
        color: covered
            ? PosPaymentSpec.changeBannerFill // #EBF9F1
            : PosHomeSpec.inkAlpha(0.03),
        borderRadius:
            BorderRadius.circular(PosPaymentSpec.changeBannerRadius), // 12
      ),
      // Figma strokes inside the box: the 1px line must not push the text
      // in (node 1915:11904 — "Change Due" sits 16 from the edge).
      foregroundDecoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(PosPaymentSpec.changeBannerRadius),
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

/// The live cash status for the **primary** Cash pane: a three-state banner
/// (Remaining / exact / Change Due) and, only while there is change to give, a
/// compact "Give back: …" breakdown line.
///
/// Everything here is a pure function of (due, tendered) via
/// [CashChangeCalculator] — nothing is stored (decision D1). The split panes
/// keep [PosPayChangeDueBanner] and are untouched.
class _CashStatusSection extends StatelessWidget {
  final int dueCents;
  final int tenderedCents;
  final List<int> breakdownDenominations;

  const _CashStatusSection({
    required this.dueCents,
    required this.tenderedCents,
    required this.breakdownDenominations,
  });

  static const CashChangeCalculator _calc = CashChangeCalculator();

  /// Formats a denomination like the chips do: the symbol and decimals follow
  /// the config (via [PosHomeSpec.formatPrice]), with a whole amount's `.00`
  /// trimmed so the line reads `€ 10 + € 5 + 2 × € 2 + € 0.50`.
  static String _money(int cents) {
    final String priced =
        PosHomeSpec.formatPrice(posCentsToMoney(cents), padZero: false);
    return priced.replaceFirst(RegExp(r'([.,])0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final CashStatus status = _calc.status(dueCents, tenderedCents);
    final bool isRemaining = status.kind == CashStatusKind.remaining;

    final List<Widget> children = [
      _CashStatusBanner(
        label: isRemaining ? 'Remaining' : 'Change Due',
        cents: status.amount,
        // Green for exact/change (unchanged from today); amber for a short
        // tender, using the theme's existing warning token (B4).
        accent: isRemaining ? TextTones.warning : PosHomeSpec.discountGreen,
        covered: !isRemaining,
      ),
    ];

    if (status.kind == CashStatusKind.change) {
      final List<CashBreakdownPart> parts =
          _calc.breakdown(status.amount, breakdownDenominations);
      if (parts.isNotEmpty) {
        final String line = parts
            .map((p) => p.count == 1
                ? _money(p.value)
                : '${p.count} × ${_money(p.value)}')
            .join(' + ');
        children
          ..add(const SizedBox(height: PosPaymentSpec.cashFieldLabelGap))
          ..add(Text(
            'Give back: $line',
            key: const Key('change-breakdown'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loewBold.copyWith(
              fontSize: PosPaymentSpec.cashFieldLabelSize, // 13
              color: TextTones.secondary,
            ),
          ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// The three-state banner. Same box as [PosPayChangeDueBanner] but the label,
/// amount and accent are driven in, so the primary pane can show "Remaining"
/// without changing the shared split banner.
class _CashStatusBanner extends StatelessWidget {
  final String label;
  final int cents;
  final Color accent;
  final bool covered;

  const _CashStatusBanner({
    required this.label,
    required this.cents,
    required this.accent,
    required this.covered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('change-due'),
      height: PosPaymentSpec.changeDueHeight,
      padding: const EdgeInsets.symmetric(
          horizontal: PosPaymentSpec.v2ChangeBannerPaddingH),
      decoration: BoxDecoration(
        color: covered
            ? PosPaymentSpec.changeBannerFill // #EBF9F1
            : PosHomeSpec.inkAlpha(0.03),
        borderRadius: BorderRadius.circular(PosPaymentSpec.changeBannerRadius),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PosPaymentSpec.changeBannerRadius),
        border: Border.all(
          color: covered ? PosHomeSpec.discountGreen : PosHomeSpec.hairline,
          width: PosPaymentSpec.changeBannerBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: loewBold.copyWith(
              fontSize: PosPaymentSpec.changeLabelSize,
              color: accent,
            ),
          ),
          Text(
            PosHomeSpec.formatPrice(posCentsToMoney(cents), padZero: false),
            style: loewExtraBold.copyWith(
              fontSize: PosPaymentSpec.changeValueSize,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// `quick-denominations` (node 1915:10255): €5 / €10 / €20 / €50 / Exact.
class PosPayDenominationRow extends StatelessWidget {
  final List<PosCashDenomination> denominations;
  final PosCashDenomination? selected;
  final ValueChanged<PosCashDenomination> onSelect;

  const PosPayDenominationRow({
    super.key,
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
            key: const Key('denom-chip'),
            height: PosPaymentSpec.denomBtnHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
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
