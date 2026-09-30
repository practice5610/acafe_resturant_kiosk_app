import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/error_response_model.dart';
import 'package:acafe_customer/localization/app_localization.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:provider/provider.dart';

class ApiCheckerHelper {
  static bool _isOnKioskBootstrapRoute() {
    final context = Get.context;
    if (context == null) return false;
    final path =
        GoRouter.of(context).routeInformationProvider.value.uri.path;
    return path == RouterHelper.kioskLoginScreen ||
        path == RouterHelper.splashScreen ||
        path == RouterHelper.kioskBootstrapScreen;
  }

  static void checkApi(ApiResponseModel apiResponse,{bool firebaseResponse = false} ) {
    ErrorResponseModel error = getError(apiResponse);

    Future.delayed(const Duration(milliseconds: 0)).then((value) {
      if( error.errors![0].code == '401' || error.errors![0].code == 'auth-001'
          &&  ModalRoute.of(Get.context!)?.settings.name != RouterHelper.kioskLoginScreen) {
        // Kiosk device token revoked / device set inactive mid-session: wipe the
        // device session and send the kiosk back to the device login screen.
        Provider.of<KioskAuthProvider>(Get.context!, listen: false).logout().then((value) {
          if(Get.context != null && ModalRoute.of(Get.context!)?.settings.name != RouterHelper.kioskLoginScreen) {
            RouterHelper.getKioskLoginRoute(action: RouteAction.pushNamedAndRemoveUntil);
          }
        });

      } else if (error.errors![0].code == 'permission-denied') {
        // A staff member tried something their role does not allow. The device
        // session is fine and must not be touched -- this is an answer, not an
        // auth failure, so it gets a plain sentence and nothing else.
        showCustomSnackBarHelper("You don't have permission to do that.");
      } else if (error.errors![0].code == 'no-staff-session') {
        // The staff token no longer stands for anybody. The staff interceptor
        // has already put the PIN screen back up; nothing to say here.
        return;
      }else {
        // Background boot calls (config cache, policy pages, etc.) should not
        // flash errors on the kiosk login screen when the API is unreachable.
        if (_isOnKioskBootstrapRoute()) return;
        showCustomSnackBarHelper(firebaseResponse ? error.errors?.first.message?.replaceAll('_', ' ').toCapitalized() : error.errors!.first.message);
      }
    });


  }

  static ErrorResponseModel getError(ApiResponseModel apiResponse){
    ErrorResponseModel error;

    try{
      error = ErrorResponseModel.fromJson(apiResponse);
    }catch(e){
      if(apiResponse.error is String){
        error = ErrorResponseModel(errors: [Errors(code: '', message: apiResponse.error.toString())]);

      }else{
        error = ErrorResponseModel.fromJson(apiResponse.error);
      }
    }
    return error;
  }
}