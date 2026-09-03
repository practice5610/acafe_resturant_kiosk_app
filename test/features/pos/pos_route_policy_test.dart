import 'package:acafe_customer/features/pos/domain/pos_route_policy.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// The POS routing rules. These are the part of the feature where a mistake is
/// invisible in review and obvious in service — a redirect loop that bricks a
/// till, or a Back button that re-locks it mid-sale.
String? redirect(
  String path, {
  bool isPosDevice = true,
  bool isLoggedIn = true,
  bool isPinVerified = true,
}) =>
    PosRoutePolicy.redirect(
      path: path,
      isPosDevice: isPosDevice,
      isLoggedIn: isLoggedIn,
      isPinVerified: isPinVerified,
      kioskLoginPath: RouterHelper.kioskLoginScreen,
      kioskWelcomePath: RouterHelper.kioskWelcomeScreen,
    );

void main() {
  group('kiosk devices are never shown POS', () {
    test('a logged-in kiosk device on a POS path goes to the kiosk welcome', () {
      expect(
        redirect(PosRoutes.home, isPosDevice: false),
        RouterHelper.kioskWelcomeScreen,
      );
    });

    test('an unbound kiosk device on a POS path goes to device login', () {
      expect(
        redirect(PosRoutes.home, isPosDevice: false, isLoggedIn: false),
        RouterHelper.kioskLoginScreen,
      );
    });
  });

  group('gate 1: device must be bound to a branch', () {
    test('an unbound POS terminal is sent to the shared device login', () {
      expect(redirect(PosRoutes.home, isLoggedIn: false),
          RouterHelper.kioskLoginScreen);
      expect(redirect(PosRoutes.login, isLoggedIn: false),
          RouterHelper.kioskLoginScreen);
    });

    test('device login itself is allowed through, so it can be completed', () {
      expect(
        redirect(RouterHelper.kioskLoginScreen, isLoggedIn: false),
        isNull,
      );
    });
  });

  group('gate 2: shift PIN', () {
    test('every POS path funnels to the PIN screen until it is entered', () {
      for (final path in [
        PosRoutes.home,
        PosRoutes.browse,
        PosRoutes.orders,
        PosRoutes.receipts,
        PosRoutes.report,
        PosRoutes.settings,
        PosRoutes.payment,
        PosRoutes.paymentCash,
        PosRoutes.paymentWait,
        PosRoutes.paymentSuccess,
      ]) {
        expect(redirect(path, isPinVerified: false), PosRoutes.login,
            reason: '$path should be locked behind the PIN');
      }
    });

    test('the PIN screen itself renders rather than redirecting to itself', () {
      expect(redirect(PosRoutes.login, isPinVerified: false), isNull);
    });
  });

  group('unlocked terminal', () {
    test('every POS path is reachable', () {
      for (final path in [
        PosRoutes.home,
        PosRoutes.browse,
        PosRoutes.orders,
        PosRoutes.receipts,
        PosRoutes.report,
        PosRoutes.settings,
        PosRoutes.payment,
        PosRoutes.paymentCash,
        PosRoutes.paymentWait,
        PosRoutes.paymentSuccess,
      ]) {
        expect(redirect(path), isNull, reason: '$path should be reachable');
      }
    });

    test('the PIN screen is unreachable, so Back cannot re-lock the till', () {
      expect(redirect(PosRoutes.login), PosRoutes.home);
    });

    test('kiosk paths resolve to the POS home', () {
      for (final path in [
        RouterHelper.kioskMenuScreen,
        RouterHelper.kioskWelcomeScreen,
        RouterHelper.kioskCartScreen,
        RouterHelper.kioskLoginScreen,
        RouterHelper.dashboard,
      ]) {
        expect(redirect(path), PosRoutes.home,
            reason: '$path should send a POS terminal home');
      }
    });
  });

  group('system states outrank both gates', () {
    test('maintenance and force-update pass through at every gate state', () {
      for (final path in [RouterHelper.maintain, RouterHelper.update]) {
        expect(redirect(path), isNull);
        expect(redirect(path, isPinVerified: false), isNull);
        expect(redirect(path, isLoggedIn: false, isPinVerified: false), isNull);
      }
    });

    test('the policy passthrough set matches the real route constants', () {
      // These are duplicated as literals in PosRoutePolicy to keep it free of
      // a RouterHelper import. This test is what stops them drifting apart.
      expect(
        PosRoutePolicy.passthroughPaths,
        {RouterHelper.maintain, RouterHelper.update},
      );
    });
  });

  group('no redirect loops', () {
    test('following a redirect always reaches a settled path', () {
      final states = [
        (loggedIn: false, pin: false),
        (loggedIn: true, pin: false),
        (loggedIn: true, pin: true),
      ];
      final paths = [
        PosRoutes.login,
        PosRoutes.home,
        PosRoutes.browse,
        PosRoutes.payment,
        RouterHelper.kioskMenuScreen,
        RouterHelper.kioskLoginScreen,
        RouterHelper.dashboard,
        RouterHelper.maintain,
      ];

      for (final state in states) {
        for (final start in paths) {
          String current = start;
          final seen = <String>{};
          // Resolve until settled; a cycle or a long chain is the bug.
          for (var hop = 0; hop < 5; hop++) {
            final next = redirect(current,
                isLoggedIn: state.loggedIn, isPinVerified: state.pin);
            if (next == null) break;
            expect(seen.add(next), isTrue,
                reason: 'redirect loop from $start in $state via $next');
            current = next;
          }
          expect(redirect(current,
              isLoggedIn: state.loggedIn, isPinVerified: state.pin),
              isNull,
              reason: 'did not settle from $start in $state (stuck at $current)');
        }
      }
    });
  });
}
