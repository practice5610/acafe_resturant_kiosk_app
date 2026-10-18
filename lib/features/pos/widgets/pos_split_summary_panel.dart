import 'package:acafe_customer/features/pos/domain/pos_cash_denomination.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_cash_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_option_row.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_summary_panel.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The split chooser's options (frame 13).
enum PosSplitChoice { byItem, customAmount }

/// One payment already taken, as listed in a split pane.
@immutable
class PosSplitPaidRowData {
  final String label;
  final String subtitle;
  final double amount;

  /// Opens the refund of this one payment; null hides the Refund pill (the
  /// payment cannot be refunded — see [PosSplitPaidRow.onRefund]).
  final VoidCallback? onRefund;

  const PosSplitPaidRowData({
    required this.label,
    required this.subtitle,
    required this.amount,
    this.onRefund,
  });
}

/// The split entry pane — `Column/Right` (Figma **1915:10034**): frames 05 / 09
/// / 10 / 11 / 12 (split by payment), 19 (split by item → custom amount) and 15
/// (split by item → cash entry).
///
/// pt-24 px-20 pb-14, gap-8, top to bottom:
///  • SPLIT PAYMENT summary: header, 36px total, the Remaining bar
///  • one row per payment already taken (48 tall)
///  • the entry card ([entryLabel]) with its Card / Cash segmented control
///  • Cash only: Change Due (against [changeBaseCents]) and €5…Exact
///  • the 78px keypad and the tip row
///
/// The pane has no button of its own — the screen's sticky bar confirms. Draw
/// it on a [PosPayCard] with [borderColor] / [borderWidth].
class PosSplitSummaryPanel extends StatelessWidget {
  final double grandTotal;
  final double remaining;

  /// Payments already taken.
  final List<PosSplitPaidRowData> paid;

  /// "One amount at a time, …" (split by payment), "Enter the amount this
  /// guest pays" (custom amount, frame 19), "By item · …" (frame 15).
  final String subtitle;

  /// "PAYMENT 2", "GUEST 1 · CUSTOM AMOUNT", "PAYMENT 1 · AMOUNT DUE € 12.00".
  final String entryLabel;

  /// What the cash tender is measured against for Change Due: what is still
  /// owed (split by payment / custom amount) or the group's amount (frame 15).
  final int changeBaseCents;

  /// 61 / py-16 (frames 05, 19) or 48 / py-8 (frames 09–12, 15).
  final double tipRowHeight;

  /// The amount currently keyed in (cash: the tender).
  final PosCashEntry entry;

  /// Card or Cash for the current split.
  final PosPaymentMethod splitMethod;
  final ValueChanged<PosPaymentMethod> onSplitMethod;

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  /// Cash only: a denomination chip sets the amount (Exact = [changeBaseCents]).
  /// Null hides the row.
  final ValueChanged<PosCashDenomination>? onDenomination;
  final PosCashDenomination? selectedDenomination;

  /// The tip baked into this order when it was placed upfront. Shown as
  /// informational only — tipping is closed once the order is placed.
  final double tip;

  /// True when the pane owns a bounded height; the stack then scrolls inside
  /// it if the window is shorter than the frame.
  final bool fill;

  const PosSplitSummaryPanel({
    super.key,
    required this.grandTotal,
    required this.remaining,
    required this.paid,
    required this.subtitle,
    required this.entryLabel,
    required this.changeBaseCents,
    required this.tipRowHeight,
    required this.entry,
    required this.splitMethod,
    required this.onSplitMethod,
    required this.onKey,
    required this.onBackspace,
    this.onDenomination,
    this.selectedDenomination,
    this.tip = 0,
    this.fill = false,
  });

  /// Split by payment (frames 05, 09–12), from the backend's split state.
  factory PosSplitSummaryPanel.forPayments({
    Key? key,
    required PosSplitState state,
    required PosCashEntry entry,
    required PosPaymentMethod splitMethod,
    required ValueChanged<PosPaymentMethod> onSplitMethod,
    required ValueChanged<String> onKey,
    required VoidCallback onBackspace,
    ValueChanged<PosCashDenomination>? onDenomination,
    PosCashDenomination? selectedDenomination,
    double tip = 0,
    bool fill = false,
    bool customAmount = false,
    ValueChanged<PosSplitPayment>? onRefund,
  }) {
    return PosSplitSummaryPanel(
      key: key,
      grandTotal: state.grandTotal,
      remaining: state.fullyPaid ? 0 : state.remaining,
      paid: [
        for (final PosSplitPayment p in state.payments)
          PosSplitPaidRowData(
            label: customAmount ? 'Guest ${p.seq}' : 'Payment ${p.seq}',
            subtitle: p.paidWith == 'card'
                ? 'Card payment successful'
                : 'Cash payment successful',
            amount: p.paidAmount,
            onRefund: onRefund != null && p.refundable
                ? () => onRefund(p)
                : null,
          ),
      ],
      subtitle: customAmount
          ? 'Enter the amount this guest pays'
          : 'One amount at a time, the remainder follows automatically',
      entryLabel: customAmount
          ? 'GUEST ${state.nextSequence} · CUSTOM AMOUNT'
          : 'PAYMENT ${state.nextSequence}',
      changeBaseCents:
          posMoneyToCents(state.remaining, decimals: entry.decimals),
      // 61 before any payment is taken (frames 05, 19), 48 after (09–12).
      tipRowHeight: state.payments.isEmpty
          ? PosPaymentSpec.tipSectionHeight
          : PosPaymentSpec.v2SplitTipRowHeight,
      entry: entry,
      splitMethod: splitMethod,
      onSplitMethod: onSplitMethod,
      onKey: onKey,
      onBackspace: onBackspace,
      onDenomination: onDenomination,
      selectedDenomination: selectedDenomination,
      tip: tip,
      fill: fill,
    );
  }

  /// `Column/Right` stroke: `#E8E3D5` at 1.5px.
  static const Color borderColor = PosPaymentSpec.v2OtherRowBorder;
  static const double borderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final bool cash = splitMethod == PosPaymentMethod.cash;
    const double gap = PosPaymentSpec.v2SplitGap;

    final Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(
        PosPaymentSpec.v2SplitPanePaddingH,
        PosPaymentSpec.v2SplitPanePaddingTop,
        PosPaymentSpec.v2SplitPanePaddingH,
        PosPaymentSpec.v2SplitPanePaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PosSplitSummaryHeader(
            title: 'SPLIT PAYMENT',
            subtitle: subtitle,
            total: grandTotal,
            remaining: remaining,
          ),
          for (final PosSplitPaidRowData p in paid) ...[
            const SizedBox(height: gap),
            PosSplitPaidRow(
              label: p.label,
              subtitle: p.subtitle,
              amount: p.amount,
              onRefund: p.onRefund,
            ),
          ],
          const SizedBox(height: gap),
          _EntryCard(
            label: entryLabel,
            entry: entry,
            method: splitMethod,
            onMethod: onSplitMethod,
          ),
          if (cash && onDenomination != null) ...[
            const SizedBox(height: gap),
            PosPayChangeDueBanner(
              cents: entry.cents - changeBaseCents,
              covered: !entry.isEmpty && entry.cents >= changeBaseCents,
            ),
            const SizedBox(height: gap),
            PosPayDenominationRow(
              denominations: PosCashDenomination.defaults,
              selected: selectedDenomination,
              onSelect: onDenomination!,
            ),
          ],
          const SizedBox(height: gap),
          SizedBox(
            height: PosPaymentSpec.keypadHeight,
            child: PosKeypad(
              rows: PosKeypad.digitRows(decimal: ','),
              style: posPaymentKeypadStyle(
                  backspaceAsset: Images.posKeyBackspaceSvg),
              onKey: onKey,
              onBackspace: onBackspace,
            ),
          ),
          const SizedBox(height: gap),
          PosPayTipRow(amount: tip, onTap: null, height: tipRowHeight),
        ],
      ),
    );
    return fill ? SingleChildScrollView(child: body) : body;
  }
}

/// "Split by item" opens on this chooser — `Column/Right` of frame 13 (node
/// **1915:11077**): By item or Custom amount, before any order is placed.
///
/// pt-24 px-20 pb-14, gap-12: the SPLIT PAYMENT summary (nothing paid yet, so
/// Remaining is the whole total), "DIVIDE BETWEEN GUESTS" and the two p-16
/// option rows. The screen's sticky bar ("Continue") commits the choice.
class PosSplitChooserPanel extends StatelessWidget {
  final double grandTotal;
  final PosSplitChoice choice;
  final ValueChanged<PosSplitChoice> onChoice;

  /// True when the pane owns a bounded height (scrolls inside it).
  final bool fill;

  const PosSplitChooserPanel({
    super.key,
    required this.grandTotal,
    required this.choice,
    required this.onChoice,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    const double gap = PosPaymentSpec.v2SplitItemGap;
    const EdgeInsets optionPadding =
        EdgeInsets.all(PosPaymentSpec.v2ChooserOptionPadding);
    final Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(
        PosPaymentSpec.v2SplitPanePaddingH,
        PosPaymentSpec.v2SplitPanePaddingTop,
        PosPaymentSpec.v2SplitPanePaddingH,
        PosPaymentSpec.v2SplitPanePaddingBottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          PosSplitSummaryHeader(
            title: 'SPLIT PAYMENT',
            subtitle: 'Choose how to divide between guests',
            total: grandTotal,
            remaining: grandTotal,
          ),
          const SizedBox(height: gap),
          const PosPaySectionLabel('DIVIDE BETWEEN GUESTS'),
          const SizedBox(height: gap),
          PosPayOptionRow(
            label: 'By item',
            subtitle: 'Assign order items to each guest',
            selected: choice == PosSplitChoice.byItem,
            onTap: () => onChoice(PosSplitChoice.byItem),
            padding: optionPadding,
          ),
          const SizedBox(height: gap),
          PosPayOptionRow(
            label: 'Custom amount',
            subtitle: 'Enter any amount per guest',
            selected: choice == PosSplitChoice.customAmount,
            onTap: () => onChoice(PosSplitChoice.customAmount),
            padding: optionPadding,
          ),
        ],
      ),
    );
    return fill ? SingleChildScrollView(child: body) : body;
  }
}

// ── Summary ("Samenvatting", node 1915:10036) ──────────────────────────────

/// Header, 36px total and the Remaining bar — gap-7. Shared by the split by
/// payment and split by item panes.
class PosSplitSummaryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double total;
  final double remaining;

  /// The split-by-item item picker (frames 14 / 16 / 20) drops the Remaining
  /// bar; its own "… remaining after this payment" note carries it.
  final bool showRemaining;

  /// "Total to pay" / "Remaining" on the payment panes; the refund panes read
  /// "Refund amount" / "Order total" (node 1915:11436 / 11438).
  final String totalLabel;
  final String barLabel;

  /// Replaces the formatted [total] (the refund quote reads "—" until the
  /// backend's balance has loaded).
  final String? totalText;

  const PosSplitSummaryHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.total,
    required this.remaining,
    this.showRemaining = true,
    this.totalLabel = 'Total to pay',
    this.barLabel = 'Remaining',
    this.totalText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kop: gap-2.
        Text(
          title,
          style: loewBold.copyWith(
            fontSize: PosPaymentSpec.v2SplitHeaderSize,
            letterSpacing: PosPaymentSpec.v2SplitHeaderTracking,
            color: PosPaymentSpec.v2SplitLabelInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: swiss721Light.copyWith(
            fontSize: 10,
            height: PosPaymentSpec.figmaLeading(10),
            color: PosPaymentSpec.v2SplitSubtitleInk,
          ),
        ),
        const SizedBox(height: 7),
        // Totaal: gap-1, the total set `leading-none`.
        Text(
          totalText ?? PosHomeSpec.formatPrice(total, padZero: false),
          maxLines: 1,
          style: loewExtraBold.copyWith(
            fontSize: PosPaymentSpec.v2SplitTotalSize,
            height: 1,
            color: PosHomeSpec.ink,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          totalLabel,
          style: swiss721Light.copyWith(
            fontSize: 10,
            height: PosPaymentSpec.figmaLeading(10),
            color: PosPaymentSpec.v2SplitLabelInk,
          ),
        ),
        if (showRemaining) ...[
        const SizedBox(height: 7),
        // Nog te betalen: #F0EBD8, r8, px-10 py-6.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PosPaymentSpec.v2SplitRemainPaddingH,
            vertical: PosPaymentSpec.v2SplitRemainPaddingV,
          ),
          decoration: BoxDecoration(
            color: PosHomeSpec.hairline,
            borderRadius:
                BorderRadius.circular(PosPaymentSpec.v2SplitRemainRadius),
          ),
          child: Row(
            children: [
              Text(
                barLabel,
                style: loewBold.copyWith(
                  fontSize: PosPaymentSpec.v2SplitRemainLabelSize,
                  color: PosPaymentSpec.v2SplitLabelInk,
                ),
              ),
              const Spacer(),
              Text(
                PosHomeSpec.formatPrice(remaining, padZero: false),
                style: loewExtraBold.copyWith(
                  fontSize: PosPaymentSpec.v2SplitRemainAmountSize,
                  color: PosHomeSpec.ink,
                ),
              ),
            ],
          ),
        ),
        ],
      ],
    );
  }
}

// ── Paid payment row (node 1915:9775) ─────────────────────────────────────

/// One payment already taken: dial-pad well, "Payment N" over its status, the
/// amount and, for a refundable payment, the Refund pill. 48 tall, pl-20 pr-8
/// py-8, gap-10.
class PosSplitPaidRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final double amount;

  /// Starts the refund of this one payment. Null hides the pill — the row then
  /// ends on the amount, as when a payment cannot be refunded.
  final VoidCallback? onRefund;

  const PosSplitPaidRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.amount,
    this.onRefund,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PosPaymentSpec.v2SplitPaidRowHeight,
      padding: const EdgeInsets.fromLTRB(
        PosPaymentSpec.v2PaidRowPaddingLeft,
        PosPaymentSpec.v2PaidRowPaddingV,
        PosPaymentSpec.v2PaidRowPaddingRight,
        PosPaymentSpec.v2PaidRowPaddingV,
      ),
      child: Row(
        children: [
          PosPaySectionIcon(
            svg: _iconDialPad,
            glyphWidth: PosPaymentSpec.v2GlyphDialPad.width,
            glyphHeight: PosPaymentSpec.v2GlyphDialPad.height,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: loewBold.copyWith(fontSize: 12, color: PosHomeSpec.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: swiss721Light.copyWith(
                    fontSize: 10,
                    height: PosPaymentSpec.figmaLeading(10),
                    color: PosHomeSpec.inkAlpha(
                        PosPaymentSpec.v2MutedInkOpacity), // #8A94A6
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            PosHomeSpec.formatPrice(amount, padZero: false),
            style: loewBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
          ),
          if (onRefund != null) ...[
            const SizedBox(width: 10),
            _RefundPill(onTap: onRefund!),
          ],
        ],
      ),
    );
  }
}

/// `Actief` (node 1915:9783): black 85×24, r12, "Refund" Loew Bold 10
/// `#F7F1DE`, centred.
class _RefundPill extends StatelessWidget {
  final VoidCallback onTap;

  const _RefundPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.v2RefundPillRadius);
    return Semantics(
      button: true,
      label: 'Refund',
      child: Material(
        color: Colors.black,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            width: PosPaymentSpec.v2RefundPillWidth,
            height: PosPaymentSpec.v2RefundPillHeight,
            child: Center(
              child: Text(
                'Refund',
                style: loewBold.copyWith(
                  fontSize: PosPaymentSpec.v2RefundPillLabelSize,
                  color: PosHomeSpec.pageBg, // #F7F1DE
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Entry card ("Payment Card/Open", node 1915:10048) ─────────────────────

class _EntryCard extends StatelessWidget {
  final String label;
  final PosCashEntry entry;
  final PosPaymentMethod method;
  final ValueChanged<PosPaymentMethod> onMethod;

  const _EntryCard({
    required this.label,
    required this.entry,
    required this.method,
    required this.onMethod,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.v2SplitPaymentCardRadius);
    // 62 tall, white, r12, #E8E3D5 1.5px inside stroke; content 12 in.
    return Container(
      height: PosPaymentSpec.v2SplitEntryCardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: PosHomeSpec.tileBg, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: PosPaymentSpec.v2OtherRowBorder, width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(
                    fontSize: 10,
                    letterSpacing: PosPaymentSpec.v2SplitPaymentLabelTracking,
                    color: PosPaymentSpec.v2SplitLabelInk,
                  ),
                ),
                const SizedBox(height: 2),
                // `€  20` as typed; a caret while nothing is keyed in (`€  |`).
                Text(
                  '€  ${entry.isEmpty ? '|' : entry.raw}',
                  maxLines: 1,
                  style: loewExtraBold.copyWith(
                    fontSize: PosPaymentSpec.v2SplitPaymentAmountSize,
                    color: PosHomeSpec.ink,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: PosSplitMethodToggle(method: method, onMethod: onMethod),
          ),
        ],
      ),
    );
  }
}

// ── Card / Cash segmented control ("Betaalmethode", node 1915:10056) ─────

/// `#F0EBD8` track, p-3, r8, gap-2; each segment px-8 py-5, r6, a 12px icon
/// and a Loew Bold 10 label. The active segment is white with ink content;
/// the idle one is clear with `#A7A19A` content.
class PosSplitMethodToggle extends StatelessWidget {
  final PosPaymentMethod method;
  final ValueChanged<PosPaymentMethod> onMethod;

  const PosSplitMethodToggle({
    super.key,
    required this.method,
    required this.onMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PosPaymentSpec.v2SplitTogglePadding),
      decoration: BoxDecoration(
        color: PosHomeSpec.hairline,
        borderRadius: BorderRadius.circular(PosPaymentSpec.v2SplitToggleRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: 'Card',
            cash: false,
            active: method == PosPaymentMethod.card,
            onTap: () => onMethod(PosPaymentMethod.card),
          ),
          const SizedBox(width: 2),
          _Segment(
            label: 'Cash',
            cash: true,
            active: method == PosPaymentMethod.cash,
            onTap: () => onMethod(PosPaymentMethod.cash),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool cash;
  final bool active;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.cash,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color ink =
        active ? PosHomeSpec.ink : PosPaymentSpec.v2SplitSubtitleInk;
    final Widget icon = cash
        // bi:cash at 12 (glyph 12×7.5); the idle one is drawn at 45%.
        ? Opacity(
            opacity: active ? 1 : 0.45,
            child: SizedBox(
              width: 12,
              height: 12,
              child: Center(
                child: SvgPicture.string(_iconCash, width: 12, height: 7.5),
              ),
            ),
          )
        : SvgPicture.string(
            _iconCard,
            width: 12,
            height: 12,
            colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
          );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: active ? PosHomeSpec.tileBg : Colors.transparent,
          borderRadius:
              BorderRadius.circular(PosPaymentSpec.v2SplitToggleInnerRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 5),
            Text(
              label,
              style: loewBold.copyWith(
                fontSize: PosPaymentSpec.v2SplitToggleLabelSize,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Figma vectors, inlined (nodes 1915:9777 / 10058 / 10062) ──────────────

const String _iconCard =
    '<svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M0.9996 4.99989H11.0004M0.9996 4.99989V8.50029C0.9996 9.05263 1.44735 9.5004 1.99968 9.5004H10.0003C10.5526 9.5004 11.0004 9.05263 11.0004 8.50029V4.99989M0.9996 4.99989V3.49971C0.9996 2.94737 1.44735 2.4996 1.99968 2.4996H10.0003C10.5526 2.4996 11.0004 2.94737 11.0004 3.49971V4.99989" '
    'stroke="#241F20" stroke-linecap="round"/></svg>';

const String _iconCash =
    '<svg width="12" height="7.5" viewBox="0 0 12 7.5" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M6 5.25C6.39782 5.25 6.77936 5.09196 7.06066 4.81066C7.34196 4.52936 7.5 4.14782 7.5 3.75C7.5 3.35218 7.34196 2.97064 7.06066 2.68934C6.77936 2.40804 6.39782 2.25 6 2.25C5.60218 2.25 5.22064 2.40804 4.93934 2.68934C4.65804 2.97064 4.5 3.35218 4.5 3.75C4.5 4.14782 4.65804 4.52936 4.93934 4.81066C5.22064 5.09196 5.60218 5.25 6 5.25Z" fill="black"/>'
    '<path d="M0 0.75C0 0.551088 0.0790176 0.360322 0.21967 0.21967C0.360322 0.0790176 0.551088 0 0.75 0H11.25C11.4489 0 11.6397 0.0790176 11.7803 0.21967C11.921 0.360322 12 0.551088 12 0.75V6.75C12 6.94891 11.921 7.13968 11.7803 7.28033C11.6397 7.42098 11.4489 7.5 11.25 7.5H0.75C0.551088 7.5 0.360322 7.42098 0.21967 7.28033C0.0790176 7.13968 0 6.94891 0 6.75V0.75ZM2.25 0.75C2.25 1.14782 2.09196 1.52936 1.81066 1.81066C1.52936 2.09196 1.14782 2.25 0.75 2.25V5.25C1.14782 5.25 1.52936 5.40804 1.81066 5.68934C2.09196 5.97064 2.25 6.35218 2.25 6.75H9.75C9.75 6.35218 9.90804 5.97064 10.1893 5.68934C10.4706 5.40804 10.8522 5.25 11.25 5.25V2.25C10.8522 2.25 10.4706 2.09196 10.1893 1.81066C9.90804 1.52936 9.75 1.14782 9.75 0.75H2.25Z" fill="black"/>'
    '</svg>';

/// `streamline-ultimate:dial-pad-bold`, ink @0.6.
const String _iconDialPad =
    '<svg width="15" height="15" viewBox="0 0 15 15" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M0.98125 1.61875C0.98125 2.04807 1.1518 2.4598 1.45537 2.76338C1.75895 3.06695 2.17068 3.2375 2.6 3.2375C3.02932 3.2375 3.44105 3.06695 3.74463 2.76338C4.0482 2.4598 4.21875 2.04807 4.21875 1.61875C4.21875 1.40617 4.17688 1.19568 4.09553 0.999281C4.01418 0.802885 3.89494 0.624436 3.74463 0.474121C3.59431 0.323806 3.41586 0.20457 3.21947 0.12322C3.02307 0.0418702 2.81258 0 2.6 0C2.38742 0 2.17693 0.0418702 1.98053 0.12322C1.78414 0.20457 1.60569 0.323806 1.45537 0.474121C1.30506 0.624436 1.18582 0.802885 1.10447 0.999281C1.02312 1.19568 0.98125 1.40617 0.98125 1.61875ZM5.8625 1.61875C5.8625 1.83133 5.90437 2.04182 5.98572 2.23822C6.06707 2.43461 6.18631 2.61306 6.33662 2.76338C6.48694 2.91369 6.66539 3.03293 6.86178 3.11428C7.05818 3.19563 7.26867 3.2375 7.48125 3.2375C7.69383 3.2375 7.90432 3.19563 8.10072 3.11428C8.29711 3.03293 8.47556 2.91369 8.62588 2.76338C8.77619 2.61306 8.89543 2.43461 8.97678 2.23822C9.05813 2.04182 9.1 1.83133 9.1 1.61875C9.1 1.40617 9.05813 1.19568 8.97678 0.999281C8.89543 0.802885 8.77619 0.624436 8.62588 0.474121C8.47556 0.323806 8.29711 0.20457 8.10072 0.12322C7.90432 0.0418702 7.69383 0 7.48125 0C7.26867 0 7.05818 0.0418702 6.86178 0.12322C6.66539 0.20457 6.48694 0.323806 6.33662 0.474121C6.18631 0.624436 6.06707 0.802885 5.98572 0.999281C5.90437 1.19568 5.8625 1.40617 5.8625 1.61875ZM12.4 3.2375C12.7202 3.2375 13.0331 3.14256 13.2993 2.96469C13.5655 2.78682 13.773 2.53401 13.8955 2.23822C14.018 1.94243 14.0501 1.61695 13.9876 1.30295C13.9252 0.988941 13.771 0.700507 13.5446 0.474121C13.3182 0.247735 13.0298 0.0935637 12.7158 0.0311038C12.4018 -0.031356 12.0763 0.000700648 11.7805 0.12322C11.4847 0.245739 11.2319 0.453219 11.0541 0.719421C10.8762 0.985623 10.7813 1.29859 10.7813 1.61875C10.7813 2.04807 10.9518 2.4598 11.2554 2.76338C11.5589 3.06695 11.9707 3.2375 12.4 3.2375ZM2.6 3.91875C2.27984 3.91875 1.96687 4.01369 1.70067 4.19156C1.43447 4.36943 1.22699 4.62224 1.10447 4.91803C0.981951 5.21382 0.949894 5.5393 1.01235 5.8533C1.07481 6.16731 1.22898 6.45574 1.45537 6.68213C1.68176 6.90852 1.97019 7.06269 2.2842 7.12515C2.5982 7.18761 2.92368 7.15555 3.21947 7.03303C3.51526 6.91051 3.76807 6.70303 3.94594 6.43683C4.12381 6.17063 4.21875 5.85766 4.21875 5.5375C4.2171 5.10869 4.04603 4.69791 3.74281 4.39469C3.43959 4.09147 3.02881 3.9204 2.6 3.91875ZM7.5 3.91875C7.17984 3.91875 6.86687 4.01369 6.60067 4.19156C6.33447 4.36943 6.12699 4.62224 6.00447 4.91803C5.88195 5.21382 5.84989 5.5393 5.91235 5.8533C5.97481 6.16731 6.12898 6.45574 6.35537 6.68213C6.58176 6.90852 6.87019 7.06269 7.1842 7.12515C7.4982 7.18761 7.82368 7.15555 8.11947 7.03303C8.41526 6.91051 8.66807 6.70303 8.84594 6.43683C9.02381 6.17063 9.11875 5.85766 9.11875 5.5375C9.1171 5.10869 8.94603 4.69791 8.64281 4.39469C8.33959 4.09147 7.92881 3.9204 7.5 3.91875ZM12.4 3.91875C12.0798 3.91875 11.7669 4.01369 11.5007 4.19156C11.2345 4.36943 11.027 4.62224 10.9045 4.91803C10.782 5.21382 10.7499 5.5393 10.8124 5.8533C10.8748 6.16731 11.029 6.45574 11.2554 6.68213C11.4818 6.90852 11.7702 7.06269 12.0842 7.12515C12.3982 7.18761 12.7237 7.15555 13.0195 7.03303C13.3153 6.91051 13.5681 6.70303 13.7459 6.43683C13.9238 6.17063 14.0187 5.85766 14.0187 5.5375C14.0171 5.10869 13.846 4.69791 13.5428 4.39469C13.2396 4.09147 12.8288 3.9204 12.4 3.91875ZM2.6 7.84375C2.27984 7.84375 1.96687 7.93869 1.70067 8.11656C1.43447 8.29443 1.22699 8.54724 1.10447 8.84303C0.981951 9.13882 0.949894 9.4643 1.01235 9.7783C1.07481 10.0923 1.22898 10.3807 1.45537 10.6071C1.68176 10.8335 1.97019 10.9877 2.2842 11.0501C2.5982 11.1126 2.92368 11.0806 3.21947 10.958C3.51526 10.8355 3.76807 10.628 3.94594 10.3618C4.12381 10.0956 4.21875 9.78266 4.21875 9.4625C4.21875 9.03318 4.0482 8.62145 3.74463 8.31787C3.44105 8.0143 3.02932 7.84375 2.6 7.84375ZM7.5 7.84375C7.17984 7.84375 6.86687 7.93869 6.60067 8.11656C6.33447 8.29443 6.12699 8.54724 6.00447 8.84303C5.88195 9.13882 5.84989 9.4643 5.91235 9.7783C5.97481 10.0923 6.12898 10.3807 6.35537 10.6071C6.58176 10.8335 6.87019 10.9877 7.1842 11.0501C7.4982 11.1126 7.82368 11.0806 8.11947 10.958C8.41526 10.8355 8.66807 10.628 8.84594 10.3618C9.02381 10.0956 9.11875 9.78266 9.11875 9.4625C9.11875 9.03318 8.9482 8.62145 8.64463 8.31787C8.34105 8.0143 7.92932 7.84375 7.5 7.84375ZM5.8625 13.3813C5.8625 13.5938 5.90437 13.8043 5.98572 14.0007C6.06707 14.1971 6.18631 14.3756 6.33662 14.5259C6.48694 14.6762 6.66539 14.7954 6.86178 14.8768C7.05818 14.9581 7.26867 15 7.48125 15C7.69383 15 7.90432 14.9581 8.10072 14.8768C8.29711 14.7954 8.47556 14.6762 8.62588 14.5259C8.77619 14.3756 8.89543 14.1971 8.97678 14.0007C9.05813 13.8043 9.1 13.5938 9.1 13.3813C9.1 13.1687 9.05813 12.9582 8.97678 12.7618C8.89543 12.5654 8.77619 12.3869 8.62588 12.2366C8.47556 12.0863 8.29711 11.9671 8.10072 11.8857C7.90432 11.8044 7.69383 11.7625 7.48125 11.7625C7.26867 11.7625 7.05818 11.8044 6.86178 11.8857C6.66539 11.9671 6.48694 12.0863 6.33662 12.2366C6.18631 12.3869 6.06707 12.5654 5.98572 12.7618C5.90437 12.9582 5.8625 13.1687 5.8625 13.3813ZM12.4 7.84375C12.0798 7.84375 11.7669 7.93869 11.5007 8.11656C11.2345 8.29443 11.027 8.54724 10.9045 8.84303C10.782 9.13882 10.7499 9.4643 10.8124 9.7783C10.8748 10.0923 11.029 10.3807 11.2554 10.6071C11.4818 10.8335 11.7702 10.9877 12.0842 11.0501C12.3982 11.1126 12.7237 11.0806 13.0195 10.958C13.3153 10.8355 13.5681 10.628 13.7459 10.3618C13.9238 10.0956 14.0187 9.78266 14.0187 9.4625C14.0187 9.24992 13.9769 9.03943 13.8955 8.84303C13.8142 8.64664 13.6949 8.46819 13.5446 8.31787C13.3943 8.16756 13.2159 8.04832 13.0195 7.96697C12.8231 7.88562 12.6126 7.84375 12.4 7.84375Z" fill="#241F20" fill-opacity="0.6"/>'
    '</svg>';
