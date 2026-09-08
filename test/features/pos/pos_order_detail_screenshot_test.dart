import 'dart:io';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the Orders detail overlay to PNG so each of the four Figma frames
/// can be compared by eye:
///
///   1641:4341  App Order   / NEW
///   1641:4490  Kiosk Order / NEW
///   1641:4640  Cashier     / NEW
///   1641:5129  App Order   / IN PROGRESS
///
/// plus the two cases Figma does not draw but the board can reach: a finished
/// order (status label, no action) and a guest order with neither contact
/// details nor a real note, which is what most live orders actually look like.
///
///   flutter test --update-goldens test/features/pos/pos_order_detail_screenshot_test.dart
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
  await _loadMaterialIcons();
}

Future<void> _loadMaterialIcons() async {
  final String? flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? _flutterRootFromDartExecutable();
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

String? _flutterRootFromDartExecutable() {
  final List<String> parts = Platform.resolvedExecutable.split('/');
  final int index = parts.indexOf('bin');
  if (index <= 0) return null;
  return parts.sublist(0, index).join('/');
}

final DateTime _frozen = DateTime(2026, 6, 23, 10, 55, 0);

class _StubSplashProvider extends SplashProvider {
  _StubSplashProvider({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );
}

/// Serves one canned `transactions/{id}` body. Shapes match what the extended
/// endpoint really returns — `items` carries resolved add-on names, and the
/// contact fields are null for a guest.
class _StubManagerRepo implements KioskManagerRepo {
  final Map<String, dynamic> payload;

  _StubManagerRepo(this.payload);

  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async {
    return ApiResponseModel.withSuccess(
      Response<dynamic>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 200,
        data: payload,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _item({
  required String name,
  required double price,
  String? variation,
  List<String> addons = const [],
  String? instruction,
}) =>
    <String, dynamic>{
      'name': name,
      'image': null,
      'quantity': 1,
      'unit_price': price,
      'instruction': instruction,
      'variations': variation == null
          ? const []
          : [
              {
                'name': 'Size',
                'options': [
                  {'label': variation, 'price': 0}
                ]
              }
            ],
      'addons': [
        for (final String a in addons) {'name': a, 'quantity': 1},
      ],
    };

Map<String, dynamic> _payload({
  required String status,
  required String channel,
  bool withContact = true,
  String? note = 'Please make the Flat White extra hot. '
      'The Croissant should be warmed up if possible. Thanks!',
}) =>
    <String, dynamic>{
      'id': 1234,
      'created_at': _frozen.toIso8601String(),
      'order_status': status,
      'order_type': 'pos',
      'channel_key': channel,
      'display_method': 'card',
      'payment_status': 'paid',
      'table': null,
      'customer_name': 'Max Mustermann (Alias 123)',
      'customer_phone': withContact ? '+49 176 1234567' : null,
      'customer_email': withContact ? 'max.mustermann@example.com' : null,
      'order_note': note,
      'items': [
        _item(name: 'Cappuccino', price: 4.5, variation: 'Cup', addons: ['Oat Milk']),
        _item(name: 'Croissant', price: 3.2, variation: 'Can', instruction: 'Warmed up'),
        _item(name: 'Flat White', price: 4.0, variation: 'Cup', addons: ['Extra hot']),
      ],
      'subtotal': 11.7,
      'discount': 0,
      'total': 11.7,
    };

PosOrderCard _card(String status, String channel) => PosOrderCard(
      id: 1234,
      createdAt: _frozen,
      orderStatus: status,
      orderType: 'pos',
      channelKey: channel,
      orderAmount: 11.7,
      customerName: 'Max Mustermann (Alias 123)',
      addressLines: const [],
      displayMethod: 'card',
      branchName: 'Ludwigsfelde',
    );

Future<void> _shoot(
  WidgetTester tester, {
  required String file,
  required Size size,
  required String status,
  required String channel,
  bool withContact = true,
  String? note,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    AppConstants.baseUrl,
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );

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
          backgroundColor: const Color(0xFFFDFBF4),
          body: PosOrderDetailOverlay(
            order: _card(status, channel),
            repo: _StubManagerRepo(_payload(
              status: status,
              channel: channel,
              withContact: withContact,
              note: note,
            )),
            onAdvance: (_) async => const PosAdvanceResult.advanced(),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  await expectLater(
    find.byType(PosOrderDetailOverlay),
    matchesGoldenFile('goldens/$file'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  const Size figma = Size(1366, 1024);

  testWidgets('1641:4341 — App Order / NEW', (tester) async {
    await _shoot(tester,
        file: 'pos_order_detail_app_new.png',
        size: figma,
        status: 'new',
        channel: 'web_app',
        note: 'Please make the Flat White extra hot.');
  });

  testWidgets('1641:4490 — Kiosk Order / NEW', (tester) async {
    await _shoot(tester,
        file: 'pos_order_detail_kiosk_new.png',
        size: figma,
        status: 'new',
        channel: 'kiosk',
        note: 'Please make the Flat White extra hot.');
  });

  testWidgets('1641:4640 — Cashier / NEW', (tester) async {
    await _shoot(tester,
        file: 'pos_order_detail_cashier_new.png',
        size: figma,
        status: 'new',
        channel: 'counter_pos',
        note: 'Please make the Flat White extra hot.');
  });

  testWidgets('1641:5129 — App Order / IN PROGRESS', (tester) async {
    await _shoot(tester,
        file: 'pos_order_detail_app_in_progress.png',
        size: figma,
        status: 'preparing',
        channel: 'web_app',
        note: 'Please make the Flat White extra hot.');
  });

  testWidgets('finished order — status label, no action', (tester) async {
    await _shoot(tester,
        file: 'pos_order_detail_completed.png',
        size: figma,
        status: 'completed',
        channel: 'counter_pos',
        note: 'Please make the Flat White extra hot.');
  });

  testWidgets('guest order — no contact card, no note section', (tester) async {
    // What most live orders look like: 49 of 57 on the local branch are guests
    // whose only note is the name-carrier already shown in the header.
    await _shoot(tester,
        file: 'pos_order_detail_guest.png',
        size: figma,
        status: 'new',
        channel: 'counter_pos',
        withContact: false,
        note: 'Kiosk order — Max Mustermann (Alias 123)');
  });

  testWidgets('narrow POS hardware — columns stack, nothing clips',
      (tester) async {
    await _shoot(tester,
        file: 'pos_order_detail_840.png',
        size: const Size(840, 800),
        status: 'preparing',
        channel: 'kiosk',
        note: 'Please make the Flat White extra hot.');
  });

  testWidgets('1641:4791 — complete confirmation dialog', (tester) async {
    tester.view
      ..physicalSize = figma
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xB3241F20),
        body: PosCompleteConfirmationDialog(),
      ),
    ));
    await tester.pump();
    await expectLater(
      find.byType(PosCompleteConfirmationDialog),
      matchesGoldenFile('goldens/pos_complete_confirmation.png'),
    );
  });

  testWidgets('complete confirmation on a narrow window', (tester) async {
    tester.view
      ..physicalSize = const Size(640, 700)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xB3241F20),
        body: PosCompleteConfirmationDialog(),
      ),
    ));
    await tester.pump();
    await expectLater(
      find.byType(PosCompleteConfirmationDialog),
      matchesGoldenFile('goldens/pos_complete_confirmation_640.png'),
    );
  });
}
