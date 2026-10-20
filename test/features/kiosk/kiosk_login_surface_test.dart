import 'package:acafe_customer/features/kiosk/domain/kiosk_login_surface.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/single_child_widget.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// One web build serves kiosk.* and pos.*; the login subtitle names the
/// terminal the address says it is binding.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  KioskLoginSurface surfaceOf(String url) =>
      KioskLoginSurface.fromUri(Uri.parse(url));

  group('KioskLoginSurface.fromUri', () {
    test('pos.* is POS', () {
      expect(surfaceOf('https://pos.acafepos.com/kiosk-login'),
          KioskLoginSurface.pos);
      expect(surfaceOf('https://POS.acafepos.com/'), KioskLoginSurface.pos);
      expect(surfaceOf('https://pos-staging.acafepos.com/'),
          KioskLoginSurface.pos);
    });

    test('kiosk.* is kiosk', () {
      expect(surfaceOf('https://kiosk.acafepos.com/kiosk-login'),
          KioskLoginSurface.kiosk);
      expect(surfaceOf('https://kiosk-test.acafepos.com/'),
          KioskLoginSurface.kiosk);
    });

    test('any other address is a neutral device', () {
      // "pos" inside another label (acafepos) must not count.
      expect(surfaceOf('https://acafepos.com/'), KioskLoginSurface.device);
      expect(surfaceOf('https://admin.acafepos.com/'),
          KioskLoginSurface.device);
      expect(surfaceOf('http://localhost:54926/kiosk-login'),
          KioskLoginSurface.device);
      expect(surfaceOf('http://192.168.1.20:8080/'), KioskLoginSurface.device);
      expect(surfaceOf('https://possum.example.com/'),
          KioskLoginSurface.device);
    });

    test('each surface has its own subtitle', () {
      expect(KioskLoginSurface.pos.hint,
          'Sign in once to bind this POS to its branch.');
      expect(KioskLoginSurface.kiosk.hint,
          'Sign in once to bind this kiosk to its branch.');
      expect(KioskLoginSurface.device.hint,
          'Sign in once to bind this device to its branch.');
    });
  });

  group('login screen subtitle', () {
    late List<SingleChildWidget> withAuth;

    setUpAll(() async {
      await loadKioskTestFonts();
      withAuth = await kioskBaseProviders(withAuth: true);
    });

    for (final surface in KioskLoginSurface.values) {
      testWidgets('shows the ${surface.name} subtitle', (tester) async {
        const Size size = Size(1280, 800);
        await pumpKioskScreen(
          tester,
          size,
          KioskLoginScreen(surface: surface),
          providers: withAuth,
        );
        await settleKiosk(tester);

        expect(find.text(surface.hint), findsOneWidget);
        for (final other in KioskLoginSurface.values) {
          if (other != surface) expect(find.text(other.hint), findsNothing);
        }
      });
    }
  });
}
