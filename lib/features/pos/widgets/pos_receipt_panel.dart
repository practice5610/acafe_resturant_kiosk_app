import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// [PosOrderType] moved to `domain/` so [PosSaleSession] can hold it without
/// `domain/` depending on `widgets/`. Re-exported so every screen that already
/// imports this file for the enum keeps working.
export 'package:acafe_customer/features/pos/domain/pos_sale_session.dart'
    show PosOrderType;

/// Right pane: the sale in progress.
///
/// Header, order-type toggle, customer/table fields, the order list (or its
/// empty state), and the totals footer.
class PosReceiptPanel extends StatelessWidget {
  final String? orderNumber;
  final PosOrderType orderType;
  final ValueChanged<PosOrderType> onOrderTypeChanged;
  final TextEditingController customerNameController;
  final TextEditingController tableController;
  final double subtotal;
  final double discount;
  final double total;

  /// Order lines, or null/empty to show the empty state.
  final Widget? orderList;

  /// Fired with the ⋯ button's [BuildContext] so the caller can anchor a menu.
  final ValueChanged<BuildContext>? onOptions;
  final VoidCallback? onPay;

  /// When null, the panel expands to the parent's width (compact sheet).
  final double? width;

  const PosReceiptPanel({
    super.key,
    required this.orderType,
    required this.onOrderTypeChanged,
    required this.customerNameController,
    required this.tableController,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.orderNumber,
    this.orderList,
    this.onOptions,
    this.onPay,
    this.width = PosHomeSpec.receiptWidth,
  });

  bool get _hasItems => orderList != null;

  @override
  Widget build(BuildContext context) {
    final PosReceiptCustomerInfo customer = PosReceiptCustomerInfo(
      nameController: customerNameController,
      tableController: tableController,
      showBottomHairline: !_hasItems,
    );

    return Container(
      width: width,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: PosHomeSpec.panelBg,
        border: Border(
          left: BorderSide(color: Colors.black, width: PosHomeSpec.paneBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PosReceiptHeader(orderNumber: orderNumber, onOptions: onOptions),
          _OrderTypeToggle(
            selected: orderType,
            onChanged: onOrderTypeChanged,
          ),
          if (_hasItems) ...[
            customer,
            const PosReceiptOrderListLabel(),
          ] else ...[
            const PosReceiptOrderListLabel(),
            customer,
          ],
          Expanded(
            child: ClipRect(child: orderList ?? const PosReceiptEmptyState()),
          ),
          PosReceiptSummary(subtotal: subtotal, discount: discount, total: total),
          if (_hasItems) _PayButton(total: total, onPay: onPay),
        ],
      ),
    );
  }
}

class PosReceiptHeader extends StatelessWidget {
  final String? orderNumber;
  final ValueChanged<BuildContext>? onOptions;

  const PosReceiptHeader({super.key, this.orderNumber, this.onOptions});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosHomeSpec.headerHeight,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PosHomeSpec.panelPaddingH,
              PosHomeSpec.headerPaddingTop,
              PosHomeSpec.panelPaddingH,
              PosHomeSpec.headerPaddingBottom,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: PosHomeSpec.headerTitleSize *
                          PosHomeSpec.headerTitleHeight,
                      child: Text(
                        'Purchase Receipt',
                        style: loewExtraBold.copyWith(
                          fontSize: PosHomeSpec.headerTitleSize,
                          color: PosHomeSpec.ink,
                          height: PosHomeSpec.headerTitleHeight,
                        ),
                      ),
                    ),
                    const SizedBox(height: PosHomeSpec.headerTitleGap),
                    SizedBox(
                      height: PosHomeSpec.headerNumberSize *
                          PosHomeSpec.headerNumberHeight,
                      child: Text(
                        '#${orderNumber ?? PosHomeSpec.placeholderOrderNumber}',
                        style: swiss721Light.copyWith(
                          fontSize: PosHomeSpec.headerNumberSize,
                          color: PosHomeSpec.inkAlpha(0.53),
                          height: PosHomeSpec.headerNumberHeight,
                        ),
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (buttonContext) {
                    return Material(
                      color: PosHomeSpec.ink,
                      borderRadius: BorderRadius.circular(
                          PosHomeSpec.optionsButtonRadius),
                      child: InkWell(
                        onTap: onOptions == null
                            ? null
                            : () => onOptions!(buttonContext),
                        borderRadius: BorderRadius.circular(
                            PosHomeSpec.optionsButtonRadius),
                        child: Container(
                          width: PosHomeSpec.optionsButtonSize,
                          height: PosHomeSpec.optionsButtonSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                PosHomeSpec.optionsButtonRadius),
                            border: Border.all(color: PosHomeSpec.hairline),
                          ),
                          child: RotatedBox(
                            quarterTurns: 1,
                            child: SvgPicture.asset(
                              Images.posMoreVertSvg,
                              width: PosHomeSpec.optionsIconSize,
                              height: PosHomeSpec.optionsIconSize,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: PosHomeSpec.hairline,
              child: SizedBox(height: 1, width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTypeToggle extends StatelessWidget {
  final PosOrderType selected;
  final ValueChanged<PosOrderType> onChanged;

  const _OrderTypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosHomeSpec.orderTypeHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PosHomeSpec.panelPaddingH,
          PosHomeSpec.orderTypePaddingTop,
          PosHomeSpec.panelPaddingH,
          PosHomeSpec.orderTypePaddingBottom,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _OrderTypeButton(
                label: 'Dine In',
                active: selected == PosOrderType.dineIn,
                onTap: () => onChanged(PosOrderType.dineIn),
              ),
            ),
            const SizedBox(width: PosHomeSpec.orderTypeGap),
            Expanded(
              child: _OrderTypeButton(
                label: 'Take Away',
                active: selected == PosOrderType.takeAway,
                onTap: () => onChanged(PosOrderType.takeAway),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTypeButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _OrderTypeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? PosHomeSpec.ink : PosHomeSpec.inactiveFill,
      borderRadius: BorderRadius.circular(PosHomeSpec.orderTypeRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosHomeSpec.orderTypeRadius),
        child: SizedBox(
          height: PosHomeSpec.orderTypeButtonHeight,
          child: Center(
            child: Text(
              label,
              style: (active ? loewBold : loewMedium).copyWith(
                fontSize: PosHomeSpec.orderTypeLabelSize,
                color: active
                    ? PosHomeSpec.pageBg
                    : PosHomeSpec.inkAlpha(0.25),
                height: PosHomeSpec.orderTypeLabelHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PosReceiptOrderListLabel extends StatelessWidget {
  const PosReceiptOrderListLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosHomeSpec.orderListLabelBlockHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PosHomeSpec.panelPaddingH,
          0,
          PosHomeSpec.panelPaddingH,
          PosHomeSpec.orderListLabelPaddingBottom,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Order list',
            style: loewBold.copyWith(
              fontSize: PosHomeSpec.orderListLabelSize,
              color: PosHomeSpec.ink,
              height: PosHomeSpec.orderListLabelHeight,
            ),
          ),
        ),
      ),
    );
  }
}

class PosReceiptCustomerInfo extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController tableController;
  final bool showBottomHairline;

  const PosReceiptCustomerInfo({
    super.key,
    required this.nameController,
    required this.tableController,
    this.showBottomHairline = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosHomeSpec.customerInfoHeight,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PosHomeSpec.panelPaddingH,
              0,
              PosHomeSpec.panelPaddingH,
              PosHomeSpec.customerInfoPaddingBottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Field(
                    label: 'Customer name',
                    controller: nameController,
                    borderColor: PosHomeSpec.ink,
                  ),
                ),
                const SizedBox(width: PosHomeSpec.fieldGap),
                SizedBox(
                  width: PosHomeSpec.tableFieldWidth,
                  child: _Field(
                    label: 'Table',
                    controller: tableController,
                    borderColor: PosHomeSpec.tableFieldBorder,
                  ),
                ),
              ],
            ),
          ),
          if (showBottomHairline)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ColoredBox(
                color: PosHomeSpec.hairline,
                child: SizedBox(height: 1, width: double.infinity),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color borderColor;

  const _Field({
    required this.label,
    required this.controller,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: PosHomeSpec.fieldLabelSize * PosHomeSpec.fieldLabelHeight,
          child: Text(
            label,
            style: loewRegular.copyWith(
              fontSize: PosHomeSpec.fieldLabelSize,
              color: PosHomeSpec.inkAlpha(0.53),
              height: PosHomeSpec.fieldLabelHeight,
            ),
          ),
        ),
        const SizedBox(height: PosHomeSpec.fieldLabelGap),
        Container(
          height: PosHomeSpec.fieldInputHeight,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosHomeSpec.fieldRadius),
            border: Border.all(
              color: borderColor,
              width: PosHomeSpec.fieldBorder,
            ),
          ),
          child: TextField(
            controller: controller,
            cursorColor: PosHomeSpec.ink,
            textAlignVertical: TextAlignVertical.center,
            style: loewMedium.copyWith(
              fontSize: PosHomeSpec.fieldTextSize,
              color: PosHomeSpec.ink,
              height: PosHomeSpec.fieldTextHeight,
            ),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class PosReceiptEmptyState extends StatelessWidget {
  const PosReceiptEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PosHomeSpec.panelPaddingH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'No items',
            textAlign: TextAlign.center,
            style: loewExtraBold.copyWith(
              fontSize: PosHomeSpec.emptyHeadingSize,
              color: PosHomeSpec.ink,
              height: PosHomeSpec.emptyHeadingHeight,
            ),
          ),
          const SizedBox(height: PosHomeSpec.emptyStateGap),
          Text(
            'Add items to get started',
            textAlign: TextAlign.center,
            style: swiss721Light.copyWith(
              fontSize: PosHomeSpec.emptySublineSize,
              color: PosHomeSpec.inkAlpha(0.53),
              height: PosHomeSpec.emptySublineHeight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtotal / discount / total block.
///
/// Shared by the counter receipt panel and the payment screen's
/// `payment-details` (Figma 1641:2860): the two frames draw the same three
/// rows with the same type, and differ only in the chrome around them — the
/// panel pins the block to a fixed-height footer under a hairline, the payment
/// card lets it size to its content.
class PosReceiptSummary extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double total;

  /// Footer variant: fixed height and a hairline above. False sizes to content
  /// with no rule, as the payment card draws it.
  final bool pinned;

  const PosReceiptSummary({
    super.key,
    required this.subtotal,
    required this.discount,
    required this.total,
    this.pinned = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool showDiscount = discount > 0;
    return Container(
      height: pinned
          ? (showDiscount
              ? PosHomeSpec.summaryHeightWithDiscount
              : PosHomeSpec.summaryHeight)
          : null,
      padding: const EdgeInsets.fromLTRB(
        PosHomeSpec.panelPaddingH,
        PosHomeSpec.summaryPaddingTop,
        PosHomeSpec.panelPaddingH,
        0,
      ),
      decoration: pinned
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: PosHomeSpec.hairline)),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: PosHomeSpec.summaryRowSize * PosHomeSpec.summaryRowHeight,
            child: _SummaryRow(
              label: 'Subtotal',
              value: PosHomeSpec.formatPrice(subtotal),
            ),
          ),
          if (showDiscount) ...[
            const SizedBox(height: PosHomeSpec.summaryGap),
            SizedBox(
              height: PosHomeSpec.summaryRowSize * PosHomeSpec.summaryRowHeight,
            child: _SummaryRow(
              label: 'Discount',
              value: '- ${PosHomeSpec.formatPrice(discount)}',
              color: PosHomeSpec.discountGreen,
            ),
            ),
          ],
          const SizedBox(height: PosHomeSpec.summaryGap),
          const ColoredBox(
            color: PosHomeSpec.hairline,
            child: SizedBox(height: 1, width: double.infinity),
          ),
          const SizedBox(height: PosHomeSpec.summaryGap),
          SizedBox(
            height: PosHomeSpec.summaryTotalSize * PosHomeSpec.summaryTotalHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: loewExtraBold.copyWith(
                    fontSize: PosHomeSpec.summaryTotalSize,
                    color: PosHomeSpec.ink,
                    height: PosHomeSpec.summaryTotalHeight,
                  ),
                ),
                Text(
                  PosHomeSpec.formatPrice(total),
                  style: loewExtraBold.copyWith(
                    fontSize: PosHomeSpec.summaryTotalSize,
                    color: PosHomeSpec.ink,
                    height: PosHomeSpec.summaryTotalHeight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: swiss721Light.copyWith(
            fontSize: PosHomeSpec.summaryRowSize,
            color: color ?? PosHomeSpec.inkAlpha(0.6),
            height: PosHomeSpec.summaryRowHeight,
          ),
        ),
        Text(
          value,
          style: swiss721Light.copyWith(
            fontSize: PosHomeSpec.summaryRowSize,
            color: color ?? PosHomeSpec.ink,
            height: PosHomeSpec.summaryRowHeight,
          ),
        ),
      ],
    );
  }
}

class _PayButton extends StatelessWidget {
  final double total;
  final VoidCallback? onPay;

  const _PayButton({required this.total, this.onPay});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosHomeSpec.payPaddingH,
        PosHomeSpec.payGapAbove,
        PosHomeSpec.payPaddingH,
        PosHomeSpec.payPaddingBottom,
      ),
      child: Material(
        color: PosHomeSpec.ink,
        borderRadius: BorderRadius.circular(PosHomeSpec.payRadius),
        child: InkWell(
          onTap: onPay,
          borderRadius: BorderRadius.circular(PosHomeSpec.payRadius),
          child: SizedBox(
            height: PosHomeSpec.payHeight,
            width: double.infinity,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'PAY / ${PosHomeSpec.formatPrice(total)}',
                    maxLines: 1,
                    style: loewBold.copyWith(
                      fontSize: PosHomeSpec.payLabelSize,
                      color: Colors.white,
                      height: 22 / 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
