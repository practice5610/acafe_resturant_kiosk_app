import 'dart:io';

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_advance_outcome.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_card.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/screens/pos_orders_list_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_card_tile.dart';
import 'package:acafe_customer/features/pos/widgets/pos_item_status_widgets.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_detail_overlay.dart';
import 'package:acafe_customer/features/pos/widgets/pos_order_source_icon.dart';
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

/// Measures the Orders board and the detail modal against Figma 1915:15767's
/// own numbers (frame metadata: x / y / w / h of every node), not by eye.
///
/// Rendered the way the app renders them: the production `light` theme, the
/// real Loew and Swiss 721 fonts, at Figma's 1366 frame width. Every Figma
/// stroke is drawn *inside* its node and does not move its content, so each
/// expected value below is a Figma coordinate, unadjusted.
///
/// Values that differ on purpose (kept extras, extra preset chips, the app's
/// own currency format) are listed in [_report] but not asserted.

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

final DateTime _now = DateTime(2026, 6, 23, 10, 36, 0);

class _Splash extends SplashProvider {
  _Splash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        currencySymbol: '€',
        currencySymbolPosition: 'left',
        decimalPointSettings: 2,
      );
}

Map<String, dynamic> _row(int id, String status, String channel, int ago,
        {List<String> address = const [],
        String name = 'Max Mustermann (Alias 123)',
        List<(String, String)> stations = const []}) =>
    {
      'id': id,
      'created_at': _now.subtract(Duration(minutes: ago)).toIso8601String(),
      'order_status': status,
      'order_type': 'pos',
      'channel_key': channel,
      'order_amount': 11.67,
      'customer_name': name,
      'address_lines': address,
      'display_method': 'card',
      'branch_name': 'Ludwigsfelde',
      'stations': [
        for (final (n, s) in stations) {'name': n, 'status': s},
      ],
    };

/// Figma 1915:15768's twelve cards, in its order.
class _Repo implements PosOrdersRepo {
  @override
  DioClient get dioClient => throw UnimplementedError();

  static const List<String> _addr = ['Potsdamer Str. 33', '14974 Ludwigsfelde'];

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
  }) async =>
      ApiResponseModel.withSuccess(Response(
        requestOptions: RequestOptions(path: '/orders'),
        statusCode: 200,
        data: {
          'counts': {
            'new': 6,
            'preparing': 2,
            'ready_to_collect': 0,
            'on_hold': 1,
            'completed': 3,
          },
          'orders': [
            _row(27364, 'new', 'web_app', 1, address: _addr),
            _row(27366, 'new', 'counter_pos', 2, address: _addr),
            _row(27368, 'new', 'web_app', 3, address: _addr),
            _row(27367, 'new', 'counter_pos', 6, address: _addr),
            _row(27369, 'new', 'counter_pos', 8, address: ['Ludwigsfelde']),
            _row(27365, 'new', 'web_app', 20, address: ['Ludwigsfelde']),
            _row(27363, 'preparing', 'web_app', 3,
                address: ['Ludwigsfelde'],
                stations: [('Bar', 'ready'), ('Kitchen', 'preparing')]),
            _row(27362, 'preparing', 'web_app', 7,
                address: _addr,
                stations: [('Bar', 'preparing'), ('Kitchen', 'preparing')]),
            _row(27361, 'on_hold', 'counter_pos', 9,
                address: ['Ludwigsfelde'],
                stations: [('Bar', 'ready'), ('Kitchen', 'pending')]),
            _row(27358, 'completed', 'counter_pos', 80,
                address: ['Berliner Str. 12', '10115 Berlin'],
                name: 'Anna Schmidt (Alias 456)'),
            _row(27359, 'completed', 'web_app', 60,
                address: ['Hauptstr. 7', '10827 Berlin'],
                name: 'Thomas Müller (Alias 789)'),
            _row(27360, 'completed', 'counter_pos', 35,
                address: ['Schönhauser Allee 45', '10439 Berlin'],
                name: 'Lisa Weber (Alias 321)'),
          ],
        },
      ));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Figma 1915:16197: App / NEW, both stations not started, Figma's own copy.
class _Manager implements KioskManagerRepo {
  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async =>
      ApiResponseModel.withSuccess(Response(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 200,
        data: {
          'id': 1234,
          'created_at': '2026-06-23T10:55:00',
          'order_status': 'new',
          'order_type': 'pos',
          'channel_key': 'web_app',
          'display_method': 'card',
          'payment_status': 'paid',
          'customer_name': 'Max Mustermann (Alias 123)',
          'customer_phone': '+49 176 1234567',
          'customer_email': 'max.mustermann@example.com',
          'order_note': '"Please make the Flat White extra hot. The Croissant '
              'should be warmed up if possible. Thanks!"',
          'items': [
            for (final (n, p, v, a, s) in const [
              ('Cappuccino', 4.5, 'Cup', 'Oat Milk', 'Bar'),
              ('Croissant', 3.2, 'Can', 'Warmed up', 'Kitchen'),
              ('Flat White', 4.0, 'Cup', 'Extra hot', 'Bar'),
            ])
              {
                'name': n,
                'quantity': 1,
                'unit_price': p,
                'prep_status': 'pending',
                'station': s,
                'variations': [
                  {
                    'name': 'Size',
                    'options': [
                      {'label': v}
                    ]
                  }
                ],
                'addons': [
                  {'name': a, 'quantity': 1}
                ],
              },
          ],
          'stations': [
            {'name': 'Bar', 'status': 'pending'},
            {'name': 'Kitchen', 'status': 'pending'},
          ],
          'subtotal': 11.7,
          'discount': 0,
          'total': 11.7,
        },
      ));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// The same order with addressable lines, so each row draws its action.
class _ManagerWithIds extends _Manager {
  @override
  Future<ApiResponseModel> getTransactionDetail(int id) async {
    final ApiResponseModel response = await super.getTransactionDetail(id);
    int next = 0;
    for (final item in (response.response!.data as Map)['items'] as List) {
      (item as Map)['id'] = ++next;
    }
    return response;
  }
}

class _Check {
  final String name;
  final double figma;
  final double actual;
  final bool strict;
  final double tolerance;
  const _Check(this.name, this.figma, this.actual, this.strict, this.tolerance);
  bool get ok => (figma - actual).abs() <= tolerance;
}

final List<_Check> _report = <_Check>[];

/// [tolerance] is half a pixel for geometry. Values that hang off a text
/// run's *width* get 1.5px: Figma and Flutter advance the same Loew glyphs
/// ~1px differently over a short word, which no layout value can change.
void _expectFigma(String name, double figma, double actual,
        {bool strict = true, double tolerance = 0.5}) =>
    _report.add(_Check(name, figma, actual, strict, tolerance));

void _expectAllMatch() {
  final List<_Check> off =
      _report.where((c) => c.strict && !c.ok).toList(growable: false);
  expect(
    off.map((c) => '${c.name}: Figma ${c.figma}, app ${c.actual}').toList(),
    isEmpty,
    reason: 'Orders must match Figma 1915:15767 node for node',
  );
}

void _printReport(String title) {
  // ignore: avoid_print
  print('\n== $title ==');
  for (final _Check c in _report) {
    // ignore: avoid_print
    print('${c.ok ? 'ok  ' : (c.strict ? 'DIFF' : 'kept')}  '
        '${c.name.padRight(46)} figma ${c.figma.toStringAsFixed(1).padLeft(7)}'
        '   app ${c.actual.toStringAsFixed(1).padLeft(7)}');
  }
}

Future<SharedPreferences> _prefs({bool images = false}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.token: 'device-token',
    AppConstants.branch: 1,
    AppConstants.kioskShowImages: images,
  });
  return SharedPreferences.getInstance();
}

Widget _host(SharedPreferences prefs, Widget body) => MultiProvider(
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
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  setUp(_report.clear);

  Rect rectOf(WidgetTester t, Finder f) => t.getRect(f);

  /// The decorated box a control's label sits in.
  Finder boxOf(Finder text) =>
      find.ancestor(of: text, matching: find.byType(Container)).first;

  testWidgets('board matches Figma 1915:15768', (tester) async {
    tester.view
      ..physicalSize = const Size(1366, 926)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final prefs = await _prefs();

    await tester.pumpWidget(_host(
        prefs, PosOrdersListScreen(repo: _Repo(), clock: () => _now)));
    await tester.pump();
    await tester.pump();

    // ── Filter area (1915:15771) ───────────────────────────────────────
    final Finder nowText = find.text('NOW').first;
    final Rect now = rectOf(tester, boxOf(nowText));
    final Rect nowT = rectOf(tester, nowText);
    _expectFigma('today-btn height', 30, now.height);
    _expectFigma('today-btn top', 14 + 1, now.top);
    _expectFigma('today-btn width', 62, now.width);
    _expectFigma('Now text dy', 8, nowT.top - now.top);
    _expectFigma('Now text height', 14, nowT.height);

    final Finder fromDate = find.textContaining(', 20').first;
    final Rect from = rectOf(tester, boxOf(fromDate));
    final Rect fromT = rectOf(tester, fromDate);
    _expectFigma('from-date height', 30, from.height);
    _expectFigma('from-date text dx', 30, fromT.left - from.left);
    _expectFigma('from-date text dy', 8, fromT.top - from.top);
    _expectFigma('From label height', 14,
        rectOf(tester, find.text('FROM')).height);
    _expectFigma('From label to field gap', 6,
        from.left - rectOf(tester, find.text('FROM')).right);

    final Rect search = rectOf(tester, find.byType(TextField));
    final Rect hint = rectOf(tester, find.text('SEARCH IN ORDERS...'));
    final Rect clear = rectOf(tester, find.byTooltip('Clear search'));
    _expectFigma('search-field height', 32, search.height);
    _expectFigma('search-field top', 14, search.top);
    _expectFigma('search-field right', 24 + 1318, search.right);
    _expectFigma('search hint dx', 30, hint.left - search.left);
    _expectFigma('search hint height', 14, hint.height);
    // Figma sets no tracking; M3's bodyLarge would otherwise add 0.5.
    _expectFigma(
        'search hint tracking',
        0,
        tester
                .widget<Text>(find.text('SEARCH IN ORDERS...'))
                .style
                ?.letterSpacing ??
            0,
        tolerance: 0.01);
    _expectFigma('close-btn width', 22, clear.width);
    _expectFigma('close-btn height', 16, clear.height);
    _expectFigma('close-btn right inset', 10, search.right - clear.right);
    _expectFigma('close-btn dy', 8, clear.top - search.top);

    final Finder filterText = find.text('FILTER');
    final Rect filter = rectOf(tester, boxOf(filterText));
    final Rect filterT = rectOf(tester, filterText);
    _expectFigma('filter-btn top', 56, filter.top);
    _expectFigma('filter-btn left', 24, filter.left);
    _expectFigma('filter-btn height', 32, filter.height);
    _expectFigma('filter-btn width', 99, filter.width, tolerance: 1.5);
    _expectFigma('Filter text width (glyph advance)', 47, filterT.width,
        tolerance: 1.5);
    _expectFigma('Filter text dx', 36, filterT.left - filter.left);
    _expectFigma('Filter text dy', 8, filterT.top - filter.top);
    _expectFigma('Filter text height', 16, filterT.height);

    final Finder srcText = find.text('ALL SOURCES');
    final Rect src = rectOf(tester, boxOf(srcText));
    final Rect srcT = rectOf(tester, srcText);
    _expectFigma('dropdown-sources left', 24 + 107, src.left, tolerance: 1.5);
    _expectFigma('dropdown-sources height', 32, src.height);
    _expectFigma('dropdown text dx', 12, srcT.left - src.left);
    _expectFigma('dropdown text dy', 8, srcT.top - src.top);
    _expectFigma('dropdown text height', 16, srcT.height);
    _expectFigma('dropdown right pad (14 chevron + 6 + 10)', 30,
        src.right - srcT.right);

    final Finder allText = find.text('ALL');
    final Rect all = rectOf(tester, boxOf(allText));
    _expectFigma('pill-popular top', 98, all.top);
    _expectFigma('pill-popular height', 32, all.height);
    _expectFigma('All text dx', 18, rectOf(tester, allText).left - all.left);

    // ── Sections (1915:15831) ──────────────────────────────────────────
    Finder header(String label) => find.byWidgetPredicate((w) =>
        w is Text &&
        w.data == label &&
        w.style?.fontSize == PosOrdersSpec.sectionHeaderSize);
    final Rect newH = rectOf(tester, header('NEW'));
    _expectFigma('section-new header top', 144 + 20, newH.top);
    _expectFigma('section-new header left', 24, newH.left);
    _expectFigma('NEW header height', 18, newH.height);
    final Rect badge = rectOf(tester, find.text('6'));
    _expectFigma('new-badge text height', 13, badge.height);

    final Finder cards = find.byType(PosOrderCardTile);
    final Rect c0 = rectOf(tester, cards.at(0));
    final Rect c1 = rectOf(tester, cards.at(1));
    final Rect c4 = rectOf(tester, cards.at(4));
    _expectFigma('first card top', 144 + 20 + 30, c0.top);
    _expectFigma('card width', 288, c0.width);
    // Every card keeps a two-line note's room and the grid gives a section
    // one height (user request 2026-10-19), so cards outgrow Figma's 155 and
    // the timer + footer sit on the bottom edge in every section.
    _expectFigma('card height', 155, c0.height, strict: false);
    _expectFigma('card gap x', 12, c1.left - c0.right);
    _expectFigma('card gap y', 12, c4.top - c0.bottom);

    // ── Card internals (1915:15837) ────────────────────────────────────
    Finder inCard(int i, Finder f) =>
        find.descendant(of: cards.at(i), matching: f);
    final Rect clock = rectOf(tester, inCard(0, find.text('10:35')));
    _expectFigma('card clock dx', 12 + 14, clock.left - c0.left);
    _expectFigma('card clock dy', 12, clock.top - c0.top);
    _expectFigma('card clock height', 16, clock.height);
    final Rect src0 =
        rectOf(tester, inCard(0, find.byType(PosOrderSourceIcon)));
    _expectFigma('source-badge dx', 252, src0.left - c0.left);
    _expectFigma('source-badge dy', 12, src0.top - c0.top);
    _expectFigma('source-badge size', 24, src0.width);
    // The order number (not in Figma; user request 2026-10-19) takes Figma's
    // customer-name slot in the name's own size, so the customer block below
    // moves down by exactly its height + gap and nothing else.
    final Rect number = rectOf(tester,
        inCard(0, find.byKey(PosOrderCardTile.numberKeyFor(27364))));
    _expectFigma('order number dy (Figma name slot)', 36, number.top - c0.top);
    _expectFigma('order number dx', 12, number.left - c0.left);
    _expectFigma('order number height (= name)', 17, number.height);
    final double shift =
        number.height + PosOrdersSpec.orderNumberGap; // the number row
    final Rect name =
        rectOf(tester, inCard(0, find.text('Max Mustermann (Alias 123)')));
    _expectFigma('customer name dy', 36, name.top - c0.top, strict: false);
    _expectFigma('customer name dy under the number', 36 + shift,
        name.top - c0.top);
    _expectFigma('customer name dx', 12, name.left - c0.left);
    _expectFigma('customer name height', 17, name.height);
    final Rect a1 = rectOf(tester, inCard(0, find.text('Potsdamer Str. 33')));
    final Rect a2 = rectOf(tester, inCard(0, find.text('14974 Ludwigsfelde')));
    _expectFigma('address line 1 dy', 36 + 19, a1.top - c0.top, strict: false);
    _expectFigma('address line 1 to name', 19, a1.top - name.top);
    _expectFigma('address line height', 13, a1.height);
    _expectFigma('address line 2 dy', 36 + 34, a2.top - c0.top, strict: false);
    _expectFigma('address line 2 to name', 34, a2.top - name.top);
    final Rect timer = rectOf(tester, inCard(0, find.text('1:00')));
    _expectFigma('timer dy', 91, timer.top - c0.top, strict: false);
    _expectFigma('timer height', 13, timer.height);
    final Rect price = rectOf(tester, inCard(0, find.textContaining('11')));
    _expectFigma('price dy', 112, price.top - c0.top, strict: false);
    _expectFigma('price height', 17, price.height);

    // Urgent card (1915:15946): content inset by the 4px bar.
    final Rect u = rectOf(tester, cards.at(5));
    final Rect uName = rectOf(tester,
        inCard(5, find.text('Max Mustermann (Alias 123)')));
    _expectFigma('urgent card content dx', 4 + 12, uName.left - u.left);
    _expectFigma('urgent card name dy', 36, uName.top - u.top, strict: false);
    _expectFigma('urgent card name dy under the number', 36 + shift,
        uName.top - u.top);

    // IN PROGRESS card (1915:15974): footer pinned to the bottom.
    final Rect p = rectOf(tester, cards.at(6));
    _expectFigma('in-progress card height', 155, p.height, strict: false);
    final Rect pill = rectOf(tester,
        find.ancestor(of: find.text('Bar · Ready').first,
            matching: find.byType(AnimatedContainer)).first);
    final Rect pillT = rectOf(tester, find.text('Bar · Ready').first);
    _expectFigma('station pill height', 18, pill.height);
    _expectFigma('station pill text dx', 8, pillT.left - pill.left);
    _expectFigma('station pill text height', 12, pillT.height);
    _expectFigma('station pill dy in card', 125, pill.top - p.top,
        strict: false);
    final Rect pTimer = rectOf(tester, inCard(6, find.text('3:00')));
    _expectFigma('in-progress timer dy', 104, pTimer.top - p.top,
        strict: false);
    // The pinned bottom group itself is still Figma's (1915:15986): footer 12
    // off the bottom edge, timer 21 above the pills.
    _expectFigma('station pill bottom inset', 155 - 125 - 18,
        p.bottom - pill.bottom);
    _expectFigma('in-progress timer to pill', 125 - 104, pill.top - pTimer.top);

    _printReport('board');
    expect(tester.takeException(), isNull);
    _expectAllMatch();
  });

  testWidgets('detail modal matches Figma 1915:16197', (tester) async {
    tester.view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final prefs = await _prefs();

    final PosOrderCard card = PosOrderCard(
      id: 1234,
      createdAt: DateTime(2026, 6, 23, 10, 55),
      orderStatus: 'new',
      orderType: 'pos',
      channelKey: 'web_app',
      orderAmount: 11.7,
      customerName: 'Max Mustermann (Alias 123)',
      addressLines: const [],
      displayMethod: 'card',
    );

    await tester.pumpWidget(_host(
      prefs,
      PosOrderDetailOverlay(
        order: card,
        repo: _Manager(),
        ordersRepo: _Repo(),
        onAdvance: (_) async => const PosAdvanceResult.advanced(),
      ),
    ));
    await tester.pumpAndSettle();

    final Finder title = find.text('Order #1234');
    final Rect t = rectOf(tester, title);
    // The modal's own box: the Container holding header, body and bar.
    final Rect modal = rectOf(tester,
        find.ancestor(of: title, matching: find.byType(Container)).last);
    _expectFigma('modal width', 1120, modal.width);
    _expectFigma('title dx', 24, t.left - modal.left);
    _expectFigma('title dy', 24, t.top - modal.top);
    _expectFigma('title height', 26, t.height);

    Rect pillOf(String text) =>
        rectOf(tester, find.ancestor(of: find.text(text).first,
            matching: find.byType(Container)).first);
    final Rect status = pillOf('NEW');
    final Rect statusT = rectOf(tester, find.text('NEW'));
    _expectFigma('status badge height', 22, status.height);
    _expectFigma('status badge dx from title', 12, status.left - t.right);
    _expectFigma('status text dx', 10, statusT.left - status.left);
    _expectFigma('status text height', 14, statusT.height);
    final Rect time = pillOf('10:55');
    _expectFigma('time badge height', 24, time.height);
    _expectFigma('time text height', 16,
        rectOf(tester, find.text('10:55')).height);
    final Rect source = pillOf('App Order');
    final Rect sourceT = rectOf(tester, find.text('App Order'));
    _expectFigma('source badge height', 24, source.height);
    _expectFigma('source text dx', 30, sourceT.left - source.left);
    _expectFigma('source text dy', 4, sourceT.top - source.top);
    final Rect station = rectOf(tester, find.ancestor(
        of: find.text('Bar · Pending').first,
        matching: find.byType(AnimatedContainer)).first);
    _expectFigma('header station pill height', 22, station.height);
    _expectFigma('header station gap', 12, station.left - source.right);

    final Rect custLabel = rectOf(tester, find.text('CUSTOMER DETAILS'));
    _expectFigma('customer label dy', 66 + 24, custLabel.top - modal.top);
    _expectFigma('customer label height', 14, custLabel.height);
    final Rect custName =
        rectOf(tester, find.text('Max Mustermann (Alias 123)').last);
    _expectFigma('customer name dy', 66 + 24 + 24 + 16, custName.top - modal.top);
    _expectFigma('customer name height', 19, custName.height);
    final Rect phone = rectOf(tester, find.text('+49 176 1234567'));
    _expectFigma('phone dy', 66 + 24 + 24 + 43, phone.top - modal.top);
    _expectFigma('phone height', 16, phone.height);
    _expectFigma('phone text dx from card', 16 + 22, phone.left - custLabel.left);
    final Rect mail = rectOf(tester, find.text('max.mustermann@example.com'));
    _expectFigma('mail dy', 66 + 24 + 24 + 63, mail.top - modal.top);

    // Order Notes moved under Total on request (2026-10-19) and gathers every
    // note on the order, each headed with its line or "Whole order", in 15/22
    // so a kitchen instruction reads at a glance. Figma's place above Total
    // and its 13/18 text are reported, not enforced.
    final Rect notesLabel = rectOf(tester, find.text('ORDER NOTES'));
    _expectFigma('notes label dy', 66 + 24 + 143, notesLabel.top - modal.top,
        strict: false);
    final Rect note = rectOf(tester, find.textContaining('Please make'));
    _expectFigma('note text dy', 66 + 24 + 143 + 22 + 14, note.top - modal.top,
        strict: false);
    _expectFigma('note text height (2 lines)', 36, note.height, strict: false);
    expect(notesLabel.top,
        greaterThan(rectOf(tester, find.text('TOTAL')).bottom),
        reason: 'Order Notes sits under Total');
    expect(notesLabel.left, custLabel.left,
        reason: 'and stays in the left column');

    final Rect itemsLabel = rectOf(tester, find.text('ORDER ITEMS'));
    _expectFigma('items label dx', 24 + 620 + 32, itemsLabel.left - modal.left);
    final Rect cap = rectOf(tester, find.text('Cappuccino'));
    final Rect meta = rectOf(tester, find.text('€ 4.50 · Cup'));
    final Rect addon = rectOf(tester, find.text('Oat Milk'));
    _expectFigma('item name height', 17, cap.height);
    _expectFigma('item meta gap', 4, meta.top - cap.bottom);
    _expectFigma('item meta height', 14, meta.height);
    _expectFigma('item note gap', 4, addon.top - meta.bottom - 0.5);
    _expectFigma('item note height', 13, addon.height);
    final Rect itemPill = rectOf(tester, find.ancestor(
        of: find.text('Bar · Pending').at(1),
        matching: find.byType(AnimatedContainer)).first);
    _expectFigma('item pill height', 21, itemPill.height);
    // Picture-less rows: the kept colour bar hugs the text, so each row is
    // Figma's 77 (12 + 53 + 12).
    _expectFigma('item row pitch', 77,
        rectOf(tester, find.text('Croissant')).top - cap.top);
    _expectFigma('item pill text height', 13,
        rectOf(tester, find.text('Bar · Pending').at(1)).height);
    _expectFigma('items list dy (label + 4)', 18,
        cap.top - 12 - itemsLabel.top, strict: false);

    _printReport('modal');
    expect(tester.takeException(), isNull);
    _expectAllMatch();
  });

  testWidgets(
      'thumbnail + station pill + action: the pill keeps Figma\'s '
      'top-right place (1915:16923)', (tester) async {
    tester.view
      ..physicalSize = const Size(1366, 1024)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final prefs = await _prefs(images: true);

    await tester.pumpWidget(_host(
      prefs,
      PosOrderDetailOverlay(
        order: PosOrderCard(
          id: 1234,
          createdAt: DateTime(2026, 6, 23, 10, 55),
          orderStatus: 'new',
          orderType: 'pos',
          channelKey: 'web_app',
          orderAmount: 11.7,
          customerName: 'Max Mustermann (Alias 123)',
          addressLines: const [],
          displayMethod: 'card',
        ),
        repo: _ManagerWithIds(),
        ordersRepo: _Repo(),
        onAdvance: (_) async => const PosAdvanceResult.advanced(),
      ),
    ));
    await tester.pumpAndSettle();

    // Beside a thumbnail, "Kitchen · Pending" and a Start button leave the
    // name too little room on one line; the row used to drop both under the
    // text. Figma keeps the pill top-right on the name's line.
    final Rect itemsLabel = rectOf(tester, find.text('ORDER ITEMS'));
    final double columnRight = itemsLabel.left + 420;
    final Rect name = rectOf(tester, find.text('Croissant'));
    final Rect pill = rectOf(
        tester,
        find
            .ancestor(
                of: find.text('Kitchen · Pending').at(1),
                matching: find.byType(AnimatedContainer))
            .first);
    _expectFigma('pill right inset', 16, columnRight - pill.right);
    _expectFigma('pill dy from name', 2, pill.top - name.top);
    _expectFigma('pill height', 21, pill.height);

    // The action hangs under its own pill, flush right with it.
    final Rect start = find
        .text('Start')
        .evaluate()
        .map((e) => tester.getRect(find
            .ancestor(
                of: find.byWidget(e.widget),
                matching: find.byType(PosItemActionButton))
            .first))
        .firstWhere((r) => r.top > pill.top && r.top < pill.bottom + 20);
    _expectFigma('action gap under pill', 8, start.top - pill.bottom,
        strict: false);
    _expectFigma('action right = pill right', pill.right, start.right);
    _expectFigma('action height', 44, start.height);
    // Every name stays on one readable line.
    for (final String n in const ['Cappuccino', 'Croissant', 'Flat White']) {
      _expectFigma('$n on one line', 17, rectOf(tester, find.text(n)).height);
    }

    _printReport('item rows with thumbnails');
    expect(tester.takeException(), isNull);
    _expectAllMatch();
  });
}
