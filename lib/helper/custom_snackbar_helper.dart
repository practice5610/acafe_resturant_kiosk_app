import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/responsive_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:go_router/go_router.dart';

enum SnackBarStatus {error, success, alert, info}

/// Bottom inset so floating snackbars sit above the kiosk menu cart bar.
double kioskMenuSnackBarBottomMargin(BuildContext context) {
  final media = MediaQuery.of(context);
  final double cartBarHeight = Responsive.isWide(context)
      ? KioskUI.cartBarHeight + 20 // bar + vertical margins
      : 340 * KioskResponsive.scale(media.size.width); // filled cart bar + padding
  return cartBarHeight + media.padding.bottom + Dimensions.paddingSizeSmall;
}

bool _isKioskMenuRoute(BuildContext context) {
  try {
    final path =
        GoRouter.of(context).routeInformationProvider.value.uri.path;
    return path == RouterHelper.kioskMenuScreen;
  } catch (_) {
    return false;
  }
}

EdgeInsets _snackBarMargin(BuildContext context) {
  final size = MediaQuery.of(context).size;
  if (_isKioskMenuRoute(context)) {
    return EdgeInsets.only(
      left: Dimensions.paddingSizeDefault,
      right: Dimensions.paddingSizeDefault,
      bottom: kioskMenuSnackBarBottomMargin(context),
    );
  }
  if (ResponsiveHelper.isDesktop(context)) {
    return EdgeInsets.only(
      right: size.width * 0.7,
      bottom: Dimensions.paddingSizeExtraSmall,
      left: Dimensions.paddingSizeExtraSmall,
    );
  }
  return EdgeInsets.only(bottom: size.height * 0.08);
}

void showCustomSnackBarHelper(String? message, {
  bool isError = true, bool isToast = false, SnackBarStatus? snackBarStatus}) {

  final context = Get.context!;

  ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(
    elevation: 0,
    shape: OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: Colors.transparent)
    ),
    content: Align(alignment: Alignment.center,
      child: Material(color: Colors.black, elevation: 0, borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 60,
          ),
          padding: const EdgeInsets.all(Dimensions.paddingSizeDefault),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [


            snackBarStatus != null && snackBarStatus == SnackBarStatus.info ? const Icon(
              Icons.warning_rounded,
              color: Colors.orangeAccent,
              size: 22, // Icon size
            ) : CircleAvatar(
              radius: 12, // Adjust radius as needed
              backgroundColor: isError ? Colors.red : Colors.green, // Background color of the circle
              child: Icon(
                isError ? Icons.close_rounded : Icons.check,
                color: Colors.white,
                size: 16, // Icon size
              ),
            ),

            const SizedBox(width: Dimensions.paddingSizeSmall),

            Flexible(child: Text(
              message ?? '',
              style: rubikBold.copyWith(
                color: Colors.white,
                fontSize: Dimensions.fontSizeDefault,
              ),
            )),

          ]),
        ),
      ),
    ),
    margin: _snackBarMargin(context),
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,

  ));

}