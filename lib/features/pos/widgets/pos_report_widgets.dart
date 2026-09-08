import 'package:acafe_customer/features/pos/domain/pos_report_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';

/// Shared building blocks for the Report Overview panels (Figma **1641:5518**).
///
/// Every panel on that screen is the same card: white fill, `#E1DBC4` hairline,
/// 16px radius, 16px padding, a title row, then content at a 12px rhythm. These
/// live in one place so the nine panels cannot drift apart.

/// A report panel. [trailing] is the pill on the right of the title row.
class PosReportCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final Widget child;

  /// Bottom-row panels title at 15px, middle-row panels at 16px.
  final bool compactTitle;

  const PosReportCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.compactTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(posPx(context, PosReportSpec.cardPadding)),
      decoration: BoxDecoration(
        color: PosUI.surface,
        borderRadius:
            BorderRadius.circular(posPx(context, PosReportSpec.cardRadius)),
        border: Border.all(color: PosReportSpec.cardBorder, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            SizedBox(
              height: posPx(context, PosReportSpec.panelTitleHeight),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title!,
                      style: PosUI.text(
                        context,
                        size: compactTitle
                            ? PosReportSpec.panelTitleSizeSmall
                            : PosReportSpec.panelTitleSize,
                        weight: FontWeight.w800,
                        color: PosReportSpec.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) ...<Widget>[
                    SizedBox(width: posPx(context, 8)),
                    Flexible(child: trailing!),
                  ],
                ],
              ),
            ),
            SizedBox(height: posPx(context, PosReportSpec.cardInnerGap)),
          ],
          child,
        ],
      ),
    );
  }
}

/// The pale rounded pill used for counts and contextual notes
/// (`148 orders`, `Peak: 12:00-13:00`, `32 pending prep`).
class PosReportBadge extends StatelessWidget {
  final String label;
  final double textSize;

  /// Filled dark, for the emphasis badges on the KPI cards.
  final bool solid;

  const PosReportBadge(
    this.label, {
    super.key,
    this.textSize = PosReportSpec.badgeTextSize,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: posPx(context, PosReportSpec.badgePaddingH),
        vertical: posPx(context, PosReportSpec.badgePaddingV),
      ),
      decoration: BoxDecoration(
        color: solid ? PosReportSpec.ink : PosReportSpec.rowFill,
        borderRadius:
            BorderRadius.circular(posPx(context, PosReportSpec.badgeRadius)),
        border: solid
            ? null
            : Border.all(color: PosReportSpec.cardBorder, width: 1),
      ),
      child: Text(
        label,
        style: PosUI.text(
          context,
          size: textSize,
          weight: FontWeight.w700,
          color: solid ? PosUI.pageBg : PosReportSpec.ink,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A `label ................ value` line. The label yields first so a long
/// category name truncates instead of pushing the amount off the card.
class PosReportDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final double size;
  final FontWeight valueWeight;
  final Color? valueColor;
  final FontWeight labelWeight;
  final Color? labelColor;

  const PosReportDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.size = PosReportSpec.detailRowSize,
    this.valueWeight = FontWeight.w700,
    this.valueColor,
    this.labelWeight = FontWeight.w400,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: PosUI.text(
              context,
              size: size,
              weight: labelWeight,
              color: labelColor ?? PosReportSpec.inkMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: posPx(context, 8)),
        Text(
          value,
          style: PosUI.text(
            context,
            size: size,
            weight: valueWeight,
            color: valueColor ?? PosReportSpec.ink,
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}

/// Column headings for the two tables (`ITEM / QTY SOLD / REVENUE`).
class PosReportTableHeader extends StatelessWidget {
  final String first;
  final String second;
  final String third;
  final double secondWidth;
  final double thirdWidth;
  final EdgeInsets padding;

  const PosReportTableHeader({
    super.key,
    required this.first,
    required this.second,
    required this.third,
    required this.secondWidth,
    required this.thirdWidth,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle style = PosUI.text(
      context,
      size: PosReportSpec.tableHeaderSize,
      weight: FontWeight.w700,
      color: PosReportSpec.inkMuted,
    );

    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(child: Text(first, style: style, maxLines: 1)),
          SizedBox(
            width: posPx(context, secondWidth),
            child: Text(second,
                style: style, textAlign: TextAlign.right, maxLines: 1),
          ),
          SizedBox(
            width: posPx(context, thirdWidth),
            child: Text(third,
                style: style, textAlign: TextAlign.right, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

/// What a panel shows when it has nothing truthful to draw.
///
/// Three genuinely different situations share this widget, and the copy has to
/// keep them apart — conflating them is how a dashboard starts lying:
///
///  * **empty** — the query ran and the day really had none of this.
///  * **not recorded** — the day was closed before this section was captured.
///    The data is gone, not zero.
///  * **not tracked** — the system has no such data at all, for any day
///    (staff attribution). Nothing about waiting or refreshing will help.
class PosReportEmptyState extends StatelessWidget {
  final String message;
  final String? detail;
  final double minHeight;

  const PosReportEmptyState({
    super.key,
    required this.message,
    this.detail,
    this.minHeight = 0,
  });

  /// A day closed before this section existed as a stored column.
  const PosReportEmptyState.notRecorded({Key? key, double minHeight = 0})
      : this(
          key: key,
          message: 'Not captured for this day',
          detail: 'This day was closed before this section was recorded.',
          minHeight: minHeight,
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: posPx(context, minHeight)),
      padding: EdgeInsets.symmetric(
        vertical: posPx(context, 16),
        horizontal: posPx(context, 12),
      ),
      decoration: BoxDecoration(
        color: PosReportSpec.rowFill,
        borderRadius: BorderRadius.circular(
          posPx(context, PosReportSpec.featuredRowRadius),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: PosUI.text(
              context,
              size: PosReportSpec.detailRowSize,
              weight: FontWeight.w700,
              color: PosReportSpec.ink,
            ),
          ),
          if (detail != null) ...<Widget>[
            SizedBox(height: posPx(context, 4)),
            Text(
              detail!,
              style: PosUI.text(
                context,
                size: PosReportSpec.paymentSubSize,
                weight: FontWeight.w400,
                color: PosReportSpec.inkMuted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
