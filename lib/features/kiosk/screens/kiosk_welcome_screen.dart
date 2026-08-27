import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_image_helper.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

/// Kiosk intro screen — a full-screen background image with the black A/CAFÉ
/// logo pinned to the top, a "TOUCH TO ORDER" prompt in the middle and an
/// animated down-arrow at the bottom (per the Figma "Overlay-Content" design).
/// Tapping anywhere on the screen goes to the menu.
///
/// Menu data (categories + products) is prefetched in the background so the
/// menu screen renders instantly when the user taps to continue.
class KioskWelcomeScreen extends StatefulWidget {
  const KioskWelcomeScreen({super.key});

  @override
  State<KioskWelcomeScreen> createState() => _KioskWelcomeScreenState();
}

class _KioskWelcomeScreenState extends State<KioskWelcomeScreen> {
  static const String _introImageAsset = 'assets/video/kiosk_intro_Image.png';
  static const AssetImage _introImage = AssetImage(_introImageAsset);

  bool _imageReady = false;
  bool _orderLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMenuPrefetch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheIntro();
  }

  Future<void> _precacheIntro() async {
    if (_imageReady) return;
    try {
      await precacheImage(_introImage, context);
    } catch (_) {
      // Asset missing or failed to decode -> keep the solid dark background
      // instead of crashing the kiosk.
      return;
    }
    if (mounted) setState(() => _imageReady = true);
  }

  void _startMenuPrefetch() {
    if (!mounted) return;
    final locale = Provider.of<LocalizationProvider>(context, listen: false)
        .locale
        .languageCode;
    final categories = Provider.of<CategoryProvider>(context, listen: false);
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final deals = Provider.of<KioskDealProvider>(context, listen: false);

    // Disk cache if present; one network prefetch only when the cache is empty.
    deals.loadCached();
    deals.fetchDeals();
    categories.warmKioskMenuFromDisk(locale).then((_) {
      if (!mounted) return;
      KioskMenuImageHelper.precacheAroundSelected(context, categories, splash);
    });
  }

  Future<void> _onContinue() async {
    if (_orderLoading) return;
    setState(() => _orderLoading = true);

    final locale = Provider.of<LocalizationProvider>(context, listen: false)
        .locale
        .languageCode;
    final categories = Provider.of<CategoryProvider>(context, listen: false);
    final splash = Provider.of<SplashProvider>(context, listen: false);

    await categories.ensureKioskMenuReady(localeCode: locale);
    if (!mounted) return;
    await Provider.of<KioskDealProvider>(context, listen: false).fetchDeals();
    if (!mounted) return;

    // Warm the FIRST (visible) category's images before showing the menu so the
    // first paint has no shimmer; neighbours warm in the background. Bounded by
    // a timeout so a slow network can never freeze the tap.
    await KioskMenuImageHelper.precacheAroundSelected(
      context,
      categories,
      splash,
      awaitVisible: true,
    ).timeout(const Duration(seconds: 3), onTimeout: () {});
    if (!mounted) return;

    setState(() => _orderLoading = false);

    RouterHelper.getKioskMenuRoute(action: RouteAction.pushReplacement);
  }

  @override
  Widget build(BuildContext context) {
    final Size size =
        KioskMetrics.maybeOf(context)?.window ?? MediaQuery.sizeOf(context);
    final bool landscape = size.width >= size.height;
    // Landscape type is keyed to the shorter axis so the prompt does not
    // explode across a wide panel. Portrait still follows width.
    final double typeRef =
        landscape ? math.min(size.width * 0.55, size.height) : size.width;
    final double logoWidth = (typeRef * 0.26).clamp(150.0, 980.0);
    final double instructionFont = (typeRef * 0.054).clamp(20.0, 220.0);
    final double arrowSize = landscape
        ? (size.height * 0.16).clamp(64.0, 280.0)
        : (size.height * 0.19).clamp(90.0, 520.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _orderLoading ? null : _onContinue,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: intro image if available, otherwise a solid dark fill.
            _buildBackground(),

            // Gentle top + bottom dark scrim so the logo, prompt and arrow stay
            // readable over the (potentially bright) image.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black45,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black45,
                  ],
                  stops: [0.0, 0.22, 0.7, 1.0],
                ),
              ),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.035),
                    // A/CAFÉ logo pinned to the top (white artwork tinted black).
                    SvgPicture.asset(
                      Images.kioskLogoWhiteSvg,
                      width: logoWidth,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                    ),
                    const Spacer(),
                    // Center prompt.
                    Text(
                      'TOUCH TO ORDER',
                      textAlign: TextAlign.center,
                      style: loewExtraBold.copyWith(
                        color: Colors.black,
                        fontSize: instructionFont,
                        height: 1.1,
                      ),
                    ),
                    const Spacer(),
                    // Animated down-arrow (or a spinner while the menu is being
                    // made ready after a tap).
                    SizedBox(
                      height: arrowSize,
                      child: Center(
                        child: _orderLoading
                            ? const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                ),
                              )
                            : Image.asset(
                                Images.kioskDownArrow,
                                width: arrowSize,
                                height: arrowSize,
                                fit: BoxFit.contain,
                                color: Colors.black,
                                colorBlendMode: BlendMode.srcIn,
                              ),
                      ),
                    ),
                    SizedBox(height: size.height * 0.03),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    // Solid dark background shown until the intro image is decoded — no default
    // image is ever shown, so there is no swap/flicker. The intro then fades in
    // once it is fully in the image cache.
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        AnimatedOpacity(
          opacity: _imageReady ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: _imageReady
              ? const Image(
                  image: _introImage,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
