import 'package:acafe_customer/common/models/product_model.dart';
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

/// POS ⇄ Kiosk (POS_KIOSK_MODE_PHASE1.md §5). The server holds the mode; the
/// app follows it and tears the till down on the way into kiosk mode.

const PosStaffSession _sara = PosStaffSession(
  id: 'sara',
  staffId: 7,
  name: 'Sara',
  initials: 'S',
  role: 'Employee',
  permissions: {'switch_device_mode': true},
);

Map<String, dynamic> _deviceJson({bool kioskMode = false}) => {
      'id': 2,
      'name': 'Till 1',
      'category': 'pos',
      'status': 'active',
      'kiosk_mode': kioskMode,
    };

class _FakeModeRepo extends DeviceModeRepo {
  _FakeModeRepo() : super(dioClient: null);

  DeviceModeResponse enter = DeviceModeResponse(200, {'device': _deviceJson(kioskMode: true)});
  DeviceModeResponse exit = DeviceModeResponse(200, {
    'device': _deviceJson(),
    'staff_session': {
      'token': 'staff-token',
      'expires_at': '2030-01-01T00:00:00+00:00',
      'staff': {
        'id': 'sara',
        'staff_id': 7,
        'name': 'Sara',
        'initials': 'S',
        'role': 'Employee',
        'permissions': {'switch_device_mode': true},
      },
    },
  });
  int enterCalls = 0;
  final List<String> pins = [];

  @override
  Future<DeviceModeResponse> enterKiosk() async {
    enterCalls++;
    return enter;
  }

  @override
  Future<DeviceModeResponse> exitKiosk(String pin) async {
    pins.add(pin);
    return exit;
  }
}

/// The branch's real answer once the till is a POS again. While it was a
/// kiosk the server refused the roster, which the app reads as "staff login
/// off" -- the very thing that must not survive the way back.
class _BranchWithStaffLogin extends PosStaffSessionRepo {
  _BranchWithStaffLogin() : super(dioClient: null);

  @override
  Future<PosSignInRoster?> signInRoster() async => const PosSignInRoster(
        staffLoginRequired: true,
        pinLength: 4,
        lockoutSeconds: 0,
        members: [],
      );
}

DeviceModeResponse _refusal(int status, String code,
        [Map<String, dynamic> extra = const {}]) =>
    DeviceModeResponse(status, {
      'errors': [
        {'code': code, 'message': 'server says $code', ...extra},
      ],
    });

void main() {
  // CartRepo reads the navigator context when it saves.
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late DioClient dio;
  late KioskAuthProvider auth;

  Future<void> boot({String category = 'pos', bool kioskMode = false}) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.token: 'device-token',
      AppConstants.branch: 1,
      AppConstants.kioskDeviceId: 2,
      AppConstants.kioskDeviceName: 'Till 1',
      AppConstants.kioskDeviceCategory: category,
      AppConstants.kioskDeviceKioskMode: kioskMode,
    });
    prefs = await SharedPreferences.getInstance();
    dio = DioClient(AppConstants.baseUrl, null,
        loggingInterceptor: LoggingInterceptor(), sharedPreferences: prefs);
    auth = KioskAuthProvider(
        kioskAuthRepo: KioskAuthRepo(dioClient: dio, sharedPreferences: prefs));
  }

  group('effective mode', () {
    test('a POS till serving as a kiosk is not a POS', () async {
      await boot(kioskMode: true);

      expect(auth.isPosTerminal, isTrue);
      expect(auth.kioskModeActive, isTrue);
      expect(auth.isPosDevice, isFalse);
    });

    test('a POS till outside kiosk mode is a POS', () async {
      await boot();

      expect(auth.kioskModeActive, isFalse);
      expect(auth.isPosDevice, isTrue);
    });

    test('a stale flag on a kiosk device means nothing', () async {
      await boot(category: 'kiosk', kioskMode: true);

      expect(auth.isPosTerminal, isFalse);
      expect(auth.kioskModeActive, isFalse);
      expect(auth.isPosDevice, isFalse);
    });

    test('logging the device out forgets kiosk mode', () async {
      await boot(kioskMode: true);

      await auth.logout();

      expect(prefs.containsKey(AppConstants.kioskDeviceKioskMode), isFalse);
    });
  });

  group('pushes and reconciliation', () {
    test('a push turning kiosk mode on is a mode change', () async {
      await boot();

      expect(
        await auth.applyDeviceSettingsFromRealtime(deviceId: 2, category: 'pos', kioskMode: true),
        KioskDeviceSettingsOutcome.modeChanged,
      );
      expect(auth.isPosDevice, isFalse);
    });

    test('the same mode again changes nothing', () async {
      await boot(kioskMode: true);

      expect(
        await auth.applyDeviceSettingsFromRealtime(deviceId: 2, category: 'pos', kioskMode: true),
        KioskDeviceSettingsOutcome.ignored,
      );
      expect(auth.kioskModeActive, isTrue, reason: 'a reconnect never brings the POS back');
    });

    test('a frame without the field leaves the mode alone', () async {
      await boot(kioskMode: true);

      await auth.applyDeviceSettingsFromRealtime(deviceId: 2, category: 'pos', name: 'Renamed');

      expect(auth.kioskModeActive, isTrue);
    });

    test('the event carries kiosk_mode, and null when an older server omits it', () {
      final withField = DeviceSettingsEvent.fromJson({'device_id': 2, 'kiosk_mode': true});
      final without = DeviceSettingsEvent.fromJson({'device_id': 2});

      expect(withField.kioskMode, isTrue);
      expect(without.kioskMode, isNull);
    });
  });

  group('DeviceModeProvider', () {
    late _FakeModeRepo repo;
    late PosStaffSessionProvider staff;
    late PosSessionProvider posSession;
    late KioskManagerProvider manager;
    late CartProvider cart;
    late DeviceModeProvider modes;

    Future<void> build({bool kioskMode = false}) async {
      await boot(kioskMode: kioskMode);
      repo = _FakeModeRepo();
      staff = PosStaffSessionProvider(repo: _BranchWithStaffLogin());
      // What the till last heard while it was a kiosk: refused, read as off.
      staff.debugSetRoster(PosSignInRoster.off);
      posSession = PosSessionProvider(
          kioskManagerRepo: KioskManagerRepo(dioClient: dio, sharedPreferences: prefs));
      manager = KioskManagerProvider(
          kioskManagerRepo: KioskManagerRepo(dioClient: dio, sharedPreferences: prefs));
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
        CartModel(4.5, 4.5, const [], 0, 1, 0, const [], Product(name: 'Latte'), const []),
      ]);
      PosSaleSession.instance.customerName.text = 'Walk-in Ana';
    }

    group('into kiosk mode', () {
      test('signs staff out, drops every unlock and clears the ticket', () async {
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

      test('a refusal changes nothing and says why', () async {
        await build();
        staff.debugSignIn(_sara);
        seedTicket();
        repo.enter = _refusal(422, 'no-staff-can-exit');

        final result = await modes.switchToKiosk();

        expect(result.ok, isFalse);
        expect(result.message, 'server says no-staff-can-exit');
        expect(auth.kioskModeActive, isFalse);
        expect(staff.isSignedIn, isTrue);
        expect(cart.cartList, hasLength(1));
      });
    });

    group('back to POS', () {
      test('the right PIN returns the till and signs the member in', () async {
        await build(kioskMode: true);
        seedTicket(); // a customer walked away mid-order

        final result = await modes.switchToPos('4321');

        expect(result.ok, isTrue);
        expect(repo.pins, ['4321']);
        expect(auth.kioskModeActive, isFalse);
        expect(auth.isPosDevice, isTrue);
        expect(staff.session?.staffId, 7);
        expect(staff.token, 'staff-token');
        expect(cart.cartList, isEmpty, reason: "the customer's basket is not the till's ticket");
      });

      test("the branch's staff login is read again, so the PIN screen comes back", () async {
        await build(kioskMode: true);

        await modes.switchToPos('4321');

        expect(staff.loginRequired, isTrue);
        expect(staff.isSignedIn, isTrue, reason: 'the member who typed the PIN stays signed in');
      });

      test('a wrong PIN keeps the kiosk and counts down', () async {
        await build(kioskMode: true);
        repo.exit = _refusal(422, 'incorrect-pin', {'attempts_remaining': 3});

        final result = await modes.switchToPos('0000');

        expect(result.ok, isFalse);
        expect(result.message, 'Wrong PIN · 3 tries left');
        expect(auth.kioskModeActive, isTrue);
        expect(staff.isSignedIn, isFalse);
      });

      test('the wrong PIN that locks the pad says so at once', () async {
        await build(kioskMode: true);
        repo.exit = _refusal(422, 'incorrect-pin',
            {'attempts_remaining': 0, 'locked_out': true, 'retry_after_seconds': 900});

        expect((await modes.switchToPos('0000')).message, 'Locked · try again in 15 min');
      });

      test('a lockout says how long', () async {
        await build(kioskMode: true);
        repo.exit = _refusal(429, 'exit-locked', {'retry_after_seconds': 600, 'requires_panel_reset': false});

        expect((await modes.switchToPos('0000')).message, 'Locked · try again in 10 min');
      });

      test('a day lockout points at the panel', () async {
        await build(kioskMode: true);
        repo.exit = _refusal(429, 'exit-locked', {'retry_after_seconds': 80000, 'requires_panel_reset': true});

        expect((await modes.switchToPos('0000')).message, 'Locked · use Return to POS in admin');
      });

      test('no connection is not a wrong PIN', () async {
        await build(kioskMode: true);
        repo.exit = const DeviceModeResponse(null, null);

        final result = await modes.switchToPos('4321');

        expect(result.message, 'No connection · try again');
        expect(auth.kioskModeActive, isTrue);
      });
    });

    test('a till the panel returned to POS asks for staff login again', () async {
      await build(kioskMode: true);
      await auth.applyDeviceSettingsFromRealtime(deviceId: 2, category: 'pos', kioskMode: false);

      await modes.afterRemoteSwitch();

      expect(staff.loginRequired, isTrue);
      expect(staff.isSignedIn, isFalse);
    });

    test('a switch made elsewhere tears the till down the same way', () async {
      await build();
      staff.debugSignIn(_sara);
      seedTicket();
      await auth.applyDeviceSettingsFromRealtime(deviceId: 2, category: 'pos', kioskMode: true);

      await modes.afterRemoteSwitch();

      expect(staff.isSignedIn, isFalse);
      expect(cart.cartList, isEmpty);
    });
  });
}
