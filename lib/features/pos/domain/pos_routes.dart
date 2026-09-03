/// POS route paths.
///
/// Kept in `domain/` rather than on the router so widgets (the nav bar, back
/// buttons) can reference a path without importing the route table — which
/// imports every screen, which imports the widgets. Same reason
/// `RouterHelper`'s constants sit above its `GoRouter`.
///
/// All POS paths carry the `/pos-` prefix. That prefix is load-bearing:
/// [KioskRouteGuard] uses it to tell the two route families apart in one
/// `startsWith`, so a POS-category device and a kiosk-category device can be
/// guided to their own tree without enumerating either.
class PosRoutes {
  PosRoutes._();

  /// Every POS path starts with this.
  static const String prefix = '/pos-';

  // Entry
  static const String login = '/pos-login';

  // Shell tabs (persistent top nav)
  static const String home = '/pos-home';
  static const String browse = '/pos-browse';
  static const String report = '/pos-report';
  static const String orders = '/pos-orders';
  static const String receipts = '/pos-receipts';
  static const String settings = '/pos-settings';

  // Payment flow (full-screen, outside the shell chrome)
  static const String payment = '/pos-payment';
  static const String paymentCash = '/pos-payment-cash';
  static const String paymentWait = '/pos-payment-wait';
  static const String paymentSuccess = '/pos-payment-success';

  /// True for any path in the POS tree.
  static bool matches(String path) => path.startsWith(prefix);

  /// Paths reachable before the shift PIN has been entered.
  static const Set<String> preAuthPaths = {login};
}
