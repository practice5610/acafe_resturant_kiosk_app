import 'package:flutter/material.dart';

/// Single source of truth for the kiosk intro / welcome artwork.
///
/// Decode once into Flutter's [ImageCache] ahead of navigation so
/// [KioskWelcomeScreen] paints without a blank flash. Callers never hold a
/// bare [ui.Image] — the framework owns cache lifetime and evicts under
/// memory pressure (see the raised limits in `main.dart`).
class KioskIntroImage {
  KioskIntroImage._();

  static const String assetPath = 'assets/video/kiosk_intro_Image.png';

  static const AssetImage provider = AssetImage(assetPath);

  /// How long a navigation path may wait for a cold decode. Kept short so a
  /// slow device never stalls login / bootstrap; a cache hit returns instantly.
  static const Duration navigateTimeout = Duration(milliseconds: 400);

  /// Fire-and-forget warm. Safe to call from any mounted screen (login while
  /// the user types, success while thank-you plays, etc.). Failures are
  /// swallowed — welcome still falls back to its solid edge colour.
  static void warm(BuildContext context) {
    if (!context.mounted) return;
    // ignore: discarded_futures
    ensureReady(context);
  }

  /// Await the decode (bounded by [timeout]) so the next route can paint with
  /// the artwork already in [ImageCache]. Never throws.
  static Future<void> ensureReady(
    BuildContext context, {
    Duration timeout = navigateTimeout,
  }) async {
    if (!context.mounted) return;
    try {
      await precacheImage(provider, context).timeout(timeout, onTimeout: () {});
    } catch (_) {
      // Missing asset / decode error / disposed context — welcome handles it.
    }
  }
}
