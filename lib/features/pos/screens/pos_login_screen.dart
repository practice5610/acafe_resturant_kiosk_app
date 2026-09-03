import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_image_helper.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pin_card.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Shift unlock for a POS terminal.
///
/// Deliberately thin: everything visual lives in [PosPinCard], which knows
/// nothing about providers or routing. This screen is only the wiring — it
/// hands the card a submit function and navigates on success.
///
/// While the PIN card is on screen we warm the kiosk menu cache the same way
/// the kiosk welcome screen does, so a successful unlock can enter `/pos-home`
/// with categories, products, and the first grid's images already ready —
/// no empty chrome flash while APIs catch up.
///
/// The code is the device's own `configuration_code`, set by admin when the
/// device is created (Kiosk -> Add New / Edit -> Category: POS), checked by
/// [KioskManagerProvider.verifyPin] against
/// `POST /api/v1/kiosk/manager/verify-code`. No new endpoint, no new schema.
///
/// This sits *after* device login, not instead of it: the username/password
/// device login binds the terminal to a branch once and persists a token; this
/// PIN is the per-shift gate that stops a terminal left unattended from being
/// usable. A wrong code is rate limited server-side
/// (`throttle:device-manager-pin`).
class PosLoginScreen extends StatefulWidget {
  const PosLoginScreen({super.key});

  /// Digits the card asks for.
  ///
  /// The Figma frame draws six boxes, but `devices.configuration_code` is a
  /// `varchar(4)` validated `digits:4` in all four device controllers — a
  /// six-digit gate could never be satisfied by any real device, so the screen
  /// would reject every staff member. Four is the only value that authenticates
  /// today; flip this to 6 once the column and validators move.
  /// See POS_PIN_LOGIN_PHASE1.md.
  static const int pinLength = 4;

  @override
  State<PosLoginScreen> createState() => _PosLoginScreenState();
}

class _PosLoginScreenState extends State<PosLoginScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmMenu());
  }

  /// Same background warm as kiosk welcome: disk first, network if needed,
  /// then fire-and-forget image precache for the selected category.
  void _warmMenu() {
    if (!mounted) return;
    final locale =
        context.read<LocalizationProvider>().locale.languageCode;
    final categories = context.read<CategoryProvider>();
    final splash = context.read<SplashProvider>();

    categories.warmKioskMenuFromDisk(locale).then((_) {
      if (!mounted) return;
      KioskMenuImageHelper.precacheAroundSelected(
        context,
        categories,
        splash,
      );
    });
  }

  /// Finish menu + first-category images before leaving the PIN screen so
  /// `/pos-home` paints from cache (mirrors kiosk welcome `_onContinue`).
  Future<void> _readyHomeForEntry() async {
    final locale =
        context.read<LocalizationProvider>().locale.languageCode;
    final categories = context.read<CategoryProvider>();
    final splash = context.read<SplashProvider>();

    try {
      await categories.ensureKioskMenuReady(localeCode: locale);
    } catch (_) {
      // Home still opens; its own cold-path loader covers the miss.
    }
    if (!mounted) return;

    try {
      await KioskMenuImageHelper.precacheAroundSelected(
        context,
        categories,
        splash,
        awaitVisible: true,
      ).timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {}
  }

  Future<bool> _verify(String pin) async {
    final manager = context.read<KioskManagerProvider>();
    final bool ok = await manager.verifyPin(pin);
    if (!mounted) return ok;
    if (!ok) return false;

    // Keep PosPinCard's busy state up while we finish the menu warm so the
    // next route never mounts on an empty catalog.
    await _readyHomeForEntry();
    if (!mounted) return true;
    context.go(PosRoutes.home);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosPinSpec.pageBg,
      body: SafeArea(
        child: Center(
          // Scrolls only when the viewport is genuinely shorter than the card.
          // Width stays bounded by the viewport, so the card's own max-width
          // cap and the keypad's horizontal flex both still resolve — the
          // unbounded-constraint footgun in this codebase is about children
          // that want to FILL the scroll axis, and nothing here does.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: PosPinCard(
                pinLength: PosLoginScreen.pinLength,
                onSubmit: _verify,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
