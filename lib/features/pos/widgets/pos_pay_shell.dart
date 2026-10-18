import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Gives the "POS payment" layer Figma's `leading-normal` line boxes.
///
/// The app theme is Material 3, whose text styles carry explicit line heights
/// (`bodyMedium` 1.43, `bodyLarge` 1.5). Every `Text` without its own `height`
/// inherits one — directly, or via the `Material` that each `InkWell` / card
/// re-applies — so a 14px Loew label lays out 20px tall where Figma draws 17.
///
/// Below this scope the theme's text styles carry no `height`, so Loew falls
/// back to its own metrics, which equal Figma's "normal" leading at every size
/// the layer uses (10 → 12 … 48 → 58). Swiss 721 Light runs ~2px taller than
/// Figma by its own metrics, so its captions set [PosPaymentSpec.figmaLeading]
/// explicitly.
///
/// Wrap each route body and dialog root of the layer in this.
class PosPayTextScope extends StatelessWidget {
  final Widget child;

  const PosPayTextScope({super.key, required this.child});

  /// [style] with `height` dropped (TextStyle.copyWith cannot null a field).
  static TextStyle? _normal(TextStyle? style) {
    if (style == null) return null;
    return TextStyle(
      inherit: style.inherit,
      color: style.color,
      backgroundColor: style.backgroundColor,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      fontStyle: style.fontStyle,
      letterSpacing: style.letterSpacing,
      wordSpacing: style.wordSpacing,
      textBaseline: style.textBaseline,
      leadingDistribution: style.leadingDistribution,
      locale: style.locale,
      foreground: style.foreground,
      background: style.background,
      shadows: style.shadows,
      fontFeatures: style.fontFeatures,
      fontVariations: style.fontVariations,
      decoration: style.decoration,
      decorationColor: style.decorationColor,
      decorationStyle: style.decorationStyle,
      decorationThickness: style.decorationThickness,
      debugLabel: style.debugLabel,
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      overflow: style.overflow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme t = theme.textTheme;
    final TextTheme normal = TextTheme(
      displayLarge: _normal(t.displayLarge),
      displayMedium: _normal(t.displayMedium),
      displaySmall: _normal(t.displaySmall),
      headlineLarge: _normal(t.headlineLarge),
      headlineMedium: _normal(t.headlineMedium),
      headlineSmall: _normal(t.headlineSmall),
      titleLarge: _normal(t.titleLarge),
      titleMedium: _normal(t.titleMedium),
      titleSmall: _normal(t.titleSmall),
      bodyLarge: _normal(t.bodyLarge),
      bodyMedium: _normal(t.bodyMedium),
      bodySmall: _normal(t.bodySmall),
      labelLarge: _normal(t.labelLarge),
      labelMedium: _normal(t.labelMedium),
      labelSmall: _normal(t.labelSmall),
    );
    return Theme(
      data: theme.copyWith(textTheme: normal),
      child: DefaultTextStyle(
        style: normal.bodyMedium ?? const TextStyle(),
        child: child,
      ),
    );
  }
}

/// The redesigned payment screen's content shell — `content-area`
/// (Figma **1915:9352**, "POS payment" layer 1915:9314).
///
/// Three panes: a receipt sidebar, a payment-method column and a flexible
/// payment-summary column, `gap-20`, `px-32`. The two left panes are fixed in
/// the file (440 / 370 at 1366 wide); here they are expressed as a **ratio of
/// the window** so they move continuously with it rather than pinning to
/// literal pixels — the same approach [PosResponsive] already uses for the
/// Home side panes. The summary pane takes the remainder.
///
/// Structure, not density: at/above [PosResponsive.desktopFloor] the three
/// panes sit side by side with their own internal scrolling; below it (a staff
/// tablet, a half-width browser) they stack into one scroll. Each pane builder
/// is handed [fill] — `true` when the pane owns a bounded height and may let
/// its own content scroll, `false` when it sizes to its content inside the
/// stacked list.
class PosPayThreePane extends StatelessWidget {
  final Widget Function(bool fill) receipt;
  final Widget Function(bool fill) method;
  final Widget Function(bool fill) summary;

  const PosPayThreePane({
    super.key,
    required this.receipt,
    required this.method,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;

        double receiptW = w * PosPaymentSpec.v2ReceiptPaneRatio;
        double methodW = w * PosPaymentSpec.v2MethodPaneRatio;
        if (receiptW < PosPaymentSpec.v2ReceiptPaneMin) {
          receiptW = PosPaymentSpec.v2ReceiptPaneMin;
        }
        if (methodW < PosPaymentSpec.v2MethodPaneMin) {
          methodW = PosPaymentSpec.v2MethodPaneMin;
        }

        const double gutters = PosPaymentSpec.v2ContentPaddingH * 2 +
            PosPaymentSpec.v2ContentGap * 2;
        final double summaryW = w - gutters - receiptW - methodW;

        // Side by side only while all three panes clear their floor. Below the
        // desktop floor, or when the summary would be starved, stack instead —
        // never shrink a column past legibility.
        final bool sideBySide = w >= PosResponsive.desktopFloor &&
            summaryW >= PosPaymentSpec.v2SummaryPaneMin;

        if (sideBySide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              PosPaymentSpec.v2ContentPaddingH,
              0,
              PosPaymentSpec.v2ContentPaddingH,
              PosPaymentSpec.v2ContentPaddingBottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: receiptW, child: receipt(true)),
                const SizedBox(width: PosPaymentSpec.v2ContentGap),
                SizedBox(width: methodW, child: method(true)),
                const SizedBox(width: PosPaymentSpec.v2ContentGap),
                Expanded(child: summary(true)),
              ],
            ),
          );
        }

        // Stacked band. A ListView (not a full-screen SingleChildScrollView)
        // scrolls the three cards; each sizes to its content.
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            PosPaymentSpec.v2ContentPaddingH,
            0,
            PosPaymentSpec.v2ContentPaddingH,
            PosPaymentSpec.v2ContentPaddingH,
          ),
          children: [
            receipt(false),
            const SizedBox(height: PosPaymentSpec.v2ContentGap),
            method(false),
            const SizedBox(height: PosPaymentSpec.v2ContentGap),
            summary(false),
          ],
        );
      },
    );
  }
}

/// The rounded panel a pane is drawn on. The receipt and method columns use the
/// `#F0EBD8` hairline at 1.5px (node 1915:9353 / 9420); the summary column uses
/// the warmer `#E8E0CC` at 1px (node 1915:9475). [summaryBorder] picks between
/// them.
class PosPayCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool summaryBorder;

  /// Explicit stroke, for panes the file draws in neither style — the split
  /// panes (`Column/Right`, node 1915:10034) use `#E8E3D5` at 1.5px.
  final Color? borderColor;
  final double? borderWidth;

  const PosPayCard({
    super.key,
    required this.child,
    this.padding,
    this.summaryBorder = false,
    this.borderColor,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.v2CardRadius);
    // Figma strokes sit inside the frame and do not move its content, so the
    // border is painted over the child rather than insetting it the way a
    // Container border would (content would otherwise land 1–1.5px off).
    return Container(
      padding: padding,
      clipBehavior: padding == null ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: PosHomeSpec.panelBg,
        borderRadius: radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: borderColor ??
              (summaryBorder
                  ? PosPaymentSpec.v2SummaryBorder
                  : PosHomeSpec.hairline),
          width: borderWidth ??
              (summaryBorder
                  ? PosPaymentSpec.v2OtherRowBorderWidth // 1px
                  : PosPaymentSpec.cardBorder), // 1.5px
        ),
      ),
      child: child,
    );
  }
}

/// `sticky-bottom-bar` + `pay-btn-inner` (Figma **1915:9516 / 9517**): a
/// hairline-and-shadow strip carrying one full-width pill. Replaces the old
/// fixed-width compact Confirm button.
///
/// A null [onConfirm] renders the disabled state (the pill dimmed, inert),
/// which is the state the screen already drives for an empty cart or a short
/// cash tender.
class PosPayPillBar extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onConfirm;

  const PosPayPillBar({
    super.key,
    required this.label,
    required this.onConfirm,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onConfirm != null && !loading;
    final BorderRadius radius =
        BorderRadius.circular(PosPaymentSpec.v2PillRadius);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PosHomeSpec.pageBg,
        border: Border(
          top: BorderSide(
            color: PosHomeSpec.ink,
            width: PosPaymentSpec.v2BarBorderTop,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: PosPaymentSpec.v2BarShadow,
            offset: PosPaymentSpec.v2BarShadowOffset,
            blurRadius: PosPaymentSpec.v2BarShadowBlur,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PosPaymentSpec.v2BarPaddingH,
          PosPaymentSpec.v2BarPaddingTop,
          PosPaymentSpec.v2BarPaddingH,
          PosPaymentSpec.v2BarPaddingBottom,
        ),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Material(
            color: PosHomeSpec.ink,
            borderRadius: radius,
            child: InkWell(
              onTap: enabled ? onConfirm : null,
              borderRadius: radius,
              child: Container(
                height: PosPaymentSpec.v2PillHeight,
                alignment: Alignment.center,
                child: loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewBold.copyWith(
                          fontSize: PosPaymentSpec.v2PillLabelSize,
                          color: Colors.white,
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

/// `back-btn-row` (node 1915:9347): the back button at the left, with the
/// ticket's `customer / total` caption centred across the row.
class PosPayBackRow extends StatelessWidget {
  /// Null renders the row and the button, greyed and inert — the chrome has to
  /// hold its 67px or the content below jumps when the waiting card appears.
  final VoidCallback? onBack;

  /// `Dylan / € 19.00` (node 1915:9351) — centred, Loew ExtraBold 14.
  final String label;

  const PosPayBackRow({super.key, required this.onBack, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosPaymentSpec.backRowHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Padding(
                // Keep the caption clear of the back button at either edge.
                padding: const EdgeInsets.symmetric(horizontal: 88),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: loewExtraBold.copyWith(
                    fontSize: 14,
                    color: PosHomeSpec.ink,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: PosPaymentSpec.backRowPaddingH),
              child: Opacity(
                opacity: onBack == null ? 0.4 : 1,
                child: Material(
                  color: PosHomeSpec.tileBg,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onBack,
                    child: Container(
                      width: PosPaymentSpec.backButtonSize,
                      height: PosPaymentSpec.backButtonSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            PosPaymentSpec.backButtonRadius),
                        border: Border.all(
                          color: PosHomeSpec.ink,
                          width: PosPaymentSpec.backButtonBorder,
                        ),
                      ),
                      child: SvgPicture.asset(
                        Images.posArrowLeftSvg,
                        width: PosPaymentSpec.backIconSize,
                        height: PosPaymentSpec.backIconSize,
                        colorFilter: const ColorFilter.mode(
                          PosHomeSpec.ink,
                          BlendMode.srcIn,
                        ),
                        placeholderBuilder: (_) => const Icon(
                          Icons.arrow_back,
                          size: PosPaymentSpec.backIconSize,
                          color: PosHomeSpec.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `purchase-receipt-sidebar` (node 1915:9353): header, customer name, the
/// "Order list" label and the inset rows. The header, field and rows are the
/// counter screen's own widgets, so the ticket reads the same either side of
/// PAY; only the card and the inset differ.
class PosPayReceiptCard extends StatelessWidget {
  /// True when the pane owns a bounded height and the rows scroll inside it.
  final bool fill;
  final List<CartModel?> lines;
  final bool hasItems;
  final String? imageBaseUrl;
  final String? dealImageBaseUrl;
  final String? orderNumber;
  final TextEditingController customerNameController;
  final TextEditingController tableController;
  final ValueChanged<int> onIncrement;
  final ValueChanged<int> onDecrement;
  final ValueChanged<BuildContext> onOptions;

  const PosPayReceiptCard({
    super.key,
    required this.fill,
    required this.lines,
    required this.hasItems,
    required this.imageBaseUrl,
    required this.dealImageBaseUrl,
    required this.orderNumber,
    required this.customerNameController,
    required this.tableController,
    required this.onIncrement,
    required this.onDecrement,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    final Widget list = hasItems
        ? PosReceiptOrderList(
            // `order-items` (1915:9368): inset px-24, no thumbnails.
            inset: true,
            lines: lines,
            imageBaseUrl: imageBaseUrl,
            dealImageBaseUrl: dealImageBaseUrl,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
            shrinkWrap: !fill,
            // No EDIT here: customising a line belongs to the counter screen.
            // Quantity and delete stay, so an operator can still fix a mistake
            // without walking the sale back.
          )
        : const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: PosReceiptEmptyState(),
          );

    return PosPayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          PosReceiptHeader(orderNumber: orderNumber, onOptions: onOptions),
          PosReceiptCustomerInfo(
            nameController: customerNameController,
            tableController: tableController,
            showBottomHairline: false,
            // `customer-info` (1915:9361) is py-16.
            paddingTop: PosPaymentSpec.v2CustomerInfoPaddingTop,
          ),
          const PosReceiptOrderListLabel(),
          if (fill) Expanded(child: list) else list,
        ],
      ),
    );
  }
}

/// The small radio of the OTHER rows and the receipt options (nodes 1915:9452
/// / 10429 / 13056). Idle: an 18px slot drawing the 24px `#B9B5A6` ring
/// (`inset -16.67%`), overhanging 3px each side. Selected: the 24px filled
/// radio.
class PosPayRadio extends StatelessWidget {
  final bool selected;

  const PosPayRadio({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    const double drawn = PosPaymentSpec.v2OtherRadioDrawn;
    if (selected) {
      return SvgPicture.asset(
        Images.posRadioOnSvg,
        width: drawn,
        height: drawn,
        placeholderBuilder: (_) => const Icon(
          Icons.radio_button_checked,
          size: drawn,
          color: PosHomeSpec.ink,
        ),
      );
    }
    return SizedBox(
      width: PosPaymentSpec.v2OtherRadioSize,
      height: PosPaymentSpec.v2OtherRadioSize,
      child: OverflowBox(
        minWidth: drawn,
        maxWidth: drawn,
        minHeight: drawn,
        maxHeight: drawn,
        child: SvgPicture.asset(
          Images.posRadioOffSvg,
          width: drawn,
          height: drawn,
          placeholderBuilder: (_) => const Icon(
            Icons.radio_button_unchecked,
            size: drawn,
            color: PosHomeSpec.itemDivider,
          ),
        ),
      ),
    );
  }
}
