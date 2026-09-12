import 'package:acafe_customer/features/pos/domain/pos_route_policy.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// The POS routing rules. These are the part of the feature where a mistake is
/// invisible in review and obvious in service — a redirect loop that bricks a
/// till, or a Back button that lands somewhere broken.
String? redirect(
  String path, {
  bool isPosDevice = true,
  bool isLoggedIn = true,
  bool canAccessManagerTabs = true,
}) =>
    PosRoutePolicy.redirect(
      path: path,
      isPosDevice: isPosDevice,
      isLoggedIn: isLoggedIn,
      canAccessManagerTabs: canAccessManagerTabs,
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
    });

    test('device login itself is allowed through, so it can be completed', () {
      expect(
        redirect(RouterHelper.kioskLoginScreen, isLoggedIn: false),
        isNull,
      );
    });
  });

  group('logged-in terminal', () {
    test('every non-manager POS path is reachable with no PIN at all', () {
      for (final path in [
        PosRoutes.home,
        PosRoutes.browse,
        PosRoutes.orders,
        PosRoutes.receipts,
        PosRoutes.payment,
        PosRoutes.paymentCash,
        PosRoutes.paymentWait,
        PosRoutes.paymentSuccess,
      ]) {
        expect(redirect(path, canAccessManagerTabs: false), isNull,
            reason: '$path should need no manager access');
      }
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

  group('gate 2: manager-only tabs', () {
    test('with no step-up grant, Report and Settings bounce to home', () {
      for (final path in [PosRoutes.report, PosRoutes.settings]) {
        expect(
          redirect(path, canAccessManagerTabs: false),
          PosRoutes.home,
          reason: '$path should be Manager/Owner-only',
        );
      }
    });

    test('with a step-up grant, both tabs are reachable', () {
      for (final path in [PosRoutes.report, PosRoutes.settings]) {
        expect(redirect(path, canAccessManagerTabs: true), isNull);
      }
    });

    test('the manager-only set matches the real route constants', () {
      expect(
        PosRoutePolicy.managerOnlyPaths,
        {PosRoutes.report, PosRoutes.settings},
      );
    });
  });

  group('system states outrank both gates', () {
    test('maintenance and force-update pass through at every gate state', () {
      for (final path in [RouterHelper.maintain, RouterHelper.update]) {
        expect(redirect(path), isNull);
        expect(redirect(path, canAccessManagerTabs: false), isNull);
        expect(redirect(path, isLoggedIn: false, canAccessManagerTabs: false),
            isNull);
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
        (loggedIn: false, manager: true),
        (loggedIn: true, manager: true),
        (loggedIn: true, manager: false),
      ];
      final paths = [
        PosRoutes.home,
        PosRoutes.browse,
        PosRoutes.report,
        PosRoutes.settings,
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
                isLoggedIn: state.loggedIn,
                canAccessManagerTabs: state.manager);
            if (next == null) break;
            expect(seen.add(next), isTrue,
                reason: 'redirect loop from $start in $state via $next');
            current = next;
          }
          expect(
              redirect(current,
                  isLoggedIn: state.loggedIn,
                  canAccessManagerTabs: state.manager),
              isNull,
              reason: 'did not settle from $start in $state (stuck at $current)');
        }
      }
    });
  });
}
