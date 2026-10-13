import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Actions from the receipt ⋯ menu (Figma `lightspeed-context-menu` 1641:3570).
enum PosReceiptMenuAction {
  applyDiscount,
  applyCustomDiscount,
  removeDiscount,
  priceOverride,
  taxExempt,
  compItem,
  moveTable,
  holdFire,
  sendKitchen,
  repeatItem,
  partialPayment,
  giftCard,
  loyaltyPoints,
}

/// Opens the receipt context menu anchored to [anchorContext] (the ⋯ button).
///
/// Matches Figma `lightspeed-context-menu` (1915:13568): white 240-wide panel,
/// right-aligned to the options button, dimmed backdrop, two section headers +
/// 40px rows + one divider. [hasDiscount] enables the "Remove discount" row;
/// when false it renders dimmed and non-tappable, exactly as the frame draws it.
Future<PosReceiptMenuAction?> showPosReceiptContextMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  bool hasDiscount = false,
}) {
  final RenderBox? box = anchorContext.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) {
    return Future<PosReceiptMenuAction?>.value(null);
  }

  final Offset origin = box.localToGlobal(Offset.zero);
  final Size buttonSize = box.size;
  final Size screen = MediaQuery.sizeOf(context);

  // Figma: menu right edge aligns with the options button's right edge;
  // top sits at the button's bottom (136 vs button bottom ~137.5).
  double left = origin.dx + buttonSize.width - PosHomeSpec.contextMenuWidth;
  double top = origin.dy + buttonSize.height + PosHomeSpec.contextMenuAnchorGap;

  const double menuHeight = PosReceiptContextMenuPanel.preferredHeight;
  if (left < 8) left = 8;
  if (left + PosHomeSpec.contextMenuWidth > screen.width - 8) {
    left = screen.width - PosHomeSpec.contextMenuWidth - 8;
  }
  if (top + menuHeight > screen.height - 8) {
    top = (screen.height - menuHeight - 8).clamp(8.0, screen.height);
  }

  return showGeneralDialog<PosReceiptMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: FadeTransition(
              opacity: animation,
              child: PosReceiptContextMenuPanel(hasDiscount: hasDiscount),
            ),
          ),
        ],
      );
    },
  );
}

/// Visual panel for the receipt ⋯ menu (Figma `lightspeed-context-menu`).
class PosReceiptContextMenuPanel extends StatelessWidget {
  /// True enables the "Remove discount" row; false renders it dimmed and
  /// non-tappable, as Figma 1915:13576 draws it when no discount is applied.
  final bool hasDiscount;

  const PosReceiptContextMenuPanel({super.key, this.hasDiscount = false});

  /// Measured from the Figma `lightspeed-context-menu` (1915:13568): 8px padding
  /// top and bottom, two 27px section headers, five 40px rows and one 12px
  /// divider between the sections.
  static const double preferredHeight = 2 * PosHomeSpec.contextMenuPadding +
      2 * PosHomeSpec.contextMenuHeaderHeight +
      5 * PosHomeSpec.contextMenuItemHeight +
      PosHomeSpec.contextMenuDividerHeight;

  /// The two sections the Browse-POS design shows. "Remove discount" is disabled
  /// unless a discount is applied. (Other [PosReceiptMenuAction] values remain in
  /// the enum for the payment screen / future use but are not surfaced here, to
  /// match the design exactly.)
  List<_MenuSection> _sections() => [
        _MenuSection(
          title: 'Discount Actions',
          items: [
            const _MenuEntry(
              action: PosReceiptMenuAction.applyDiscount,
              label: 'Apply discount',
              iconAsset: Images.posMenuPercentSvg,
            ),
            _MenuEntry(
              action: PosReceiptMenuAction.removeDiscount,
              label: 'Remove discount',
              iconAsset: Images.posMenuTrashSvg,
              danger: true,
              disabled: !hasDiscount,
            ),
          ],
        ),
        const _MenuSection(
          title: 'Price Adjustments',
          items: [
            _MenuEntry(
              action: PosReceiptMenuAction.priceOverride,
              label: 'Price override',
              iconAsset: Images.posMenuTagSvg,
            ),
            _MenuEntry(
              action: PosReceiptMenuAction.taxExempt,
              label: 'Tax exempt',
              iconAsset: Images.posMenuShieldCheckSvg,
            ),
            _MenuEntry(
              action: PosReceiptMenuAction.compItem,
              label: 'Comp item',
              iconAsset: Images.posMenuGiftSvg,
            ),
          ],
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final List<_MenuSection> sections = _sections();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: PosHomeSpec.contextMenuWidth,
        padding: const EdgeInsets.all(PosHomeSpec.contextMenuPadding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(PosHomeSpec.contextMenuRadius),
          border: Border.all(
            color: PosHomeSpec.contextMenuBorder,
            width: PosHomeSpec.contextMenuBorderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: PosHomeSpec.contextMenuShadowOpacity),
              offset: PosHomeSpec.contextMenuShadowOffset,
              blurRadius: PosHomeSpec.contextMenuShadowBlur,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int s = 0; s < sections.length; s++) ...[
              if (s > 0) const _MenuDivider(),
              _SectionHeader(title: sections[s].title),
              for (final item in sections[s].items)
                _MenuItemRow(entry: item),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuSection {
  final String title;
  final List<_MenuEntry> items;

  const _MenuSection({required this.title, required this.items});
}

class _MenuEntry {
  final PosReceiptMenuAction action;
  final String label;
  final String iconAsset;
  final bool danger;

  /// Dimmed and non-tappable (Figma 1915:13576 opacity 35%) — e.g. "Remove
  /// discount" when there is no discount to remove.
  final bool disabled;

  const _MenuEntry({
    required this.action,
    required this.label,
    required this.iconAsset,
    this.danger = false,
    this.disabled = false,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosHomeSpec.contextMenuHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PosHomeSpec.contextMenuHeaderPaddingH,
          PosHomeSpec.contextMenuHeaderPaddingTop,
          PosHomeSpec.contextMenuHeaderPaddingH,
          PosHomeSpec.contextMenuHeaderPaddingBottom,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loewExtraBold.copyWith(
              fontSize: PosHomeSpec.contextMenuHeaderSize,
              color: PosHomeSpec.inkAlpha(0.53),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final _MenuEntry entry;

  const _MenuItemRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final Color labelColor =
        entry.danger ? PosHomeSpec.contextMenuDanger : PosHomeSpec.ink;
    final TextStyle labelStyle = (entry.danger ? loewBold : loewMedium).copyWith(
      fontSize: PosHomeSpec.contextMenuItemLabelSize,
      color: labelColor,
      height: PosHomeSpec.contextMenuItemLabelHeight,
    );

    final Widget row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.disabled
            ? null
            : () => Navigator.of(context).pop(entry.action),
        borderRadius:
            BorderRadius.circular(PosHomeSpec.contextMenuItemRadius),
        child: SizedBox(
          height: PosHomeSpec.contextMenuItemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PosHomeSpec.contextMenuItemPaddingH,
              vertical: PosHomeSpec.contextMenuItemPaddingV,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: PosHomeSpec.contextMenuIconBox,
                  height: PosHomeSpec.contextMenuIconBox,
                  child: Center(
                    child: SvgPicture.asset(
                      entry.iconAsset,
                      width: PosHomeSpec.contextMenuIconSize,
                      height: PosHomeSpec.contextMenuIconSize,
                      colorFilter: entry.danger
                          ? const ColorFilter.mode(
                              PosHomeSpec.contextMenuDanger,
                              BlendMode.srcIn,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: PosHomeSpec.contextMenuItemGap),
                Expanded(
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!entry.disabled) return row;
    return Opacity(
      opacity: 0.35,
      child: IgnorePointer(child: row),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosHomeSpec.contextMenuDividerHeight,
      child: Center(
        child: Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: PosHomeSpec.contextMenuBorder,
        ),
      ),
    );
  }
}
