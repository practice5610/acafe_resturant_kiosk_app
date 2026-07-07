import 'dart:io';
import 'package:dio/dio.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClient {
  final String baseUrl;
  final LoggingInterceptor loggingInterceptor;
  final SharedPreferences sharedPreferences;

  Dio? dio;
  String? token;

  DioClient(this.baseUrl,
      Dio? dioC, {
        required this.loggingInterceptor,
        required this.sharedPreferences,
      }) {
    token = sharedPreferences.getString(AppConstants.token);
    dio = dioC ?? Dio();

    updateHeader(dioC: dioC, getToken: token);


  }

  Future<void> updateHeader({String? getToken, Dio? dioC})async {
    dio
      ?..options.baseUrl = baseUrl
      ..options.connectTimeout = const Duration(seconds: 30)
      ..options.receiveTimeout = const Duration(seconds: 30)
      ..httpClientAdapter
      ..options.headers = {

        'Content-Type': 'application/json; charset=UTF-8',
        'branch-id': '${sharedPreferences.getInt(AppConstants.branch)}',
        'X-localization': sharedPreferences.getString(AppConstants.languageCode)
            ?? 'en',
        'Authorization': 'Bearer $getToken',
        'ngrok-skip-browser-warning': 'true',

      };
    dio?.interceptors.add(loggingInterceptor);
  }



  Future<Response> get(String uri, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      var response = await dio!.get(
        uri,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on SocketException catch (e) {
      throw SocketException(e.toString());
    } on FormatException catch (_) {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      var response = await dio!.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on FormatException catch (_) {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      var response = await dio!.put(
        uri,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on FormatException catch (_) {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> delete(String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      var response = await dio!.delete(
        uri,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      return response;
    } on FormatException catch (_) {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }


  Future<Response> postMultipart(String uri, {
    Map<String, dynamic>? data,
    List<XFile?>? files,
    String? fileKey,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try{
      List<MultipartFile> fileList = [];

      if(files != null) {
        for(int i = 0; i < files.length; i++) {
          fileList.add(MultipartFile.fromBytes(
            await files[i]!.readAsBytes(),
            filename: files[i]!.name,
          ));
        }
      }

      if(fileList.isNotEmpty) {
        data?.addAll({
          '${fileKey ?? 'image'}[]' : fileList,
        });
      }
    }catch(e) {
      rethrow;
    }




    try {
      var response = await dio!.post(
        uri,
        data: FormData.fromMap(data ?? {}),
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
      return response;
    } on FormatException catch (_) {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }
}
