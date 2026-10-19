import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_customer_name_dialog.dart';
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
/// Header, customer/table fields, the order list (or its empty state), and the
/// totals footer. (The Dine In / Take Away toggle was removed from the UI in
/// the Browse-POS redesign; see the note in [build].)
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
          // The Dine In / Take Away toggle was removed from the UI in the
          // Browse-POS redesign. `orderType` / `onOrderTypeChanged` are retained
          // on the panel's API (callers still pass them, and PosSaleSession keeps
          // its default) so no order-writing path or API contract changes — the
          // value is simply no longer operator-selectable here.
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

  /// False drops the ⋯ button entirely rather than disabling it. A historical
  /// receipt (Figma 1641:3301) has no ⋯ at all — every action behind that menu
  /// edits a sale in progress, so on a settled one there is nothing to offer.
  /// Defaults true so the counter and payment screens are unchanged.
  final bool showOptions;

  const PosReceiptHeader({
    super.key,
    this.orderNumber,
    this.onOptions,
    this.showOptions = true,
  });

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
                if (showOptions)
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

  /// True renders both fields as display-only: same border, label and type as
  /// the editable pair, but no caret and no keyboard. A receipt in the history
  /// is a record — retyping the name on it would change nothing, so the field
  /// must not invite the attempt. Defaults false, so the live-sale screens keep
  /// their editable fields.
  final bool readOnly;

  /// Space above the field. The counter frame draws none; the payment layer's
  /// `customer-info` (Figma 1915:9361) is `py-16`, so it passes 16.
  final double paddingTop;

  /// Paint the field's 1.5px border inside the box, as the payment layer's
  /// `name-input` does (node 1915:9364: text 14px from the edge). Off by
  /// default, so the counter screen and Receipts keep today's field.
  final bool insideStroke;

  const PosReceiptCustomerInfo({
    super.key,
    required this.nameController,
    required this.tableController,
    this.showBottomHairline = true,
    this.readOnly = false,
    this.paddingTop = 0,
    this.insideStroke = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosHomeSpec.customerInfoHeight + paddingTop,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              PosHomeSpec.panelPaddingH,
              paddingTop,
              PosHomeSpec.panelPaddingH,
              PosHomeSpec.customerInfoPaddingBottom,
            ),
            // Full-width customer-name field. The Table field was removed in the
            // Browse-POS redesign (its controller is retained so the order
            // payload default is unchanged). Tapping the field opens the
            // "Who is this order for?" modal rather than editing inline.
            child: _NameTrigger(
              controller: nameController,
              readOnly: readOnly,
              insideStroke: insideStroke,
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

/// The receipt's customer-name field. Shows the entered name (or the
/// "Enter customer name" placeholder) and, when editable, opens the
/// "Who is this order for?" modal on tap (Figma 1915:15666 / 1915:15751).
/// A settled receipt ([readOnly]) shows the name as plain display text.
class _NameTrigger extends StatelessWidget {
  final TextEditingController controller;
  final bool readOnly;
  final bool insideStroke;

  const _NameTrigger({
    required this.controller,
    required this.readOnly,
    this.insideStroke = false,
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
            'Customer name',
            style: loewRegular.copyWith(
              fontSize: PosHomeSpec.fieldLabelSize,
              color: PosHomeSpec.inkAlpha(0.53),
              height: PosHomeSpec.fieldLabelHeight,
            ),
          ),
        ),
        const SizedBox(height: PosHomeSpec.fieldLabelGap),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final bool hasName = value.text.trim().isNotEmpty;
            final BoxDecoration border = BoxDecoration(
              borderRadius: BorderRadius.circular(PosHomeSpec.fieldRadius),
              border: Border.all(
                color: PosHomeSpec.ink,
                width: PosHomeSpec.fieldBorder,
              ),
            );
            final Widget field = Container(
              height: PosHomeSpec.fieldInputHeight,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: insideStroke ? null : border,
              foregroundDecoration: insideStroke ? border : null,
              child: Text(
                hasName ? value.text : 'Enter customer name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: loewMedium.copyWith(
                  fontSize: PosHomeSpec.fieldTextSize,
                  color:
                      hasName ? PosHomeSpec.ink : PosHomeSpec.inkAlpha(0.4),
                  height: PosHomeSpec.fieldTextHeight,
                ),
              ),
            );

            if (readOnly) return field;
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(PosHomeSpec.fieldRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(PosHomeSpec.fieldRadius),
                onTap: () => showPosCustomerNameDialog(
                  context: context,
                  controller: controller,
                ),
                child: field,
              ),
            );
          },
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

  /// A saved sale's tip, already inside [total]; drawn as its own row when
  /// above zero. The live cart never has one, so it stays three rows there.
  final double tip;
  final double total;

  /// Footer variant: fixed height and a hairline above. False sizes to content
  /// with no rule, as the payment card draws it.
  final bool pinned;

  /// Fitted density for the payment card's medium/laptop band. Unused (and
  /// left at full size) by the pinned receipt footer, which always has room.
  final PosPaymentDensity density;

  const PosReceiptSummary({
    super.key,
    required this.subtotal,
    required this.discount,
    this.tip = 0,
    required this.total,
    this.pinned = true,
    this.density = PosPaymentDensity.full,
  });

  @override
  Widget build(BuildContext context) {
    final bool showDiscount = discount > 0;
    final bool showTip = tip > 0;
    // Each optional row adds what the discount variant adds to the base.
    final int extraRows = (showDiscount ? 1 : 0) + (showTip ? 1 : 0);
    return Container(
      height: pinned
          ? PosHomeSpec.summaryHeight +
              extraRows *
                  (PosHomeSpec.summaryHeightWithDiscount -
                      PosHomeSpec.summaryHeight)
          : null,
      padding: EdgeInsets.fromLTRB(
        PosHomeSpec.panelPaddingH,
        pinned
            ? PosHomeSpec.summaryPaddingTop
            : density.px(PosHomeSpec.summaryPaddingTop),
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
            height: PosHomeSpec.summaryRowSize *
                PosHomeSpec.summaryRowHeight *
                density.textScale,
            child: _SummaryRow(
              label: 'Subtotal',
              value: PosHomeSpec.formatPrice(subtotal),
              density: density,
            ),
          ),
          if (showDiscount) ...[
            SizedBox(height: density.px(PosHomeSpec.summaryGap)),
            SizedBox(
              height: PosHomeSpec.summaryRowSize *
                  PosHomeSpec.summaryRowHeight *
                  density.textScale,
              child: _SummaryRow(
                label: 'Discount',
                value: '- ${PosHomeSpec.formatPrice(discount)}',
                color: PosHomeSpec.discountGreen,
                density: density,
              ),
            ),
          ],
          if (showTip) ...[
            SizedBox(height: density.px(PosHomeSpec.summaryGap)),
            SizedBox(
              height: PosHomeSpec.summaryRowSize *
                  PosHomeSpec.summaryRowHeight *
                  density.textScale,
              child: _SummaryRow(
                label: 'Tip',
                value: PosHomeSpec.formatPrice(tip),
                density: density,
              ),
            ),
          ],
          SizedBox(height: density.px(PosHomeSpec.summaryGap)),
          const ColoredBox(
            color: PosHomeSpec.hairline,
            child: SizedBox(height: 1, width: double.infinity),
          ),
          SizedBox(height: density.px(PosHomeSpec.summaryGap)),
          SizedBox(
            height: PosHomeSpec.summaryTotalSize *
                PosHomeSpec.summaryTotalHeight *
                density.textScale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: loewExtraBold.copyWith(
                    fontSize: density.text(PosHomeSpec.summaryTotalSize),
                    color: PosHomeSpec.ink,
                    height: PosHomeSpec.summaryTotalHeight,
                  ),
                ),
                Text(
                  PosHomeSpec.formatPrice(total),
                  style: loewExtraBold.copyWith(
                    fontSize: density.text(PosHomeSpec.summaryTotalSize),
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
  final PosPaymentDensity density;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.color,
    this.density = PosPaymentDensity.full,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: swiss721Light.copyWith(
            fontSize: density.text(PosHomeSpec.summaryRowSize),
            color: color ?? PosHomeSpec.inkAlpha(0.6),
            height: PosHomeSpec.summaryRowHeight,
          ),
        ),
        Text(
          value,
          style: swiss721Light.copyWith(
            fontSize: density.text(PosHomeSpec.summaryRowSize),
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

/// Never accepts focus — used by [PosReceiptCustomerInfo] in read-only mode so
/// a historical receipt's fields cannot show a caret.
class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;

  @override
  bool get canRequestFocus => false;
}
