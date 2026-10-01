import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_section.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_settings_panel.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_pos_staff_backend.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Loew');
  for (final path in const [
    'assets/fonts/Loew-Regular.ttf',
    'assets/fonts/Loew-Medium.ttf',
    'assets/fonts/Loew-Bold.ttf',
    'assets/fonts/Loew-ExtraBold.ttf',
  ]) {
    loader.addFont(File(path)
        .readAsBytes()
        .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
}

class _Splash extends SplashProvider {
  _Splash({required super.splashRepo});

  @override
  ConfigModel? get configModel => ConfigModel(
        restaurantName: 'A|CAFÉ',
        restaurantEmail: 'info@acafe.nl',
        restaurantPhone: '+31 20 000 0000',
        currencySymbol: '€',
      );
}

/// The fake staff API the screen talks to. Recreated per test so hires and
/// PINs do not leak between them.
late FakePosStaffBackend backend;

Future<void> _pumpStaff(
  WidgetTester tester, {
  bool staffLoginRequired = false,
  List<Map<String, dynamic>>? rolesOverride,
}) async {
  backend = FakePosStaffBackend(
    staffLoginRequired: staffLoginRequired,
    rolesOverride: rolesOverride,
  );
  tester.view.physicalSize = const Size(1366, 1024);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({
    AppConstants.token: 'tok',
    AppConstants.branch: 1,
    AppConstants.languageCode: 'nl',
    AppConstants.countryCode: 'NL',
    AppConstants.kioskDeviceCategory: 'pos',
    AppConstants.kioskDeviceName: 'Till 1 Amsterdam',
    AppConstants.kioskBranchName: 'Amsterdam',
    AppConstants.kioskUsername: 'till1',
  });
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient(
    'http://localhost',
    null,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );

  // The Staff section resolves its DioClient from the service locator. This one
  // answers from the in-memory fake, which honours the real API contract — the
  // server mints roster ids and owns PIN uniqueness now, so a test that wants to
  // see a hire land has to talk to something that behaves like the server.
  final Dio staffDio = Dio(BaseOptions(baseUrl: 'http://localhost'))
    ..httpClientAdapter = backend;
  final DioClient staffClient = DioClient(
    'http://localhost',
    staffDio,
    loggingInterceptor: LoggingInterceptor(),
    sharedPreferences: prefs,
  );
  if (di.sl.isRegistered<DioClient>()) di.sl.unregister<DioClient>();
  di.sl.registerSingleton<DioClient>(staffClient);
  addTearDown(() {
    if (di.sl.isRegistered<DioClient>()) di.sl.unregister<DioClient>();
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SplashProvider>(
          create: (_) => _Splash(
            splashRepo: SplashRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
        ChangeNotifierProvider<LocalizationProvider>(
          create: (_) => LocalizationProvider(
            sharedPreferences: prefs,
            dioClient: dio,
          ),
        ),
        ChangeNotifierProvider<KioskAuthProvider>(
          create: (_) => KioskAuthProvider(
            kioskAuthRepo:
                KioskAuthRepo(dioClient: dio, sharedPreferences: prefs),
          ),
        ),
      ],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1366, 1024)),
        child: PosShell(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: PosSettingsSpec.pageBg,
              body: PosSettingsScreen(sharedPreferences: prefs),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('STAFF'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('Staff UI matches Figma chrome and fixtures', (tester) async {
    await _pumpStaff(tester);

    expect(find.text(PosStaffSettingsPanel.pageTitle), findsWidgets);
    expect(find.text(PosStaffSettingsPanel.pageSubtitle), findsOneWidget);
    expect(find.text('Add Staff Member'), findsOneWidget);

    expect(find.text('SHIFTS'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Afternoon'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(find.text('+9 more'), findsOneWidget);
    expect(find.text('+8 more'), findsOneWidget);
    expect(find.text('+10 more'), findsOneWidget);

    expect(find.text('TEAM OF THE DAY'), findsOneWidget);
    expect(find.text('Maria van den Berg'), findsWidgets);
    expect(find.text('Thomas de Vries'), findsOneWidget);
    expect(find.text('MEMBER DETAILS'), findsOneWidget);
    expect(find.text('PERMISSIONS'), findsOneWidget);
    // Labels come from the catalogue, not from constants in the app.
    expect(find.text('Process refunds'), findsOneWidget);
    expect(find.text('Close day'), findsOneWidget);
    // Branch shown read-only in the header, with the sign-in state.
    expect(find.text('Amsterdam'), findsOneWidget);
    expect(find.text('Staff sign-in off'), findsOneWidget);
    expect(
      find.text(
        'Staff sign-in is off for this branch. Restricted actions '
        'prompt the manager code set for this device.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting a team member updates Member Details', (tester) async {
    await _pumpStaff(tester);

    // Roles are data now, so there is no hardcoded "Manager" to preselect; the
    // first member on the roster is.
    expect(find.widgetWithText(TextField, 'Maria van den Berg'), findsOneWidget);

    await tester.tap(find.text('Sophie Jansen'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Sophie Jansen'), findsOneWidget);
    expect(find.text('Employee'), findsWidgets);
  });

  testWidgets('shift + Add opens hire dialog with that shift pre-selected',
      (tester) async {
    await _pumpStaff(tester);
    expect(find.text('+9 more'), findsOneWidget);

    await tester.tap(find.byTooltip('Add to Morning'));
    await tester.pumpAndSettle();

    expect(find.text('ADD STAFF MEMBER'), findsOneWidget);

    await tester.enterText(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .first,
      'Amir Morning',
    );
    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.widgetWithText(TextField, 'Amir Morning'), findsOneWidget);
    // Morning 12 → 13, so both morning and evening show "+10 more".
    expect(find.text('+10 more'), findsNWidgets(2));
    expect(find.text('+9 more'), findsNothing);
  });

  testWidgets('Afternoon + Add pre-selects Afternoon only', (tester) async {
    await _pumpStaff(tester);

    await tester.tap(find.byTooltip('Add to Afternoon'));
    await tester.pumpAndSettle();

    expect(find.text('ADD STAFF MEMBER'), findsOneWidget);

    await tester.enterText(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .first,
      'Lea Afternoon',
    );
    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Lea Afternoon'), findsOneWidget);
    // Afternoon was 11 → 12 (+9 more). Morning/evening unchanged.
    expect(find.text('+9 more'), findsNWidgets(2));
  });

  testWidgets('Add Staff Member rosters the new hire onto chosen shifts',
      (tester) async {
    await _pumpStaff(tester);

    await tester.tap(find.text('Add Staff Member'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .first,
      'Sanne Bakker',
    );
    // Morning is selected by default; also pick Evening.
    await tester.ensureVisible(
      find.descendant(of: find.byType(Dialog), matching: find.text('Evening')),
    );
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Evening')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();

    // The new hire is selected, so Member Details is bound to them.
    expect(find.widgetWithText(TextField, 'Sanne Bakker'), findsOneWidget);
    // Morning 12 -> 13 and evening 13 -> 14.
    expect(find.text('+10 more'), findsOneWidget);
    expect(find.text('+11 more'), findsOneWidget);
    expect(find.text('+9 more'), findsNothing);
  });

  testWidgets('Add Staff Member defaults to the first shift and requires one',
      (tester) async {
    await _pumpStaff(tester);

    await tester.tap(find.text('Add Staff Member'));
    await tester.pumpAndSettle();

    // Morning starts selected — tapping it alone cannot clear the requirement.
    await tester.ensureVisible(
      find.descendant(of: find.byType(Dialog), matching: find.text('Morning')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Morning')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select at least one shift'), findsOneWidget);

    await tester.enterText(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .first,
      'Amir',
    );
    await tester.ensureVisible(find.text('Add Member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();

    // Still on Morning (compulsory default) — member is added to morning.
    expect(find.widgetWithText(TextField, 'Amir'), findsOneWidget);
    expect(find.text('Amir'), findsWidgets);
  });

  testWidgets('the overflow chip opens the shift roster and removes from it',
      (tester) async {
    await _pumpStaff(tester);

    await tester.tap(find.text('+9 more'));
    await tester.pumpAndSettle();

    expect(find.text('MORNING SHIFT'), findsOneWidget);
    expect(find.text('08:00-14:00 \u00b7 12 on shift'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Maria from Morning'));
    await tester.pumpAndSettle();

    expect(find.text('08:00-14:00 \u00b7 11 on shift'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('+8 more'), findsNWidgets(2));
  });

  testWidgets('member edits survive leaving and re-entering the tab',
      (tester) async {
    await _pumpStaff(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Maria van den Berg'),
      'Maria Bakker',
    );
    await tester.pumpAndSettle();

    // Leave Staff and come back — the section host rebuilds the provider and
    // re-reads the server, so this only passes if the edit was written through.
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STAFF'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Maria Bakker'), findsOneWidget);
    expect(find.text('Maria van den Berg'), findsNothing);
    expect(backend.member('maria')!['name'], 'Maria Bakker');
  });

  testWidgets('Member Details shows a PIN row that sets a PIN', (tester) async {
    await _pumpStaff(tester);

    // Maria has no PIN yet.
    expect(find.text('PIN'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('Set PIN'), findsOneWidget);

    await tester.tap(find.text('Set PIN'));
    await tester.pumpAndSettle();
    expect(find.text('SET PIN'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
      '1234',
    );
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Set PIN')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    // Masked, never shown.
    expect(find.text('\u2022\u2022\u2022\u2022'), findsOneWidget);
    expect(find.text('Reset PIN'), findsOneWidget);
    expect(backend.member('maria')!['has_pin'], isTrue);
  });

  testWidgets('a PIN already in use is refused with the server message',
      (tester) async {
    await _pumpStaff(tester);
    backend.setPin('thomas', '1234');

    await tester.tap(find.text('Set PIN'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
      '1234',
    );
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Set PIN')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget, reason: 'stays open to fix');
    expect(
      find.text('Another staff member in this branch already uses that PIN.'),
      findsOneWidget,
    );
  });

  testWidgets('the Add dialog takes an optional PIN', (tester) async {
    await _pumpStaff(tester);

    await tester.tap(find.text('Add Staff Member'));
    await tester.pumpAndSettle();

    final Finder fields =
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    expect(fields, findsNWidgets(3), reason: 'name, phone and PIN');
    expect(find.text('optional'), findsNWidgets(2), reason: 'phone and PIN');

    await tester.enterText(fields.at(0), 'Tom Hendriks');
    await tester.enterText(fields.at(2), '4321');
    await tester.ensureVisible(find.text('Add Member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Tom Hendriks'), findsOneWidget);
    expect(backend.member('tom-hendriks')!['has_pin'], isTrue);
  });

  testWidgets('a malformed PIN in the Add dialog is caught before sending',
      (tester) async {
    await _pumpStaff(tester);

    await tester.tap(find.text('Add Staff Member'));
    await tester.pumpAndSettle();
    final Finder fields =
        find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), 'Tom');
    await tester.enterText(fields.at(2), '12');
    await tester.ensureVisible(find.text('Add Member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();

    expect(find.text('The PIN must be exactly 4 digits'), findsOneWidget);
    expect(backend.member('tom'), isNull);
  });

  testWidgets('the Role dropdown lists the backend roles in order and selects',
      (tester) async {
    await _pumpStaff(tester);

    await tester.tap(find.text('Add Staff Member'));
    await tester.pumpAndSettle();

    // Defaults to the first catalogue role — the Role field is never blank.
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('Owner')),
      findsOneWidget,
    );

    // Opening it lists every role the backend returned, in catalogue order.
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Owner')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manager'), findsWidgets);
    expect(find.text('Employee'), findsWidgets);

    // Picking one is functional (no freeze) and updates the field.
    await tester.tap(find.text('Employee').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('Employee')),
      findsOneWidget,
    );

    // Cancel always closes the dialog, whatever the state.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('with no roles the dialog shows a notice and Cancel still works',
      (tester) async {
    await _pumpStaff(tester, rolesOverride: const []);

    await tester.tap(find.text('Add Staff Member'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.text('No roles available. Ask an admin to create one.'),
      findsOneWidget,
    );

    // The dialog never traps the manager: Cancel closes it regardless of state.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('roles created after the screen mounted appear on opening Add',
      (tester) async {
    // The screen hydrates once with no roles...
    await _pumpStaff(tester, rolesOverride: const []);
    // ...then an admin creates the roles in the panel.
    backend.setRoles(FakePosStaffBackend.roles);

    // Opening Add re-fetches the catalogue, so the new roles are assignable
    // without a full reload of the till.
    await tester.tap(find.text('Add Staff Member'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('Owner')),
      findsOneWidget,
    );
    expect(
      find.text('No roles available. Ask an admin to create one.'),
      findsNothing,
    );
  });

  testWidgets('edits go out as single-member PATCHes, never the whole roster',
      (tester) async {
    await _pumpStaff(tester);
    backend.requests.clear();

    // The toggle sits in the same Row as the label.
    final Finder row = find.ancestor(
      of: find.text('Process refunds'),
      matching: find.byType(Row),
    ).first;
    final Finder toggle = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_PosToggle',
      ),
    );
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final writes = backend.requests.where((r) => r.method != 'GET').toList();
    expect(writes, isNotEmpty);
    for (final w in writes) {
      expect(w.method, isNot('PUT'), reason: 'no whole-roster PUT from the app');
      expect(w.path, contains('/staff/members/'));
    }
  });

  testWidgets('the header says when staff sign-in is on', (tester) async {
    await _pumpStaff(tester, staffLoginRequired: true);

    expect(find.text('Staff sign-in on'), findsOneWidget);
  });

  test('staff section subtitle matches Figma', () {
    expect(
      PosSettingsSection.staff.subtitle,
      PosStaffSettingsPanel.pageSubtitle,
    );
  });
}
