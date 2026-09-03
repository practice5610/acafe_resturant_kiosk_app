import 'package:acafe_customer/features/coupon/domain/models/coupon_apply_result.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Compact POS dialog to type a coupon code and apply it via [CouponProvider].
///
/// Used by the receipt context menu's "Apply discount" / "Apply custom
/// discount" actions — same backend path the kiosk coupon screen uses.
Future<void> showPosCouponApplyDialog({
  required BuildContext context,
  required double orderAmount,
  String title = 'Apply discount',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _PosCouponApplyDialog(
      orderAmount: orderAmount,
      title: title,
    ),
  );
}

class _PosCouponApplyDialog extends StatefulWidget {
  final double orderAmount;
  final String title;

  const _PosCouponApplyDialog({
    required this.orderAmount,
    required this.title,
  });

  @override
  State<_PosCouponApplyDialog> createState() => _PosCouponApplyDialogState();
}

class _PosCouponApplyDialogState extends State<_PosCouponApplyDialog> {
  final TextEditingController _code = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a coupon code');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final CouponProvider coupon = context.read<CouponProvider>();
    final CouponApplyResult result =
        await coupon.applyCouponDetailed(code, widget.orderAmount);

    if (!mounted) return;

    if (result.isApplied) {
      Navigator.of(context).pop();
      showCustomSnackBarHelper(
        'Discount applied',
        isError: false,
      );
      return;
    }

    final String fallback = result.status == CouponApplyStatus.belowMinPurchase
        ? 'Minimum purchase not met'
        : 'Could not apply this code';
    setState(() {
      _submitting = false;
      _error = result.errorMessage?.trim().isNotEmpty == true
          ? result.errorMessage!.trim().replaceAll('_', ' ')
          : fallback;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PosHomeSpec.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosHomeSpec.fieldRadius),
      ),
      title: Text(
        widget.title,
        style: loewExtraBold.copyWith(
          fontSize: 16,
          color: PosHomeSpec.ink,
        ),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Coupon code',
              style: loewRegular.copyWith(
                fontSize: PosHomeSpec.fieldLabelSize,
                color: PosHomeSpec.inkAlpha(0.53),
              ),
            ),
            const SizedBox(height: PosHomeSpec.fieldLabelGap),
            TextField(
              controller: _code,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitting ? null : _submit(),
              style: loewMedium.copyWith(
                fontSize: PosHomeSpec.fieldTextSize,
                color: PosHomeSpec.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Enter code',
                hintStyle: loewRegular.copyWith(
                  fontSize: PosHomeSpec.fieldTextSize,
                  color: PosHomeSpec.inkAlpha(0.4),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(PosHomeSpec.fieldRadius),
                  borderSide: const BorderSide(
                    color: PosHomeSpec.ink,
                    width: PosHomeSpec.fieldBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(PosHomeSpec.fieldRadius),
                  borderSide: const BorderSide(
                    color: PosHomeSpec.ink,
                    width: PosHomeSpec.fieldBorder,
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: loewMedium.copyWith(
                  fontSize: 13,
                  color: PosHomeSpec.contextMenuDanger,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: loewMedium.copyWith(color: PosHomeSpec.inkAlpha(0.6)),
          ),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PosHomeSpec.ink,
                  ),
                )
              : Text(
                  'Apply',
                  style: loewBold.copyWith(color: PosHomeSpec.ink),
                ),
        ),
      ],
    );
  }
}
