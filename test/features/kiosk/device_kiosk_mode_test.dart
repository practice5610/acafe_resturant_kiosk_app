import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/data/datasource/remote/dio/logging_interceptor.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/device_mode_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_auth_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/device_mode_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff_session_repo.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/features/realtime/device_settings_event.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// POS ⇄ Kiosk, SESSION-LOCAL model (reversal of POS_KIOSK_MODE_PHASE1.md §5).
///
/// The "Switch to Kiosk" button flips only the running screen: no backend call,
/// nothing persisted to the device row. A cold start (fresh login OR reload)
/// always opens as the device's admin category, so a `category == 'pos'` device
/// is a POS again every time. A kiosk_mode broadcast from another session never
/// moves this one. The way back is a normal staff sign-in whose member must
/// hold `switch_device_mode`.

const PosStaffSession _sara = PosStaffSession(
  id: 'sara',
  staffId: 7,
  name: 'Sara',
  initials: 'S',
  role: 'Employee',
  permissions: {'switch_device_mode': true},
);

/// A valid member who may sign in but may NOT switch the till back to POS.
const PosStaffSession _tom = PosStaffSession(
  id: 'tom',
  staffId: 9,
  name: 'Tom',
  initials: 'T',
  role: 'Barista',
  permissions: {'switch_device_mode': false},
);

/// Stands in for the real POS staff login. [signIn] validates the exit PIN now
/// (not a device-mode endpoint); the device row is never touched.
class _FakeStaffRepo extends PosStaffSessionRepo {
  _FakeStaffRepo() : super(dioClient: null);

  PosSignInRoster roster = const PosSignInRoster(
    staffLoginRequired: true,
    pinLength: 4,
    lockoutSeconds: 0,
    members: [],
  );

  /// What the next sign-in returns. Defaults to Sara (has the permission).
  (PosStaffSession?, String?, DateTime?, PosSignInResult) Function(String pin)
      onSignIn = _signedIn(_sara);

  final List<String> pins = [];

  static (PosStaffSession?, String?, DateTime?, PosSignInResult) Function(String)
      _signedIn(PosStaffSession member) => (pin) => (
            member,
            'staff-token',
            DateTime.parse('2030-01-01T00:00:00Z'),
            const PosSignInResult(PosSignInOutcome.signedIn),
          );

  @override
  Future<PosSignInRoster?> signInRoster() async => roster;

  @override
  Future<(PosStaffSession?, String?, DateTime?, PosSignInResult)> signIn(
    String pin, {
    String? memberId,
    int? roleId,
  }) async {
    pins.add(pin);
    return onSignIn(pin);
  }
}

void main() {
  // CartRepo reads the navigator context when it saves.
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late DioClient dio;
  late KioskAuthProvider auth;

  Future<void> boot(
      {String category = 'pos',
      bool kioskMode = false,
      bool showImages = true}) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.token: 'device-token',
      AppConstants.branch: 1,
      AppConstants.kioskDeviceId: 2,
      AppConstants.kioskDeviceName: 'Till 1',
      AppConstants.kioskDeviceCategory: category,
      // A stale persisted flag is deliberately ignored by the session-local
      // model; kept here to prove a cold start never reads it.
      AppConstants.kioskDeviceKioskMode: kioskMode,
      AppConstants.kioskShowImages: showImages,
    });
    prefs = await SharedPreferences.getInstance();
    dio = DioClient(AppConstants.baseUrl, null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
    auth = KioskAuthProvider(
        kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs));
  }

  group('effective mode (session-local)', () {
    test('a reload restores the kiosk flag from this browser (stays kiosk)',
        () async {
      await boot(kioskMode: true);

      expect(auth.isPosTerminal, isTrue);
      expect(auth.kioskModeActive, isTrue,
          reason: 'a page reload of the same device session stays a kiosk');
      expect(auth.isPosDevice, isFalse);
    });

    test('a cold device with no stored flag opens as POS', () async {
      await boot();

      expect(auth.isPosTerminal, isTrue);
      expect(auth.kioskModeActive, isFalse);
      expect(auth.isPosDevice, isTrue);
    });

    test('entering kiosk mode persists locally, so a reload keeps it', () async {
      await boot();
      await auth.applyKioskMode(true);

      // A reload = a fresh provider over the same SharedPreferences.
      final reloaded = KioskAuthProvider(
          kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs));

      expect(reloaded.kioskModeActive, isTrue);
    });

    test('logging the device out clears the stored kiosk flag', () async {
      await boot(kioskMode: true);
      expect(auth.kioskModeActive, isTrue);

      await auth.logout();

      expect(prefs.getBool(AppConstants.kioskDeviceKioskMode), anyOf(isNull, isFalse));
      final reloaded = KioskAuthProvider(
          kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs));
      expect(reloaded.kioskModeActive, isFalse);
    });

    test('flipping the session flag makes this screen a kiosk', () async {
      await boot();
      expect(auth.isPosDevice, isTrue);

      await auth.applyKioskMode(true);

      expect(auth.kioskModeActive, isTrue);
      expect(auth.isPosDevice, isFalse);
    });

    test('a kiosk-category device is never a till', () async {
      await boot(category: 'kiosk');

      expect(auth.isPosTerminal, isFalse);
      expect(auth.kioskModeActive, isFalse);
      expect(auth.isPosDevice, isFalse);
    });
  });

  group('product images', () {
    // "Show Product Images" is the staffed till's speed setting. A till serving
    // as a kiosk shows the full menu, pictures included.
    test('switching to kiosk turns images on, back to POS restores the setting',
        () async {
      await boot(showImages: false);
      expect(auth.showImages, isFalse);

      await auth.applyKioskMode(true);
      expect(auth.showImages, isTrue);
      expect(CustomImageWidget.showProductImages, isTrue);

      await auth.applyKioskMode(false);
      expect(auth.showImages, isFalse);
      expect(CustomImageWidget.showProductImages, isFalse);
    });

    test('a kiosk_mode push from another session does not turn images on',
        () async {
      await boot(showImages: false);

      await auth.applyDeviceSettingsFromRealtime(
          deviceId: 2, category: 'pos', kioskMode: true);

      expect(CustomImageWidget.showProductImages, isFalse,
          reason: 'the broadcast must not flip this session into kiosk mode');
      expect(auth.isPosDevice, isTrue);
    });

    test('a real kiosk keeps its own picture-less setting', () async {
      await boot(category: 'kiosk', showImages: false);

      expect(auth.showImages, isFalse);
    });
  });

  group('cross-session broadcast is inert for mode', () {
    test('a push turning kiosk mode on is never a mode change', () async {
      await boot();

      final outcome = await auth.applyDeviceSettingsFromRealtime(
          deviceId: 2, category: 'pos', kioskMode: true);

      expect(outcome, isNot(KioskDeviceSettingsOutcome.modeChanged));
      expect(auth.isPosDevice, isTrue,
          reason: 'another screen entering kiosk must not move this one');
    });

    test('other device settings still apply alongside an ignored kiosk_mode',
        () async {
      await boot();

      final outcome = await auth.applyDeviceSettingsFromRealtime(
          deviceId: 2, category: 'pos', name: 'Renamed', kioskMode: true);

      expect(outcome, KioskDeviceSettingsOutcome.applied);
      expect(auth.deviceName, 'Renamed');
      expect(auth.isPosDevice, isTrue);
    });

    test('the event still carries kiosk_mode, null when an older server omits it',
        () {
      final withField =
          DeviceSettingsEvent.fromJson({'device_id': 2, 'kiosk_mode': true});
      final without = DeviceSettingsEvent.fromJson({'device_id': 2});

      expect(withField.kioskMode, isTrue);
      expect(without.kioskMode, isNull);
    });
  });

  group('DeviceModeProvider', () {
    late DeviceModeRepo repo;
    late _FakeStaffRepo staffRepo;
    late PosStaffSessionProvider staff;
    late PosSessionProvider posSession;
    late KioskManagerProvider manager;
    late CartProvider cart;
    late DeviceModeProvider modes;

    Future<void> build() async {
      await boot();
      // A real repo with no client: proof the switch never calls the backend
      // is that these endpoints throw nothing because they are never reached.
      repo = DeviceModeRepo(dioClient: null);
      staffRepo = _FakeStaffRepo();
      staff = PosStaffSessionProvider(repo: staffRepo);
      posSession = PosSessionProvider(
          kioskManagerRepo:
              KioskManagerRepo(dioClient: dio, sharedPreferences: prefs));
      manager = KioskManagerProvider(
          kioskManagerRepo:
              KioskManagerRepo(dioClient: dio, sharedPreferences: prefs));
      // No repo: saving the basket needs a navigator context these tests lack.
      cart = CartProvider(cartRepo: null);
      modes = DeviceModeProvider(
        repo: repo,
        auth: auth,
        staff: staff,
        posSession: posSession,
        kioskManager: manager,
        cart: cart,
      );
    }

    void seedTicket() {
      cart.replaceCartList([
        CartModel(4.5, 4.5, const [], 0, 1, 0, const [], Product(name: 'Latte'),
            const []),
      ]);
      PosSaleSession.instance.customerName.text = 'Walk-in Ana';
    }

    group('into kiosk mode', () {
      test('signs staff out, drops every unlock and clears the ticket',
          () async {
        await build();
        staff.debugSignIn(_sara);
        posSession.debugSetElevated(true);
        seedTicket();

        final result = await modes.switchToKiosk();

        expect(result.ok, isTrue);
        expect(auth.kioskModeActive, isTrue);
        expect(staff.isSignedIn, isFalse);
        expect(staff.token, isNull);
        expect(posSession.canAccessManagerTabs, isFalse);
        expect(cart.cartList, isEmpty);
        expect(PosSaleSession.instance.customerName.text, isEmpty);
      });
    });

    group('back to POS', () {
      test('the right PIN with the permission returns the till and signs in',
          () async {
        await build();
        await auth.applyKioskMode(true);
        seedTicket(); // a customer walked away mid-order

        final result = await modes.switchToPos('4321');

        expect(result.ok, isTrue);
        expect(staffRepo.pins, ['4321'], reason: 'validated by a staff sign-in');
        expect(auth.kioskModeActive, isFalse);
        expect(auth.isPosDevice, isTrue);
        expect(staff.session?.staffId, 7);
        expect(staff.token, 'staff-token');
        expect(cart.cartList, isEmpty,
            reason: "the customer's basket is not the till's ticket");
      });

      test('landing on the POS leaves the staff gate ready (not blank)',
          () async {
        // A kiosk session reloaded while in kiosk mode never bootstrapped the
        // staff provider (the gate is disabled on a kiosk). The build() staff
        // provider is deliberately un-bootstrapped to mirror that.
        await build();
        await auth.applyKioskMode(true);
        expect(staff.bootstrapped, isFalse, reason: 'preconditions: the reloaded-kiosk state');

        await modes.switchToPos('4321');

        expect(staff.bootstrapped, isTrue,
            reason: 'PosStaffGate needs this true or it holds its blank cover');
        expect(staff.isSignedIn, isTrue);
      });

      test('the branch staff login is read again, so the member stays signed in',
          () async {
        await build();
        await auth.applyKioskMode(true);

        await modes.switchToPos('4321');

        expect(staff.loginRequired, isTrue);
        expect(staff.isSignedIn, isTrue);
      });

      test('a valid PIN WITHOUT the permission keeps the kiosk', () async {
        await build();
        await auth.applyKioskMode(true);
        staffRepo.onSignIn = _FakeStaffRepo._signedIn(_tom);

        final result = await modes.switchToPos('1111');

        expect(result.ok, isFalse);
        expect(result.message,
            "You don't have permission to switch this till to POS.");
        expect(auth.kioskModeActive, isTrue,
            reason: 'an unpermitted member must not drop into the POS');
        expect(staff.isSignedIn, isFalse,
            reason: 'the just-issued session is discarded');
      });

      test('a wrong PIN keeps the kiosk and counts down', () async {
        await build();
        await auth.applyKioskMode(true);
        staffRepo.onSignIn = (pin) => (
              null,
              null,
              null,
              const PosSignInResult(PosSignInOutcome.wrongPin,
                  attemptsRemaining: 3),
            );

        final result = await modes.switchToPos('0000');

        expect(result.ok, isFalse);
        expect(result.message, 'Wrong PIN · 3 tries left');
        expect(auth.kioskModeActive, isTrue);
        expect(staff.isSignedIn, isFalse);
      });

      test('a lockout says how long', () async {
        await build();
        await auth.applyKioskMode(true);
        staffRepo.onSignIn = (pin) => (
              null,
              null,
              null,
              const PosSignInResult(PosSignInOutcome.lockedOut,
                  retryAfterSeconds: 600),
            );

        expect((await modes.switchToPos('0000')).message,
            'Locked · try again in 10 min');
        expect(auth.kioskModeActive, isTrue);
      });

      test('no connection is not a wrong PIN', () async {
        await build();
        await auth.applyKioskMode(true);
        staffRepo.onSignIn = (pin) => (
              null,
              null,
              null,
              const PosSignInResult(PosSignInOutcome.unavailable),
            );

        final result = await modes.switchToPos('4321');

        expect(result.message, 'No connection · try again');
        expect(auth.kioskModeActive, isTrue);
      });
    });
  });
}
