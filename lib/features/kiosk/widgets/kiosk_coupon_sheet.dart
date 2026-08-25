import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_model.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

const Color _kFieldBg = Color(0xFFFBF8EF);
const Color _kCardBg = Colors.white;

/// Kiosk coupon entry sheet — text field, apply/remove, and available promo list.
/// Narrow screens scale via [KioskResponsive]; wide screens use fixed [KioskUI] tokens.
class KioskCouponSheet extends StatefulWidget {
  final double orderAmount;

  const KioskCouponSheet({super.key, required this.orderAmount});

  static const double maxSheetWidth = 640;

  @override
  State<KioskCouponSheet> createState() => _KioskCouponSheetState();
}

class _KioskCouponSheetState extends State<KioskCouponSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final coupon = Provider.of<CouponProvider>(context, listen: false);
    _controller = TextEditingController(text: coupon.coupon?.code ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      coupon.getCouponList(orderAmount: widget.orderAmount);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply(CouponProvider coupon, String code, {int? index}) async {
    coupon.removeCouponData(true);
    if (code.isEmpty) {
      showCustomSnackBarHelper(
        getTranslated('enter_a_Coupon_code', context) ?? 'Enter a coupon code',
      );
      return;
    }
    if (coupon.isLoading) return;

    final discount = await coupon.applyCoupon(code, widget.orderAmount,
        selectedIndex: index);
    if (!mounted) return;

    if ((discount ?? 0) > 0) {
      context.pop();
      showCustomSnackBarHelper(
        '${getTranslated('you_got', context) ?? 'You got'} '
        '${PriceConverterHelper.convertPrice(discount)} '
        '${getTranslated('discount', context) ?? 'discount'}',
        isError: false,
      );
    } else {
      showCustomSnackBarHelper(
        getTranslated('invalid_code_or', context) ?? 'Invalid code',
        isError: true,
      );
    }
  }

  void _remove(CouponProvider coupon) {
    _controller.clear();
    coupon.removeCouponData(true);
    showCustomSnackBarHelper(
      getTranslated('coupon_removed_successfully', context) ?? 'Coupon removed',
      isError: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = Responsive.isWide(context);
        final double s =
            wide ? 1.0 : KioskResponsive.scale(constraints.maxWidth);

        final double titleSize =
            wide ? KioskUI.heading : (48 * s).clamp(28.0, 36.0);
        final double bodySize =
            wide ? KioskUI.body : (32 * s).clamp(16.0, 22.0);
        final double fieldHeight = wide ? 56.0 : (88 * s).clamp(52.0, 64.0);
        final double radius = wide ? KioskUI.radius : 20 * s;
        final double hPad = wide ? 24.0 : 32 * s;
        final double vPad = wide ? 16.0 : 24 * s;
        final double listMaxHeight = wide
            ? 280.0
            : (MediaQuery.sizeOf(context).height * 0.28).clamp(160.0, 240.0);

        return Material(
          color: KioskUI.pageBg,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(wide ? 28 : 24 * s),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        (getTranslated('add_coupon', context) ?? 'ADD COUPON')
                            .toUpperCase(),
                        style: loewExtraBold.copyWith(
                          fontSize: titleSize,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    KioskTap(
                      onTap: () => context.pop(),
                      child: Container(
                        width: wide ? 44 : 52,
                        height: wide ? 44 : 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Icon(Icons.close,
                            size: wide ? 20 : 22, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Consumer<CouponProvider>(
                  builder: (context, coupon, _) {
                    final bool applied = (coupon.discount ?? 0) > 0;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (applied) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: wide ? 16 : 32 * s,
                              vertical: wide ? 12 : 24 * s,
                            ),
                            decoration: BoxDecoration(
                              color: _kFieldBg,
                              borderRadius: BorderRadius.circular(radius),
                              border: Border.all(color: Colors.black26),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.black,
                                    size: wide ? 22 : 44 * s),
                                SizedBox(width: wide ? 10 : 20 * s),
                                Expanded(
                                  child: Text(
                                    '${coupon.coupon?.code ?? ''} — '
                                    '${getTranslated('applied_you_saved', context) ?? 'Applied'} '
                                    '${PriceConverterHelper.convertPrice(coupon.discount)}',
                                    style: loewMedium.copyWith(
                                      fontSize: bodySize,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                KioskTap(
                                  onTap: () => _remove(coupon),
                                  child: Icon(Icons.close,
                                      size: wide ? 22 : 44 * s,
                                      color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: wide ? 16 : 32 * s),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: AbsorbPointer(
                                absorbing: applied,
                                child: Container(
                                  height: fieldHeight,
                                  alignment: Alignment.center,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: wide ? 16 : 40 * s,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kFieldBg,
                                    borderRadius: BorderRadius.circular(radius),
                                    border: Border.all(
                                      color: _kCheckoutHintColor,
                                      width: wide ? 1.5 : 2 * s,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    textAlign: TextAlign.center,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    style: loewRegular.copyWith(
                                      fontSize: wide ? 18 : 52 * s,
                                      color: Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      isCollapsed: true,
                                      border: InputBorder.none,
                                      hintText: getTranslated(
                                              'enter_coupon', context) ??
                                          'Enter coupon',
                                      hintStyle: loewRegular.copyWith(
                                        fontSize: wide ? 18 : 52 * s,
                                        color: _kCheckoutHintColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: wide ? 12 : 24 * s),
                            Material(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(radius),
                              clipBehavior: Clip.antiAlias,
                              child: KioskTap(
                                onTap: applied
                                    ? () => _remove(coupon)
                                    : coupon.isLoading
                                        ? null
                                        : () => _apply(
                                              coupon,
                                              _controller.text.trim(),
                                            ),
                                child: Container(
                                  width: wide ? 100 : 120,
                                  height: fieldHeight,
                                  alignment: Alignment.center,
                                  child: coupon.isLoading
                                      ? SizedBox(
                                          width: wide ? 24 : 40 * s,
                                          height: wide ? 24 : 40 * s,
                                          child:
                                              const CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Text(
                                          applied
                                              ? (getTranslated(
                                                      'remove', context) ??
                                                  'REMOVE')
                                              : (getTranslated(
                                                      'apply', context) ??
                                                  'APPLY'),
                                          style: loewExtraBold.copyWith(
                                            fontSize: bodySize,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(height: wide ? 12 : 16 * s),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listMaxHeight),
                child: Consumer<CouponProvider>(
                  builder: (context, coupon, _) {
                    if (coupon.availableCouponList == null) {
                      return _CouponListShimmer(wide: wide, s: s);
                    }
                    if ((coupon.availableCouponList?.isEmpty ?? true) &&
                        (coupon.unavailableCouponList?.isEmpty ?? true)) {
                      return _NoCouponsEmpty(wide: wide, s: s);
                    }
                    return ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, vPad),
                      children: [
                        if (coupon.availableCouponList?.isNotEmpty ??
                            false) ...[
                          Text(
                            getTranslated('available_coupon_for_this_order',
                                    context) ??
                                'Available for this order',
                            style: loewBold.copyWith(
                              fontSize: wide ? KioskUI.section : 54 * s,
                              color: Colors.black,
                            ),
                          ),
                          SizedBox(height: wide ? 12 : 24 * s),
                          for (int i = 0;
                              i < coupon.availableCouponList!.length;
                              i++)
                            Padding(
                              padding:
                                  EdgeInsets.only(bottom: wide ? 12 : 24 * s),
                              child: _KioskCouponCard(
                                wide: wide,
                                s: s,
                                coupon: coupon.availableCouponList![i],
                                isAvailable: true,
                                onApply: () => _apply(
                                  coupon,
                                  coupon.availableCouponList![i].code ?? '',
                                  index: i,
                                ),
                              ),
                            ),
                        ],
                        if (coupon.unavailableCouponList?.isNotEmpty ??
                            false) ...[
                          SizedBox(height: wide ? 8 : 16 * s),
                          Text(
                            getTranslated('unavailable_coupon', context) ??
                                'Unavailable',
                            style: loewBold.copyWith(
                              fontSize: wide ? KioskUI.section : 54 * s,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(height: wide ? 12 : 24 * s),
                          for (final c in coupon.unavailableCouponList!)
                            Padding(
                              padding:
                                  EdgeInsets.only(bottom: wide ? 12 : 24 * s),
                              child: _KioskCouponCard(
                                wide: wide,
                                s: s,
                                coupon: c,
                                isAvailable: false,
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

const Color _kCheckoutHintColor = Color(0xFFB9B5A6);

class _KioskCouponCard extends StatelessWidget {
  final bool wide;
  final double s;
  final CouponModel? coupon;
  final bool isAvailable;
  final VoidCallback? onApply;

  const _KioskCouponCard({
    required this.wide,
    required this.s,
    required this.coupon,
    required this.isAvailable,
    this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final double bodySize = wide ? KioskUI.body : 40 * s;
    final double captionSize = wide ? KioskUI.caption : 34 * s;
    final double radius = wide ? 14.0 : 28 * s;

    return Opacity(
      opacity: isAvailable ? 1 : 0.45,
      child: Material(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: isAvailable ? onApply : null,
          child: Container(
            padding: EdgeInsets.all(wide ? 16 : 32 * s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              children: [
                CustomAssetImageWidget(
                  Images.couponIcon,
                  width: wide ? 36 : 72 * s,
                  height: wide ? 36 : 72 * s,
                ),
                SizedBox(width: wide ? 14 : 28 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon?.code?.toUpperCase() ?? '',
                        style: loewExtraBold.copyWith(
                          fontSize: bodySize,
                          color: Colors.black,
                        ),
                      ),
                      if ((coupon?.title ?? '').isNotEmpty) ...[
                        SizedBox(height: wide ? 4 : 8 * s),
                        Text(
                          coupon!.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: loewRegular.copyWith(
                            fontSize: captionSize,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      SizedBox(height: wide ? 6 : 12 * s),
                      Text(
                        PriceConverterHelper.getDiscountType(
                          discount: coupon?.discount,
                          discountType: coupon?.discountType,
                        ),
                        style: loewBold.copyWith(
                          fontSize: bodySize,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAvailable && onApply != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 14 : 28 * s,
                      vertical: wide ? 8 : 16 * s,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(wide ? 10 : 20 * s),
                    ),
                    child: Text(
                      getTranslated('apply', context)?.toUpperCase() ?? 'APPLY',
                      style: loewExtraBold.copyWith(
                        fontSize: captionSize,
                        color: Colors.white,
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

class _NoCouponsEmpty extends StatelessWidget {
  final bool wide;
  final double s;
  const _NoCouponsEmpty({required this.wide, required this.s});

  @override
  Widget build(BuildContext context) {
    final double artSize = wide ? 100.0 : (140 * s).clamp(80.0, 120.0);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 24 : 32 * s,
          vertical: wide ? 16 : 20 * s,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomAssetImageWidget(
              Images.noCouponSvg,
              width: artSize,
              height: artSize,
            ),
            SizedBox(height: wide ? 12 : 16 * s),
            Text(
              getTranslated('no_promo_available', context) ??
                  'No promos available',
              textAlign: TextAlign.center,
              style: loewMedium.copyWith(
                fontSize: wide ? KioskUI.body : (28 * s).clamp(14.0, 18.0),
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponListShimmer extends StatelessWidget {
  final bool wide;
  final double s;
  const _CouponListShimmer({required this.wide, required this.s});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 24 : 60 * s,
        vertical: wide ? 12 : 24 * s,
      ),
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        height: wide ? 88 : 160 * s,
        margin: EdgeInsets.only(bottom: wide ? 12 : 24 * s),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(wide ? 14 : 28 * s),
        ),
      ),
    );
  }
}
