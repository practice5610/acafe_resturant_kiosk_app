import 'package:flutter/material.dart';

import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/utill/styles.dart';

/// B-04 "Cancel your order?" confirmation. Resolves `true` when the customer
/// confirms (YES, CANCEL) and `false` when they keep ordering or dismiss.
///
/// The caller clears the cart and returns to the start screen on `true`; the
/// dialog itself owns no cart or navigation state, so it is pure and testable.
Future<bool> showLandscapeCancelOrderDialog(
  BuildContext context, {
  required double s,
  int? itemCount,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => _LandscapeCancelDialog(s: s, itemCount: itemCount),
  );
  return result ?? false;
}

class _LandscapeCancelDialog extends StatelessWidget {
  final double s;
  final int? itemCount;
  const _LandscapeCancelDialog({required this.s, this.itemCount});

  @override
  Widget build(BuildContext context) {
    final String subtitle = itemCount != null
        ? kioskTranslate(
            context,
            'landscape_cancel_order_body_count',
            'All {count} items will be removed and you go back to the start screen.',
          ).replaceAll('{count}', '$itemCount')
        : kioskTranslate(
            context,
            'landscape_cancel_order_body',
            'All items will be removed and you go back to the start screen.',
          );

    return Center(
      child: Material(
        color: KioskUI.card,
        borderRadius: BorderRadius.circular(18 * s),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 560 * s,
          padding: EdgeInsets.fromLTRB(40 * s, 40 * s, 40 * s, 32 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kioskTranslate(
                    context, 'landscape_cancel_order_title', 'Cancel your order?'),
                textAlign: TextAlign.center,
                style: loewExtraBold.copyWith(
                    fontSize: 28 * s, height: 1.1, color: Colors.black),
              ),
              SizedBox(height: 12 * s),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: swiss721Light.copyWith(
                    fontSize: 16 * s, height: 1.3, color: const Color(0xFF73736E)),
              ),
              SizedBox(height: 28 * s),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      s: s,
                      filled: false,
                      label: kioskTranslate(
                          context, 'landscape_cancel_order_confirm', 'YES, CANCEL'),
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                  SizedBox(width: 16 * s),
                  Expanded(
                    child: _DialogButton(
                      s: s,
                      filled: true,
                      label: kioskTranslate(
                          context, 'landscape_keep_ordering', 'KEEP ORDERING'),
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final double s;
  final bool filled;
  final String label;
  final VoidCallback onTap;
  const _DialogButton({
    required this.s,
    required this.filled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.black : Colors.transparent,
      borderRadius: BorderRadius.circular(10 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          height: 60 * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10 * s),
            border: Border.all(color: Colors.black, width: (1.5 * s).clamp(1.0, 3.0)),
          ),
          child: Text(
            label,
            style: loewBold.copyWith(
                fontSize: 17 * s,
                color: filled ? Colors.white : Colors.black),
          ),
        ),
      ),
    );
  }
}
