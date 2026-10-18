import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_builder.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_model.dart';
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
/// compact rows (py-10, gap-8) and the label gains its "· n OF m" count.
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

  /// Kept for callers; the screen's sticky bar owns the start action.
  final VoidCallback onStartPayment;
  final VoidCallback onAddTip;

  /// Groups recorded so far. Paid ones are listed as payment rows, and their
  /// items show as inert "Paid" rows (frame 16).
  final List<PosSplitByItemGroup> groups;

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
    required this.onStartPayment,
    required this.onAddTip,
    this.groups = const [],
  });

  /// Frames 14 / 16 lay three rows straight into the pane; frames 20 / 21 put
  /// six and ten into a 276px scroller. Four or more py-14 rows (≥ 288px)
  /// would no longer fit that space.
  static const int _maxInlineRows = 3;

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
        final double selectedAmount = builder.calculateAmount(lineItems);
        final double after = remaining - selectedAmount;

        Widget row(PosSplitByItemLineItem item) => _ItemRow(
              item: item,
              selected: builder.isSelected(item.id),
              paid: paidItemIds.contains(item.id),
              compact: scrolling,
              onTap: () => onToggleItem(item.id),
            );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                ),
              ],
              const SizedBox(height: gap),
              _SectionLabel(
                scrolling
                    ? 'SELECT ITEMS FOR PAYMENT $groupSeq'
                        ' · ${builder.selectedItemIds.length} OF ${lineItems.length}'
                    : 'SELECT ITEMS FOR PAYMENT $groupSeq',
              ),
              if (scrolling) ...[
                const SizedBox(height: gap),
                // items-scroll (1915:12647): 276 tall, gap-8, with a 4px
                // #B9B5A6 thumb 6.5px outside the rows' right edge.
                SizedBox(
                  height: PosPaymentSpec.v2SplitItemListHeight,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: _ItemScroller(
                      children: [
                        for (int i = 0; i < lineItems.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          row(lineItems[i]),
                        ],
                      ],
                    ),
                  ),
                ),
              ] else
                for (final item in lineItems) ...[
                  const SizedBox(height: gap),
                  row(item),
                ],
              const SizedBox(height: gap),
              const _SectionLabel('PAY WITH'),
              const SizedBox(height: gap),
              PosPayWithRow(
                method: paymentMethod,
                onChanged: onPaymentMethodChanged,
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
              PosPayTipRow(onTap: onAddTip),
            ],
          ),
        );
      },
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

/// "SELECT ITEMS FOR PAYMENT N" / "PAY WITH" — Loew Bold 11, `#78706E`.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: loewBold.copyWith(fontSize: 11, color: _labelInk),
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
  final VoidCallback onTap;

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
          if (paid) const _PaidPill() else _Checkbox(checked: on),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
                ),
                if (item.variant.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.variant,
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

/// 26px, r7: ink with a `#F0EBD9` tick when checked (node 1915:11244); white
/// with a 1.5px `#B9B5A6` stroke otherwise (node 1915:11258).
class _Checkbox extends StatelessWidget {
  final bool checked;

  const _Checkbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    if (checked) {
      return SvgPicture.string(_checkboxChecked, width: 26, height: 26);
    }
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: PosHomeSpec.tileBg,
        border: Border.all(color: PosHomeSpec.itemDivider, width: 1.5),
        borderRadius: BorderRadius.circular(7),
      ),
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
  final ValueChanged<PosPaymentMethod> onChanged;

  const PosPayWithRow({super.key, required this.method, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MethodButton(
          label: 'Card',
          asset: Images.posCreditCardSvg,
          active: method == PosPaymentMethod.card,
          onTap: () => onChanged(PosPaymentMethod.card),
        ),
        const SizedBox(width: PosPaymentSpec.payWithBtnGap),
        _MethodButton(
          label: 'Cash',
          asset: Images.posBanknoteSvg,
          active: method == PosPaymentMethod.cash,
          onTap: () => onChanged(PosPaymentMethod.cash),
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
  final VoidCallback onTap;

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

const String _checkboxChecked =
    '<svg width="26" height="26" viewBox="0 0 26 26" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="26" height="26" rx="7" fill="#241F20"/>'
    '<path d="M7.5 13L11.5 17L18.5 9" stroke="#F0EBD9" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';
