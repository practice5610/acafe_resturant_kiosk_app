import 'package:flutter/material.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/common/widgets/custom_button_widget.dart';
import 'package:acafe_customer/helper/responsive_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

class NoDataWidget extends StatelessWidget {
  final bool isOrder;
  final bool isCart;
  final bool isNothing;
  final bool isFooter;
  final bool isAddress;
  final bool isCoupon;

  const NoDataWidget({
    super.key,
    this.isCart = false,
    this.isNothing = false,
    this.isOrder = false,
    this.isFooter = true,
    this.isAddress = false,
    this.isCoupon = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Center(
      child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [

        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: !ResponsiveHelper.isDesktop(context) && height < 600 ? height : height - 450,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

              Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

                  SizedBox(
                    height: 110, width: 110,
                    child: CustomAssetImageWidget(
                      isCoupon? Images.noCouponSvg : isOrder ? Images.emptyBoxSvg : isCart ? Images.emptyCartSvg
                          : isAddress ? Images.noAddressSvg : Images.noFoodImage,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                  Text(
                    getTranslated(
                      isCoupon? 'no_promo_available' : isOrder ? 'no_order_history' : isCart ? 'your_cart_is_empty'
                      : isAddress ? 'no_saved_address_found' : 'nothing_found', context,
                    )!,
                    style: rubikSemiBold.copyWith(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: Dimensions.fontSizeLarge),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  Text(
                     getTranslated(
                       isOrder ? 'you_havent_made_any_purchase_yet' : isCart ? 'please_add_some_items_from_the_menu'
                       : isAddress ? 'please_add_your_address_for_your_better_experience' : '', context,
                     )!,
                    style: rubikRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor), textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),

                  if(isOrder || isCart) SizedBox(
                    width: 220,
                    height: 40,
                    child: CustomButtonWidget(
                        onTap: ()=> RouterHelper.getSearchResultRoute(''),
                        btnTxt: getTranslated('explore_menu', context)!,
                      ),
                  ),

                ]),
              ),
          ]),
        ),

      ])),
    );
  }
}
