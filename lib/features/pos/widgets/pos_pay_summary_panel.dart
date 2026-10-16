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
                  const PosPaySectionIcon(svg: posPayIconBanknote),
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
              const SizedBox(height: 10),
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

  const PosPaySummaryHeader({
    super.key,
    required this.total,
    required this.subtitle,
    this.amountFontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final double amtFont = amountFontSize;
    final double gapBeforeAmt = (amtFont < 42) ? 10 : 20;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, amtFont < 42 ? 12 : 16, 20, amtFont < 42 ? 8 : 12),
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
              color: PosHomeSpec.inkAlpha(0.33),
            ),
          ),
          SizedBox(height: gapBeforeAmt),
          Text(
            PosHomeSpec.formatPrice(total, padZero: false),
            maxLines: 1,
            style: loewExtraBold.copyWith(fontSize: amtFont, color: PosHomeSpec.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Amount due',
            style: swiss721Light.copyWith(
              fontSize: 13,
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
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          const PosPaySectionIcon(svg: posPayIconPlusCircle),
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
            // ("0.00"); a chosen tip keeps that treatment but in ink + bold.
            hasTip ? PosHomeSpec.formatPrice(amount, padZero: false) : '0.00',
            style: loewBold.copyWith(
              fontSize: 14,
              color: hasTip
                  ? PosHomeSpec.ink
                  : PosHomeSpec.inkAlpha(PosPaymentSpec.v2MutedInkOpacity),
            ),
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

  const PosPaySectionIcon({super.key, required this.svg});

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
      child: SvgPicture.string(svg, width: 14, height: 14, fit: BoxFit.contain),
    );
  }
}

/// The 3×2 quick-amount grid (nodes 1915:9491 / 9498). INERT: the chips render
/// but drive nothing. The exact-total chip is highlighted; the rest are round
/// suggestions above the total. No value here reaches the money path.
class _QuickAmountGrid extends StatelessWidget {
  final double total;

  const _QuickAmountGrid({required this.total});

  List<double> _presets() {
    final List<double> out = [];
    for (final int step in const [5, 10, 20, 50]) {
      final double v = (total / step).ceil() * step.toDouble();
      if (v > total && !out.contains(v)) out.add(v);
    }
    while (out.length < 4) {
      out.add((out.isEmpty ? total : out.last) + 5);
    }
    return out.take(4).toList();
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
        const SizedBox(height: 8),
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

const String _ink = '#241F20';

/// Inlined lucide vectors (matching the file's icon set) — no Figma asset URLs,
/// no new bundled files, so a stale web AssetManifest cannot blank them.
const String posPayIconBanknote =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_ink" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="20" height="12" x="2" y="6" rx="2"/><circle cx="12" cy="12" r="2"/>'
    '<path d="M6 12h.01M18 12h.01"/></svg>';

const String posPayIconPlusCircle =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_ink" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="12" cy="12" r="10"/><path d="M8 12h8"/><path d="M12 8v8"/></svg>';

const String posPayIconChevronRight =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_ink" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<path d="m9 18 6-6-6-6"/></svg>';
