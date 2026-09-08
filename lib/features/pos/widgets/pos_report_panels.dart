import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_widgets.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── Payment Methods ─────────────────────────────────────────────────────

/// `payment-methods-card` (Figma **1641:5518**).
///
/// Rows come from `payment_methods.methods[]`, which the backend builds with
/// `ZReportService::classifyPayment()`. That is deliberately NOT the Receipts
/// list's row-level `transaction_reference` / `bring_change_amount` heuristic:
/// two different derivations would let this screen and the Receipts screen
/// disagree about the same day, and the closed Z Report snapshot is built from
/// `classifyPayment` too.
///
/// Figma's third row is labelled "Other". The schema has no gift-card or
/// mobile-pay tender to put there — the real third bucket is Wallet, and it is
/// named honestly even when it is zero (Phase 1, Decision 5).
class PosReportPaymentMethodsPanel extends StatelessWidget {
  final PosReportData data;

  const PosReportPaymentMethodsPanel({super.key, required this.data});

  static const Map<String, String> _icons = <String, String>{
    'cash': Images.posBanknoteSvg,
    'card': Images.posCreditCardSvg,
    'wallet': Images.walletSvg,
  };

  static const Map<String, IconData> _fallbackIcons = <String, IconData>{
    'cash': Icons.payments_outlined,
    'card': Icons.credit_card_rounded,
    'wallet': Icons.account_balance_wallet_outlined,
  };

  static const Map<String, String> _labels = <String, String>{
    'cash': 'Cash',
    'card': 'PIN / Card',
    'wallet': 'Wallet',
  };

  @override
  Widget build(BuildContext context) {
    final List<PosReportPaymentRow> methods = data.paymentMethods;
    final int orders = data.paymentOrderCount;

    return PosReportCard(
      title: 'Payment Methods',
      trailing: Align(
        alignment: Alignment.centerRight,
        child: PosReportBadge('$orders order${orders == 1 ? '' : 's'}'),
      ),
      child: methods.isEmpty
          // "No payments" and "the payload didn't carry this section" both
          // render as an empty list, so `has_orders` decides which it is
          // instead of assuming the flattering one.
          ? (data.hasOrders
              ? const PosReportEmptyState(
                  message: 'Payment breakdown unavailable',
                  detail:
                      'This day has orders, but no payment split was returned '
                      'for it.',
                )
              : const PosReportEmptyState(
                  message: 'No payments taken',
                  detail: 'Nothing has been tendered on this day yet.',
                ))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < methods.length; i++) ...<Widget>[
                  if (i > 0)
                    SizedBox(height: posPx(context, PosReportSpec.panelListGap)),
                  _PaymentRow(
                    label: _labels[methods[i].key] ?? methods[i].label,
                    asset: _icons[methods[i].key],
                    fallback: _fallbackIcons[methods[i].key] ??
                        Icons.receipt_long_outlined,
                    row: methods[i],
                  ),
                ],
              ],
            ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String? asset;
  final IconData fallback;
  final PosReportPaymentRow row;

  const _PaymentRow({
    required this.label,
    required this.asset,
    required this.fallback,
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final double iconSize = posPx(context, PosReportSpec.paymentIconSize);

    return Container(
      height: posPx(context, PosReportSpec.paymentRowHeight),
      padding: EdgeInsets.all(posPx(context, PosReportSpec.paymentRowPadding)),
      decoration: BoxDecoration(
        color: PosReportSpec.rowFill,
        borderRadius:
            BorderRadius.circular(posPx(context, PosReportSpec.paymentRowRadius)),
        border: Border.all(color: PosReportSpec.cardBorder, width: 1),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: posPx(context, PosReportSpec.paymentIconBox),
            height: posPx(context, PosReportSpec.paymentIconBox),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosReportSpec.ink,
              borderRadius: BorderRadius.circular(
                posPx(context, PosReportSpec.paymentIconBoxRadius),
              ),
            ),
            child: asset == null
                ? Icon(fallback, size: iconSize, color: PosUI.pageBg)
                : SvgPicture.asset(
                    asset!,
                    width: iconSize,
                    height: iconSize,
                    colorFilter:
                        const ColorFilter.mode(PosUI.pageBg, BlendMode.srcIn),
                    placeholderBuilder: (_) =>
                        Icon(fallback, size: iconSize, color: PosUI.pageBg),
                  ),
          ),
          SizedBox(width: posPx(context, PosReportSpec.paymentRowGap)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: PosUI.text(
                    context,
                    size: PosReportSpec.paymentNameSize,
                    weight: FontWeight.w800,
                    color: PosReportSpec.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: posPx(context, 2)),
                Text(
                  '${row.orderCount} transaction${row.orderCount == 1 ? '' : 's'}',
                  style: PosUI.text(
                    context,
                    size: PosReportSpec.paymentSubSize,
                    weight: FontWeight.w400,
                    color: PosReportSpec.inkMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: posPx(context, 8)),
          Text(
            PosHomeSpec.formatPrice(row.amount, padZero: false),
            style: PosUI.text(
              context,
              size: PosReportSpec.paymentAmountSize,
              weight: FontWeight.w800,
              color: PosReportSpec.ink,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// ── Top Selling Products ────────────────────────────────────────────────

/// `top-products-card`. The leading row is the featured one — taller, with the
/// product thumbnail — exactly as drawn.
class PosReportTopProductsPanel extends StatelessWidget {
  final PosReportData data;

  /// Figma shows five. The endpoint returns ten so the panel can grow without
  /// a backend change.
  static const int maxRows = 5;

  const PosReportTopProductsPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final List<PosReportProductRow> rows =
        data.topProducts.take(maxRows).toList();

    return PosReportCard(
      title: 'Top Selling Products',
      child: !data.topProductsRecorded
          ? const PosReportEmptyState.notRecorded()
          : rows.isEmpty
              ? const PosReportEmptyState(
                  message: 'Nothing sold yet',
                  detail: 'Best sellers rank here once orders are fulfilled.',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PosReportTableHeader(
                      first: 'ITEM',
                      second: 'QTY SOLD',
                      third: 'REVENUE',
                      secondWidth: PosReportSpec.qtyColumnWidth,
                      thirdWidth: PosReportSpec.revenueColumnWidth,
                      padding: EdgeInsets.only(
                        left: posPx(context, 8),
                        right: posPx(context, 8),
                        bottom: posPx(context, 4),
                      ),
                    ),
                    for (int i = 0; i < rows.length; i++) ...<Widget>[
                      if (i > 0)
                        SizedBox(height: posPx(context, PosReportSpec.tableGap)),
                      _ProductRow(row: rows[i], featured: i == 0),
                    ],
                  ],
                ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final PosReportProductRow row;
  final bool featured;

  const _ProductRow({required this.row, required this.featured});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: posPx(
        context,
        featured
            ? PosReportSpec.featuredRowHeight
            : PosReportSpec.compactRowHeight,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: posPx(context, PosReportSpec.featuredRowPadding),
      ),
      decoration: BoxDecoration(
        color: PosReportSpec.rowFill,
        borderRadius: BorderRadius.circular(
          posPx(context, PosReportSpec.featuredRowRadius),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                if (featured) ...<Widget>[
                  _Thumb(url: row.imageUrl),
                  SizedBox(
                      width: posPx(context, PosReportSpec.featuredInfoGap)),
                ],
                Expanded(
                  child: Text(
                    row.name,
                    style: PosUI.text(
                      context,
                      size: PosReportSpec.tableRowSize,
                      weight: FontWeight.w700,
                      color: PosReportSpec.ink,
                    ),
                    maxLines: featured ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: posPx(context, 8)),
          SizedBox(
            width: posPx(context, PosReportSpec.qtyColumnWidth),
            child: Text(
              '${row.quantity} sold',
              textAlign: TextAlign.right,
              style: PosUI.text(
                context,
                size: PosReportSpec.tableRowSize,
                weight: FontWeight.w600,
                color: PosReportSpec.inkMuted,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(
            width: posPx(context, PosReportSpec.revenueColumnWidth),
            child: Text(
              PosHomeSpec.formatPrice(row.amount, padZero: false),
              textAlign: TextAlign.right,
              style: PosUI.text(
                context,
                size: PosReportSpec.tableRowSize,
                weight: FontWeight.w800,
                color: PosReportSpec.ink,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;

  const _Thumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final double w = posPx(context, PosReportSpec.featuredThumbWidth);
    final double h = posPx(context, PosReportSpec.featuredThumbHeight);
    final BorderRadius radius =
        BorderRadius.circular(posPx(context, PosReportSpec.featuredThumbRadius));

    // A product deleted since the sale still ranks, but has no image to load.
    if (url == null) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: PosReportSpec.barIdle,
          borderRadius: radius,
        ),
        child: Icon(
          Icons.local_cafe_outlined,
          size: posPx(context, 20),
          color: PosReportSpec.inkMuted,
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: CustomImageWidget(
        image: url!,
        width: w,
        height: h,
        fit: BoxFit.cover,
      ),
    );
  }
}

// ── Cash Drawer Summary ─────────────────────────────────────────────────

/// `cash-drawer-card`, in its reduced honest form (Phase 1, Decision 1).
///
/// Figma draws Opening float / Cash In / Cash Out / Expected / Actual count /
/// Difference. Only two of those are real today: cash taken, and cash handed
/// back on cancelled-but-paid orders. Full drawer reconciliation was
/// deliberately retired in migration `2026_08_06_000001` — there is no float
/// record, no paid-in/paid-out ledger and no counted-cash input anywhere in the
/// system, so Expected and Difference could only be fabricated.
///
/// The missing rows are named rather than dropped silently, so the panel reads
/// as "not tracked yet" instead of "the drawer balanced perfectly".
class PosReportCashDrawerPanel extends StatelessWidget {
  final PosReportData data;

  const PosReportCashDrawerPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return PosReportCard(
      title: 'Cash Drawer Summary',
      compactTitle: true,
      child: !data.cashRecorded
          ? const PosReportEmptyState.notRecorded()
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PosReportDetailRow(
                  label: 'Cash sales (${data.cashSalesCount})',
                  value: PosHomeSpec.formatPrice(data.cashSales, padZero: false),
                ),
                SizedBox(height: posPx(context, PosReportSpec.detailRowGap)),
                PosReportDetailRow(
                  label: 'Cash refunds (${data.cashRefundsCount})',
                  value: '−${PosHomeSpec.formatPrice(data.cashRefunds, padZero: false)}',
                  valueColor:
                      data.cashRefunds > 0 ? PosUI.danger : PosReportSpec.ink,
                ),
                SizedBox(height: posPx(context, PosReportSpec.cardInnerGap)),
                const PosReportEmptyState(
                  message: 'Drawer count not tracked',
                  detail:
                      'Opening float, expected total and counted cash need the '
                      'cash-reconciliation feature, which is not part of this '
                      'release.',
                ),
              ],
            ),
    );
  }
}

// ── Category Sales ──────────────────────────────────────────────────────

/// `category-sales-card` — the stacked bar plus its legend.
class PosReportCategorySalesPanel extends StatelessWidget {
  final PosReportData data;

  const PosReportCategorySalesPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final List<PosReportCategoryRow> rows = data.categorySales;
    final double total = data.categoryTotal;

    return PosReportCard(
      title: 'Category Sales',
      compactTitle: true,
      trailing: total > 0
          ? Align(
              alignment: Alignment.centerRight,
              child: PosReportBadge(
                'Total ${PosHomeSpec.formatPrice(total, padZero: false)}',
                textSize: PosReportSpec.tableHeaderSize,
              ),
            )
          : null,
      child: !data.categoryRecorded
          ? const PosReportEmptyState.notRecorded()
          : rows.isEmpty
              ? const PosReportEmptyState(
                  message: 'No category sales',
                  detail: 'Revenue splits by menu category once items sell.',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _StackedBar(rows: rows),
                    SizedBox(height: posPx(context, PosReportSpec.cardInnerGap)),
                    for (int i = 0; i < rows.length; i++) ...<Widget>[
                      if (i > 0)
                        SizedBox(
                            height: posPx(context, PosReportSpec.legendRowGap)),
                      _LegendRow(row: rows[i], index: i),
                    ],
                  ],
                ),
    );
  }
}

class _StackedBar extends StatelessWidget {
  final List<PosReportCategoryRow> rows;

  const _StackedBar({required this.rows});

  @override
  Widget build(BuildContext context) {
    // Flex weights rather than pixel widths, so the bar fills whatever the
    // card gives it at any window size and can never overflow its own row.
    // Weights are integers: a category rounding to 0 would vanish, so every
    // segment keeps a floor of 1.
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        posPx(context, PosReportSpec.stackedBarRadius),
      ),
      child: SizedBox(
        height: posPx(context, PosReportSpec.stackedBarHeight),
        child: Row(
          // stretch, not the default centre: a ColoredBox has no intrinsic
          // height, so under loose cross-axis constraints every segment
          // collapses to zero and the bar renders as nothing at all.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0)
                SizedBox(width: posPx(context, PosReportSpec.stackedBarGap)),
              Expanded(
                flex: (rows[i].percentage * 10).round().clamp(1, 1000),
                child: ColoredBox(
                  color: PosReportSpec.categoryColors[
                      i % PosReportSpec.categoryColors.length],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final PosReportCategoryRow row;
  final int index;

  const _LegendRow({required this.row, required this.index});

  @override
  Widget build(BuildContext context) {
    final double dot = posPx(context, PosReportSpec.legendDotSize);

    return Row(
      children: <Widget>[
        Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            color: PosReportSpec
                .categoryColors[index % PosReportSpec.categoryColors.length],
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: posPx(context, PosReportSpec.legendGap)),
        Expanded(
          child: Text(
            row.name,
            style: PosUI.text(
              context,
              size: PosReportSpec.detailRowSize,
              weight: FontWeight.w400,
              color: PosReportSpec.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: posPx(context, 8)),
        Text(
          '${PosHomeSpec.formatPrice(row.amount, padZero: false)} (${row.percentage.toStringAsFixed(0)}%)',
          style: PosUI.text(
            context,
            size: PosReportSpec.detailRowSize,
            weight: FontWeight.w600,
            color: PosReportSpec.ink,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

// ── Staff Shifts & Tips ─────────────────────────────────────────────────

/// `staff-tips-card`. The layout is complete; the rows are honestly empty.
///
/// There is no staff-attribution data anywhere in this system: no Employee,
/// Staff or Shift model, no cashier field on orders, and POS login is a single
/// 4-digit `devices.configuration_code` per *terminal* rather than per person.
/// So per-person Sales and Tips cannot be computed even approximately.
///
/// Per Phase 1 Decision 2 the panel ships visually complete with a stated gap
/// rather than with invented names — the staff-identity model is scoped as its
/// own feature.
class PosReportStaffTipsPanel extends StatelessWidget {
  final PosReportData data;

  const PosReportStaffTipsPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return PosReportCard(
      title: 'Staff Shifts & Tips',
      compactTitle: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PosReportTableHeader(
            first: 'NAME',
            second: 'SALES',
            third: 'TIPS',
            secondWidth: PosReportSpec.staffColumnWidth,
            thirdWidth: PosReportSpec.staffColumnWidth,
            padding: EdgeInsets.only(
              left: posPx(context, 4),
              right: posPx(context, 4),
              bottom: posPx(context, 2),
            ),
          ),
          SizedBox(height: posPx(context, PosReportSpec.tableGap)),
          const PosReportEmptyState(
            message: "Staff attribution isn't tracked yet",
            detail:
                'Orders record the terminal, not the person, so sales and tips '
                'cannot be split per staff member.',
          ),
          SizedBox(height: posPx(context, PosReportSpec.detailRowGap)),
          PosReportDetailRow(
            label: 'Tip pool (all staff)',
            value: PosHomeSpec.formatPrice(data.totalTips, padZero: false),
            valueWeight: FontWeight.w800,
          ),
        ],
      ),
    );
  }
}

// ── Refunds & Discounts ─────────────────────────────────────────────────

/// `refunds-discounts-card`.
///
/// There is no refund entity in this schema. The closest real analogue is a
/// cancelled order that had already been paid — `voided.approx_refund_value` —
/// which is what "Total refunds" reports.
class PosReportRefundsPanel extends StatelessWidget {
  final PosReportData data;

  const PosReportRefundsPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    String row(int count, double amount) =>
        '$count (${PosHomeSpec.formatPrice(amount, padZero: false)})';

    return PosReportCard(
      title: 'Refunds & Discounts',
      compactTitle: true,
      child: Padding(
        padding: EdgeInsets.only(top: posPx(context, 4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PosReportDetailRow(
              label: 'Total refunds',
              value: row(data.refundCount, data.refundValue),
              labelColor: PosReportSpec.ink,
              valueWeight: FontWeight.w800,
            ),
            SizedBox(height: posPx(context, PosReportSpec.refundRowGap)),
            PosReportDetailRow(
              label: 'Staff discounts',
              value: row(data.staffDiscountCount, data.staffDiscountValue),
              labelColor: PosReportSpec.ink,
              valueWeight: FontWeight.w800,
            ),
            SizedBox(height: posPx(context, PosReportSpec.refundRowGap)),
            PosReportDetailRow(
              label: 'Promo discounts',
              value: row(data.promoDiscountCount, data.promoDiscountValue),
              labelColor: PosReportSpec.ink,
              valueWeight: FontWeight.w800,
            ),
          ],
        ),
      ),
    );
  }
}
