import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

const Color _kCardBg = Color(0xFFFBF8EF);
const Color _kInk = Color(0xFF231F20);
const Color _kFilledText = Color(0xFFF3F3DD);

/// Asks "Remove <product>?" before a cart line is deleted.
///
/// Same visual language as the cart: cream card, Loew type, outlined
/// KEEP IT + filled black REMOVE (mirrors ADD COUPON / CHECK OUT), frosted
/// [KioskScrim] behind. Resolves true only when the guest taps REMOVE; a tap
/// on the scrim or KEEP IT resolves false.
Future<bool> showKioskRemoveItemDialog(
  BuildContext context, {
  required String productName,
  String? imageUrl,
}) async {
  final bool? result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false, // KioskScrim handles the outside tap.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, animation, _) => Stack(
      children: [
        Positioned.fill(
          child: KioskScrim(
            animation: animation,
            onDismiss: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Center(
          child: _RemoveItemCard(productName: productName, imageUrl: imageUrl),
        ),
      ],
    ),
    transitionBuilder: (ctx, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

class _RemoveItemCard extends StatelessWidget {
  final String productName;
  final String? imageUrl;
  const _RemoveItemCard({required this.productName, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final double s = KioskLayout.scaleOf(context);
    final double screenW = MediaQuery.sizeOf(context).width;
    final double width = (1500 * s).clamp(300.0, screenW - 32);
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        padding: EdgeInsets.fromLTRB(80 * s, 80 * s, 80 * s, 70 * s),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(48 * s),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 80 * s,
              offset: Offset(0, 30 * s),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImage)
              Container(
                width: 280 * s,
                height: 280 * s,
                padding: EdgeInsets.all(24 * s),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CustomImageWidget(
                  image: imageUrl!,
                  placeholder: Images.placeholderImage,
                  emptyWhenMissing: true,
                  fit: BoxFit.contain,
                ),
              )
            else
              Container(
                width: 200 * s,
                height: 200 * s,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline,
                    size: 100 * s, color: _kFilledText),
              ),
            SizedBox(height: 56 * s),
            Text(
              kioskTranslate(context, 'kiosk_remove_item_title', 'REMOVE ITEM?'),
              textAlign: TextAlign.center,
              style: loewRegular700.copyWith(
                fontSize: 44 * s,
                letterSpacing: 4 * s,
                color: TextTones.secondary,
              ),
            ),
            SizedBox(height: 24 * s),
            Text(
              productName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: loewExtraBold.copyWith(
                fontSize: 96 * s,
                height: 1.1,
                color: _kInk,
              ),
            ),
            SizedBox(height: 32 * s),
            Text(
              kioskTranslate(context, 'kiosk_remove_item_body',
                  'Are you sure you want to remove this item from your order?'),
              textAlign: TextAlign.center,
              style: loewRegular.copyWith(
                fontSize: 56 * s,
                height: 1.3,
                color: TextTones.secondary,
              ),
            ),
            SizedBox(height: 80 * s),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    s: s,
                    label: kioskTranslate(
                        context, 'kiosk_remove_item_keep', 'KEEP IT'),
                    filled: false,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                ),
                SizedBox(width: 40 * s),
                Expanded(
                  child: _DialogButton(
                    s: s,
                    label: kioskTranslate(
                        context, 'kiosk_remove_item_confirm', 'REMOVE'),
                    filled: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final double s;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _DialogButton(
      {required this.s,
      required this.label,
      required this.filled,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double height = (180 * s).clamp(52.0, 180.0);
    return Material(
      color: filled ? Colors.black : Colors.transparent,
      borderRadius: BorderRadius.circular(30 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30 * s),
            border: filled
                ? null
                : Border.all(color: Colors.black, width: (8 * s).clamp(2.0, 10.0)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: (filled ? loewRegular800 : loewRegular700).copyWith(
              fontSize: 52 * s,
              letterSpacing: 1,
              color: filled ? _kFilledText : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
