import 'dart:math' as math;

import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The payment-summary column for the **Card** method — `payment-summary-card`
/// (Figma **1915:9475**, "POS payment" layer 1915:9314).
///
/// Shows the amount due at display scale, an "Amount received" row with
/// quick-amount chips, and an "Add tip" row. Per Phase 2a scope the chips and
/// the tip row are **inert**: they render to match the frame but are wired to
/// nothing — no money-path, no state. Only the amount (the live sale total) and
/// the "Amount received" figure are dynamic.
class PosPaySummaryPanel extends StatelessWidget {
  /// Grand total to display (payable + tip).
  final double total;

  /// The tip currently applied, shown on the tip row. 0 = none.
  final double tip;

  /// Opens the tip modal. Null when tipping is disabled → the row is inert.
  final VoidCallback? onTipTap;

  const PosPaySummaryPanel({
    super.key,
    required this.total,
    this.tip = 0,
    this.onTipTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PosPaySummaryHeader(total: total, subtitle: 'Payment overview'),
        const PosPaySummaryDivider(),
        // ontvangen-section / Amount received (1915:9484) — INERT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const PosPaySectionIcon(
                    svg: posPayIconCash,
                    glyphWidth: 16,
                    glyphHeight: 10,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Amount received',
                    style: loewBold.copyWith(
                      fontSize: 12,
                      color: PosHomeSpec.ink, // #1A1A2E -> ink
                    ),
                  ),
                  const Spacer(),
                  Text(
                    PosHomeSpec.formatPrice(total, padZero: false),
                    style: loewBold.copyWith(
                      fontSize: 16,
                      color: PosHomeSpec.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PosPaymentSpec.v2ReceivedGap),
              _QuickAmountGrid(total: total),
            ],
          ),
        ),
        const PosPaySummaryDivider(),
        PosPayTipRow(amount: tip, onTap: onTipTap),
      ],
    );
  }
}

/// `summary-header` (nodes 1915:9476 / 10235): the PAYMENT AMOUNT caption and
/// the 48px amount-due display. [subtitle] differs between frames ("Payment
/// overview" on Card, "Overview for partial payments" on Cash).
class PosPaySummaryHeader extends StatelessWidget {
  final double total;
  final String subtitle;

  /// Compact amount font size for fill mode. Defaults to 48 (Figma spec).
  final double amountFontSize;

  /// Line box of the 48px amount. Null = the font's own (58, Card frame
  /// node 1915:9481); the Cash frame pins it to 47 (node 1915:10240).
  final double? amountLineHeight;

  /// pb-12 on both frames; the Cash frame's header box is a fixed 139 against
  /// 140 of content, so it passes 11.
  final double paddingBottom;

  const PosPaySummaryHeader({
    super.key,
    required this.total,
    required this.subtitle,
    this.amountFontSize = 48,
    this.amountLineHeight,
    this.paddingBottom = 12,
  });

  @override
  Widget build(BuildContext context) {
    final double amtFont = amountFontSize;
    // `summary-header` (1915:9476): pt-16 px-20 pb-12, gap-10 between the
    // caption block and the total display.
    const double gapBeforeAmt = 10;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, amtFont < 42 ? 12 : 16, 20, amtFont < 42 ? 8 : paddingBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PAYMENT AMOUNT',
            style: loewBold.copyWith(
              fontSize: 14,
              letterSpacing: 1,
              color: PosHomeSpec.inkAlpha(0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: swiss721Light.copyWith(
              fontSize: 12,
              height: PosPaymentSpec.figmaLeading(12),
color: PosHomeSpec.inkAlpha(0.33),
            ),
          ),
          const SizedBox(height: gapBeforeAmt),
          Text(
            PosHomeSpec.formatPrice(total, padZero: false),
            maxLines: 1,
            style: loewExtraBold.copyWith(
              fontSize: amtFont,
              color: PosHomeSpec.ink,
              height: amountLineHeight == null ? null : amountLineHeight! / amtFont,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Amount due',
            style: swiss721Light.copyWith(
              fontSize: 13,
              height: PosPaymentSpec.figmaLeading(13),
color: PosHomeSpec.inkAlpha(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1px `#E8E0CC` rule between summary sections (nodes 1915:9483 / 9505 / 10242).
class PosPaySummaryDivider extends StatelessWidget {
  const PosPaySummaryDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: PosPaymentSpec.v2SummaryBorder,
      child: SizedBox(height: 1, width: double.infinity),
    );
  }
}

/// `tip-section` (nodes 1915:9506 / 10298).
///
/// Functional when [onTap] is non-null (tipping enabled): tapping opens the tip
/// modal, and [amount] shows the chosen tip. A null [onTap] renders the row
/// inert (tipping disabled), preserving the pane's layout.
class PosPayTipRow extends StatelessWidget {
  /// The tip currently applied, in currency. 0 shows the "0.00" placeholder.
  final double amount;

  /// Null = inert (tipping off).
  final VoidCallback? onTap;

  const PosPayTipRow({super.key, this.amount = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool hasTip = amount > 0;
    final Widget row = Container(
      height: PosPaymentSpec.tipSectionHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const PosPaySectionIcon(
            svg: posPayIconPlusCircle,
            glyphWidth: 12,
            glyphHeight: 12,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add tip',
                  style: loewBold.copyWith(fontSize: 12, color: PosHomeSpec.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  'Add the tip you received here',
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
            // The receipt frame draws the figure without a currency symbol
            // ("0.00").
            hasTip ? PosHomeSpec.formatPrice(amount, padZero: false) : '0.00',
            // Node 1915:9513: Loew Bold 14, #1A1A2E (→ ink) — not muted.
            style: loewBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
          ),
          const SizedBox(width: 10),
          SvgPicture.string(
            posPayIconChevronRight,
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// A 24px icon well — bg `#F0EAD6`, r5, with a 12–16px glyph (node 1915:9486).
class PosPaySectionIcon extends StatelessWidget {
  final String svg;

  /// The glyph box inside the 24px well — `bi:cash` is 16×10 (node
  /// 1915:9487), `plus-circle` 12×12 (node 1915:9508).
  final double glyphWidth;
  final double glyphHeight;

  const PosPaySectionIcon({
    super.key,
    required this.svg,
    this.glyphWidth = 14,
    this.glyphHeight = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PosPaymentSpec.v2SectionIconBg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: SvgPicture.string(
        svg,
        width: glyphWidth,
        height: glyphHeight,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// The 3×2 quick-amount grid (nodes 1915:9491 / 9498). INERT: the chips render
/// but drive nothing. The exact-total chip is highlighted; the rest are round
/// suggestions above the total. No value here reaches the money path.
class _QuickAmountGrid extends StatelessWidget {
  final double total;

  const _QuickAmountGrid({required this.total});

  /// The frame's sequence for € 19.00 is 20 · 25 · 30 · 50 (nodes 1915:9496–
  /// 9503): the next €5 above the total, €5 more, the next €10 above that,
  /// then the next €50.
  List<double> _presets() {
    double above(double v, int step) => ((v / step).floor() + 1) * step.toDouble();
    final double first = above(total, 5);
    final double second = first + 5;
    final double third = above(second, 10);
    final double fourth = above(third, 50);
    return [first, second, third, fourth];
  }

  @override
  Widget build(BuildContext context) {
    final List<double> presets = _presets();
    final List<_Chip> chips = [
      const _Chip(label: 'Custom'),
      _Chip(
        label: PosHomeSpec.formatPrice(total, padZero: false)
            .replaceAll(RegExp(r'[^\d.,]'), '')
            .trim(),
        selected: true,
      ),
      for (final double v in presets) _Chip(label: v.toStringAsFixed(2)),
    ];

    return Column(
      children: [
        Row(children: _spread(chips.sublist(0, 3))),
        const SizedBox(height: PosPaymentSpec.v2ReceivedGap),
        Row(children: _spread(chips.sublist(3, math.min(6, chips.length)))),
      ],
    );
  }

  List<Widget> _spread(List<Widget> items) {
    final List<Widget> out = [];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 6));
      out.add(Expanded(child: items[i]));
    }
    return out;
  }
}

/// One quick-amount chip — h34, r6, py8 (node 1915:9492). Selected: ink fill,
/// white label. Idle: white fill, `#D6CCBA` border, ink label. Non-interactive.
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;

  const _Chip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? PosHomeSpec.ink : PosHomeSpec.tileBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? PosHomeSpec.ink : PosPaymentSpec.v2QuickAmountBorder,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: loewBold.copyWith(
          fontSize: 13,
          color: selected ? Colors.white : PosHomeSpec.ink,
        ),
      ),
    );
  }
}

/// The frame's own vectors, inlined (no Figma asset URLs, no new bundled
/// files, so a stale web AssetManifest cannot blank them).
///
/// `bi:cash` (node 1915:9487) — filled, 16×10.
const String posPayIconCash =
    '<svg width="16" height="10" viewBox="0 0 16 10" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M8 7C8.53043 7 9.03914 6.78929 9.41421 6.41421C9.78929 6.03914 10 5.53043 10 5C10 4.46957 9.78929 3.96086 9.41421 3.58579C9.03914 3.21071 8.53043 3 8 3C7.46957 3 6.96086 3.21071 6.58579 3.58579C6.21071 3.96086 6 4.46957 6 5C6 5.53043 6.21071 6.03914 6.58579 6.41421C6.96086 6.78929 7.46957 7 8 7Z" fill="black"/>'
    '<path d="M0 1C0 0.734784 0.105357 0.48043 0.292893 0.292893C0.48043 0.105357 0.734784 0 1 0H15C15.2652 0 15.5196 0.105357 15.7071 0.292893C15.8946 0.48043 16 0.734784 16 1V9C16 9.26522 15.8946 9.51957 15.7071 9.70711C15.5196 9.89464 15.2652 10 15 10H1C0.734784 10 0.48043 9.89464 0.292893 9.70711C0.105357 9.51957 0 9.26522 0 9V1ZM3 1C3 1.53043 2.78929 2.03914 2.41421 2.41421C2.03914 2.78929 1.53043 3 1 3V7C1.53043 7 2.03914 7.21071 2.41421 7.58579C2.78929 7.96086 3 8.46957 3 9H13C13 8.46957 13.2107 7.96086 13.5858 7.58579C13.9609 7.21071 14.4696 7 15 7V3C14.4696 3 13.9609 2.78929 13.5858 2.41421C13.2107 2.03914 13 1.53043 13 1H3Z" fill="black"/>'
    '</svg>';

/// `plus-circle` (node 1915:9508), 12×12. The file strokes it `#5A6A8A`, an
/// off-palette slate like `#1A1A2E`; drawn in ink per the same sign-off.
const String posPayIconPlusCircle =
    '<svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M3.99984 6H6M6 6H8.00016M6 6V3.99984M6 6V8.00016M11.0004 6C11.0004 8.76164 8.76164 11.0004 6 11.0004C3.23836 11.0004 0.9996 8.76164 0.9996 6C0.9996 3.23836 3.23836 0.9996 6 0.9996C8.76164 0.9996 11.0004 3.23836 11.0004 6Z" '
    'stroke="#241F20" stroke-width="2" stroke-linecap="round"/></svg>';

/// `chevron-right` (node 1915:9514), 16×16. `#8A94A6` in the file → ink @0.4
/// ([PosPaymentSpec.v2MutedInkOpacity]), per the sign-off.
const String posPayIconChevronRight =
    '<svg width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M6 12L10 8L6 4" stroke="#241F20" stroke-opacity="0.4" stroke-width="2" stroke-linecap="round"/></svg>';
