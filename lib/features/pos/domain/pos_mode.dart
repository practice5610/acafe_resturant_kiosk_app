import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Which interface family this app instance renders.
///
/// The app is one binary running on two very different pieces of furniture: a
/// self-service kiosk a customer walks up to, and a staffed counter terminal.
/// They share every provider, repository and API call below the widget layer
/// and share nothing above it.
enum AppMode {
  /// Existing portrait-first self-service UI. Unchanged by the POS work.
  kiosk,

  /// Landscape-first staff terminal.
  pos,
}

extension AppModeX on AppMode {
  bool get isPos => this == AppMode.pos;
  bool get isKiosk => this == AppMode.kiosk;
}

/// Resolves [AppMode] from the device row the back office owns.
///
/// **Not** from orientation. The kiosk already renders deliberate landscape
/// compositions — `KioskMetrics.isLandscape`, `Responsive.isWide()`, a
/// dedicated landscape branch in `kioskCustomizeArtboardHeight()`, and golden
/// tests at 1920x1080 and 2560x1440. Keying the interface off orientation
/// would make all of that unreachable, and on this app's Flutter-web
/// deployment "orientation" is merely browser window aspect, so dragging a
/// window narrower would tear down the navigator mid-sale.
///
/// `device.category` is the right axis: admin sets it on the Device screen, it
/// is persisted to SharedPreferences at login (so it is known before first
/// paint, with no boot flash), it is re-read from `/device/me` on every
/// reconnect, and it is pushed live over Reverb via `device.settings.changed`.
/// It is also already the thing that tags orders `order_type: 'pos'`.
class PosMode {
  PosMode._();

  /// Watches the device session, so a `device.settings.changed` push that
  /// re-categorises this device swaps the interface without a restart.
  static AppMode of(BuildContext context) =>
      context.watch<KioskAuthProvider>().isPosDevice
          ? AppMode.pos
          : AppMode.kiosk;

  /// Non-listening read, for routing guards and other call sites that must not
  /// register a dependency on the element tree.
  static AppMode read(BuildContext context) =>
      Provider.of<KioskAuthProvider>(context, listen: false).isPosDevice
          ? AppMode.pos
          : AppMode.kiosk;
}
