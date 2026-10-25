import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_logout_button.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_pin_entry_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_staff_exit_trigger.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_category_sidebar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_category_strip.dart';
import 'package:acafe_customer/features/pos/widgets/pos_kiosk_mode_actions.dart';
import 'package:acafe_customer/helper/kiosk_route_guard.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// POS ⇄ Kiosk on screen (POS_KIOSK_MODE_PHASE1.md §5.3-5.5).

late KioskAuthProvider auth;
late PosSessionProvider posSession;

Future<void> _auth({String category = 'pos', bool kioskMode = false}) async {
  SharedPreferences.setMockInitialValues({
    AppConstants.token: 'device-token',
    AppConstants.branch: 1,
    AppConstants.kioskDeviceCategory: category,
    AppConstants.kioskDeviceKioskMode: kioskMode,
    AppConstants.kioskBranchName: 'Amsterdam',
    AppConstants.kioskDeviceName: 'Till 1',
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(AppConstants.baseUrl, null,
      loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
  auth = KioskAuthProvider(
      kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs));
  // Kiosk mode is session-local now: entering it is an in-memory flip, not a
  // persisted flag. (On a kiosk-category device this is inert, as in the app.)
  if (kioskMode) await auth.applyKioskMode(true);
  posSession = PosSessionProvider(
      kioskManagerRepo: KioskManagerRepo(dioClient: dio, sharedPreferences: prefs));
}

Widget _host(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<KioskAuthProvider>.value(value: auth),
        ChangeNotifierProvider<PosSessionProvider>.value(value: posSession),
      ],
      child: MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  group('the hidden way back to POS', () {
    late int opened;
    late int ordersStarted;

    /// The logo inside a tap-anywhere surface, like the kiosk welcome screen.
    Future<void> pumpTrigger(WidgetTester tester) async {
      opened = 0;
      ordersStarted = 0;
      await tester.pumpWidget(_host(GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ordersStarted++,
        child: SizedBox(
          width: 600,
          height: 400,
          child: Column(children: [
            KioskStaffExitTrigger(onTriggered: () => opened++, child: const Text('A/CAFÉ')),
            const SizedBox(height: 100),
            const Text('TOUCH TO ORDER'),
          ]),
        ),
      )));
    }

    Future<void> tapLogo(WidgetTester tester, {int times = 1, Duration gap = const Duration(milliseconds: 200)}) async {
      for (int i = 0; i < times; i++) {
        await tester.tap(find.text('A/CAFÉ'));
        await tester.pump(gap);
      }
    }

    testWidgets('three quick taps on the logo open the staff PIN pad', (tester) async {
      await _auth(kioskMode: true);
      await pumpTrigger(tester);

      await tapLogo(tester, times: 3);

      expect(opened, 1);
      expect(ordersStarted, 0, reason: 'tapping the logo never starts an order');
    });

    testWidgets('one or two taps do nothing', (tester) async {
      await _auth(kioskMode: true);
      await pumpTrigger(tester);

      await tapLogo(tester, times: 2);
      await tester.pump(const Duration(seconds: 2));
      await tapLogo(tester);

      expect(opened, 0);
    });

    testWidgets('slow taps do not add up', (tester) async {
      await _auth(kioskMode: true);
      await pumpTrigger(tester);

      await tapLogo(tester, times: 3, gap: const Duration(milliseconds: 900));

      expect(opened, 0);
    });

    testWidgets('the rest of the screen still starts an order', (tester) async {
      await _auth(kioskMode: true);
      await pumpTrigger(tester);

      await tester.tap(find.text('TOUCH TO ORDER'));
      await tester.pump();

      expect(ordersStarted, 1);
    });

    testWidgets('a real kiosk has no way to the POS at all', (tester) async {
      await _auth(category: 'kiosk', kioskMode: true);
      await pumpTrigger(tester);

      await tapLogo(tester, times: 3);

      expect(opened, 0);
      expect(ordersStarted, 3, reason: 'on a real kiosk the logo is just part of the screen');
    });
  });

  group('the staff PIN pad', () {
    Future<void> type(WidgetTester tester, String pin) async {
      for (final digit in pin.split('')) {
        await tester.tap(find.text(digit).last);
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('a refusal stays on the pad and says why', (tester) async {
      await _auth(kioskMode: true);
      await tester.pumpWidget(_host(KioskPinEntrySheet(
        title: 'Staff access',
        prompt: 'Enter your staff PIN',
        submitLabel: 'Switch to POS',
        onSubmitPin: (_) async => 'Wrong PIN · 3 tries left',
      )));

      expect(find.text('Staff access'), findsOneWidget);
      await type(tester, '0000');

      expect(find.text('Wrong PIN · 3 tries left'), findsOneWidget);
      expect(find.byType(KioskPinEntrySheet), findsOneWidget);
    });

    testWidgets('the right PIN closes the pad with success', (tester) async {
      await _auth(kioskMode: true);
      bool? result;
      final List<String> pins = [];
      await tester.pumpWidget(_host(Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showDialog<bool>(
              context: context,
              builder: (_) => KioskPinEntrySheet(
                title: 'Staff access',
                onSubmitPin: (pin) async {
                  pins.add(pin);
                  return null;
                },
              ),
            );
          },
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await type(tester, '4321');

      expect(pins, ['4321']);
      expect(result, isTrue);
    });
  });

  group('nothing staff-only is left on the kiosk', () {
    testWidgets('no Logout button while a till serves as a kiosk', (tester) async {
      await _auth(kioskMode: true);
      await tester.pumpWidget(_host(const KioskLogoutButton()));

      expect(find.byKey(KioskLogoutButton.buttonKey), findsNothing);
    });

    testWidgets('a real kiosk keeps its Logout button', (tester) async {
      await _auth(category: 'kiosk');
      await tester.pumpWidget(_host(const KioskLogoutButton()));

      expect(find.byKey(KioskLogoutButton.buttonKey), findsOneWidget);
    });

    testWidgets('typed URLs to staff screens land on the welcome screen', (tester) async {
      await _auth(kioskMode: true);
      late BuildContext context;
      await tester.pumpWidget(_host(Builder(builder: (c) {
        context = c;
        return const SizedBox();
      })));

      for (final path in [
        RouterHelper.kioskManagerDashboardScreen,
        RouterHelper.kioskManagerSalesOverviewScreen,
        RouterHelper.kioskManagerTransactionsScreen,
        RouterHelper.kioskManagerStockScreen,
        '/pos-home',
        '/pos-receipts',
      ]) {
        expect(KioskRouteGuard.redirect(context, path), RouterHelper.kioskWelcomeScreen, reason: path);
      }
    });
  });

  group('the Kiosk Mode button on the till', () {
    final List<CategoryModel> cats = [CategoryModel(id: 1, name: 'Coffee')];

    testWidgets('sits in the rail beside Punch In / Out and fires', (tester) async {
      int taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PosCategorySidebar(
            categories: cats,
            selectedId: '1',
            onSelect: (_) {},
            onPunch: () {},
            onKioskMode: () => taps++,
          ),
        ),
      ));

      expect(find.text(PosKioskModeEntryButton.label), findsOneWidget);
      await tester.tap(find.byKey(PosKioskModeEntryButton.buttonKey));
      expect(taps, 1);
    });

    testWidgets('is absent when the till may not switch', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PosCategorySidebar(categories: cats, selectedId: '1', onSelect: (_) {}, onPunch: () {}),
        ),
      ));

      expect(find.byKey(PosKioskModeEntryButton.buttonKey), findsNothing);
    });

    testWidgets('the compact strip carries it too', (tester) async {
      int taps = 0;
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PosCategoryStrip(
            categories: cats,
            selectedId: '1',
            onSelect: (_) {},
            onPunch: () {},
            onKioskMode: () => taps++,
          ),
        ),
      ));

      await tester.tap(find.byKey(PosKioskModeEntryButton.buttonKey));
      expect(taps, 1);
    });

    testWidgets('warns that an open ticket will be cleared', (tester) async {
      await _auth();
      await tester.pumpWidget(_host(Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmSwitchToKiosk(context, ticketItems: 2, onConfirmed: () async {}),
          child: const Text('Kiosk Mode'),
        ),
      )));

      await tester.tap(find.text('Kiosk Mode'));
      await tester.pumpAndSettle();

      expect(find.textContaining('The 2 items on this ticket will be cleared.'), findsOneWidget);
    });

    testWidgets('asks before switching, and cancelling changes nothing', (tester) async {
      await _auth();
      int switches = 0;
      await tester.pumpWidget(_host(Builder(
        builder: (context) => TextButton(
          onPressed: () => confirmSwitchToKiosk(context, onConfirmed: () async => switches++),
          child: const Text('Kiosk Mode'),
        ),
      )));

      await tester.tap(find.text('Kiosk Mode'));
      await tester.pumpAndSettle();
      expect(find.text('Switch this till to Kiosk?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(switches, 0);

      await tester.tap(find.text('Kiosk Mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();
      expect(switches, 1);
    });
  });
}
