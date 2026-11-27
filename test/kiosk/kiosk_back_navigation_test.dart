import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  late GoRouter router;

  Widget page(String path) => Builder(
        builder: (c) => Scaffold(
          body: Text(path),
          floatingActionButton: FloatingActionButton(
            key: const Key('back'),
            onPressed: () => path == '/cart-kiosk'
                ? KioskNavigationHelper.backToMenu(c)
                : KioskNavigationHelper.backTo(
                    c,
                    path == '/checkout-kiosk'
                        ? '/cart-kiosk'
                        : '/checkout-kiosk',
                  ),
          ),
        ),
      );

  Future<void> boot(WidgetTester t) async {
    router = GoRouter(initialLocation: '/menu-kiosk', routes: [
      for (final p in [
        '/menu-kiosk',
        '/cart-kiosk',
        '/checkout-kiosk',
        '/checkout-email-kiosk',
      ])
        GoRoute(path: p, builder: (_, __) => page(p)),
    ]);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
  }

  String loc() =>
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation;

  testWidgets('clean stack walks email > name > cart > menu', (t) async {
    await boot(t);
    router.push('/cart-kiosk');
    await t.pumpAndSettle();
    router.push('/checkout-kiosk');
    await t.pumpAndSettle();
    router.push('/checkout-email-kiosk');
    await t.pumpAndSettle();
    for (final want in ['/checkout-kiosk', '/cart-kiosk', '/menu-kiosk']) {
      await t.tap(find.byKey(const Key('back')).last);
      await t.pumpAndSettle();
      expect(loc(), want);
    }
  });

  testWidgets('polluted cart/email ping-pong stack still reaches menu',
      (t) async {
    await boot(t);
    for (final p in [
      '/cart-kiosk',
      '/checkout-email-kiosk',
      '/cart-kiosk',
      '/checkout-email-kiosk',
    ]) {
      router.push(p);
      await t.pumpAndSettle();
    }
    for (final want in ['/checkout-kiosk', '/cart-kiosk', '/menu-kiosk']) {
      await t.tap(find.byKey(const Key('back')).last);
      await t.pumpAndSettle();
      expect(loc(), want);
    }
    expect(router.canPop(), isFalse);
  });
}
