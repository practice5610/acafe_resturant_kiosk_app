import 'dart:convert';

import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late CategoryProvider categories;
  late KioskAuthRepo auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );
    categories = CategoryProvider(
      categoryRepo: CategoryRepo(dioClient: dio, sharedPreferences: prefs),
    );
    auth = KioskAuthRepo(dioClient: dio, sharedPreferences: prefs);
  });

  Map<String, dynamic> menuCache({
    required int branchId,
    required List<Map<String, dynamic>> products,
  }) {
    return {
      'locale': 'en',
      'branchId': branchId,
      'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      'categories': {
        'total_size': products.isEmpty ? 0 : 1,
        'limit': 24,
        'offset': 1,
        'categories': products.isEmpty
            ? []
            : [
                {'id': 1, 'name': 'Coffee'},
              ],
      },
      'productsByCategory': products.isEmpty
          ? <String, dynamic>{}
          : {
              '1': {
                'total_size': products.length,
                'products': products,
              },
            },
    };
  }

  test('disk cache from another branch is not shown on Paris', () async {
    await prefs.setInt(AppConstants.branch, 2);
    await prefs.setString(
      AppConstants.kioskMenuCacheKey,
      jsonEncode(menuCache(
        branchId: 1,
        products: [
          {'id': 10, 'name': 'Latte', 'price': 4.0, 'status': 1},
        ],
      )),
    );

    await categories.warmKioskMenuFromDisk('en');

    expect(categories.allPrefetchedProducts.map((p) => p.id), isEmpty);
    expect(categories.isKioskMenuReadyFor('en'), isFalse);
  });

  test('empty Paris cache is a valid ready menu', () async {
    await prefs.setInt(AppConstants.branch, 2);
    await prefs.setString(
      AppConstants.kioskMenuCacheKey,
      jsonEncode(menuCache(branchId: 2, products: const [])),
    );

    await categories.warmKioskMenuFromDisk('en');

    expect(categories.isKioskMenuReadyFor('en'), isTrue);
    expect(categories.allPrefetchedProducts, isEmpty);
    expect(categories.categoryList, isEmpty);
  });

  test('same-branch cache hydrates owned products only', () async {
    await prefs.setInt(AppConstants.branch, 2);
    await prefs.setString(
      AppConstants.kioskMenuCacheKey,
      jsonEncode(menuCache(
        branchId: 2,
        products: [
          {'id': 510, 'name': 'Latte', 'price': 4.0, 'status': 1},
        ],
      )),
    );

    await categories.warmKioskMenuFromDisk('en');

    expect(categories.isKioskMenuReadyFor('en'), isTrue);
    expect(
      categories.allPrefetchedProducts.map((p) => p.id).toList(),
      [510],
    );
  });

  test('clearSession drops branch id and leftover menu cache', () async {
    await prefs.setInt(AppConstants.branch, 1);
    await prefs.setString(AppConstants.token, 'device-token');
    await prefs.setString(
      AppConstants.kioskMenuCacheKey,
      jsonEncode(menuCache(
        branchId: 1,
        products: [
          {'id': 10, 'name': 'Latte', 'price': 4.0, 'status': 1},
        ],
      )),
    );

    await auth.clearSession();

    expect(prefs.containsKey(AppConstants.branch), isFalse);
    expect(prefs.containsKey(AppConstants.kioskMenuCacheKey), isFalse);
    expect(prefs.containsKey(AppConstants.token), isFalse);
  });

  test('logging into another branch drops the previous menu cache', () async {
    await prefs.setInt(AppConstants.branch, 1);
    await prefs.setString(
      AppConstants.kioskMenuCacheKey,
      jsonEncode(menuCache(
        branchId: 1,
        products: [
          {'id': 10, 'name': 'Latte', 'price': 4.0, 'status': 1},
        ],
      )),
    );

    await auth.saveSession(token: 'paris-token', branchId: 2);

    expect(prefs.getInt(AppConstants.branch), 2);
    expect(prefs.containsKey(AppConstants.kioskMenuCacheKey), isFalse);
  });
}
