import 'dart:io';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/screens/pos_orders_list_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the Orders board to PNG so the layout can be compared against Figma
/// `1641:2874` by eye, section by section, rather than only by assertion.
///
/// Regenerate after a deliberate design change:
///
///   flutter test --update-goldens test/features/pos/pos_orders_screenshot_test.dart
///
/// One expected difference from the Figma frame: the timer values ascend rather
/// than descend. Figma draws a countdown, which implies a per-order deadline
/// that does not exist in the data — see PosOrderTimer.
Future<void> _loadFonts() async {
  const Map<String, List<String>> families = {
    'Loew': [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
    'Swiss721': ['assets/fonts/Swiss721-Light.ttf'],
  };

  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(File(path)
          .readAsBytes()
          .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }

  // The card's source glyph, the checkmark and the ⋯ menu are all Material
  // icons. Without this they render as empty tofu boxes and the image is
  // useless for judging exactly the part of the card Figma is most specific
  // about. Located from the SDK rather than the app's assets because the icon
  // font ships with Flutter, not the app.
  await _loadMaterialIcons();
}

Future<void> _loadMaterialIcons() async {
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      _flutterRootFromDartExecutable();
  if (flutterRoot == null) return;

  final File font = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!font.existsSync()) return;

  final loader = FontLoader('MaterialIcons')
    ..addFont(font
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

/// `dart` runs from `<flutter>/bin/cache/dart-sdk/bin/dart` under `flutter test`.
String? _flutterRootFromDartExecutable() {
  final List<String> parts = Platform.resolvedExecutable.split('/');
  final int index = parts.indexOf('bin');
  if (index <= 0) return null;
  return parts.sublist(0, index).join('/');
}

/// A fixed instant. Goldens that bake `DateTime.now()` differ on every run —
/// the clock times and the elapsed labels both move — so the board's clock and
/// the row timestamps are pinned to the same reference here.
final DateTime _frozenNow = DateTime(2026, 6, 23, 10, 36, 0);

class _StubSplashProvider extends SplashProvider {
  _StubSplashProvider({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );
}

/// Stands in for the device-auth board feed. The shapes are exactly what
/// `KioskManagerController::orders` returns; the ages are fixed relative to a
/// frozen clock so the three urgency states each appear.
class _StubOrdersRepo implements PosOrdersRepo {
  @override
  DioClient get dioClient => throw UnimplementedError();

  static Map<String, dynamic> _row({
    required int id,
    required String status,
    required String channel,
    required int minutesAgo,
    required double amount,
    String name = 'Max Mustermann',
    List<String> address = const [],
  }) =>
      <String, dynamic>{
        'id': id,
        'created_at': _frozenNow
            .subtract(Duration(minutes: minutesAgo, seconds: 23))
            .toIso8601String(),
        'order_status': status,
        'order_type': 'pos',
        'channel_key': channel,
        'order_amount': amount,
        'customer_name': name,
        'address_lines': address,
        'display_method': 'card',
        'branch_name': 'Ludwigsfelde',
      };

  @override
  Future<ApiResponseModel> getOrders({
    String? dateFrom,
    String? dateTo,
    String? search,
    String? section,
    String? status,
    String? source,
    String? type,
    String? method,
    int limit = 200,
  }) async {
    return ApiResponseModel.withSuccess(Response(
      requestOptions: RequestOptions(path: '/orders'),
      statusCode: 200,
      data: <String, dynamic>{
        'counts': {'new': 6, 'in_progress': 3, 'finished': 3},
        'limit': limit,
        'orders': [
          // NEW — normal, warning and urgent, plus the address variants.
          _row(
            id: 27364,
            status: 'new',
            channel: 'web_app',
            minutesAgo: 1,
            amount: 11.67,
            address: ['Potsdamer Str. 33', '14974 Ludwigsfelde'],
          ),
          _row(
            id: 27366,
            status: 'new',
            channel: 'counter_pos',
            minutesAgo: 2,
            amount: 11.67,
            address: ['Potsdamer Str. 33', '14974 Ludwigsfelde'],
          ),
          _row(
            id: 27368,
            status: 'new',
            channel: 'kiosk',
            minutesAgo: 4,
            amount: 11.67,
          ),
          _row(
            id: 27367,
            status: 'new',
            channel: 'counter_pos',
            minutesAgo: 6,
            amount: 11.67,
            address: ['Potsdamer Str. 33', '14874 Ludwigsfelde'],
          ),
          _row(
            id: 27369,
            status: 'new',
            channel: 'counter_pos',
            minutesAgo: 9,
            amount: 11.67,
          ),
          _row(
            id: 27365,
            status: 'new',
            channel: 'web_app',
            minutesAgo: 22,
            amount: 11.67,
          ),
          // IN PROGRESS
          _row(
            id: 27363,
            status: 'preparing',
            channel: 'web_app',
            minutesAgo: 3,
            amount: 11.67,
          ),
          _row(
            id: 27362,
            status: 'preparing',
            channel: 'web_app',
            minutesAgo: 7,
            amount: 11.67,
            address: ['Potsdamer Str. 33', '14974 Ludwigsfelde'],
          ),
          _row(
            id: 27361,
            status: 'on_hold',
            channel: 'counter_pos',
            minutesAgo: 18,
            amount: 11.67,
          ),
          // FINISHED
          _row(
            id: 27358,
            status: 'completed',
            channel: 'counter_pos',
            minutesAgo: 61,
            amount: 23.45,
            name: 'Anna Schmidt',
            address: ['Berliner Str. 12', '10115 Berlin'],
          ),
          _row(
            id: 27359,
            status: 'item_to_collect',
            channel: 'web_app',
            minutesAgo: 74,
            amount: 18.90,
            name: 'Thomas Müller',
            address: ['Hauptstr. 7', '10827 Berlin'],
          ),
          _row(
            id: 27360,
            status: 'delivered',
            channel: 'counter_pos',
            minutesAgo: 95,
            amount: 8.50,
            name: 'Lisa Weber',
            address: ['Schönhauser Allee 45', '10439 Berlin'],
          ),
        ],
      },
    ));
  }

  @override
  Future<ApiResponseModel> updateStatus({
    required int orderId,
    required String orderStatus,
  }) async =>
      ApiResponseModel.withSuccess(Response(
        requestOptions: RequestOptions(path: '/status'),
        statusCode: 200,
        data: <String, dynamic>{'message': 'Order status updated!'},
      ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.token: 'device-token',
      AppConstants.branch: 1,
    });
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      AppConstants.baseUrl,
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>(
            create: (_) => _StubSplashProvider(
              splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: PosHomeSpec.pageBg,
            body: PosOrdersListScreen(
              repo: _StubOrdersRepo(),
              clock: () => _frozenNow,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('Orders board golden at 1366x926 (Figma 1641:2874)',
      (tester) async {
    await pumpAt(tester, const Size(1366, 926));

    expect(find.text('Search in orders...'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('FINISHED'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(PosOrdersListScreen),
      matchesGoldenFile('goldens/pos_orders_1366.png'),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();

    expect(find.text('FINISHED'), findsOneWidget);
    expect(find.text('Done'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  }, skip: !Platform.isMacOS && !Platform.isLinux);

  testWidgets('the whole board in one frame, for Figma comparison',
      (tester) async {
    // Taller than any real terminal on purpose: this image exists so all three
    // sections can be checked against 1641:2874 at once, without scrolling.
    await pumpAt(tester, const Size(1366, 1500));

    expect(find.text('NEW'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('FINISHED'), findsOneWidget);
    // preparing x2 and on_hold in IN PROGRESS; item_to_collect in FINISHED
    // still carries the action that finishes it.
    expect(find.text('Mark as ready'), findsNWidgets(2));
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Mark as complete'), findsOneWidget);
    // Only the two genuinely terminal orders read Done.
    expect(find.text('Done'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(PosOrdersListScreen),
      matchesGoldenFile('goldens/pos_orders_full.png'),
    );
  }, skip: !Platform.isMacOS && !Platform.isLinux);

  testWidgets('Orders board on a tablet width', (tester) async {
    await pumpAt(tester, const Size(840, 1000));

    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(PosOrdersListScreen),
      matchesGoldenFile('goldens/pos_orders_840.png'),
    );
  }, skip: !Platform.isMacOS && !Platform.isLinux);
}
