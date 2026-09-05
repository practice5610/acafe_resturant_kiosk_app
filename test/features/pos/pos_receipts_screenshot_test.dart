import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_receipts_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  // Both families the receipt uses: Loew for headings and table text, Swiss721
  // for the muted price/summary lines. Missing either one renders those runs as
  // tofu boxes and makes the golden useless for comparison.
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
}

/// Stands in for the device-auth feed so the frame renders without a network.
/// The shapes are exactly what KioskManagerController returns.
class _StubManager extends KioskManagerProvider {
  _StubManager({required super.kioskManagerRepo});

  @override
  List<Map<String, dynamic>> get transactions => const [
        {
          'id': 27362,
          'created_at': '2026-06-23T12:14:00.000',
          'customer_name': 'Dylan',
          'products_summary': 'Oat Milk Matcha + Vanilla Matcha Latte',
          'display_method': 'card',
          'order_amount': 16.70,
          'order_status': 'delivered',
          'payment_status': 'paid',
          'channel_key': 'counter_pos',
        },
        {
          'id': 27361,
          'created_at': '2026-06-23T11:58:00.000',
          'customer_name': 'Yuki',
          'products_summary': '2x Classic Poffertjes + Flat White',
          'display_method': 'cash',
          'order_amount': 15.50,
          'order_status': 'delivered',
          'payment_status': 'paid',
          'channel_key': 'counter_pos',
        },
        {
          'id': 27360,
          'created_at': '2026-06-23T11:32:00.000',
          'customer_name': 'Arthur',
          'products_summary': '1x Double Matcha Cup',
          'display_method': 'card',
          'order_amount': 7.00,
          'order_status': 'delivered',
          'payment_status': 'paid',
          'channel_key': 'counter_pos',
        },
        {
          'id': 27359,
          'created_at': '2026-06-23T11:05:00.000',
          'customer_name': 'Senne',
          'products_summary': 'Classic Butter Poffertjes + Iced Latte',
          'display_method': 'card',
          'order_amount': 11.20,
          'order_status': 'delivered',
          'payment_status': 'paid',
          'channel_key': 'counter_pos',
        },
        {
          'id': 27358,
          'created_at': '2026-06-23T10:48:00.000',
          'customer_name': 'Sarah',
          'products_summary': '1x Ceremonial Matcha Latte Pure',
          'display_method': 'card',
          'order_amount': 7.50,
          'order_status': 'delivered',
          'payment_status': 'paid',
          'channel_key': 'counter_pos',
        },
      ];

  @override
  bool get transactionsLoading => false;

  @override
  bool get hasMoreTransactions => false;

  @override
  int? get receiptDetailId => 27362;

  @override
  bool get receiptDetailLoading => false;

  @override
  Map<String, dynamic>? get receiptDetail => {
        'id': 27362,
        'created_at': '2026-06-23T12:14:00.000',
        'customer_name': 'Dylan',
        'display_method': 'card',
        'order_status': 'delivered',
        'table': null,
        'subtotal': 25.00,
        'discount': 8.30,
        'total': 16.70,
        'details': [
          _line('Oat Milk Matcha', 6.00, 'Cup', const ['Extra Oat Milk option']),
          _line('Vanilla Matcha Latte', 6.50, 'Can',
              const ['Premium Vanilla syrup']),
          _line('Mango Matcha Specialty', 7.00, 'Cup', const [
            'Mango purée',
            'Coconut milk',
            'Honey drizzle',
            'Chia seeds',
          ], removed: const ['Whipped cream']),
        ],
      };

  @override
  Future<void> loadTransactions({
    bool reset = true,
    String? reportDate,
    String? dateFrom,
    String? dateTo,
    String? search,
    String? status,
    String? channel,
    double? amountMin,
    double? amountMax,
    bool replaceFilters = false,
  }) async {}

  @override
  Future<void> loadReceiptDetail(int id) async {}

  @override
  void clearReceiptDetail() {}
}

/// An order_details row as the formatter hands it back.
Map<String, dynamic> _line(
  String name,
  double price,
  String size,
  List<String> extras, {
  List<String> removed = const [],
}) {
  final List<Map<String, dynamic>> addOns = [
    for (int i = 0; i < extras.length; i++)
      {'id': 100 + i, 'name': extras[i], 'price': 0, 'is_default': 0},
    for (int i = 0; i < removed.length; i++)
      {'id': 200 + i, 'name': removed[i], 'price': 0, 'is_default': 1},
  ];

  return {
    'price': price,
    'quantity': 1,
    'discount_on_product': 0,
    'tax_amount': 0,
    'add_on_ids': [for (int i = 0; i < extras.length; i++) 100 + i],
    'add_on_prices': [for (final _ in extras) 0],
    'variation': [
      {
        'name': 'Can or cup?',
        'values': [
          {'label': size, 'optionPrice': 0},
        ],
      },
    ],
    'product_details': {
      'id': 1,
      'name': name,
      'price': price,
      'image': 'x.png',
      'variations': [
        {
          'name': 'Can or cup?',
          'type': 'single',
          'values': [
            {'label': 'Cup', 'optionPrice': 0},
            {'label': 'Can', 'optionPrice': 0},
          ],
        },
      ],
      'add_ons': addOns,
    },
  };
}

class _Splash extends SplashProvider {
  _Splash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        restaurantName: 'A/CAFÉ',
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        countryCode: 'NL',
        decimalPointSettings: 2,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      AppConstants.languageCode: 'en',
      AppConstants.countryCode: 'NL',
    });
    final prefs = await SharedPreferences.getInstance();
    final dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>(
            create: (_) => _Splash(
              splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
            ),
          ),
          ChangeNotifierProvider<KioskManagerProvider>(
            create: (_) => _StubManager(
              kioskManagerRepo: KioskManagerRepo(
                dioClient: dio,
                sharedPreferences: prefs,
              ),
            ),
          ),
        ],
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: PosShell(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: PosHomeSpec.pageBg,
                body: const PosReceiptsScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('Receipts golden at 1366x926 (Figma 1641:3228)', (tester) async {
    await pumpAt(tester, const Size(1366, 926));

    expect(find.text('Search receipts..'), findsOneWidget);
    expect(find.text('EXPORT'), findsOneWidget);
    expect(find.text('Purchase Receipt'), findsOneWidget);
    expect(find.text('Print Receipt'), findsOneWidget);
    expect(find.text('Dylan'), findsWidgets);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(PosReceiptsScreen),
      matchesGoldenFile('goldens/pos_receipts_1366.png'),
    );
  }, skip: !Platform.isMacOS && !Platform.isLinux);

  testWidgets('Receipts collapses to one pane on a tablet width',
      (tester) async {
    await pumpAt(tester, const Size(840, 1000));

    // Below the split threshold the detail pane is gone and the list owns the
    // width; the receipt opens as a sheet on tap instead.
    expect(find.text('Purchase Receipt'), findsNothing);
    expect(find.text('Search receipts..'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byType(PosReceiptsScreen),
      matchesGoldenFile('goldens/pos_receipts_840.png'),
    );
  }, skip: !Platform.isMacOS && !Platform.isLinux);
}
