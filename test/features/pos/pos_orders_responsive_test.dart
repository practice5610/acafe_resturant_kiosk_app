import 'dart:async';
import 'dart:io';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/screens/pos_orders_list_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/theme/light_theme.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pos_test_kiosk_auth.dart';

/// The Orders board and detail modal across screen sizes and data shapes:
/// empty, loading, failed, long text, many orders, many stations. Nothing may
/// overflow or throw at any of them. Real fonts, production theme.

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
}

const List<Size> _sizes = [
  Size(320, 568),
  Size(420, 900),
  Size(600, 900),
  Size(820, 1180),
  Size(1024, 768),
  Size(1366, 1024),
  Size(1920, 1080),
  Size(2560, 1440),
];

final DateTime _now = DateTime(2026, 6, 23, 10, 36);

const String _longName =
    'Maximilian-Alexander von Mustermann-Schönhausen (Alias 1234567)';
const String _longLine =
    'Potsdamer Straße 33, Hinterhaus, 3. Obergeschoss links, Klingel Müller';

List<(String, String)> _stations(int n) => [
      for (int i = 0; i < n; i++)
        (
          const ['Bar', 'Kitchen', 'Pastry', 'Cold Drinks', 'Expo'][i % 5],
          const ['ready', 'preparing', 'pending'][i % 3],
        ),
    ];

Map<String, dynamic> _row(int id, String status, int ago,
        {bool long = false, int stations = 0}) =>
    {
      'id': id,
      'created_at': _now.subtract(Duration(minutes: ago)).toIso8601String(),
      'order_status': status,
      'order_type': 'pos',
      'channel_key': const ['web_app', 'kiosk', 'counter_pos'][id % 3],
      'order_amount': long ? 12345.67 : 11.67,
      'customer_name': long ? _longName : 'Max Mustermann',
      'address_lines': long ? [_longLine, _longLine, _longLine] : <String>[],
      'display_method': 'card',
      'branch_name': 'Ludwigsfelde',
      'item_states': [
        {'id': id * 10, 'prep_status': 'ready'},
        {'id': id * 10 + 1, 'prep_status': 'pending'},
      ],
      'stations': [
        for (final (n, s) in _stations(stations)) {'name': n, 'status': s},
      ],
    };

enum _Shape { empty, typical, long, many, stations }

class _Repo implements PosOrdersRepo {
  final _Shape shape;
  final Completer<ApiResponseModel>? hold;
  final bool fail;

  _Repo(this.shape, {this.hold, this.fail = false});

  @override
  DioClient get dioClient => throw UnimplementedError();

  List<Map<String, dynamic>> get _orders {
    switch (shape) {
      case _Shape.empty:
        return const [];
      case _Shape.typical:
        return [
          _row(1, 'new', 1),
          _row(2, 'new', 20),
          _row(3, 'preparing', 4, stations: 2),
          _row(4, 'on_hold', 9, stations: 2),
          _row(5, 'item_to_collect', 30),
          _row(6, 'completed', 60),
        ];
      case _Shape.long:
        return [
          for (final (i, s) in const [
            'new',
            'preparing',
            'on_hold',
            'item_to_collect',
            'completed'
          ].indexed)
            _row(10 + i, s, 5 + i * 30, long: true, stations: 3),
        ];
      case _Shape.many:
        return [
          for (int i = 0; i < 60; i++)
            _row(100 + i,
                const ['new', 'preparing', 'completed'][i % 3], i, stations: 2),
        ];
      case _Shape.stations:
        return [
          for (int i = 0; i < 6; i++)
            _row(200 + i, i.isEven ? 'preparing' : 'on_hold', i * 4,
                stations: 5),
        ];
    }
  }

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
  }) {
    if (hold != null) return hold!.future;
    if (fail) {
      return Future.value(ApiResponseModel.withError('Server error'));
    }
    return Future.value(ApiResponseModel.withSuccess(Response(
      requestOptions: RequestOptions(path: '/orders'),
      statusCode: 200,
      data: {
        'counts': {'new': 1, 'in_progress': 1, 'finished': 1},
        'orders': _orders,
      },
    )));
  }

  @override
  Future<ApiResponseModel> updateStatus({
    required int orderId,
    required String orderStatus,
  }) async =>
      ApiResponseModel.withSuccess(Response(
        requestOptions: RequestOptions(path: '/status'),
        statusCode: 200,
        data: {'message': 'ok'},
      ));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Manager implements KioskManagerRepo {
  final int items;
  final int stations;
  final bool long;

  _Manager({this.items = 3, this.stations = 2, this.long = false});

  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async =>
      ApiResponseModel.withSuccess(Response(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 200,
        data: {
          'id': id,
          'created_at': '2026-06-23T10:55:00',
          'order_status': 'preparing',
          'order_type': 'pos',
          'channel_key': 'counter_pos',
          'display_method': 'card',
          'payment_status': 'paid',
          'customer_name': long ? _longName : 'Max Mustermann',
          'customer_phone': '+49 176 1234567',
          'customer_email': long
              ? 'maximilian.alexander.von.mustermann.schoenhausen@example.com'
              : 'max@example.com',
          'order_note': long ? List.filled(8, _longLine).join(' ') : 'Hot',
          'items': [
            for (int i = 0; i < items; i++)
              {
                'id': i + 1,
                'name': long ? '$_longName item $i' : 'Item $i',
                'quantity': i + 1,
                'unit_price': 4.5,
                'prep_status': const ['pending', 'preparing', 'ready'][i % 3],
                'station': stations == 0
                    ? null
                    : const ['Bar', 'Kitchen', 'Pastry', 'Cold Drinks',
                        'Expo'][i % stations],
                'instruction': long ? _longLine : null,
                'variations': [
                  {
                    'name': 'Size',
                    'options': [
                      {'label': 'Cup'}
                    ]
                  }
                ],
                'addons': [
                  for (int a = 0; a < (long ? 4 : 1); a++)
                    {'name': 'Oat Milk $a', 'quantity': 1},
                ],
              },
          ],
          'stations': [
            for (final (n, s) in _stations(stations)) {'name': n, 'status': s},
          ],
          'subtotal': 11.7,
          'discount': 1.2,
          'total': 10.5,
        },
      ));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Splash extends SplashProvider {
  _Splash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );
}

Future<void> _pump(WidgetTester tester, Size size, Widget body) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    AppConstants.token: 'device-token',
    AppConstants.branch: 1,
    AppConstants.kioskShowImages: false,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(MultiProvider(
    providers: [
      testKioskAuthProvider(prefs),
      ChangeNotifierProvider<SplashProvider>(
        create: (_) => _Splash(
          splashRepo: SplashRepo(
            dioClient: DioClient(AppConstants.baseUrl, null,
                loggingInterceptor: LoggingInterceptor(),
                sharedPreferences: prefs),
            sharedPreferences: prefs,
          ),
        ),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: light,
      home: Scaffold(backgroundColor: PosHomeSpec.pageBg, body: body),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  setUp(() {
    if (!di.sl.isRegistered<KioskManagerRepo>()) {
      di.sl.registerLazySingleton<KioskManagerRepo>(() => _Manager());
    }
    if (!di.sl.isRegistered<PosOrdersRepo>()) {
      di.sl.registerLazySingleton<PosOrdersRepo>(() => _Repo(_Shape.typical));
    }
  });
  tearDown(() async {
    if (di.sl.isRegistered<PosOrdersRepo>()) di.sl.unregister<PosOrdersRepo>();
    if (di.sl.isRegistered<KioskManagerRepo>()) {
      di.sl.unregister<KioskManagerRepo>();
    }
  });

  for (final _Shape shape in _Shape.values) {
    testWidgets('board, ${shape.name}: no overflow at any size',
        (tester) async {
      for (final Size size in _sizes) {
        await _pump(tester, size,
            PosOrdersListScreen(repo: _Repo(shape), clock: () => _now));
        expect(tester.takeException(), isNull, reason: '${shape.name} @ $size');

        // Scroll to the end: the last section must lay out cleanly too.
        final Finder list = find.byType(ListView);
        if (list.evaluate().isNotEmpty) {
          await tester.drag(list, const Offset(0, -20000));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '${shape.name} scrolled @ $size');
        }
      }
    });
  }

  testWidgets('board, empty: says so, no cards', (tester) async {
    await _pump(tester, const Size(1366, 1024),
        PosOrdersListScreen(repo: _Repo(_Shape.empty), clock: () => _now));
    expect(find.byType(PosOrderCardTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('board, loading: spinner, then the cards', (tester) async {
    final Completer<ApiResponseModel> hold = Completer<ApiResponseModel>();
    await _pump(tester, const Size(1366, 1024),
        PosOrdersListScreen(repo: _Repo(_Shape.typical, hold: hold),
            clock: () => _now));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(PosOrderCardTile), findsNothing);

    hold.complete(await _Repo(_Shape.typical).getOrders());
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(PosOrderCardTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('board, request failed: no crash, no cards', (tester) async {
    await _pump(tester, const Size(1366, 1024),
        PosOrdersListScreen(repo: _Repo(_Shape.typical, fail: true),
            clock: () => _now));
    expect(find.byType(PosOrderCardTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('five stations on a 288px card wrap inside it', (tester) async {
    await _pump(tester, const Size(1366, 1024),
        PosOrdersListScreen(repo: _Repo(_Shape.stations), clock: () => _now));
    final Finder card = find.byType(PosOrderCardTile).first;
    final Rect cardRect = tester.getRect(card);
    for (final Element pill in find
        .descendant(of: card, matching: find.textContaining(' · '))
        .evaluate()) {
      final Rect r = tester.getRect(find.byWidget(pill.widget));
      expect(cardRect.contains(r.topLeft) && cardRect.contains(r.bottomRight),
          isTrue,
          reason: 'pill ${(pill.widget as Text).data} must stay in the card');
    }
    expect(tester.takeException(), isNull);
  });

  for (final (String label, _Manager repo) in [
    ('typical', _Manager()),
    ('many items, five stations', _Manager(items: 14, stations: 5)),
    ('long text everywhere', _Manager(items: 4, stations: 3, long: true)),
    ('no stations at all', _Manager(stations: 0)),
  ]) {
    testWidgets('modal, $label: no overflow at any size', (tester) async {
      for (final Size size in _sizes) {
        await _pump(
          tester,
          size,
          PosOrderDetailOverlay(
            order: PosOrderCard.fromJson(_row(7, 'preparing', 3)),
            repo: repo,
            ordersRepo: _Repo(_Shape.typical),
            onAdvance: (_) async => const PosAdvanceResult.advanced(),
            onSetStatus: (_, __) async => null,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$label @ $size');
      }
    });
  }

  testWidgets('the modal opens from a card and closes by × and by backdrop',
      (tester) async {
    await _pump(tester, const Size(1366, 1024),
        PosOrdersListScreen(repo: _Repo(_Shape.typical), clock: () => _now));

    await tester.tap(find.text('Max Mustermann').first);
    await tester.pumpAndSettle();
    expect(find.byType(PosOrderDetailOverlay), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(PosOrderDetailOverlay), findsNothing);

    await tester.tap(find.text('Max Mustermann').first);
    await tester.pumpAndSettle();
    expect(find.byType(PosOrderDetailOverlay), findsOneWidget);
    await tester.tapAt(const Offset(10, 1000));
    await tester.pumpAndSettle();
    expect(find.byType(PosOrderDetailOverlay), findsNothing);

    // And the board underneath is still live.
    expect(find.byType(PosOrderCardTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
