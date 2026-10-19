import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_widgets.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── Revenue by Terminal (device breakdown) ────────────────────────────────

/// One row per POS/kiosk terminal registered to the branch, plus the trailing
/// `Web/App` bucket — from `device_breakdown.rows[]`. This is display-only:
/// the branch total above it is already summed across every device (see
/// `ZReportService::preview()`), this panel just shows the same total split
/// out per source so a manager can see which terminal is actually selling.
///
/// A horizontally-scrolling row of cards rather than a table: at most a
/// handful of terminals exist per branch, and a card reads at a glance
/// (name, revenue, count) faster than a table row would.
class PosReportDeviceBreakdownPanel extends StatelessWidget {
  final PosReportData data;

  const PosReportDeviceBreakdownPanel({super.key, required this.data});

  /// Reuses the existing category palette rather than introducing new
  /// colours — `categoryColors[0]` (near-black) for staffed counters,
  /// `categoryColors[4]` (tan/gold, closest to the brand secondary) for
  /// self-service kiosks, `categoryColors[5]` (grey-brown) for Web/App and
  /// any orphaned "Unknown device" row.
  static Color _accentFor(String category) {
    switch (category) {
      case 'pos':
        return PosReportSpec.categoryColors[0];
      case 'kiosk':
        return PosReportSpec.categoryColors[4];
      default:
        return PosReportSpec.categoryColors[5];
    }
  }

  static IconData _iconFor(String category) {
    switch (category) {
      case 'pos':
        return Icons.point_of_sale_rounded;
      case 'kiosk':
        return Icons.tablet_mac_rounded;
      case 'web_app':
        return Icons.language_rounded;
      default:
        return Icons.device_unknown_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<PosReportDeviceRow> rows = data.deviceBreakdown;
    final double total = data.deviceBreakdownTotal;

    return PosReportCard(
      title: 'Revenue by Terminal',
      trailing: total > 0
          ? Align(
              alignment: Alignment.centerRight,
              child: PosReportBadge(
                'Total ${PosHomeSpec.formatPrice(total, padZero: false)}',
              ),
            )
          : null,
      child: !data.deviceBreakdownRecorded
          ? const PosReportEmptyState.notRecorded()
          : rows.isEmpty
              ? const PosReportEmptyState(
                  message: 'No terminals registered',
                  detail: 'Revenue splits by terminal once devices are added '
                      'to this branch.',
                )
              : SizedBox(
                  height: posPx(context, PosReportSpec.deviceCardHeight),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(width: posPx(context, PosReportSpec.cardGap)),
                    itemBuilder: (BuildContext context, int i) =>
                        _DeviceCard(row: rows[i]),
                  ),
                ),
    );
  }
}

/// One terminal, drawn with the payment-row tokens (`#F7F1DE`, 1px
/// `#E1DBC4`, r12, 10 padding, dark 32px icon box) so the panel reads as part
/// of the Figma set it was added to. The per-type accent survives on the share
/// bar, where it carries meaning.
class _DeviceCard extends StatelessWidget {
  final PosReportDeviceRow row;

  const _DeviceCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final Color accent = PosReportDeviceBreakdownPanel._accentFor(row.category);
    final BorderRadius radius =
        BorderRadius.circular(posPx(context, PosReportSpec.paymentRowRadius));
    final double iconSize = posPx(context, PosReportSpec.paymentIconSize);

    return Container(
      width: posPx(context, PosReportSpec.deviceCardWidth),
      padding: EdgeInsets.all(posPx(context, PosReportSpec.paymentRowPadding)),
      decoration: BoxDecoration(
        color: PosReportSpec.rowFill,
        borderRadius: radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: PosReportSpec.cardBorder,
          width: PosReportSpec.hairlineWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
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
                child: Icon(
                  PosReportDeviceBreakdownPanel._iconFor(row.category),
                  size: iconSize,
                  color: PosReportSpec.solidBadgeText,
                ),
              ),
              SizedBox(width: posPx(context, PosReportSpec.inlineGap)),
              Expanded(
                child: Text(
                  row.name,
                  style: posReportText(
                    context,
                    size: PosReportSpec.paymentNameSize,
                    weight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                PosHomeSpec.formatPrice(row.amount, padZero: false),
                style: posReportText(
                  context,
                  size: PosReportSpec.paymentAmountSize,
                  weight: FontWeight.w800,
                ),
                maxLines: 1,
              ),
              SizedBox(height: posPx(context, PosReportSpec.paymentTextGap)),
              Text(
                '${row.orderCount} order${row.orderCount == 1 ? '' : 's'}'
                ' · avg ${PosHomeSpec.formatPrice(row.averageOrderValue, padZero: false)}',
                style: posReportText(
                  context,
                  size: PosReportSpec.paymentSubSize,
                  color: PosReportSpec.inkMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(
              posPx(context, PosReportSpec.deviceShareBarHeight),
            ),
            child: SizedBox(
              height: posPx(context, PosReportSpec.deviceShareBarHeight),
              child: Stack(
                children: <Widget>[
                  const ColoredBox(
                    color: PosReportSpec.barIdle,
                    child: SizedBox.expand(),
                  ),
                  FractionallySizedBox(
                    widthFactor: (row.percentage / 100).clamp(0, 1),
                    child: ColoredBox(
                      color: accent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Payment Methods ─────────────────────────────────────────────────────

/// `payment-methods-card` (Figma **1915:18155**).
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
    'card': 'PIN/Card',
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
        borderRadius: BorderRadius.circular(
            posPx(context, PosReportSpec.paymentRowRadius)),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            posPx(context, PosReportSpec.paymentRowRadius)),
        border: Border.all(
          color: PosReportSpec.cardBorder,
          width: PosReportSpec.hairlineWidth,
        ),
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
                  style: posReportText(
                    context,
                    size: PosReportSpec.paymentNameSize,
                    weight: FontWeight.w800,
                    color: PosReportSpec.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: posPx(context, PosReportSpec.paymentTextGap)),
                Text(
                  '${row.orderCount} transaction${row.orderCount == 1 ? '' : 's'}',
                  style: posReportText(
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
          SizedBox(width: posPx(context, PosReportSpec.paymentRowGap)),
          Text(
            PosHomeSpec.formatPrice(row.amount, padZero: false),
            style: posReportText(
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
                        left:
                            posPx(context, PosReportSpec.productHeaderPaddingH),
                        right:
                            posPx(context, PosReportSpec.productHeaderPaddingH),
                        bottom: posPx(
                            context, PosReportSpec.productHeaderPaddingBottom),
                      ),
                    ),
                    for (int i = 0; i < rows.length; i++) ...<Widget>[
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
                    style: posReportText(
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
          SizedBox(
            width: posPx(context, PosReportSpec.qtyColumnWidth),
            child: Text(
              '${row.quantity} sold',
              textAlign: TextAlign.right,
              style: posReportText(
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
              style: posReportText(
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
    // Picture-less device: show the same coffee-icon tile instead of the photo.
    if (url == null || !CustomImageWidget.showProductImages) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: PosReportSpec.barIdle,
          borderRadius: radius,
        ),
        child: Icon(
          Icons.local_cafe_outlined,
          size: posPx(context, PosReportSpec.thumbIconSize),
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

/// `cash-drawer-card` — Opening float / Cash In / Cash Out / Expected, plus
/// Actual count and Difference once the drawer has actually been counted.
///
/// The opening float is not an entry anyone makes: it is yesterday's counted
/// close carried forward (`ZReportService::openingFloatFor`), so Expected is a
/// real derived figure rather than a fabricated one.
///
/// Actual count and Difference appear **only** on a day that was counted
/// through Close Day. They are absent, never zero-filled, on an open day or a
/// close that skipped the count — a zeroed Difference reads as a balanced
/// drawer, which is a claim this panel has no right to make.
class PosReportCashDrawerPanel extends StatelessWidget {
  final PosReportData data;

  const PosReportCashDrawerPanel({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final double? counted = data.countedAmount;
    final double? difference = data.discrepancyAmount;

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
                  label: 'Opening float',
                  value: PosHomeSpec.formatPrice(data.openingFloat,
                      padZero: false),
                ),
                SizedBox(height: posPx(context, PosReportSpec.detailRowGap)),
                PosReportDetailRow(
                  label: 'Cash In (${data.cashSalesCount})',
                  value: PosHomeSpec.formatPrice(data.cashSales, padZero: false),
                ),
                SizedBox(height: posPx(context, PosReportSpec.detailRowGap)),
                PosReportDetailRow(
                  label: 'Cash Out (${data.cashRefundsCount} refunds)',
                  value:
                      '${PosReportSpec.minusSign}${PosHomeSpec.formatPrice(data.cashRefunds, padZero: false)}',
                ),
                SizedBox(height: posPx(context, PosReportSpec.detailRowGap)),
                const PosReportDivider(),
                SizedBox(height: posPx(context, PosReportSpec.detailRowGap)),
                PosReportDetailRow(
                  label: 'Expected in drawer',
                  labelWeight: FontWeight.w800,
                  labelColor: PosReportSpec.ink,
                  valueWeight: FontWeight.w800,
                  value: PosHomeSpec.formatPrice(data.expectedInDrawer,
                      padZero: false),
                ),
                if (counted != null) ...<Widget>[
                  SizedBox(height: posPx(context, PosReportSpec.detailRowGap)),
                  PosReportDetailRow(
                    label: 'Actual count',
                    value: PosHomeSpec.formatPrice(counted, padZero: false),
                  ),
                  if (difference != null) ...<Widget>[
                    SizedBox(
                        height: posPx(context, PosReportSpec.detailRowGap)),
                    _DifferenceRow(difference: difference),
                  ],
                ],
              ],
            ),
    );
  }
}

/// The `Difference` line. An off drawer sits in the red pill Figma draws; a
/// balanced one stays a plain row, since red would claim a problem.
class _DifferenceRow extends StatelessWidget {
  final double difference;

  const _DifferenceRow({required this.difference});

  @override
  Widget build(BuildContext context) {
    final bool off = difference.abs() >= 0.005;
    final Widget row = PosReportDetailRow(
      label: 'Difference',
      labelWeight: FontWeight.w700,
      labelColor: off ? PosReportSpec.negativeText : null,
      valueWeight: off ? FontWeight.w800 : FontWeight.w700,
      valueColor: off ? PosReportSpec.negativeText : null,
      value: difference < 0
          ? '${PosReportSpec.minusSign}${PosHomeSpec.formatPrice(difference.abs(), padZero: false)}'
          : PosHomeSpec.formatPrice(difference, padZero: false),
    );
    if (!off) return row;

    return Container(
      padding:
          EdgeInsets.all(posPx(context, PosReportSpec.differenceRowPadding)),
      decoration: BoxDecoration(
        color: PosReportSpec.negativeFill,
        borderRadius: BorderRadius.circular(
          posPx(context, PosReportSpec.differenceRowRadius),
        ),
      ),
      child: row,
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
            style: posReportText(
              context,
              size: PosReportSpec.detailRowSize,
              weight: FontWeight.w400,
              color: PosReportSpec.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: posPx(context, PosReportSpec.inlineGap)),
        Text(
          '${PosHomeSpec.formatPrice(row.amount, padZero: false)} (${row.percentage.toStringAsFixed(0)}%)',
          style: posReportText(
            context,
            size: PosReportSpec.detailRowSize,
            weight: FontWeight.w700,
            color: PosReportSpec.ink,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

// ── Staff Shifts & Tips ─────────────────────────────────────────────────

/// `staff-tips-card`. The roster is real now (Settings → Staff), but sales
/// and tips per person still are not.
///
/// [roster] comes from [PosStaffRepo]'s local cache, not the report API:
/// there is still no cashier/staff field on an order, and POS login is a
/// single 4-digit `devices.configuration_code` per *terminal* rather than per
/// person, so nothing on an order can be traced back to whoever rang it up.
/// What changed is that the team itself is no longer unknowable — an operator
/// can add real names in Settings → Staff, and this panel should show them
/// rather than a blanket "not tracked" message that was only ever true for
/// lack of a roster to draw on.
class PosReportStaffTipsPanel extends StatelessWidget {
  final PosReportData data;
  final PosStaffRoster roster;

  const PosReportStaffTipsPanel({
    super.key,
    required this.data,
    required this.roster,
  });

  @override
  Widget build(BuildContext context) {
    final List<PosStaffMember> team =
        roster.members.where((PosStaffMember m) => m.active).toList();

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
              left: posPx(context, PosReportSpec.staffHeaderPaddingH),
              right: posPx(context, PosReportSpec.staffHeaderPaddingH),
              bottom: posPx(context, PosReportSpec.staffHeaderPaddingBottom),
            ),
          ),
          SizedBox(height: posPx(context, PosReportSpec.tableGap)),
          if (team.isEmpty)
            const PosReportEmptyState(
              message: 'No staff added yet',
              detail: 'Add your team in Settings → Staff to see them here.',
            )
          else ...<Widget>[
            for (int i = 0; i < team.length; i++) ...<Widget>[
              if (i > 0) SizedBox(height: posPx(context, PosReportSpec.tableGap)),
              _StaffRow(member: team[i]),
            ],
            SizedBox(height: posPx(context, PosReportSpec.detailRowGap)),
            Text(
              "Orders record the terminal, not the person, so sales and "
              "tips can't be split per staff member yet.",
              style: posReportText(
                context,
                size: PosReportSpec.footnoteSize,
                weight: FontWeight.w500,
                color: PosReportSpec.inkMuted,
              ),
            ),
          ],
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

class _StaffRow extends StatelessWidget {
  final PosStaffMember member;

  const _StaffRow({required this.member});

  @override
  Widget build(BuildContext context) {
    // Figma's row is one line; the role rides beside the name rather than
    // under it so the row keeps that height.
    return Container(
      padding: EdgeInsets.all(posPx(context, PosReportSpec.staffRowPadding)),
      decoration: BoxDecoration(
        color: PosReportSpec.rowFill,
        borderRadius:
            BorderRadius.circular(posPx(context, PosReportSpec.staffRowRadius)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    member.name,
                    style: posReportText(
                      context,
                      size: PosReportSpec.detailRowSize,
                      weight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: posPx(context, PosReportSpec.legendGap)),
                Flexible(
                  child: Text(
                    member.role,
                    style: posReportText(
                      context,
                      size: PosReportSpec.paymentSubSize,
                      color: PosReportSpec.inkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: posPx(context, PosReportSpec.staffColumnWidth),
            child: Text(
              '—',
              textAlign: TextAlign.right,
              style: posReportText(
                context,
                size: PosReportSpec.detailRowSize,
                weight: FontWeight.w600,
                color: PosReportSpec.inkMuted,
              ),
            ),
          ),
          SizedBox(
            width: posPx(context, PosReportSpec.staffColumnWidth),
            child: Text(
              '—',
              textAlign: TextAlign.right,
              style: posReportText(
                context,
                size: PosReportSpec.detailRowSize,
                weight: FontWeight.w700,
              ),
            ),
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
    // Figma greys a line that has nothing in it (`0 (€ 0.00)`).
    Color valueColor(int count) =>
        count == 0 ? PosReportSpec.inkMuted : PosReportSpec.ink;

    return PosReportCard(
      title: 'Refunds & Discounts',
      compactTitle: true,
      child: Padding(
        padding: EdgeInsets.only(
            top: posPx(context, PosReportSpec.refundsPaddingTop)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PosReportDetailRow(
              label: 'Total refunds',
              value: row(data.refundCount, data.refundValue),
              labelColor: PosReportSpec.ink,
              valueWeight: FontWeight.w800,
              valueColor: valueColor(data.refundCount),
            ),
            SizedBox(height: posPx(context, PosReportSpec.refundRowGap)),
            PosReportDetailRow(
              label: 'Staff discounts',
              value: row(data.staffDiscountCount, data.staffDiscountValue),
              labelColor: PosReportSpec.ink,
              valueWeight: FontWeight.w800,
              valueColor: valueColor(data.staffDiscountCount),
            ),
            SizedBox(height: posPx(context, PosReportSpec.refundRowGap)),
            PosReportDetailRow(
              label: 'Promo discounts',
              value: row(data.promoDiscountCount, data.promoDiscountValue),
              labelColor: PosReportSpec.ink,
              valueWeight: FontWeight.w800,
              valueColor: valueColor(data.promoDiscountCount),
            ),
          ],
        ),
      ),
    );
  }
}
