import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
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
    return Opacity(
      opacity: enabled ? 1 : PosOrderDetailSpec.itemActionDisabledOpacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _open(context) : null,
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
    );
  }

  Future<void> _open(BuildContext context) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Offset origin = box.localToGlobal(Offset.zero);
    final PosOrderMenuAction? action = await showPosOrderMoreMenu(
      context,
      anchor: origin,
      buttonSize: box.size,
      isHeld: isHeld,
    );

    if (action == null) return;
    await onSelected(action);
  }
}

/// Opens the compact menu above the ⋯ button.
///
/// Positioned rather than centred: the button lives in the sticky bar at the
/// bottom of the modal, so the menu opens upward and stays clear of the screen
/// edge on a narrow terminal.
///
/// [advanceLabel] adds the forward rung as the first row (the board card's
/// menu); [sideExits] false leaves Pause / Resume / Cancel out (an order that
/// can only be advanced). [openBelow] is for a button at the top of its
/// surface — the card's ⋮ — so the menu drops under it, right-aligned to it.
Future<PosOrderMenuAction?> showPosOrderMoreMenu(
  BuildContext context, {
  required Offset anchor,
  required Size buttonSize,
  required bool isHeld,
  String? advanceLabel,
  bool sideExits = true,
  bool openBelow = false,
}) {
  final Size screen = MediaQuery.sizeOf(context);

  const double width = PosOrderDetailSpec.moreMenuWidth;
  final int rows = (advanceLabel == null ? 0 : 1) + (sideExits ? 2 : 0);
  final double height = rows * PosOrderDetailSpec.moreMenuRowHeight +
      PosOrderDetailSpec.moreMenuPadV * 2;

  double left = openBelow ? anchor.dx + buttonSize.width - width : anchor.dx;
  left = left.clamp(12.0, (screen.width - width - 12).clamp(12.0, screen.width));

  final double above = anchor.dy - height - PosOrderDetailSpec.moreMenuGap;
  final double below =
      anchor.dy + buttonSize.height + PosOrderDetailSpec.moreMenuGap;

  // The preferred side first; the other one if there is no room there.
  double top;
  if (openBelow) {
    top = below + height > screen.height - 12 && above >= 12 ? above : below;
  } else {
    top = above < 12 ? below : above;
  }

  return showGeneralDialog<PosOrderMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    useRootNavigator: false,
    pageBuilder: (_, __, ___) => Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: _MoreMenuPanel(
            isHeld: isHeld,
            advanceLabel: advanceLabel,
            sideExits: sideExits,
          ),
        ),
      ],
    ),
  );
}

class _MoreMenuPanel extends StatelessWidget {
  final bool isHeld;
  final String? advanceLabel;
  final bool sideExits;

  const _MoreMenuPanel({
    required this.isHeld,
    required this.advanceLabel,
    required this.sideExits,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
              ),
            if (sideExits) ...[
              // Resume rather than Pause while held — the same swap the
              // kitchen menu makes, so the one row always offers the move that
              // applies.
              if (isHeld)
                const _MoreMenuRow(
                  action: PosOrderMenuAction.resume,
                  label: 'Resume order',
                  icon: Icons.play_arrow_rounded,
                )
              else
                const _MoreMenuRow(
                  action: PosOrderMenuAction.hold,
                  label: 'Mark on hold',
                  icon: Icons.pause_circle_outlined,
                ),
              const _MoreMenuRow(
                action: PosOrderMenuAction.cancel,
                label: 'Cancel order',
                icon: Icons.cancel_outlined,
                danger: true,
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

  const _MoreMenuRow({
    required this.action,
    required this.label,
    required this.icon,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        danger ? PosHomeSpec.contextMenuDanger : PosOrderDetailSpec.ink;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(action),
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
