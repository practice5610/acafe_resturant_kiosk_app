import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_staff_exit_trigger.dart';
import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_intro_image.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_language_offering.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_welcome_language_picker.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

/// Kiosk intro screen — a full-screen background image with the black A/CAFÉ
/// logo pinned to the top, a "TOUCH TO ORDER" prompt in the middle and the
/// language dropdown at the bottom. Tapping anywhere else goes to the menu.
///
/// The languages are the ones Settings → Hardware offers on this device;
/// English is chosen until a guest picks another (see
/// [KioskLanguageOffering.selectionFor]). A switch applies at once and starts
/// loading that language's menu in the background, so the tap to order stays
/// fast.
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

  /// Settings → Hardware's offering, resolved once so the picker is stable.
  late final List<LanguageModel> _languages =
      KioskLanguageOffering.forThisDevice();

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

  Future<void> _startMenuPrefetch() async {
    if (!mounted) return;
    final String locale = await _settleOnOfferedLanguage();
    if (!mounted) return;
    final deals = Provider.of<KioskDealProvider>(context, listen: false);

    // Disk cache if present; one network prefetch only when the cache is empty.
    deals.loadCached();
    deals.fetchDeals();
    _warmMenu(locale);
  }

  /// A kiosk left in a language Settings → Hardware no longer offers moves to
  /// English (or the first offered language) before anything is loaded in it.
  Future<String> _settleOnOfferedLanguage() async {
    final localization =
        Provider.of<LocalizationProvider>(context, listen: false);
    final String current = localization.locale.languageCode;
    final LanguageModel pick =
        KioskLanguageOffering.selectionFor(_languages, current);
    if (pick.languageCode != current) {
      await localization.setKioskLanguage(
        Locale(pick.languageCode!, pick.countryCode),
      );
    }
    return pick.languageCode!;
  }

  void _warmMenu(String locale) {
    final categories = Provider.of<CategoryProvider>(context, listen: false);
    final splash = Provider.of<SplashProvider>(context, listen: false);
    categories.warmKioskMenuFromDisk(locale).then((_) {
      if (!mounted) return;
      KioskMenuImageHelper.precacheAroundSelected(context, categories, splash);
    });
  }

  Future<void> _selectLanguage(LanguageModel language) async {
    final localization =
        Provider.of<LocalizationProvider>(context, listen: false);
    if (_orderLoading ||
        language.languageCode == localization.locale.languageCode) {
      return;
    }
    // The screen re-renders in the new language straight away; the menu
    // follows in the background (a later switch supersedes this load).
    await localization.setKioskLanguage(
      Locale(language.languageCode!, language.countryCode),
    );
    if (!mounted) return;
    _warmMenu(language.languageCode!);
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
    // the language picker scale off it, so the composition keeps the
    // artboard's proportions on a phone, a laptop window and the kiosk panel
    // alike.
    final double artWidth = math.min(size.width, size.height * _introAspect);

    final double logoWidth = (artWidth * 0.26).clamp(120.0, 980.0);
    final double instructionFont = (artWidth * 0.054).clamp(18.0, 220.0);
    // Never under the 48px touch target, even on a small window.
    final double pillHeight = (artWidth * 0.058).clamp(48.0, 168.0);
    final String prompt =
        kioskTranslate(context, 'touch_to_order', 'Touch to order')
            .toUpperCase();

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

            // Gentle top + bottom dark scrim so the logo, prompt and language
            // picker stay readable over the (potentially bright) image.
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
                    // On a POS till serving as a kiosk, three quick taps here are
                    // the staff way back to POS; inert everywhere else.
                    KioskStaffExitTrigger(
                      child: SvgPicture.asset(
                        Images.kioskLogoWhiteSvg,
                        width: logoWidth,
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(
                          Colors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Center prompt, in the chosen language. Cross-fades on a
                    // switch rather than snapping.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: Text(
                        prompt,
                        key: ValueKey<String>(prompt),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: loewExtraBold.copyWith(
                          color: Colors.black,
                          fontSize: instructionFont,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildLanguageSlot(pillHeight),
                    SizedBox(height: size.height * 0.04),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The language picker, or a spinner in its place while the menu is being
  /// made ready after a tap. The picker keeps its space while hidden so the
  /// prompt above never jumps, and is locked: a switch now would open the
  /// menu in the language being left.
  Widget _buildLanguageSlot(double pillHeight) {
    final String current =
        Provider.of<LocalizationProvider>(context).locale.languageCode;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: pillHeight),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            opacity: _orderLoading ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _orderLoading,
              child: ExcludeSemantics(
                excluding: _orderLoading,
                child: KioskWelcomeLanguagePicker(
                  languages: _languages,
                  current: current,
                  pillHeight: pillHeight,
                  enabled: !_orderLoading,
                  onSelect: _selectLanguage,
                ),
              ),
            ),
          ),
          if (_orderLoading)
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
        ],
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
          : CustomPaint(painter: KioskIntroBackgroundPainter(image)),
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
class KioskIntroBackgroundPainter extends CustomPainter {
  final ui.Image image;

  const KioskIntroBackgroundPainter(this.image);

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
  bool shouldRepaint(KioskIntroBackgroundPainter oldDelegate) =>
      oldDelegate.image != image;
}
