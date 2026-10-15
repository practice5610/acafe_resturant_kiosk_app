import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_card.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The middle pane of the redesigned payment screen — `payment-method-card`
/// (Figma **1915:9420**, "POS payment" layer 1915:9314).
///
/// A "PAYMENT METHOD" header over two groups:
///  * **PRIMARY** — Card and Cash, stacked full-width, fully wired to the
///    existing [onSelectMethod] callback (the same cash/card fork the screen
///    already drives). Reuses [PosPaymentMethodCard] verbatim, which already
///    draws the 95px / r12 / icon-well + radio treatment this frame specifies.
///  * **OTHER** — Split by item / Split by payment / Invoice / Stand-alone.
///    These are future families (split, invoice, stand-alone terminal) and are
///    rendered to match the frame but left **inert**: no tap target, no
///    navigation, no state. They carry the frame's drawn muted appearance.
///
/// Purely presentational beyond the one [onSelectMethod] it forwards — it adds
/// no money-path, order or API behaviour.
class PosPaymentMethodSelector extends StatelessWidget {
  final PosPaymentMethod method;

  /// Settings → Payments still gates the two live tenders: a method the venue
  /// does not take is not rendered, matching the current screen's behaviour.
  final bool cashEnabled;
  final bool cardEnabled;
  final ValueChanged<PosPaymentMethod> onSelectMethod;

  /// When non-null, the "Split by payment" OTHER row becomes tappable and
  /// calls this when the operator selects it. Null = row stays inert (Phase 2a
  /// default; wired to the split flow by Phase 2 Family 2).
  final VoidCallback? onSplitByPayment;

  /// True when split-by-payment mode is active. The "Split by payment" row
  /// renders with an ink-filled radio so the operator can see what is selected.
  final bool splitActive;

  const PosPaymentMethodSelector({
    super.key,
    required this.method,
    required this.cashEnabled,
    required this.cardEnabled,
    required this.onSelectMethod,
    this.onSplitByPayment,
    this.splitActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> primary = [
      if (cardEnabled)
        PosPaymentMethodCard(
          method: PosPaymentMethod.card,
          selected: method == PosPaymentMethod.card,
          onTap: () => onSelectMethod(PosPaymentMethod.card),
        ),
      if (cashEnabled)
        PosPaymentMethodCard(
          method: PosPaymentMethod.cash,
          selected: method == PosPaymentMethod.cash,
          onTap: () => onSelectMethod(PosPaymentMethod.cash),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PAYMENT METHOD',
          style: loewBold.copyWith(
            fontSize: PosPaymentSpec.v2MethodHeaderSize,
            letterSpacing: PosPaymentSpec.v2MethodHeaderTracking,
            color: PosHomeSpec.inkAlpha(PosPaymentSpec.v2MethodHeaderOpacity),
          ),
        ),
        const SizedBox(height: PosPaymentSpec.v2MethodCardGap),
        // PRIMARY group.
        const _GroupLabel('PRIMARY'),
        for (int i = 0; i < primary.length; i++) ...[
          const SizedBox(height: PosPaymentSpec.v2MethodGroupGap),
          primary[i],
        ],
        const SizedBox(height: PosPaymentSpec.v2MethodGroupsGap),
        // OTHER group. "Split by payment" (index 1) is wired to the split
        // flow when onSplitByPayment is provided; all others remain inert.
        const _GroupLabel('OTHER'),
        const SizedBox(height: PosPaymentSpec.v2MethodGroupGap),
        for (int i = 0; i < _otherMethods.length; i++) ...[
          if (i > 0) const SizedBox(height: PosPaymentSpec.v2OtherRowGap),
          _OtherMethodRow(
            data: _otherMethods[i],
            onTap: i == 1 ? onSplitByPayment : null,
            active: i == 1 && splitActive,
          ),
        ],
      ],
    );
  }
}

/// A PRIMARY / OTHER section label — Loew Bold 10, ink @0.33, 0.5px tracking.
class _GroupLabel extends StatelessWidget {
  final String label;

  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: loewBold.copyWith(
          fontSize: PosPaymentSpec.v2GroupLabelSize,
          letterSpacing: PosPaymentSpec.v2GroupLabelTracking,
          color: PosHomeSpec.inkAlpha(PosPaymentSpec.v2GroupLabelOpacity),
        ),
      ),
    );
  }
}

/// A single future-family row (node 1915:9447).
///
/// Most rows render inert (Phase 2a default). "Split by payment" (index 1)
/// becomes tappable when [onTap] is provided (Phase 2 Family 2 integration).
/// [active] controls the radio fill — true when this row is selected.
class _OtherMethodRow extends StatelessWidget {
  final _OtherMethod data;
  final VoidCallback? onTap;
  final bool active;

  const _OtherMethodRow({
    required this.data,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: PosPaymentSpec.v2OtherRowTopHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: PosPaymentSpec.v2OtherIconWell,
                height: PosPaymentSpec.v2OtherIconWell,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PosPaymentSpec.methodIdleIconBg,
                  borderRadius: BorderRadius.circular(
                      PosPaymentSpec.v2OtherIconWellRadius),
                ),
                child: SvgPicture.string(
                  data.iconSvg,
                  width: PosPaymentSpec.v2OtherIconSize,
                  height: PosPaymentSpec.v2OtherIconSize,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(
                width: PosPaymentSpec.v2OtherRadioSize,
                height: PosPaymentSpec.v2OtherRadioSize,
                child: active
                    ? SvgPicture.asset(
                        Images.posRadioOnSvg,
                        width: PosPaymentSpec.v2OtherRadioSize,
                        height: PosPaymentSpec.v2OtherRadioSize,
                        placeholderBuilder: (_) => const Icon(
                          Icons.radio_button_checked,
                          size: PosPaymentSpec.v2OtherRadioSize,
                          color: PosHomeSpec.ink,
                        ),
                      )
                    : SvgPicture.asset(
                        Images.posRadioOffSvg,
                        width: PosPaymentSpec.v2OtherRadioSize,
                        height: PosPaymentSpec.v2OtherRadioSize,
                        placeholderBuilder: (_) => const Icon(
                          Icons.radio_button_unchecked,
                          size: PosPaymentSpec.v2OtherRadioSize,
                          color: PosHomeSpec.itemDivider,
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PosPaymentSpec.v2OtherRowInnerGap),
        Text(
          data.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: loewMedium.copyWith(
            fontSize: PosPaymentSpec.v2OtherLabelSize,
            color: PosHomeSpec.inkAlpha(PosPaymentSpec.v2OtherLabelOpacity),
          ),
        ),
      ],
    );

    final container = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PosPaymentSpec.v2OtherRowPaddingH,
        vertical: PosPaymentSpec.v2OtherRowPaddingV,
      ),
      decoration: BoxDecoration(
        color: PosHomeSpec.tileBg,
        borderRadius: BorderRadius.circular(PosPaymentSpec.v2OtherRowRadius),
        border: Border.all(
          color: PosPaymentSpec.v2OtherRowBorder,
          width: PosPaymentSpec.v2OtherRowBorderWidth,
        ),
      ),
      child: content,
    );

    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: container),
    );
  }
}

/// One OTHER-group entry. Icons are inlined vectors (lucide, matching the
/// file's icon set) rather than Figma asset URLs or new bundled files, so a
/// stale web AssetManifest cannot blank them.
class _OtherMethod {
  final String label;
  final String iconSvg;

  const _OtherMethod({required this.label, required this.iconSvg});
}

const String _inkStroke = '#241F20';

const List<_OtherMethod> _otherMethods = [
  _OtherMethod(label: 'Split by item', iconSvg: _iconLayoutGrid),
  _OtherMethod(label: 'Split by payment', iconSvg: _iconSplit),
  _OtherMethod(label: 'Invoice', iconSvg: _iconFileText),
  _OtherMethod(label: 'Stand-alone', iconSvg: _iconSmartphone),
];

const String _iconLayoutGrid =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_inkStroke" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/>'
    '<rect width="7" height="7" x="14" y="14" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/></svg>';

const String _iconSplit =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_inkStroke" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M16 3h5v5"/><path d="M8 3H3v5"/>'
    '<path d="M12 22v-8.3a4 4 0 0 0-1.17-2.83L3 3"/><path d="m15 9 6-6"/></svg>';

const String _iconFileText =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_inkStroke" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z"/>'
    '<path d="M14 2v6h6"/><path d="M16 13H8"/><path d="M16 17H8"/><path d="M10 9H8"/></svg>';

const String _iconSmartphone =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_inkStroke" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><path d="M12 18h.01"/></svg>';
