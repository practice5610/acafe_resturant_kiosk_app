import 'package:acafe_customer/features/kiosk/screens/kiosk_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/single_child_widget.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// Medium landscape tablets used to throw on login:
/// `(formWidth * 1.85).clamp(formWidth, maxWidth * 0.94)` with formWidth >
/// maxWidth*0.94 → grey ErrorWidget. These sizes must stay green.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SingleChildWidget> withAuth;

  setUpAll(() async {
    await loadKioskTestFonts();
    withAuth = await kioskBaseProviders(withAuth: true);
  });

  for (final size in const [
    Size(1024, 768),
    Size(900, 600),
    Size(1100, 700),
    Size(1280, 800),
  ]) {
    testWidgets(
        'login survives medium landscape ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
      await pumpKioskScreen(
        tester,
        size,
        const KioskLoginScreen(),
        providers: withAuth,
      );
      await settleKiosk(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Something went wrong.\nTap the browser refresh button to continue.'),
          findsNothing);
      expect(find.text('Device login'), findsOneWidget);
      expect(find.text('LOGIN'), findsOneWidget);
      expectNoOverflow(tester, size);
    });
  }
}
