import 'dart:io';
import 'package:flutter/material.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:acafe_customer/common/widgets/custom_button_widget.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});


  @override
  Widget build(BuildContext context) {
    final splashProvider =  Provider.of<SplashProvider>(context, listen: false);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

            Image.asset(Images.update,
              width: (MediaQuery.of(context).size.height * 0.4).clamp(120.0, 480.0),
              height: (MediaQuery.of(context).size.height * 0.4).clamp(120.0, 480.0),
            ),
            SizedBox(height: MediaQuery.of(context).size.height*0.01),

            Text(getTranslated('your_app_is_deprecated', context)!,
              style: rubikRegular.copyWith(fontSize: (MediaQuery.of(context).size.height * 0.0175).clamp(14.0, 28.0), color: Theme.of(context).disabledColor),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MediaQuery.of(context).size.height*0.04),

             CustomButtonWidget(btnTxt: getTranslated('update_now', context), onTap: () async {
              String appUrl = 'https://google.com';

              if(Platform.isAndroid) {
                appUrl = splashProvider.configModel?.playStoreConfig?.link ?? '';
              }else if(Platform.isIOS) {
                appUrl = splashProvider.configModel?.appStoreConfig?.link ?? '';
              }
              if(await canLaunchUrl(Uri.parse(appUrl))) {
                launchUrl(Uri.parse(appUrl), mode: LaunchMode.externalApplication);

              }else {
                if(context.mounted){
                  showCustomSnackBarHelper('${getTranslated('can_not_launch', context)} $appUrl');
                }
              }
            }),

          ]),
        ),
      ),
    );
  }
}
