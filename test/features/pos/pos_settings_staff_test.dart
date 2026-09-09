import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/common/models/config_model.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_section.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/features/pos/pos_shell.dart';
import 'package:acafe_customer/features/pos/screens/pos_settings_screen.dart';
import 'package:acafe_customer/features/pos/widgets/pos_staff_settings_panel.dart';
import 'package:acafe_customer/features/splash/domain/reposotories/splash_repo.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/main.dart' show navigatorKey;
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _pumpStaff(WidgetTester tester) async {
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
    // Widget tests still use the Figma seed as fixture data; production
    // loads from the DB and starts empty when none exist.
    AppConstants.posStaffRosterKey:
        jsonEncode(PosStaffRoster.seed().toJson()),
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
            splashRepo:
                SplashRepo(dioClient: dio, sharedPreferences: prefs),
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
    expect(find.text('Maria van den Berg'), findsOneWidget);
    expect(find.text('Thomas de Vries'), findsWidgets);
    expect(find.text('MEMBER DETAILS'), findsOneWidget);
    expect(find.text('PERMISSIONS'), findsOneWidget);
    expect(find.text('Process refunds'), findsOneWidget);
    expect(find.text('Generate'), findsOneWidget);
    expect(
      find.text(
        'Restricted actions on POS will prompt a manager override passcode.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('selecting a team member updates Member Details', (tester) async {
    await _pumpStaff(tester);

    expect(find.widgetWithText(TextField, 'Thomas de Vries'), findsOneWidget);

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
      find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
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
      find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
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
      find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
      'Sanne Bakker',
    );
    // Morning is selected by default; also pick Evening.
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

  testWidgets('Add Staff Member defaults to Morning and requires a shift',
      (tester) async {
    await _pumpStaff(tester);

    await tester.tap(find.text('Add Staff Member'));
    await tester.pumpAndSettle();

    // Morning starts selected — tapping it alone cannot clear the requirement.
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Morning')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select at least one shift'), findsOneWidget);

    await tester.enterText(
      find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
      'Amir',
    );
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
      find.widgetWithText(TextField, 'Thomas de Vries'),
      'Thomas Bakker',
    );
    await tester.pumpAndSettle();

    // Leave Staff and come back — the section host rebuilds the provider from
    // prefs, so this only passes if the edit was written through.
    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('STAFF'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Thomas Bakker'), findsOneWidget);
    expect(find.text('Thomas de Vries'), findsNothing);
  });

  test('staff section subtitle matches Figma', () {
    expect(
      PosSettingsSection.staff.subtitle,
      PosStaffSettingsPanel.pageSubtitle,
    );
  });
}
