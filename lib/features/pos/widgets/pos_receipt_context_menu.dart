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
/// Matches Figma: white 240×680-ish panel, right-aligned to the options button,
/// dimmed backdrop at 27% black, section headers + 40px rows + dividers.
Future<PosReceiptMenuAction?> showPosReceiptContextMenu({
  required BuildContext context,
  required BuildContext anchorContext,
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
              child: const PosReceiptContextMenuPanel(),
            ),
          ),
        ],
      );
    },
  );
}

/// Visual panel for the receipt ⋯ menu (Figma `lightspeed-context-menu`).
class PosReceiptContextMenuPanel extends StatelessWidget {
  const PosReceiptContextMenuPanel({super.key});

  /// Measured from Figma frame height of `lightspeed-context-menu` (680).
  static const double preferredHeight = 680;

  static const List<_MenuSection> _sections = [
    _MenuSection(
      title: 'Discount Actions',
      items: [
        _MenuEntry(
          action: PosReceiptMenuAction.applyDiscount,
          label: 'Apply discount',
          iconAsset: Images.posMenuPercentSvg,
        ),
        _MenuEntry(
          action: PosReceiptMenuAction.applyCustomDiscount,
          label: 'Apply custom discount',
          iconAsset: Images.posMenuEditSvg,
        ),
        _MenuEntry(
          action: PosReceiptMenuAction.removeDiscount,
          label: 'Remove discount',
          iconAsset: Images.posMenuTrashSvg,
          danger: true,
        ),
      ],
    ),
    _MenuSection(
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
    _MenuSection(
      title: 'Order Management',
      items: [
        _MenuEntry(
          action: PosReceiptMenuAction.moveTable,
          label: 'Move to another table...',
          iconAsset: Images.posMenuMoveSvg,
        ),
        _MenuEntry(
          action: PosReceiptMenuAction.holdFire,
          label: 'Hold / Fire item',
          iconAsset: Images.posMenuPauseSvg,
        ),
        _MenuEntry(
          action: PosReceiptMenuAction.sendKitchen,
          label: 'Send to kitchen / bar',
          iconAsset: Images.posMenuSendSvg,
        ),
        _MenuEntry(
          action: PosReceiptMenuAction.repeatItem,
          label: 'Repeat item',
          iconAsset: Images.posMenuRepeatSvg,
        ),
      ],
    ),
    _MenuSection(
      title: 'Payment-Related',
      items: [
        _MenuEntry(
          action: PosReceiptMenuAction.partialPayment,
          label: 'Partial payment',
          iconAsset: Images.posMenuCreditCardSvg,
        ),
        _MenuEntry(
          action: PosReceiptMenuAction.giftCard,
          label: 'Gift card apply',
          iconAsset: Images.posMenuGiftSvg,
        ),
        _MenuEntry(
          action: PosReceiptMenuAction.loyaltyPoints,
          label: 'Loyalty points',
          iconAsset: Images.posMenuStarSvg,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
            for (int s = 0; s < _sections.length; s++) ...[
              if (s > 0) const _MenuDivider(),
              _SectionHeader(title: _sections[s].title),
              for (final item in _sections[s].items)
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

  const _MenuEntry({
    required this.action,
    required this.label,
    required this.iconAsset,
    this.danger = false,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(entry.action),
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
