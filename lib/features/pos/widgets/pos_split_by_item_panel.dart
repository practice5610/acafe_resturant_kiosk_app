import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_builder.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_model.dart';
import 'package:acafe_customer/features/pos/widgets/pos_fit_column.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_option_row.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_summary_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_summary_panel.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _labelInk = Color(0xFF78706E);
const _rowBorder = Color(0xFFE8E3D6);
const _rowSelectedFill = Color(0xFFFBF7ED);
const _selectedTotalFill = Color(0xFFF0EBD9);
const _paidPillFill = Color(0xFFE0F2E5);

/// The right pane in split-by-item mode — `Column/Right` (Figma
/// **1915:11233**, frames 14 / 16 / 20 / 21).
///
/// pt-24 px-20 pb-14, gap-12: the SPLIT PAYMENT summary, the payments already
/// taken, "SELECT ITEMS FOR PAYMENT N", the item rows, PAY WITH, the selected
/// total, the remaining note and the tip row. Up to three items sit directly
/// in the pane (py-14 rows); a longer order scrolls them in a 276px list of
/// compact rows (py-10, gap-8) and the label gains its "· n OF m" count. Each
/// row carries the line's add-ons, else its unit, under the name (frame 21).
///
/// In a window shorter than the frame the item list gets shorter first, so
/// PAY WITH, the totals and the tip row stay on screen; below that the pane
/// scales down as a whole ([PosFitColumn]).
///
/// The pane has no button of its own — "Start Payment N · € X" is the screen's
/// sticky bar. Draw it on a [PosPayCard] with the split pane stroke
/// ([PosSplitSummaryPanel.borderColor]).
class PosSplitByItemPanel extends StatelessWidget {
  final int groupSeq;
  final double grandTotal;
  final double remaining;
  final List<PosSplitByItemLineItem> lineItems;
  final PosSplitByItemGroupsBuilder groupBuilder;
  final PosPaymentMethod paymentMethod;
  final ValueChanged<int> onToggleItem;
  final ValueChanged<PosPaymentMethod> onPaymentMethodChanged;

  /// Opens the tip modal while no guest has paid yet; null leaves the row
  /// inert (the tip is part of the order total once the order is placed).
  final VoidCallback? onAddTip;
  final double tip;

  /// What this payment charges for a pick — the guest's items plus their
  /// share of any order discount / tip; the last guest pays what is left.
  /// Defaults to the picked items' sum.
  final double Function(PosSplitByItemGroupBuilder pick)? amountOf;

  /// Groups recorded so far. Paid ones are listed as payment rows, and their
  /// items show as inert "Paid" rows (frame 16).
  final List<PosSplitByItemGroup> groups;

  /// Opens the refund of one paid group; only groups that can be refunded
  /// ([PosSplitByItemGroup.refundable]) get the Refund pill.
  final ValueChanged<PosSplitByItemGroup>? onRefund;

  /// A payment has been taken but not saved yet: the pick and method are
  /// what was charged, so rows and PAY WITH are inert.
  final bool locked;

  /// True when the pane owns a bounded height (see the class comment).
  final bool fill;

  const PosSplitByItemPanel({
    super.key,
    required this.groupSeq,
    required this.grandTotal,
    required this.remaining,
    required this.lineItems,
    required this.groupBuilder,
    required this.paymentMethod,
    required this.onToggleItem,
    required this.onPaymentMethodChanged,
    this.onAddTip,
    this.tip = 0,
    this.amountOf,
    this.groups = const [],
    this.onRefund,
    this.locked = false,
    this.fill = false,
  });

  /// Frames 14 / 16 lay three rows straight into the pane; frames 20 / 21 put
  /// six and ten into a 276px scroller. Four or more py-14 rows (≥ 288px)
  /// would no longer fit that space.
  static const int _maxInlineRows = 3;

  /// The scroller at its shortest: two compact rows and a bit of the third,
  /// so it still reads as a list.
  static const double _listMinHeight = 140;

  @override
  Widget build(BuildContext context) {
    final List<PosSplitByItemGroup> paid =
        groups.where((g) => g.paidAmount > 0).toList();
    final Set<int> paidItemIds = {for (final g in paid) ...g.itemIds};
    final bool scrolling = lineItems.length > _maxInlineRows;
    const double gap = PosPaymentSpec.v2SplitItemGap;

    return ValueListenableBuilder<PosSplitByItemGroupBuilder>(
      valueListenable: groupBuilder,
      builder: (context, builder, _) {
        final double selectedAmount =
            amountOf?.call(builder) ?? builder.calculateAmount(lineItems);
        final double after = remaining - selectedAmount;
        final int ticked = [
          for (final i in lineItems)
            if (builder.isSelected(i.id) && !paidItemIds.contains(i.id)) i,
        ].length;

        Widget row(PosSplitByItemLineItem item) => _ItemRow(
              item: item,
              selected: builder.isSelected(item.id),
              paid: paidItemIds.contains(item.id),
              compact: scrolling,
              onTap: locked ? null : () => onToggleItem(item.id),
            );

        final List<Widget> above = [
          PosSplitSummaryHeader(
            title: 'SPLIT PAYMENT',
            subtitle: 'Select items for this payment',
            total: grandTotal,
            remaining: remaining,
            showRemaining: false,
          ),
          for (final PosSplitByItemGroup g in paid) ...[
            const SizedBox(height: gap),
            PosSplitPaidRow(
              label: 'Payment ${g.seq}',
              subtitle: g.paidWith == 'card'
                  ? 'Card payment successful'
                  : 'Cash payment successful',
              amount: g.paidAmount,
              onRefund: onRefund != null && g.refundable
                  ? () => onRefund!(g)
                  : null,
            ),
          ],
          const SizedBox(height: gap),
          PosPaySectionLabel(
            scrolling
                ? 'SELECT ITEMS FOR PAYMENT $groupSeq'
                    ' · $ticked OF ${lineItems.length}'
                : 'SELECT ITEMS FOR PAYMENT $groupSeq',
          ),
          if (scrolling)
            const SizedBox(height: gap)
          else
            for (final item in lineItems) ...[
              const SizedBox(height: gap),
              row(item),
            ],
        ];
        // items-scroll (1915:12647): gap-8, with a 4px #B9B5A6 thumb 6.5px
        // outside the rows' right edge.
        final Widget list = ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: _ItemScroller(
            children: [
              for (int i = 0; i < lineItems.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                row(lineItems[i]),
              ],
            ],
          ),
        );
        final List<Widget> below = [
          const SizedBox(height: gap),
          const PosPaySectionLabel('PAY WITH'),
          const SizedBox(height: gap),
          PosPayWithRow(
            method: paymentMethod,
            onChanged: locked ? null : onPaymentMethodChanged,
          ),
          const SizedBox(height: gap),
          _SelectedTotal(amount: selectedAmount),
          const SizedBox(height: gap),
          Text(
            after <= 0.004
                ? 'Nothing remaining after this payment'
                : '${PosHomeSpec.formatPrice(after, padZero: false)} remaining after this payment',
            style: swiss721Light.copyWith(
              fontSize: 11,
              height: PosPaymentSpec.figmaLeading(11),
              color: _labelInk,
            ),
          ),
          const SizedBox(height: gap),
          PosPayTipRow(amount: tip, onTap: onAddTip),
        ];

        const EdgeInsets padding = EdgeInsets.fromLTRB(
          PosPaymentSpec.v2SplitPanePaddingH,
          PosPaymentSpec.v2SplitPanePaddingTop,
          PosPaymentSpec.v2SplitPanePaddingH,
          PosPaymentSpec.v2SplitPanePaddingBottom,
        );
        if (!fill) {
          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...above,
                if (scrolling)
                  SizedBox(
                    height: PosPaymentSpec.v2SplitItemListHeight,
                    child: list,
                  ),
                ...below,
              ],
            ),
          );
        }
        return Padding(
          padding: padding,
          child: PosFitColumn(
            flexIndex: scrolling ? above.length : null,
            flexMin: _listMinHeight,
            flexMax: PosPaymentSpec.v2SplitItemListHeight,
            children: [
              ...above,
              if (scrolling) list,
              ...below,
            ],
          ),
        );
      },
    );
  }
}

// ── Scroller with the frame's thumb ───────────────────────────────────────────

class _ItemScroller extends StatefulWidget {
  final List<Widget> children;

  const _ItemScroller({required this.children});

  @override
  State<_ItemScroller> createState() => _ItemScrollerState();
}

class _ItemScrollerState extends State<_ItemScroller> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The thumb sits in the pane's right padding, 6.5px clear of the rows:
    // the scroller is 10.5px wider than the rows and the rows keep that
    // margin free.
    const double overhang = 10.5;
    return LayoutBuilder(
      builder: (context, constraints) => OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: constraints.maxWidth + overhang,
        maxWidth: constraints.maxWidth + overhang,
        child: RawScrollbar(
          controller: _controller,
          thumbVisibility: true,
          thickness: 4,
          radius: const Radius.circular(2),
          thumbColor: PosHomeSpec.itemDivider, // #B9B5A6
          child: SingleChildScrollView(
            controller: _controller,
            padding: const EdgeInsets.only(right: overhang),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Item row (`item-select-row`, node 1915:11243) ─────────────────────────────

class _ItemRow extends StatelessWidget {
  final PosSplitByItemLineItem item;
  final bool selected;
  final bool paid;
  final bool compact;

  /// Null makes the row inert (a payment is waiting to be saved).
  final VoidCallback? onTap;

  const _ItemRow({
    required this.item,
    required this.selected,
    required this.paid,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool on = selected && !paid;
    // Strokes are part of this row's layout in the file (selected rows are
    // 64 / 40 tall, idle 63 / 39), so a regular border is right here.
    final Widget body = Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 10 : 14),
      decoration: BoxDecoration(
        color: on ? _rowSelectedFill : PosHomeSpec.tileBg,
        border: Border.all(
          color: on ? PosHomeSpec.ink : _rowBorder,
          width: on ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (paid) const _PaidPill() else PosPayCheckbox(checked: on),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
                ),
                if (item.detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: swiss721Light.copyWith(
                      fontSize: 11,
                      height: PosPaymentSpec.figmaLeading(11),
                      color: _labelInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            PosHomeSpec.formatPrice(item.price, padZero: false),
            style: loewExtraBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
          ),
        ],
      ),
    );
    // A paid item is a record, not a choice: 60% and not tappable.
    if (paid) return Opacity(opacity: 0.6, child: body);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}

/// `pill-Paid` (node 1915:12163): `#E0F2E5`, px-10 py-4, r12, Loew Bold 10
/// `#2A8456`.
class _PaidPill extends StatelessWidget {
  const _PaidPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _paidPillFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Paid',
        style: loewBold.copyWith(
          fontSize: 10,
          color: PosHomeSpec.discountGreen, // #2A8456
        ),
      ),
    );
  }
}

// ── Pay with row (`pay-with-buttons`, node 1915:11264) ───────────────────────

class PosPayWithRow extends StatelessWidget {
  final PosPaymentMethod method;

  /// Null makes both buttons inert.
  final ValueChanged<PosPaymentMethod>? onChanged;

  const PosPayWithRow({super.key, required this.method, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MethodButton(
          label: 'Card',
          asset: Images.posCreditCardSvg,
          active: method == PosPaymentMethod.card,
          onTap: onChanged == null
              ? null
              : () => onChanged!(PosPaymentMethod.card),
        ),
        const SizedBox(width: PosPaymentSpec.payWithBtnGap),
        _MethodButton(
          label: 'Cash',
          asset: Images.posBanknoteSvg,
          active: method == PosPaymentMethod.cash,
          onTap: onChanged == null
              ? null
              : () => onChanged!(PosPaymentMethod.cash),
        ),
      ],
    );
  }
}

/// 48 tall, r10, gap-8: an 18px icon and a Loew Bold 15 label. Active: ink
/// with a 1.5px ink stroke and white content; idle: white with a 1px
/// `#E8E3D6` stroke and ink content.
class _MethodButton extends StatelessWidget {
  final String label;
  final String asset;
  final bool active;
  final VoidCallback? onTap;

  const _MethodButton({
    required this.label,
    required this.asset,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color content = active ? Colors.white : PosHomeSpec.ink;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: PosPaymentSpec.payWithBtnHeight,
          decoration: BoxDecoration(
            color: active ? PosHomeSpec.ink : PosHomeSpec.tileBg,
            border: Border.all(
              color: active ? PosHomeSpec.ink : _rowBorder,
              width: active ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                asset,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(content, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: loewBold.copyWith(fontSize: 15, color: content),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Selected total (`selected-total`, node 1915:11273) ────────────────────────

class _SelectedTotal extends StatelessWidget {
  final double amount;

  const _SelectedTotal({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _selectedTotalFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Selected total',
            style: loewBold.copyWith(fontSize: 11, color: _labelInk),
          ),
          Text(
            PosHomeSpec.formatPrice(amount, padZero: false),
            style: loewExtraBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
          ),
        ],
      ),
    );
  }
}
