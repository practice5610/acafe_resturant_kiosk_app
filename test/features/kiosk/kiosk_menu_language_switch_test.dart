import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/category/domain/reposotories/category_repo.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kiosk catalog that answers in the language each request is actually sent
/// in — the device-wide `X-localization` header, exactly like the backend.
///
/// A language can be held so a load stays in flight while the customer keeps
/// tapping languages on the welcome screen.
class FakeKioskCatalog extends CategoryRepo {
  FakeKioskCatalog({required super.dioClient, required super.sharedPreferences});

  /// Every request, as `<endpoint>:<language it was sent in>`.
  final List<String> requests = [];
  final Map<String, Completer<void>> _held = {};

  void hold(String language) => _held[language] = Completer<void>();
  void release(String language) => _held.remove(language)?.complete();

  String get _deviceLanguage =>
      '${dioClient.dio!.options.headers['X-localization']}';

  static ApiResponseModel _ok(Map<String, dynamic> data) =>
      ApiResponseModel.withSuccess(Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: data,
      ));

  @override
  Future<ApiResponseModel> getKioskCategoryList({
    int offset = 1,
    int limit = 24,
    String? localeCode,
  }) async {
    final String language = localeCode ?? _deviceLanguage;
    requests.add('categories:$language');
    await _held[language]?.future;
    return _ok({
      'total_size': 1,
      'limit': limit,
      'offset': offset,
      'categories': [
        {'id': 1, 'name': 'Coffee ($language)', 'parent_id': 0, 'position': 0, 'status': 1},
      ],
    });
  }

  @override
  Future<ApiResponseModel> getKioskProductList({
    String? categoryID,
    required int offset,
    int limit = 10,
    String type = 'all',
    String? name,
    String? localeCode,
  }) async {
    final String language = localeCode ?? _deviceLanguage;
    requests.add('products:$language');
    return _ok({
      'total_size': 1,
      'limit': limit,
      'offset': offset,
      'products': [
        {'id': 1, 'name': 'Latte ($language)', 'price': 4, 'status': 1},
      ],
    });
  }
}

late SharedPreferences prefs;
late FakeKioskCatalog catalog;
late CategoryProvider menu;
late LocalizationProvider localization;

/// What the welcome-screen language pills do: the real locale switch, which
/// rewrites the device-wide request language.
Future<void> switchTo(String code, String country) =>
    localization.setKioskLanguage(Locale(code, country));

List<String?> menuProductNames() =>
    menu.allPrefetchedProducts.map((p) => p.name).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({AppConstants.branch: 1});
    prefs = await SharedPreferences.getInstance();
    final DioClient dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );
    catalog = FakeKioskCatalog(dioClient: dio, sharedPreferences: prefs);
    menu = CategoryProvider(categoryRepo: catalog);
    localization =
        LocalizationProvider(sharedPreferences: prefs, dioClient: dio);
    await switchTo('nl', 'NL');
  });

  test('a language picked while another menu is loading gets its own menu',
      () async {
    catalog.hold('nl');
    final Future<void> dutch =
        menu.prefetchKioskMenu(localeCode: 'nl', force: true);

    await switchTo('fr', 'FR');
    final Future<void> french =
        menu.prefetchKioskMenu(localeCode: 'fr', force: true);

    catalog.release('nl');
    await Future.wait([dutch, french]);

    expect(menu.isKioskMenuReadyFor('fr'), isTrue,
        reason: 'the French request was answered with the Dutch load');
    expect(menuProductNames(), ['Latte (fr)']);
  });

  test('a language tapped past while another loads is never fetched',
      () async {
    catalog.hold('nl');
    final Future<void> dutch =
        menu.prefetchKioskMenu(localeCode: 'nl', force: true);

    await switchTo('fr', 'FR');
    final Future<void> french =
        menu.prefetchKioskMenu(localeCode: 'fr', force: true);
    await switchTo('de', 'DE');
    final Future<void> german =
        menu.prefetchKioskMenu(localeCode: 'de', force: true);

    catalog.release('nl');
    await Future.wait([dutch, french, german]);

    expect(catalog.requests, isNot(contains('categories:fr')),
        reason: 'French was superseded by German before its turn came');
    expect(catalog.requests, contains('categories:de'));
    expect(menu.isKioskMenuReadyFor('de'), isTrue);
    expect(menuProductNames(), ['Latte (de)']);
  });

  test('asking again for the language already loading shares that load',
      () async {
    catalog.hold('nl');
    final Future<void> first =
        menu.prefetchKioskMenu(localeCode: 'nl', force: true);
    final Future<void> second =
        menu.prefetchKioskMenu(localeCode: 'nl', force: true);

    catalog.release('nl');
    await Future.wait([first, second]);

    expect(catalog.requests.where((r) => r.startsWith('categories:')),
        hasLength(1));
    expect(menu.isKioskMenuReadyFor('nl'), isTrue);
  });

  test('a menu load asks in its own language even if the device switches mid-load',
      () async {
    catalog.hold('nl');
    final Future<void> dutch =
        menu.prefetchKioskMenu(localeCode: 'nl', force: true);

    // The device language flips while the Dutch categories are in flight; the
    // Dutch load's remaining requests must not follow it.
    await switchTo('fr', 'FR');
    catalog.release('nl');
    await dutch;

    expect(catalog.requests, ['categories:nl', 'products:nl']);
    expect(menu.isKioskMenuReadyFor('nl'), isTrue);
    expect(menuProductNames(), ['Latte (nl)']);
  });

  test('a language picked during the menu auto-refresh is loaded after it',
      () async {
    await menu.prefetchKioskMenu(localeCode: 'nl', force: true);

    catalog.hold('nl');
    final Future<void> poll = menu.pollKioskMenuForUpdates();

    await switchTo('fr', 'FR');
    final Future<void> french =
        menu.prefetchKioskMenu(localeCode: 'fr', force: true);

    catalog.release('nl');
    await Future.wait([poll, french]);

    expect(menu.isKioskMenuReadyFor('fr'), isTrue);
    expect(menuProductNames(), ['Latte (fr)']);
  });

  test('a slow load never replaces the menu of the language tapped back to',
      () async {
    // English menu cached on disk from earlier; the customer taps Dutch, then
    // straight back to English before the Dutch menu has arrived.
    await prefs.setString(AppConstants.kioskMenuCacheKey, jsonEncode({
      'locale': 'en',
      'branchId': 1,
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
          'total_size': 1,
          'limit': 50,
          'offset': 1,
          'products': [
            {'id': 1, 'name': 'Latte (en, cached)', 'price': 4, 'status': 1},
          ],
        },
      },
    }));

    catalog.hold('nl');
    final Future<void> dutch = menu.warmKioskMenuFromDisk('nl');
    final Future<void> english = menu.warmKioskMenuFromDisk('en');

    catalog.release('nl');
    await Future.wait([dutch, english]);

    expect(menu.isKioskMenuReadyFor('en'), isTrue);
    expect(menuProductNames(), ['Latte (en, cached)']);
  });

  test('kiosk catalog requests carry the language asked for, not the device one',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.languageCode: 'fr',
      AppConstants.branch: 1,
    });
    final SharedPreferences frenchDevice = await SharedPreferences.getInstance();
    final _RecordingAdapter wire = _RecordingAdapter();
    final CategoryRepo repo = CategoryRepo(
      dioClient: DioClient(
        'http://localhost',
        Dio()..httpClientAdapter = wire,
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: frenchDevice,
      ),
      sharedPreferences: frenchDevice,
    );

    await repo.getKioskCategoryList(localeCode: 'nl');
    await repo.getKioskProductList(categoryID: '1', offset: 1, localeCode: 'nl');
    await repo.getKioskProductList(categoryID: '1', offset: 1);

    expect(wire.languages, ['nl', 'nl', 'fr']);
  });
}

/// Records what actually goes over the wire, and answers every call with an
/// empty JSON object.
class _RecordingAdapter implements HttpClientAdapter {
  final List<String?> languages = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    languages.add(options.headers['X-localization']?.toString());
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
