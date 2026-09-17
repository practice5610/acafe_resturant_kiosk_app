import 'dart:ui' as ui;

import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_intro_image.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_image_helper.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_welcome_screen.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_wordmark.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// POS post-login welcome — the kiosk intro, for the till.
///
/// Same artwork, same edge-extending painter, same three elements: logo,
/// one prompt, arrow. Tapping anywhere loads the menu, then opens the till —
/// the kiosk welcome's `_startMenuPrefetch` / `_onContinue`, minus deals (POS
/// has none). The till then sees `isKioskMenuReadyFor` and paints its products
/// on the first frame instead of a shimmer.
class PosWelcomeScreen extends StatefulWidget {
  const PosWelcomeScreen({super.key});

  static const Key tapTargetKey = Key('pos-welcome-tap');

  @override
  State<PosWelcomeScreen> createState() => _PosWelcomeScreenState();
}

class _PosWelcomeScreenState extends State<PosWelcomeScreen> {
  ui.Image? _intro;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMenuPrefetch());
  }

  /// Background warm while the screen is idle: disk cache first (network only
  /// if it is empty), then the selected category's images. Not awaited.
  void _startMenuPrefetch() {
    if (!mounted) return;
    final category = context.read<CategoryProvider>();
    final splash = context.read<SplashProvider>();
    final locale = context.read<LocalizationProvider>().locale.languageCode;
    category.warmKioskMenuFromDisk(locale).then((_) {
      if (!mounted) return;
      KioskMenuImageHelper.precacheAroundSelected(context, category, splash,
          includeOptions: true);
    });
  }

  /// Awaited half: products ready, first category's product, size and add-on
  /// images decoded, then go.
  /// Each step is bounded and failure-tolerant — a bad network still opens
  /// the till, which shows its own loading state.
  Future<void> _onContinue() async {
    if (_loading) return;
    setState(() => _loading = true);

    final category = context.read<CategoryProvider>();
    final splash = context.read<SplashProvider>();
    final locale = context.read<LocalizationProvider>().locale.languageCode;

    try {
      await category.ensureKioskMenuReady(localeCode: locale);
    } catch (_) {}
    if (!mounted) return;

    try {
      await KioskMenuImageHelper.precacheAroundSelected(
        context,
        category,
        splash,
        awaitVisible: true,
        // Size + add-on images too, so the first product opened needs no
        // download — the till's customize screen reads straight from cache.
        includeOptions: true,
      ).timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {}
    if (!mounted) return;

    context.go(PosRoutes.home);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ImageStream stream = KioskIntroImage.provider
        .resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        final ui.Image image = info.image.clone();
        info.dispose();
        if (!mounted) {
          image.dispose();
          return;
        }
        setState(() {
          _intro?.dispose();
          _intro = image;
        });
      },
      // Missing asset -> plain background, never a crash.
      onError: (_, __) {},
    );
    _stream = stream;
    stream.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _intro?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    // Shortest side, so the prompt stays large on a landscape counter screen
    // as well as a portrait one.
    final double s = size.shortestSide;
    final double logoHeight = (s * 0.05).clamp(24.0, 90.0);
    final double promptSize = (s * 0.065).clamp(28.0, 110.0);
    final double arrowSize = (s * 0.1).clamp(56.0, 180.0);

    return Scaffold(
      backgroundColor: const Color(0xFFE9EAF2), // the artwork's edge colour
      body: GestureDetector(
        key: PosWelcomeScreen.tapTargetKey,
        behavior: HitTestBehavior.opaque,
        onTap: _loading ? null : _onContinue,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_intro != null)
              CustomPaint(painter: KioskIntroBackgroundPainter(_intro!)),
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: size.height * 0.05),
                  PosWordmark(height: logoHeight, color: Colors.black),
                  const Spacer(),
                  Text(
                    'TOUCH TO START',
                    textAlign: TextAlign.center,
                    style: loewExtraBold.copyWith(
                      color: Colors.black,
                      fontSize: promptSize,
                      height: 1.1,
                    ),
                  ),
                  const Spacer(),
                  // Arrow, or a spinner while the menu loads after a tap.
                  SizedBox(
                    height: arrowSize,
                    child: Center(
                      child: _loading
                          ? const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : Image.asset(
                              Images.kioskDownArrow,
                              width: arrowSize,
                              height: arrowSize,
                              color: Colors.black,
                              colorBlendMode: BlendMode.srcIn,
                            ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.04),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
