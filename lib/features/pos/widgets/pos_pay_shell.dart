import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

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

  const PosPayCard({
    super.key,
    required this.child,
    this.padding,
    this.summaryBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: padding == null ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: PosHomeSpec.panelBg,
        borderRadius: BorderRadius.circular(PosPaymentSpec.v2CardRadius),
        border: Border.all(
          color: summaryBorder
              ? PosPaymentSpec.v2SummaryBorder
              : PosHomeSpec.hairline,
          width: summaryBorder
              ? PosPaymentSpec.v2OtherRowBorderWidth // 1px
              : PosPaymentSpec.cardBorder, // 1.5px
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
