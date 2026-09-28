import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_detail_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// The order's side exits — the two things it can do that are not "move
/// forward".
///
/// These are the kitchen's own whole-order menu (`status_action_sheet.dart:
/// 70-89`) brought to the POS: Pause / Resume and Cancel, and deliberately
/// nothing else. Completing an order is not here — it is the primary CTA, the
/// same split the kitchen makes.
enum PosOrderMenuAction { hold, resume, cancel }

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
Future<PosOrderMenuAction?> showPosOrderMoreMenu(
  BuildContext context, {
  required Offset anchor,
  required Size buttonSize,
  required bool isHeld,
}) {
  final Size screen = MediaQuery.sizeOf(context);

  const double width = PosOrderDetailSpec.moreMenuWidth;
  final int rows = isHeld ? 2 : 2;
  final double height = rows * PosOrderDetailSpec.moreMenuRowHeight +
      PosOrderDetailSpec.moreMenuPadV * 2;

  double left = anchor.dx;
  left = left.clamp(12.0, (screen.width - width - 12).clamp(12.0, screen.width));

  // Above the button by preference; below it if there is no room up there.
  double top = anchor.dy - height - PosOrderDetailSpec.moreMenuGap;
  if (top < 12) top = anchor.dy + buttonSize.height + PosOrderDetailSpec.moreMenuGap;

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
          child: _MoreMenuPanel(isHeld: isHeld),
        ),
      ],
    ),
  );
}

class _MoreMenuPanel extends StatelessWidget {
  final bool isHeld;

  const _MoreMenuPanel({required this.isHeld});

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
            // Resume rather than Pause while held — the same swap the kitchen
            // menu makes, so the one row always offers the move that applies.
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
