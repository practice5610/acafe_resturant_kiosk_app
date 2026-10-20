import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Receipt-history actions menu — Figma **1915:20747**.
///
/// Anchors right-aligned under the ⋯ button in [PosReceiptHeader].
Future<void> showPosReceiptActionsMenu({
  required BuildContext context,
  required BuildContext anchorContext,
  VoidCallback? onChangeMethod,
  VoidCallback? onReopenReceipt,
}) async {
  final RenderBox btn =
      anchorContext.findRenderObject()! as RenderBox;
  final Offset btnTopLeft = btn.localToGlobal(Offset.zero);
  final double btnRight = btnTopLeft.dx + btn.size.width;
  final double btnBottom = btnTopLeft.dy + btn.size.height;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    pageBuilder: (dialogContext, __, ___) => Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned(
            top: btnBottom + PosHomeSpec.contextMenuAnchorGap,
            right: MediaQuery.of(context).size.width - btnRight,
            child: _PosReceiptActionsPanel(
              onClose: () => Navigator.of(dialogContext).pop(),
              onChangeMethod: onChangeMethod == null
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      onChangeMethod();
                    },
              onReopenReceipt: onReopenReceipt == null
                  ? null
                  : () {
                      Navigator.of(dialogContext).pop();
                      onReopenReceipt();
                    },
            ),
          ),
        ],
      ),
    ),
  );
}

class _PosReceiptActionsPanel extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onChangeMethod;
  final VoidCallback? onReopenReceipt;

  const _PosReceiptActionsPanel({
    required this.onClose,
    this.onChangeMethod,
    this.onReopenReceipt,
  });

  static const double _padding = PosHomeSpec.contextMenuPadding;
  static const double _headerH = PosHomeSpec.contextMenuHeaderHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PosHomeSpec.contextMenuWidth,
      decoration: BoxDecoration(
        color: PosHomeSpec.panelBg,
        border: Border.all(
          color: PosHomeSpec.contextMenuBorder,
          width: PosHomeSpec.contextMenuBorderWidth,
        ),
        borderRadius: BorderRadius.circular(PosHomeSpec.contextMenuRadius),
        boxShadow: [
          BoxShadow(
            color: PosHomeSpec.ink.withValues(
                alpha: PosHomeSpec.contextMenuShadowOpacity),
            blurRadius: PosHomeSpec.contextMenuShadowBlur,
            offset: PosHomeSpec.contextMenuShadowOffset,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header label
            SizedBox(
              height: _headerH,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: PosHomeSpec.contextMenuHeaderPaddingTop,
                  bottom: PosHomeSpec.contextMenuHeaderPaddingBottom,
                  left: PosHomeSpec.contextMenuHeaderPaddingH,
                  right: PosHomeSpec.contextMenuHeaderPaddingH,
                ),
                child: Text(
                  'RECEIPT ACTIONS',
                  style: loewBold.copyWith(
                    fontSize: PosHomeSpec.contextMenuHeaderSize,
                    color: TextTones.hint,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            _ActionItem(label: 'Change payment method', onTap: onChangeMethod),
            _ActionItem(label: 'Reopen receipt', onTap: onReopenReceipt),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final String label;

  /// Null = deferred/inert — rendered at 40% opacity.
  final VoidCallback? onTap;

  const _ActionItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.40 : 1.0,
      child: Material(
        color: Colors.transparent,
        borderRadius:
            BorderRadius.circular(PosHomeSpec.contextMenuItemRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(PosHomeSpec.contextMenuItemRadius),
          child: SizedBox(
            height: PosReceiptsSpec.actionsMenuItemHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PosHomeSpec.contextMenuItemPaddingH,
                vertical: PosHomeSpec.contextMenuItemPaddingV,
              ),
              child: Text(
                label,
                style: loewMedium.copyWith(
                  fontSize: PosHomeSpec.contextMenuItemLabelSize,
                  color: PosHomeSpec.ink,
                  height: PosHomeSpec.contextMenuItemLabelHeight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
