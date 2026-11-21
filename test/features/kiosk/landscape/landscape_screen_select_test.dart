import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_routes.dart';

/// selectKioskScreen is the pure screen picker the router switch uses once the
/// orientation is known. Portrait always wins; in landscape a route shows its
/// landscape variant if one is registered, otherwise it falls back to the
/// existing portrait screen so the app still works end to end at every phase.
Widget _portrait() => const Text('portrait', textDirection: TextDirection.ltr);
Widget _landscape() => const Text('landscape', textDirection: TextDirection.ltr);

void main() {
  testWidgets('portrait mode always returns the portrait screen', (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      return selectKioskScreen(
        context: context,
        isLandscape: false,
        path: '/menu-kiosk',
        portrait: _portrait(),
        landscapeRoutes: {'/menu-kiosk': (_) => _landscape()},
      );
    }));
    expect(find.text('portrait'), findsOneWidget);
    expect(find.text('landscape'), findsNothing);
  });

  testWidgets('landscape with no registered variant falls back to portrait',
      (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      return selectKioskScreen(
        context: context,
        isLandscape: true,
        path: '/menu-kiosk',
        portrait: _portrait(),
        landscapeRoutes: const {}, // nothing registered yet
      );
    }));
    expect(find.text('portrait'), findsOneWidget);
  });

  testWidgets('landscape with a registered variant returns the landscape screen',
      (tester) async {
    await tester.pumpWidget(Builder(builder: (context) {
      return selectKioskScreen(
        context: context,
        isLandscape: true,
        path: '/menu-kiosk',
        portrait: _portrait(),
        landscapeRoutes: {'/menu-kiosk': (_) => _landscape()},
      );
    }));
    expect(find.text('landscape'), findsOneWidget);
    expect(find.text('portrait'), findsNothing);
  });
}
