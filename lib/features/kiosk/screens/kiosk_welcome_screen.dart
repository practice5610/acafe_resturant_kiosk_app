import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_intro_image.dart';
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
/// The artwork is never cropped and never zoomed: it is drawn whole, and the
/// surplus left by a screen of a different shape is filled by continuing the
/// artwork's own edge pixels, so the background still reaches every edge.
///
/// Menu data (categories + products) is prefetched in the background so the
/// menu screen renders instantly when the user taps to continue.
class KioskWelcomeScreen extends StatefulWidget {
  const KioskWelcomeScreen({super.key});

  @override
  State<KioskWelcomeScreen> createState() => _KioskWelcomeScreenState();
}

class _KioskWelcomeScreenState extends State<KioskWelcomeScreen> {
  /// Aspect ratio of the intro artwork (the 2572x4522 kiosk artboard). Used to
  /// scale the overlay type with the artwork instead of with the window.
  static const double _introAspect = 2572 / 4522;

  /// Decoded artwork. Held directly (rather than shown through [Image]) so the
  /// painter can draw the whole picture *and* extend its edges in one pass.
  /// Disposed when this screen leaves — Flutter's [ImageCache] may keep its
  /// own copy until memory pressure; the next visit re-warms via
  /// [KioskIntroImage] if needed.
  ui.Image? _intro;
  ImageStream? _introStream;
  ImageStreamListener? _introListener;

  /// True when the decode arrived from cache on the same frame (pre-warmed).
  /// Skips the fade-in so a warm hit never looks like a blank flash.
  bool _introReadySync = false;

  bool _orderLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMenuPrefetch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveIntro();
  }

  @override
  void dispose() {
    if (_introListener != null) _introStream?.removeListener(_introListener!);
    _intro?.dispose();
    super.dispose();
  }

  void _resolveIntro() {
    final ImageStream stream = KioskIntroImage.provider
        .resolve(createLocalImageConfiguration(context));
    if (stream.key == _introStream?.key) return;
    if (_introListener != null) _introStream?.removeListener(_introListener!);

    _introListener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        final ui.Image image = info.image.clone();
        info.dispose();
        if (!mounted) {
          image.dispose();
          return;
        }
        setState(() {
          _intro?.dispose();
          _intro = image;
          _introReadySync = synchronousCall;
        });
      },
      // Asset missing or failed to decode -> keep the solid background instead
      // of crashing the kiosk.
      onError: (_, __) {},
    );
    _introStream = stream;
    stream.addListener(_introListener!);
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

    try {
      await categories.ensureKioskMenuReady(localeCode: locale);
    } catch (_) {
      // Menu still opens; the screen shows its own skeleton / empty state.
    }
    if (!mounted) return;

    // Deals are nice-to-have. Never block entry to the menu on a bad payload.
    try {
      await Provider.of<KioskDealProvider>(context, listen: false)
          .fetchDeals()
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
    if (!mounted) return;

    // Warm the FIRST (visible) category's images before showing the menu so the
    // first paint has no shimmer; neighbours warm in the background. Bounded by
    // a timeout so a slow network can never freeze the tap.
    try {
      await KioskMenuImageHelper.precacheAroundSelected(
        context,
        categories,
        splash,
        awaitVisible: true,
      ).timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {}
    if (!mounted) return;

    setState(() => _orderLoading = false);

    RouterHelper.getKioskMenuRoute(action: RouteAction.pushReplacement);
  }

  @override
  Widget build(BuildContext context) {
    final Size size =
        KioskMetrics.maybeOf(context)?.window ?? MediaQuery.sizeOf(context);

    // Size of the artwork as actually drawn (contain, never cropped). Type and
    // the arrow scale off it, so the composition keeps the artboard's
    // proportions on a phone, a laptop window and the kiosk panel alike.
    final double artWidth = math.min(size.width, size.height * _introAspect);
    final double artHeight = artWidth / _introAspect;

    final double logoWidth = (artWidth * 0.26).clamp(120.0, 980.0);
    final double instructionFont = (artWidth * 0.054).clamp(18.0, 220.0);
    final double arrowSize = (artHeight * 0.11).clamp(56.0, 320.0);

    return Scaffold(
      backgroundColor: _introEdgeFallback,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _orderLoading ? null : _onContinue,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The artwork, whole, filling the screen edge to edge.
            _buildBackground(),

            // Gentle top + bottom dark scrim so the logo, prompt and arrow stay
            // readable over the (potentially bright) image.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black26,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black26,
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
    final ui.Image? image = _intro;
    // Until the artwork is decoded the screen is the artwork's own edge colour,
    // so a cold decode fades in rather than swapping two different colours.
    // A pre-warmed (sync) hit paints immediately — no blank flash.
    return AnimatedOpacity(
      opacity: image == null ? 0 : 1,
      duration: _introReadySync
          ? Duration.zero
          : const Duration(milliseconds: 400),
      child: image == null
          ? const SizedBox.shrink()
          : CustomPaint(painter: _IntroBackgroundPainter(image)),
    );
  }
}

/// Flat colour matching the artwork's edge pixels (#E9EAF2), used before the
/// image is decoded.
const Color _introEdgeFallback = Color(0xFFE9EAF2);

/// Draws the intro artwork whole — `contain`, never cropped or zoomed — and
/// fills whatever the screen has left over by stretching the artwork's own
/// outermost pixels outwards.
///
/// Because the picture's border is a flat gradient backdrop, the extension is
/// invisible: the result reads as one image reaching every edge, on a phone, a
/// wide desktop window or the portrait kiosk panel, with no blurred backdrop
/// and no letterbox bars.
class _IntroBackgroundPainter extends CustomPainter {
  final ui.Image image;

  const _IntroBackgroundPainter(this.image);

  /// Width, in source pixels, of the edge strip that gets stretched outwards,
  /// and how far inside the border it is sampled from. The inset skips the
  /// outermost rows/columns, which carry compression noise that would otherwise
  /// be stretched into visible streaks.
  static const double _edgeStrip = 6;
  static const double _edgeInset = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final double iw = image.width.toDouble();
    final double ih = image.height.toDouble();
    if (iw <= 0 || ih <= 0) return;

    final double scale = math.min(size.width / iw, size.height / ih);
    final double dw = iw * scale;
    final double dh = ih * scale;
    final double dx = (size.width - dw) / 2;
    final double dy = (size.height - dh) / 2;

    final Paint paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = false;

    // Edge extension first, the artwork on top, so the 1px overlap that hides
    // the seam is always covered by real pixels.
    // Only one axis can ever have surplus, so these two blocks are exclusive.
    if (dx > 0.5) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(_edgeInset, 0, _edgeStrip, ih),
        Rect.fromLTWH(0, dy, dx + 1, dh),
        paint,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(iw - _edgeInset - _edgeStrip, 0, _edgeStrip, ih),
        Rect.fromLTWH(dx + dw - 1, dy, dx + 1, dh),
        paint,
      );
    }
    if (dy > 0.5) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, _edgeInset, iw, _edgeStrip),
        Rect.fromLTWH(dx, 0, dw, dy + 1),
        paint,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, ih - _edgeInset - _edgeStrip, iw, _edgeStrip),
        Rect.fromLTWH(dx, dy + dh - 1, dw, dy + 1),
        paint,
      );
    }

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, iw, ih),
      Rect.fromLTWH(dx, dy, dw, dh),
      paint,
    );
  }

  @override
  bool shouldRepaint(_IntroBackgroundPainter oldDelegate) =>
      oldDelegate.image != image;
}
