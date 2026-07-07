import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:acafe_customer/common/enums/data_source_enum.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/helper/router_helper.dart';
// Notification bell popup disabled for now — see showNotification() below.
// import 'package:acafe_customer/features/notification/widgets/notifiation_popup_dialog_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class NotificationHelper {


  static Future<void> initialize(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize = const AndroidInitializationSettings('notification_icon');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationsSettings = InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
    flutterLocalNotificationsPlugin.initialize(initializationsSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {

        PayloadModel payload = PayloadModel.fromJson(jsonDecode('${notificationResponse.payload}'));
        try{
          if(notificationResponse.payload!.isNotEmpty) {
            if(payload.orderId != null && payload.orderId != 'null' && payload.orderId != '') {
              RouterHelper.getOrderDetailsRoute(payload.orderId);
            }else if(payload.type == 'message') {
               RouterHelper.getChatRoute();
            }else if(payload.type == 'general'){
              RouterHelper.getNotificationRoute();
            }
            else if(payload.type == 'referral'){
              RouterHelper.getWalletRoute();
            }
          }
        }catch (e) {
          debugPrint('error ===> $e');
        }
        return;
      },);


    FirebaseMessaging.onMessage.listen((RemoteMessage message)async {
      debugPrint('onMessage: ${message.notification!.title}/${message.notification!.body}/${message.notification!.titleLocKey}\n data: ${message.data}');
      final SplashProvider splashProvider = Provider.of<SplashProvider>(Get.context!, listen: false);

      if(message.data['type'] == 'maintenance'){
        await splashProvider.initConfig(Get.context!, DataSourceEnum.client);

        if(splashProvider.configModel?.maintenanceMode?.maintenanceStatus == 1 && splashProvider.configModel?.maintenanceMode?.selectedMaintenanceSystem?.customerApp == 1) {
          RouterHelper.getMaintainRoute(action: RouteAction.pushNamedAndRemoveUntil);
        }
        if(splashProvider.configModel?.maintenanceMode?.maintenanceStatus == 0
            && GoRouter.of(Get.context!).routeInformationProvider.value.uri.path == RouterHelper.maintain){

          RouterHelper.getMainRoute(action: RouteAction.pushNamedAndRemoveUntil);

        }
      }

      if(message.data['type'] != 'maintenance'){
        showNotification(message, flutterLocalNotificationsPlugin);
      }
    });


    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async{
      debugPrint('onMessageOpenedApp: ${message.notification!.title}/${message.notification!.body}/${message.notification!.titleLocKey}\n data: ${message.data}');
      final SplashProvider splashProvider = Provider.of<SplashProvider>(Get.context!, listen: false);

      if(message.data['type'] == 'maintenance'){
        //await splashProvider.initConfig(Get.context!);
        if(splashProvider.configModel?.maintenanceMode?.maintenanceStatus == 1 && splashProvider.configModel?.maintenanceMode?.selectedMaintenanceSystem?.customerApp == 1) {
          RouterHelper.getMaintainRoute(action: RouteAction.pushNamedAndRemoveUntil);
        }
        if(splashProvider.configModel?.maintenanceMode?.maintenanceStatus == 0 && ModalRoute.of(Get.context!)?.settings.name == RouterHelper.maintain){
          RouterHelper.getMaintainRoute(action: RouteAction.pushNamedAndRemoveUntil);
        }
      }

      if(message.data['type'] == 'general') {
        RouterHelper.getNotificationRoute();
      }

      if(message.data['type'] == 'referral') {
        RouterHelper.getWalletRoute();
      }

      try{
        if(message.notification!.titleLocKey != null && message.notification!.titleLocKey!.isNotEmpty) {
          RouterHelper.getOrderDetailsRoute(message.notification!.titleLocKey);
        }
      }catch (e) {
        debugPrint('error ===> $e');
      }

    });
  }

  static Future<void> showNotification(RemoteMessage message, FlutterLocalNotificationsPlugin fln) async {
    String? title;
    String? body;
    String? orderID;
    String? image;
    String? type = '';

    title = message.data['title'];
    body = message.data['body'];
    orderID = message.data['order_id'];
    image = (message.data['image'] != null && message.data['image'].isNotEmpty)
        ? message.data['image'].startsWith('http') ? message.data['image']
        : '${AppConstants.baseUrl}/storage/app/public/notification/${message.data['image']}' : null;

    if(message.data['type'] != null) {
      type = message.data['type'];
    }

    Map<String, String> payloadData = {
      'title' : '$title',
      'body' : '$body',
      'order_id' : '$orderID',
      'image' : '$image',
      'type' : '$type',
    };

    PayloadModel payload = PayloadModel.fromJson(payloadData);

    // NOTE: Notification bell popup disabled for now — do not show the
    // NotificationPopUpDialogWidget (bell icon + alarm) when an order is placed.
    // if(kIsWeb) {
    //   showDialog(
    //       context: Get.context!,
    //       builder: (context) => Center(
    //         child: NotificationPopUpDialogWidget(payload),
    //       )
    //   );
    // }




    // Kiosk terminals must stay silent on order status changes (including
    // order-complete). Every order-status push arrives as type 'order_status',
    // so mute the notification sound for that type only; all other notification
    // types (message/general/referral) keep their sound. This is unrelated to
    // the branch "Kitchen Notification Bell" setting, which the kiosk never reads.
    final bool playSound = type != 'order_status';

    if(image != null && image.isNotEmpty) {
      try{
        await showBigPictureNotificationHiddenLargeIcon(payload, fln, playSound: playSound);
      }catch(e) {
        await showBigTextNotification(payload, fln, playSound: playSound);
      }
    }else {
      await showBigTextNotification(payload, fln, playSound: playSound);
    }
  }


  static Future<void> showBigTextNotification(PayloadModel payload, FlutterLocalNotificationsPlugin fln, {bool playSound = true}) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      payload.body!, htmlFormatBigText: true,
      contentTitle: payload.title, htmlFormatContentTitle: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      AppConstants.appName, AppConstants.appName, importance: Importance.max,
      styleInformation: bigTextStyleInformation, priority: Priority.max, playSound: playSound,
      sound: playSound ? const RawResourceAndroidNotificationSound('notification') : null,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, payload.title, payload.body, platformChannelSpecifics, payload: jsonEncode(payload.toJson()));
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(
      PayloadModel payload, FlutterLocalNotificationsPlugin fln, {bool playSound = true}) async {
    final String largeIconPath = await _downloadAndSaveFile( payload.image!, 'largeIcon');
    final String bigPicturePath = await _downloadAndSaveFile( payload.image!, 'bigPicture');
    final BigPictureStyleInformation bigPictureStyleInformation = BigPictureStyleInformation(
      FilePathAndroidBitmap(bigPicturePath), hideExpandedLargeIcon: true,
      contentTitle: payload.title, htmlFormatContentTitle: true,
      summaryText:  payload.body, htmlFormatSummaryText: true,
    );
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      AppConstants.appName, AppConstants.appName,
      largeIcon: FilePathAndroidBitmap(largeIconPath), priority: Priority.max, playSound: playSound,
      styleInformation: bigPictureStyleInformation, importance: Importance.max,
      sound: playSound ? const RawResourceAndroidNotificationSound('notification') : null,
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0,  payload.title,  payload.body, platformChannelSpecifics, payload: jsonEncode(payload.toJson()));
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final Response response = await Dio().get(url, options: Options(responseType: ResponseType.bytes));
    final File file = File(filePath);
    await file.writeAsBytes(response.data);
    return filePath;
  }



}

Future<dynamic> myBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint("onBackground: ${message.notification!.title}/${message.notification!.body}/${message.notification!.titleLocKey}");
}

class PayloadModel {
  PayloadModel({
    this.title,
    this.body,
    this.orderId,
    this.image,
    this.type,
  });

  String? title;
  String? body;
  String? orderId;
  String? image;
  String? type;

  factory PayloadModel.fromRawJson(String str) => PayloadModel.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PayloadModel.fromJson(Map<String, dynamic> json) => PayloadModel(
    title: json["title"],
    body: json["body"],
    orderId: json["order_id"],
    image: json["image"],
    type: json["type"],
  );

  Map<String, dynamic> toJson() => {
    "title": title,
    "body": body,
    "order_id": orderId,
    "image": image,
    "type": type,
  };
}

