import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_card.dart';
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
  /// calls this when the operator selects it. Null = row stays inert.
  final VoidCallback? onSplitByPayment;

  /// True when split-by-payment mode is active.
  final bool splitActive;

  /// When non-null, the "Split by item" OTHER row becomes tappable.
  final VoidCallback? onSplitByItem;

  /// True when split-by-item mode is active.
  final bool splitByItemActive;

  /// When non-null, the "Invoice" OTHER row becomes tappable.
  final VoidCallback? onInvoice;

  /// True when invoice mode is active.
  final bool invoiceActive;

  /// When non-null, the "Stand-alone" OTHER row becomes tappable.
  final VoidCallback? onStandalone;

  /// True when stand-alone mode is active.
  final bool standaloneActive;

  /// Called when the operator taps the currently-active OTHER row to deselect
  /// (cancel) it. Null = no cancellation available.
  final VoidCallback? onCancelActiveOther;

  /// True while an OTHER-mode order is being placed (API in flight). Causes
  /// the PRIMARY radio to appear deselected so there is no blink between
  /// cancel of the old OTHER and activation of the new one.
  final bool pendingOther;

  /// When false, Split by item / Split by payment are omitted. Use in
  /// change-method flows where splits cannot be a display override.
  final bool showSplitOptions;

  const PosPaymentMethodSelector({
    super.key,
    required this.method,
    required this.cashEnabled,
    required this.cardEnabled,
    required this.onSelectMethod,
    this.onSplitByPayment,
    this.splitActive = false,
    this.onSplitByItem,
    this.splitByItemActive = false,
    this.onInvoice,
    this.invoiceActive = false,
    this.onStandalone,
    this.standaloneActive = false,
    this.onCancelActiveOther,
    this.pendingOther = false,
    this.showSplitOptions = true,
  });

  @override
  Widget build(BuildContext context) {
    // When any OTHER mode is active, neither PRIMARY method shows as selected.
    // This enforces a single-select across the combined PRIMARY + OTHER group.
    final bool anyOtherActive =
        splitActive || splitByItemActive || invoiceActive || standaloneActive || pendingOther;
    final List<Widget> primary = [
      if (cardEnabled)
        PosPaymentMethodCard(
          method: PosPaymentMethod.card,
          selected: !anyOtherActive && method == PosPaymentMethod.card,
          onTap: () => onSelectMethod(PosPaymentMethod.card),
        ),
      if (cashEnabled)
        PosPaymentMethodCard(
          method: PosPaymentMethod.cash,
          selected: !anyOtherActive && method == PosPaymentMethod.cash,
          onTap: () => onSelectMethod(PosPaymentMethod.cash),
        ),
    ];

    // Indices into [_otherMethods]: 0 split-by-item, 1 split-by-payment,
    // 2 invoice, 3 stand-alone. Change-method flows omit the splits.
    final List<int> visible = [
      if (showSplitOptions) 0,
      if (showSplitOptions) 1,
      2,
      3,
    ];
    final List<bool> allActive = [
      splitByItemActive, splitActive, invoiceActive, standaloneActive,
    ];
    final List<VoidCallback?> allStarts = [
      onSplitByItem, onSplitByPayment, onInvoice, onStandalone,
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
        // OTHER group — mutually exclusive single-select with PRIMARY.
        // Re-tap the active row → [onCancelActiveOther]. Tap another row →
        // call that row's start handler directly (handlers replace state;
        // they must tear down any prior OTHER UI themselves when needed).
        const _GroupLabel('OTHER'),
        const SizedBox(height: PosPaymentSpec.v2MethodGroupGap),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int v = 0; v < visible.length; v++) ...[
              if (v > 0) const SizedBox(height: PosPaymentSpec.v2OtherRowGap),
              Builder(builder: (context) {
                final int i = visible[v];
                final bool isActive = allActive[i];
                final VoidCallback? start = allStarts[i];
                // Re-tap deselects; otherwise start (or stay inert when null).
                final VoidCallback? onTap =
                    isActive ? onCancelActiveOther : start;
                return _OtherMethodRow(
                  data: _otherMethods[i],
                  onTap: onTap,
                  active: isActive,
                );
              }),
            ],
          ],
        ),
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
    final bool enabled = onTap != null;
    final double labelOpacity = !enabled
        ? 0.28
        : active
            ? 1.0
            : PosPaymentSpec.v2OtherLabelOpacity;
    final Color borderColor =
        active ? PosHomeSpec.ink : PosPaymentSpec.v2OtherRowBorder;
    // Selected row (node 1915:10424): #241F20 at 1.5px.
    final double borderWidth = active
        ? PosPaymentSpec.v2OtherRowActiveBorderWidth
        : PosPaymentSpec.v2OtherRowBorderWidth;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: PosPaymentSpec.v2OtherRowTopHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Opacity(
                opacity: enabled ? 1.0 : 0.40,
                child: Container(
                  width: PosPaymentSpec.v2OtherIconWell,
                  height: PosPaymentSpec.v2OtherIconWell,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? PosHomeSpec.ink
                        : PosPaymentSpec.methodIdleIconBg,
                    borderRadius: BorderRadius.circular(
                        PosPaymentSpec.v2OtherIconWellRadius),
                  ),
                  child: SvgPicture.string(
                    data.iconSvg,
                    width: PosPaymentSpec.v2OtherIconSize,
                    height: PosPaymentSpec.v2OtherIconSize,
                    fit: BoxFit.contain,
                    colorFilter: active
                        ? const ColorFilter.mode(
                            PosHomeSpec.pageBg,
                            BlendMode.srcIn,
                          )
                        : null,
                  ),
                ),
              ),
              Opacity(
                opacity: enabled ? 1.0 : 0.40,
                child: PosPayRadio(selected: active),
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
            color: PosHomeSpec.inkAlpha(labelOpacity),
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
      ),
      // Inside stroke: the row is 64 tall (10 + 24 + 6 + 14 + 10), border
      // included, as in node 1915:9447.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PosPaymentSpec.v2OtherRowRadius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: content,
    );

    if (!enabled) return container;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: container),
    );
  }
}

/// One OTHER-group entry. Icons are the frame's own vectors (nodes 1915:9450 /
/// 9457 / 9464 / 9471), inlined rather than bundled so a stale web
/// AssetManifest cannot blank them.
class _OtherMethod {
  final String label;
  final String iconSvg;

  const _OtherMethod({required this.label, required this.iconSvg});
}

// Figma draws the same banknote glyph on both split rows.
const List<_OtherMethod> _otherMethods = [
  _OtherMethod(label: 'Split by item', iconSvg: _iconBanknote),
  _OtherMethod(label: 'Split by payment', iconSvg: _iconBanknote),
  _OtherMethod(label: 'Invoice', iconSvg: _iconFileText),
  _OtherMethod(label: 'Stand-alone', iconSvg: _iconSmartphone),
];

const String _iconBanknote =
    '<svg width="13" height="13" viewBox="0 0 13 13" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M3.24982 6.5H3.25524M9.75034 6.5H9.75576M2.1664 3.25H10.8338C11.4321 3.25 11.9172 3.73502 11.9172 4.33333V8.66667C11.9172 9.26497 11.4321 9.75 10.8338 9.75H2.1664C1.56804 9.75 1.08298 9.26497 1.08298 8.66667V4.33333C1.08298 3.73502 1.56804 3.25 2.1664 3.25ZM7.5835 6.5C7.5835 7.09831 7.09844 7.58333 6.50008 7.58333C5.90172 7.58333 5.41666 7.09831 5.41666 6.5C5.41666 5.90169 5.90172 5.41667 6.50008 5.41667C7.09844 5.41667 7.5835 5.90169 7.5835 6.5Z" '
    'stroke="#241F20" stroke-width="1.44444" stroke-linecap="round"/></svg>';

const String _iconFileText =
    '<svg width="13" height="13" viewBox="0 0 13 13" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M7.58322 1.0829H3.25032C2.96304 1.0829 2.68751 1.19705 2.48437 1.40023C2.28123 1.60341 2.1671 1.87898 2.1671 2.16632V10.8337C2.1671 11.121 2.28123 11.3966 2.48437 11.5998C2.68751 11.803 2.96304 11.9171 3.25032 11.9171H9.74967C10.037 11.9171 10.3125 11.803 10.5156 11.5998C10.7188 11.3966 10.8329 11.121 10.8329 10.8337V4.33316M7.58322 1.0829C7.75467 1.08262 7.92448 1.11627 8.08288 1.18191C8.24127 1.24755 8.38512 1.34388 8.50613 1.46535L10.4494 3.409C10.5712 3.53008 10.6678 3.67409 10.7336 3.83271C10.7994 3.99133 10.8332 4.16142 10.8329 4.33316M7.58322 1.0829V3.79145C7.58322 3.93512 7.64029 4.07291 7.74186 4.1745C7.84343 4.27609 7.98119 4.33316 8.12484 4.33316L10.8329 4.33316M5.41677 4.87487H4.33355M8.66645 7.04171H4.33355M8.66645 9.20855H4.33355" '
    'stroke="#241F20" stroke-width="2" stroke-linecap="round"/></svg>';

const String _iconSmartphone =
    '<svg width="13" height="13" viewBox="0 0 13 13" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M6.5 9.75026H6.50542M3.79136 1.0829H9.20864C9.80702 1.0829 10.2921 1.56796 10.2921 2.16632V10.8337C10.2921 11.432 9.80702 11.9171 9.20864 11.9171H3.79136C3.19298 11.9171 2.7079 11.432 2.7079 10.8337V2.16632C2.7079 1.56796 3.19298 1.0829 3.79136 1.0829Z" '
    'stroke="#241F20" stroke-width="2" stroke-linecap="round"/></svg>';
