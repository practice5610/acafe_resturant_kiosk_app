import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_hourly_chart.dart';
import 'package:acafe_customer/features/pos/screens/pos_report_screen.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rubik is the app-wide family (see `light_theme.dart`) and POS widgets never
/// override it, so that is what this screen actually renders in. Loew is loaded
/// too because the shell chrome uses it. Without both, every glyph in the
/// golden is a tofu box and the file is worthless as a comparison.
Future<void> _loadFonts() async {
  const Map<String, List<String>> families = <String, List<String>>{
    'Rubik': <String>[
      'assets/fonts/Rubik-Regular.ttf',
      'assets/fonts/Rubik-Medium.ttf',
      'assets/fonts/Rubik-Bold.ttf',
    ],
    'Loew': <String>[
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
      'assets/fonts/Loew-ExtraBold.ttf',
    ],
  };

  for (final MapEntry<String, List<String>> entry in families.entries) {
    final FontLoader loader = FontLoader(entry.key);
    for (final String path in entry.value) {
      loader.addFont(File(path)
          .readAsBytes()
          .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    await loader.load();
  }

  // The Material icon glyphs (calendar, chevrons, the missing-thumbnail
  // placeholder) are not registered in a widget test, so every `Icon` rasterises
  // as a tofu box. `flutter test` exports FLUTTER_ROOT; if it ever does not, the
  // golden still renders — just with boxes where the icons are — rather than the
  // suite failing on a missing file.
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final File icons = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      final FontLoader loader = FontLoader('MaterialIcons');
      loader.addFont(icons
          .readAsBytes()
          .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
      await loader.load();
    }
  }
}

class _Splash extends SplashProvider {
  _Splash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        restaurantName: 'A|CAFÉ Amsterdam',
        currencySymbol: '€',
        countryCode: 'NL',
        decimalPointSettings: 2,
      );
}

/// Exactly the shape `KioskManagerController::salesOverview` returns.
///
/// Note the deliberate mix of `int` and `double` in the money fields: PHP's
/// json_encode emits a round 50.0 as `50`, and the model has to survive that.
Map<String, dynamic> _reportPayload({
  bool closed = false,
  bool taxRecorded = true,
  bool hourlyRecorded = true,
  bool topProductsRecorded = true,
  bool categoryRecorded = true,
}) =>
    <String, dynamic>{
      'branch_id': 1,
      'report_date': '2026-06-23',
      'closed': closed,
      'z_number': closed ? 42 : null,
      'sales': <String, dynamic>{
        'net_sales': 1568.13,
        'total_tax': 274.37,
        'total_discount': 18.5,
        'total_tips': 86.2,
        'average_order_value': 12.45,
        'gross_sales': 1586.63,
      },
      'transactions': <String, dynamic>{
        'order_count': 148,
        'completed_order_count': 126,
        'canceled_order_count': 3,
      },
      'discounts': <String, dynamic>{
        'coupon': 0,
        'coupon_count': 0,
        'manual': 18.5,
        'manual_count': 5,
      },
      'voided': <String, dynamic>{
        'count': 3,
        'value': 32,
        'approx_refund_value': 32,
      },
      'payment_methods': <String, dynamic>{
        'total': 1842.5,
        'methods': <Map<String, dynamic>>[
          <String, dynamic>{
            'method': 'cash',
            'method_key': 'cash',
            'order_count': 62,
            'amount': 724.5,
          },
          <String, dynamic>{
            'method': 'card',
            'method_key': 'card',
            'order_count': 79,
            'amount': 1031.2,
          },
          <String, dynamic>{
            'method': 'wallet',
            'method_key': 'wallet',
            'order_count': 0,
            'amount': 0,
          },
        ],
      },
      'tax_breakdown': <String, dynamic>{
        'total': 274.37,
        'recorded': taxRecorded,
        'rows': <Map<String, dynamic>>[
          <String, dynamic>{'rate': 9, 'label': 'BTW 9%', 'amount': 87.23},
          <String, dynamic>{'rate': 21, 'label': 'BTW 21%', 'amount': 187.14},
        ],
      },
      'hourly_sales': <String, dynamic>{
        'recorded': hourlyRecorded,
        'max_amount': 320,
        // Peak is 09:00 on purpose: a chart that highlights noon regardless is
        // the exact bug this asserts against.
        'peak_hours': <int>[9],
        'hours': <Map<String, dynamic>>[
          <String, dynamic>{'hour': 8, 'label': '08', 'amount': 120, 'order_count': 9},
          <String, dynamic>{'hour': 9, 'label': '09', 'amount': 320, 'order_count': 24},
          <String, dynamic>{'hour': 10, 'label': '10', 'amount': 0, 'order_count': 0},
          <String, dynamic>{'hour': 11, 'label': '11', 'amount': 210, 'order_count': 17},
          <String, dynamic>{'hour': 12, 'label': '12', 'amount': 180, 'order_count': 15},
        ],
      },
      'top_products': <String, dynamic>{
        'recorded': topProductsRecorded,
        'rows': <Map<String, dynamic>>[
          <String, dynamic>{
            'product_id': 1,
            'name': 'Iced Matcha Latte',
            'quantity': 34,
            'amount': 238,
            'image_full_path': null,
          },
          <String, dynamic>{
            'product_id': 2,
            'name': 'Strawberry Matcha',
            'quantity': 26,
            'amount': 160,
            'image_full_path': null,
          },
        ],
      },
      'category_sales': <String, dynamic>{
        'recorded': categoryRecorded,
        'total': 1568.13,
        'buckets': <Map<String, dynamic>>[
          <String, dynamic>{'category': 'Matcha', 'amount': 465.5, 'percentage': 42},
          <String, dynamic>{'category': 'Coffee', 'amount': 310, 'percentage': 28},
          <String, dynamic>{'category': 'Poffertjes', 'amount': 236, 'percentage': 22},
        ],
      },
      'cash_drawer': <String, dynamic>{
        'recorded': true,
        'cash_sales': 724.5,
        'cash_sales_count': 62,
        'cash_refunds': 12,
        'cash_refunds_count': 1,
        'reconciliation_available': false,
      },
      'reconciliation': <String, dynamic>{
        'ok': true,
        'customer_paid': 1842.5,
      },
      'pending_prep_count': 32,
      'previous_day_revenue': 1754.76,
      'has_orders': true,
    };

/// Serves a fixed payload without a network, and records what Close Day did.
class _StubManager extends KioskManagerProvider {
  _StubManager({required super.kioskManagerRepo, Map<String, dynamic>? payload})
      : _payload = payload ?? _defaultPayload();

  static Map<String, dynamic> _defaultPayload() => _reportPayload();

  final Map<String, dynamic> _payload;

  final List<String> requestedDates = <String>[];
  final List<String> closedDates = <String>[];

  /// Set when a load "completes". Left null by [defer] so a test can hold a
  /// day in flight and assert what the screen shows meanwhile.
  String? _loadedDate;
  bool defer = false;

  /// Models the provider's real in-flight flag, which the screen uses to tell
  /// "still fetching" apart from "fetch failed".
  bool _inFlight = false;

  @override
  Map<String, dynamic>? get salesData => _loadedDate == null ? null : _payload;

  @override
  String? get salesDataDate => _loadedDate;

  @override
  bool get salesLoading => _inFlight;

  @override
  bool get closingRegister => false;

  @override
  Future<void> loadSalesOverview({String? reportDate}) async {
    requestedDates.add(reportDate ?? '');
    if (defer) {
      _inFlight = true;
      notifyListeners();
      return;
    }
    _inFlight = false;
    _loadedDate = reportDate;
    notifyListeners();
  }

  /// Live listener count. The classic Provider leak is a screen that subscribes
  /// and never unsubscribes, so this is the number that must come back down.
  int liveListeners = 0;

  @override
  void addListener(VoidCallback listener) {
    liveListeners++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    liveListeners--;
    super.removeListener(listener);
  }

  /// A notification from an unrelated part of this shared provider.
  void notifyUnrelated() => notifyListeners();

  /// Completes a deferred load, as the network eventually would.
  void completeLoad(String reportDate) {
    _inFlight = false;
    _loadedDate = reportDate;
    notifyListeners();
  }

  /// A load that comes back empty-handed, so the screen must offer a retry
  /// rather than spin forever.
  void failLoad() {
    _inFlight = false;
    notifyListeners();
  }

  @override
  Future<bool> closeZReport({required String reportDate, String? comment}) async {
    closedDates.add(reportDate);
    _loadedDate = reportDate;
    notifyListeners();
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  Future<_StubManager> pumpAt(
    WidgetTester tester,
    Size size, {
    Map<String, dynamic>? payload,
    DateTime? initialDate,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{
      AppConstants.languageCode: 'en',
      AppConstants.countryCode: 'NL',
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final DioClient dio = DioClient(
      'http://localhost',
      null,
      loggingInterceptor: LoggingInterceptor(),
      sharedPreferences: prefs,
    );
    final _StubManager manager = _StubManager(
      kioskManagerRepo:
          KioskManagerRepo(dioClient: dio, sharedPreferences: prefs),
      payload: payload,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SplashProvider>(
            create: (_) => _Splash(
              splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
            ),
          ),
          ChangeNotifierProvider<KioskManagerProvider>.value(value: manager),
        ],
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: PosShell(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Rubik'),
              home: Scaffold(
                backgroundColor: PosHomeSpec.pageBg,
                body: PosReportScreen(initialDate: initialDate),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return manager;
  }

  group('PosReportData', () {
    test('reads money fields that JSON round-tripped into ints', () {
      final PosReportData data = PosReportData(_reportPayload());

      // `voided.value` and `cash_drawer.cash_refunds` are ints in the fixture,
      // exactly as PHP emits them for round amounts.
      expect(data.refundValue, 32.0);
      expect(data.cashRefunds, 12.0);
      expect(data.totalRevenue, 1842.5);
    });

    test('total revenue is net + VAT, not the service gross_sales field', () {
      final PosReportData data = PosReportData(_reportPayload());

      // Decision 3: Figma's arithmetic. gross_sales (1586.63 = net + discounts)
      // is a different number and must not leak onto this card.
      expect(data.totalRevenue, closeTo(data.netSales + data.totalTax, 0.01));
      expect(data.totalRevenue, isNot(1586.63));
    });

    test('tax rows sum to the headline tax figure', () {
      final PosReportData data = PosReportData(_reportPayload());
      final double summed =
          data.taxRows.fold(0.0, (double sum, PosReportTaxRow r) => sum + r.amount);

      expect(summed, closeTo(data.totalTax, 0.01));
    });

    test('vs-yesterday delta is null when yesterday took nothing', () {
      final Map<String, dynamic> json = _reportPayload()
        ..['previous_day_revenue'] = 0;

      expect(PosReportData(json).revenueDeltaPercent, isNull);
      expect(PosReportData(_reportPayload()).revenueDeltaPercent, isNotNull);
    });

    test('peak label follows the data rather than defaulting to noon', () {
      expect(PosReportData(_reportPayload()).peakLabel, 'Peak: 09:00-10:00');
    });

    test('recorded:false sections are distinguishable from empty ones', () {
      final PosReportData missing =
          PosReportData(_reportPayload(hourlyRecorded: false));

      expect(missing.hourlyRecorded, isFalse);
      expect(PosReportData(_reportPayload()).hourlyRecorded, isTrue);
    });
  });

  group('Report Overview screen', () {
    testWidgets('renders every panel with real figures', (tester) async {
      await pumpAt(tester, const Size(1366, 926));

      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('Payment Methods'), findsOneWidget);
      expect(find.text('Top Selling Products'), findsOneWidget);
      expect(find.text('Hourly Sales'), findsOneWidget);
      expect(find.text('Cash Drawer Summary'), findsOneWidget);
      expect(find.text('Category Sales'), findsOneWidget);
      expect(find.text('Staff Shifts & Tips'), findsOneWidget);
      expect(find.text('Refunds & Discounts'), findsOneWidget);

      // VAT split, straight off tax_breakdown.
      expect(find.text('BTW 9%'), findsOneWidget);
      expect(find.text('BTW 21%'), findsOneWidget);

      // Pending-prep badge and the Wallet bucket, both real.
      expect(find.text('32 pending prep'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('fetches exactly the selected day and re-fetches on step',
        (tester) async {
      final _StubManager manager = await pumpAt(tester, const Size(1366, 926));

      final String today = manager.requestedDates.single;
      expect(today, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

      await tester.tap(find.byTooltip('Previous day'));
      await tester.pumpAndSettle();

      expect(manager.requestedDates, hasLength(2));
      expect(manager.requestedDates.last, isNot(today));
    });

    testWidgets('next-day is disabled on today', (tester) async {
      final _StubManager manager = await pumpAt(tester, const Size(1366, 926));

      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();

      // Still just the initial load: the endpoint 422s on a future date, so the
      // control must not fire at all.
      expect(manager.requestedDates, hasLength(1));
    });

    testWidgets('Close Day calls the existing close endpoint after confirming',
        (tester) async {
      final _StubManager manager = await pumpAt(tester, const Size(1366, 926));

      await tester.tap(find.text('Close Day'));
      await tester.pumpAndSettle();

      // The dialog is a guard, not a second close mechanism.
      expect(find.textContaining('finalises the Z Report'), findsOneWidget);
      expect(manager.closedDates, isEmpty);

      await tester.tap(find.widgetWithText(TextButton, 'Close Day'));
      await tester.pumpAndSettle();

      expect(manager.closedDates, hasLength(1));
      expect(manager.closedDates.single, manager.requestedDates.first);
      // A successful close re-reads the day, so the header flips to its closed
      // state from the server's answer rather than a local assumption.
      expect(manager.requestedDates, hasLength(2));
    });

    testWidgets('a closed day shows the closed state instead of a live CTA',
        (tester) async {
      await pumpAt(tester, const Size(1366, 926),
          payload: _reportPayload(closed: true));

      expect(find.text('Day Closed'), findsOneWidget);
      expect(find.text('Close Day'), findsNothing);
    });

    testWidgets('fabricates nothing for staff or the retired drawer rows',
        (tester) async {
      await pumpAt(tester, const Size(1366, 926));

      // Decision 2: the panel ships complete but honest.
      expect(find.text("Staff attribution isn't tracked yet"), findsOneWidget);

      // Decision 1: the retired reconciliation rows must not appear at all —
      // a zero-filled "Difference: € 0.00" would read as a balanced drawer.
      expect(find.text('Opening float'), findsNothing);
      expect(find.text('Actual count'), findsNothing);
      expect(find.text('Expected in drawer'), findsNothing);
      expect(find.text('Difference'), findsNothing);
      expect(find.text('Drawer count not tracked'), findsOneWidget);

      // What is real is still shown.
      expect(find.textContaining('Cash sales (62)'), findsOneWidget);
    });

    testWidgets('a pre-migration closed day says so rather than showing zeros',
        (tester) async {
      await pumpAt(
        tester,
        const Size(1366, 926),
        payload: _reportPayload(
          closed: true,
          hourlyRecorded: false,
          topProductsRecorded: false,
          categoryRecorded: false,
        ),
      );

      expect(find.text('Not captured for this day'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('never renders one day\'s figures under another day\'s date',
        (tester) async {
      final _StubManager manager = await pumpAt(
        tester,
        const Size(1366, 926),
        initialDate: DateTime(2026, 6, 23),
      );
      expect(find.text('€ 1,842.50'), findsWidgets);

      // Step back a day, with the network held open.
      manager.defer = true;
      await tester.tap(find.byTooltip('Previous day'));
      // pump, not pumpAndSettle: the loading spinner animates forever, so
      // "settled" never arrives while a day is deliberately in flight.
      await tester.pump();

      // The 23rd's figures must be gone the instant the date changes. Leaving
      // them up is worse than a spinner: they look like the 22nd's real data.
      expect(find.text('€ 1,842.50'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(manager.requestedDates.last, '2026-06-22');

      manager.completeLoad('2026-06-22');
      await tester.pumpAndSettle();
      expect(find.text('€ 1,842.50'), findsWidgets);
    });

    testWidgets('a superseded response cannot overwrite the day on screen',
        (tester) async {
      final _StubManager manager = await pumpAt(
        tester,
        const Size(1366, 926),
        initialDate: DateTime(2026, 6, 23),
      );

      manager.defer = true;
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();
      expect(manager.requestedDates, <String>['2026-06-23', '2026-06-22', '2026-06-21']);

      // The 22nd answers late, after the user has already moved to the 21st.
      manager.completeLoad('2026-06-22');
      await tester.pump();

      // Still nothing on screen: the payload does not match the selected day.
      expect(find.text('€ 1,842.50'), findsNothing);

      manager.completeLoad('2026-06-21');
      await tester.pumpAndSettle();
      expect(find.text('€ 1,842.50'), findsWidgets);
    });

    testWidgets('a failed load offers a retry instead of spinning forever',
        (tester) async {
      final _StubManager manager = await pumpAt(
        tester,
        const Size(1366, 926),
        initialDate: DateTime(2026, 6, 23),
      );

      manager.defer = true;
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The request comes back empty-handed. Because the loaded date never
      // matches the selected one, an "unmatched date means still loading" rule
      // would leave this spinner up permanently.
      manager.failLoad();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining("Couldn't load"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      // And the retry re-requests that same day.
      manager.defer = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(manager.requestedDates.last, '2026-06-22');
      expect(find.text('€ 1,842.50'), findsWidgets);
    });

    testWidgets('an unrelated provider notification does not rebuild the panels',
        (tester) async {
      final _StubManager manager = await pumpAt(
        tester,
        const Size(1366, 926),
        initialDate: DateTime(2026, 6, 23),
      );

      final PosReportHourlyChart before =
          tester.widget<PosReportHourlyChart>(find.byType(PosReportHourlyChart));

      // Something else on the shared KioskManagerProvider changed — a Receipts
      // page load, a stock toggle. This screen reads none of it.
      manager.notifyUnrelated();
      await tester.pump();

      final PosReportHourlyChart after =
          tester.widget<PosReportHourlyChart>(find.byType(PosReportHourlyChart));

      // Identical instance => the subtree was never rebuilt. A Consumer here
      // would have rebuilt all nine panels and the chart.
      expect(identical(before, after), isTrue);
    });

    testWidgets('a section the backend never sent reads as not recorded',
        (tester) async {
      // Deploy skew: this build is ahead of the API, so the keys are absent
      // rather than present-and-false. Absent must not read as "zero".
      final Map<String, dynamic> old = _reportPayload()
        ..remove('hourly_sales')
        ..remove('top_products')
        ..remove('category_sales')
        ..remove('cash_drawer');

      await pumpAt(tester, const Size(1366, 926),
          payload: old, initialDate: DateTime(2026, 6, 23));

      expect(find.text('Not captured for this day'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty payment split on a day with orders says so',
        (tester) async {
      final Map<String, dynamic> broken = _reportPayload()
        ..['payment_methods'] = <String, dynamic>{'total': 0, 'methods': <dynamic>[]};

      await pumpAt(tester, const Size(1366, 926),
          payload: broken, initialDate: DateTime(2026, 6, 23));

      // 148 orders and no payment rows is a gap, not a quiet day.
      expect(find.text('Payment breakdown unavailable'), findsOneWidget);
      expect(find.text('No payments taken'), findsNothing);
    });

    for (final Size size in const <Size>[
      Size(1920, 1080), // large counter display
      Size(1366, 926), // the Figma frame
      Size(1180, 820), // tablet landscape
      Size(900, 1200), // tablet portrait
      Size(720, 1024), // narrowest supported
    ]) {
      testWidgets('lays out without overflow at ${size.width}x${size.height}',
          (tester) async {
        await pumpAt(tester, size);

        // A RenderFlex overflow surfaces as an exception here, so this covers
        // clipped cards and truncated rows across every band.
        expect(tester.takeException(), isNull);
        expect(find.text('Total Revenue'), findsOneWidget);
        expect(find.text('Refunds & Discounts'), findsOneWidget);
      });
    }

    testWidgets('date navigation costs exactly one fetch and no idle rebuilds',
        (tester) async {
      final _StubManager manager = await pumpAt(
        tester,
        const Size(1366, 926),
        initialDate: DateTime(2026, 6, 23),
      );

      final PosReportHourlyChart before =
          tester.widget<PosReportHourlyChart>(find.byType(PosReportHourlyChart));

      // A busy shared provider: 200 notifications this screen reads nothing
      // from. None of them may reconstruct the dashboard.
      for (int i = 0; i < 200; i++) {
        manager.notifyUnrelated();
        await tester.pump();
      }
      expect(
        identical(
          before,
          tester.widget<PosReportHourlyChart>(find.byType(PosReportHourlyChart)),
        ),
        isTrue,
        reason: '200 unrelated notifications rebuilt the dashboard',
      );

      for (int i = 0; i < 60; i++) {
        await tester.tap(find.byTooltip('Previous day'));
        await tester.pump();
      }

      // One request per navigation plus the initial load — never a re-fetch of
      // a day already asked for, and never a whole-app reload.
      expect(manager.requestedDates, hasLength(61));
      expect(manager.requestedDates.toSet(), hasLength(61));
      expect(tester.takeException(), isNull);
    });

    testWidgets('repeated visits leave nothing subscribed behind', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppConstants.languageCode: 'en',
        AppConstants.countryCode: 'NL',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DioClient dio = DioClient(
        'http://localhost',
        null,
        loggingInterceptor: LoggingInterceptor(),
        sharedPreferences: prefs,
      );
      final _StubManager manager = _StubManager(
        kioskManagerRepo:
            KioskManagerRepo(dioClient: dio, sharedPreferences: prefs),
      );

      tester.view.physicalSize = const Size(1366, 926);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Widget app({required bool showReport}) => MultiProvider(
            providers: [
              ChangeNotifierProvider<SplashProvider>(
                create: (_) => _Splash(
                  splashRepo:
                      SplashRepo(dioClient: dio, sharedPreferences: prefs),
                ),
              ),
              ChangeNotifierProvider<KioskManagerProvider>.value(value: manager),
            ],
            child: MediaQuery(
              data: const MediaQueryData(size: Size(1366, 926)),
              child: PosShell(
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: ThemeData(fontFamily: 'Rubik'),
                  home: Scaffold(
                    backgroundColor: PosHomeSpec.pageBg,
                    body: showReport
                        ? PosReportScreen(initialDate: DateTime(2026, 6, 23))
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          );

      final List<int> listenersWhileOpen = <int>[];
      final List<int> listenersWhileClosed = <int>[];

      // Enter and leave the screen repeatedly, as a manager stepping in and out
      // of the Report tab all shift would.
      for (int visit = 0; visit < 6; visit++) {
        await tester.pumpWidget(app(showReport: true));
        await tester.pump(const Duration(milliseconds: 50));
        listenersWhileOpen.add(manager.liveListeners);

        await tester.pumpWidget(app(showReport: false));
        await tester.pump(const Duration(milliseconds: 50));
        listenersWhileClosed.add(manager.liveListeners);
      }

      // Flat across visits, not climbing: nothing accumulates.
      expect(
        listenersWhileOpen.toSet(),
        hasLength(1),
        reason: 'subscriptions grew across visits: $listenersWhileOpen',
      );
      expect(
        listenersWhileClosed.toSet(),
        hasLength(1),
        reason: 'subscriptions were not released on leave: $listenersWhileClosed',
      );
      // Bounded, not merely flat. The one listener is ChangeNotifierProvider's
      // own — it subscribes once and fans out through element dependencies, so
      // `context.select` adds none of its own. What matters is that six visits
      // do not leave six subscriptions behind.
      expect(listenersWhileOpen.last, lessThanOrEqualTo(2));
      expect(listenersWhileClosed.last, lessThanOrEqualTo(2));

      // The screen really is gone, not merely off-screen and still listening.
      expect(find.byType(PosReportScreen), findsNothing);

      // No timers, controllers, tickers or streams anywhere in these widgets,
      // so a pending frame callback here would mean one was introduced without
      // a matching dispose().
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Report Overview golden at 1366x926 (Figma 1641:5518)',
        (tester) async {
      // Pinned to Figma's own date so the golden does not change every midnight.
      await pumpAt(
        tester,
        const Size(1366, 926),
        initialDate: DateTime(2026, 6, 23),
      );

      await expectLater(
        find.byType(PosReportScreen),
        matchesGoldenFile('goldens/pos_report_1366.png'),
      );
    }, skip: !Platform.isMacOS && !Platform.isLinux);

    testWidgets('Report Overview golden on a narrow tablet (2-column reflow)',
        (tester) async {
      await pumpAt(
        tester,
        const Size(900, 1200),
        initialDate: DateTime(2026, 6, 23),
      );

      await expectLater(
        find.byType(PosReportScreen),
        matchesGoldenFile('goldens/pos_report_900.png'),
      );
    }, skip: !Platform.isMacOS && !Platform.isLinux);
  });

  test('spec keeps the Figma palette', () {
    // Guards the two values most likely to be "tidied" into the general POS
    // tokens: the report frames use a warmer border and a translucent muted
    // ink than PosUI's defaults.
    expect(PosReportSpec.cardBorder, const Color(0xFFE1DBC4));
    expect(PosReportSpec.inkMuted, const Color(0x99241F20));
  });
}
