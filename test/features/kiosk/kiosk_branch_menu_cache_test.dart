import 'dart:convert';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DioClient _dio(SharedPreferences prefs) => DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );

String _menuCache({
  required int branchId,
  required String locale,
  List<Map<String, dynamic>> products = const [],
}) {
  return jsonEncode({
    'locale': locale,
    'branchId': branchId,
    'fetchedAt': DateTime.now().millisecondsSinceEpoch,
    'categories': {
      'total_size': 1,
      'limit': 24,
      'offset': 1,
      'categories': [
        {'id': 1, 'name': 'Coffee', 'parent_id': 0, 'position': 0, 'status': 1},
      ],
    },
    'productsByCategory': {
      '1': {
        'total_size': products.length,
        'limit': 50,
        'offset': 1,
        'products': products,
      },
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('disk menu from another branch is rejected so an empty branch stays empty',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.branch: 10,
      AppConstants.kioskMenuCacheKey: _menuCache(
        branchId: 1,
        locale: 'en',
        products: [
          {'id': 99, 'name': 'Main Branch Latte', 'price': 4, 'status': 1},
        ],
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = CategoryProvider(
      categoryRepo: CategoryRepo(
        dioClient: _dio(prefs),
        sharedPreferences: prefs,
      ),
    );

    await provider.warmKioskMenuFromDisk('en');

    expect(provider.isKioskMenuReadyFor('en'), isFalse);
    expect(provider.allPrefetchedProducts, isEmpty);
  });

  test('disk menu for the signed-in branch hydrates, including a zero-product menu',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.branch: 10,
      AppConstants.kioskMenuCacheKey: _menuCache(branchId: 10, locale: 'en'),
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = CategoryProvider(
      categoryRepo: CategoryRepo(
        dioClient: _dio(prefs),
        sharedPreferences: prefs,
      ),
    );

    await provider.warmKioskMenuFromDisk('en');

    expect(provider.isKioskMenuReadyFor('en'), isTrue);
    expect(provider.allPrefetchedProducts, isEmpty);
    expect(provider.categoryList, isNotEmpty);
  });

  test('rebinding the device to another branch drops the previous menu cache',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.token: 'old-token',
      AppConstants.branch: 1,
      AppConstants.kioskMenuCacheKey: _menuCache(branchId: 1, locale: 'en'),
      AppConstants.kioskDealsCacheKey: '{"deals":[]}',
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = KioskAuthRepo(dioClient: _dio(prefs), sharedPreferences: prefs);

    await repo.saveSession(token: 'new-token', branchId: 10);

    expect(prefs.getInt(AppConstants.branch), 10);
    expect(prefs.getString(AppConstants.kioskMenuCacheKey), isNull);
    expect(prefs.getString(AppConstants.kioskDealsCacheKey), isNull);
  });

  test('logout removes branch id and menu cache', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.token: 'token',
      AppConstants.branch: 1,
      AppConstants.kioskMenuCacheKey: _menuCache(branchId: 1, locale: 'en'),
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = KioskAuthRepo(dioClient: _dio(prefs), sharedPreferences: prefs);

    await repo.clearSession();

    expect(prefs.containsKey(AppConstants.token), isFalse);
    expect(prefs.containsKey(AppConstants.branch), isFalse);
    expect(prefs.getString(AppConstants.kioskMenuCacheKey), isNull);
  });
}
