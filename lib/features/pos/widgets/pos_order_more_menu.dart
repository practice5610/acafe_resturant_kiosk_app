import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_menu_anchor.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The order's side exits — the two things it can do that are not "move
/// forward".
///
/// These are the kitchen's own whole-order menu (`status_action_sheet.dart:
/// 70-89`) brought to the POS: Pause / Resume and Cancel. In the detail
/// overlay that is all it holds — completing an order is the primary CTA, the
/// same split the kitchen makes.
///
/// The board card has no CTA of its own (Figma 1915:15767 draws none), so its
/// ⋮ menu also leads with the card's forward rung: [advance].
enum PosOrderMenuAction { advance, hold, resume, cancel }

/// The ⋯ button that opens the menu, sized to sit beside the primary CTA
/// without unbalancing it.
class PosOrderMoreButton extends StatelessWidget {
  final bool enabled;
  final bool isHeld;
  final Future<void> Function(PosOrderMenuAction action) onSelected;

  const PosOrderMoreButton({
    super.key,
    required this.enabled,
    required this.isHeld,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PosOrderMoreMenu(
      enabled: enabled,
      isHeld: isHeld,
      onSelected: onSelected,
      triggerBuilder: (context, isOpen, toggle) => Opacity(
        opacity: enabled ? 1 : PosOrderDetailSpec.itemActionDisabledOpacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? toggle : null,
            borderRadius:
                BorderRadius.circular(PosOrderDetailSpec.moreButtonRadius),
            child: Container(
              width: PosOrderDetailSpec.moreButtonSize,
              height: PosOrderDetailSpec.moreButtonSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(PosOrderDetailSpec.moreButtonRadius),
                border: Border.all(color: PosOrderDetailSpec.ink, width: 1.5),
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                size: PosOrderDetailSpec.moreButtonIconSize,
                color: PosOrderDetailSpec.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The order's compact action menu, hung off the button [triggerBuilder]
/// draws.
///
/// It opens through [PosMenuAnchor], the same root-overlay mechanism as every
/// POS dropdown, so it stays glued to its button wherever that button lives —
/// the board under the shell's nav bar, or the detail modal on top of it.
///
/// By default it opens above the button, left-aligned to it: the detail
/// modal's ⋯ lives in the sticky bar at its bottom. [openBelow] is for a
/// button at the top of its surface — the card's ⋮ — so the menu drops under
/// it, right-aligned to it. Either way it takes the other side when there is
/// no room.
///
/// [advanceLabel] adds the forward rung as the first row (the board card's
/// menu); [sideExits] false leaves Pause / Resume / Cancel out (an order that
/// can only be advanced).
class PosOrderMoreMenu extends StatelessWidget {
  final bool isHeld;
  final String? advanceLabel;
  final bool sideExits;
  final bool openBelow;
  final bool enabled;
  final ValueChanged<PosOrderMenuAction> onSelected;
  final PosMenuTriggerBuilder triggerBuilder;

  const PosOrderMoreMenu({
    super.key,
    required this.isHeld,
    required this.onSelected,
    required this.triggerBuilder,
    this.advanceLabel,
    this.sideExits = true,
    this.openBelow = false,
    this.enabled = true,
  });

  /// Key of the open menu panel (for tests).
  static const Key menuKey = Key('pos-order-more-menu');

  int get _rows => (advanceLabel == null ? 0 : 1) + (sideExits ? 2 : 0);

  @override
  Widget build(BuildContext context) {
    final double height = _rows * PosOrderDetailSpec.moreMenuRowHeight +
        PosOrderDetailSpec.moreMenuPadV * 2;

    return PosMenuAnchor(
      enabled: enabled && _rows > 0,
      menuHeight: height,
      // Three rows at most: never squeezed into a scroll.
      menuMinHeight: height,
      menuMinWidth: PosOrderDetailSpec.moreMenuWidth,
      gap: PosOrderDetailSpec.moreMenuGap,
      side: openBelow ? PosMenuSide.below : PosMenuSide.above,
      align: openBelow ? PosMenuAlign.end : PosMenuAlign.start,
      triggerBuilder: triggerBuilder,
      menuBuilder: (context, layout, close) => _MoreMenuPanel(
        isHeld: isHeld,
        advanceLabel: advanceLabel,
        sideExits: sideExits,
        onSelect: (PosOrderMenuAction action) {
          close();
          onSelected(action);
        },
      ),
    );
  }
}

class _MoreMenuPanel extends StatelessWidget {
  final bool isHeld;
  final String? advanceLabel;
  final bool sideExits;
  final ValueChanged<PosOrderMenuAction> onSelect;

  const _MoreMenuPanel({
    required this.isHeld,
    required this.advanceLabel,
    required this.sideExits,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: PosOrderMoreMenu.menuKey,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: PosOrderDetailSpec.moreMenuPadV,
        ),
        decoration: BoxDecoration(
          color: PosOrderDetailSpec.modalBg,
          borderRadius:
              BorderRadius.circular(PosOrderDetailSpec.moreMenuRadius),
          border: Border.all(color: PosOrderDetailSpec.hairline),
          boxShadow: PosOrderDetailSpec.modalShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (advanceLabel != null)
              _MoreMenuRow(
                action: PosOrderMenuAction.advance,
                label: advanceLabel!,
                icon: Icons.check_circle_outline_rounded,
                onSelect: onSelect,
              ),
            if (sideExits) ...[
              // Resume rather than Pause while held — the same swap the
              // kitchen menu makes, so the one row always offers the move that
              // applies.
              if (isHeld)
                _MoreMenuRow(
                  action: PosOrderMenuAction.resume,
                  label: 'Resume order',
                  icon: Icons.play_arrow_rounded,
                  onSelect: onSelect,
                )
              else
                _MoreMenuRow(
                  action: PosOrderMenuAction.hold,
                  label: 'Mark on hold',
                  icon: Icons.pause_circle_outlined,
                  onSelect: onSelect,
                ),
              _MoreMenuRow(
                action: PosOrderMenuAction.cancel,
                label: 'Cancel order',
                icon: Icons.cancel_outlined,
                danger: true,
                onSelect: onSelect,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoreMenuRow extends StatelessWidget {
  final PosOrderMenuAction action;
  final String label;
  final IconData icon;
  final bool danger;
  final ValueChanged<PosOrderMenuAction> onSelect;

  const _MoreMenuRow({
    required this.action,
    required this.label,
    required this.icon,
    required this.onSelect,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        danger ? PosHomeSpec.contextMenuDanger : PosOrderDetailSpec.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(action),
        child: SizedBox(
          height: PosOrderDetailSpec.moreMenuRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PosOrderDetailSpec.moreMenuRowPadH,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: PosOrderDetailSpec.moreMenuIconSize,
                  color: color,
                ),
                const SizedBox(width: PosOrderDetailSpec.moreMenuIconGap),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (danger ? loewBold : loewMedium).copyWith(
                      fontSize: PosOrderDetailSpec.moreMenuTextSize,
                      color: color,
                    ),
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

/// Cancelling is destructive and irreversible, so it is confirmed on the same
/// card every other order decision uses rather than a bespoke one.
Future<bool> showPosCancelOrderConfirm(
  BuildContext context, {
  required int orderId,
}) async {
  final bool? confirmed = await PosCompleteConfirmationDialog.show(
    context,
    heading: 'Cancel order #$orderId?',
    subtext: 'This cannot be undone. The order will stop being prepared.',
    cancelLabel: 'Keep order',
    confirmLabel: 'Cancel order',
  );

  return confirmed ?? false;
}
