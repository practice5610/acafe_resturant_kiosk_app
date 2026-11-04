import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_staff_exit_trigger.dart';
import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_intro_image.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_language_offering.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

/// Kiosk intro screen: a full-screen looping background video, an "ORDER HERE"
/// pill and a row of round language flags. Nothing else is drawn; the A/CAFÉ
/// wordmark is part of the video. Tapping anywhere that is not a flag goes to
/// the menu.
///
/// The languages are the ones Settings → Hardware offers on this device;
/// English is chosen until a guest picks another (see
/// [KioskLanguageOffering.selectionFor]). A switch applies at once and starts
/// loading that language's menu in the background, so the tap to order stays
/// fast. A flag tap only ever switches language; it never starts an order.
///
/// The still `kiosk_intro_Image.png` is the poster until the video is ready,
/// and stays on screen if the video cannot start.
///
/// Menu data (categories + products) is prefetched in the background so the
/// menu screen renders instantly when the user taps to continue.
class KioskWelcomeScreen extends StatefulWidget {
  /// Builds the background video's controller. Tests inject one that fails or
  /// is fake; production uses the bundled `kiosk_intro.mp4`.
  @visibleForTesting
  final VideoPlayerController Function()? videoControllerFactory;

  const KioskWelcomeScreen({super.key, this.videoControllerFactory});

  /// Keys for tests.
  static const Key orderButtonKey = ValueKey('kiosk_welcome_order_button');
  static const Key flagRowKey = ValueKey('kiosk_welcome_flag_row');
  static Key flagKey(String code) => ValueKey('kiosk_welcome_flag_$code');
  static const Key staffExitKey = ValueKey('kiosk_welcome_staff_exit');
  static const Key posterKey = ValueKey('kiosk_welcome_poster');

  @override
  State<KioskWelcomeScreen> createState() => _KioskWelcomeScreenState();
}

class _KioskWelcomeScreenState extends State<KioskWelcomeScreen> {
  /// Aspect ratio of the portrait kiosk artboard (2572x4522). On a window
  /// wider than that, widths scale off the portrait column, so the pill never
  /// stretches across a landscape screen.
  static const double _introAspect = 2572 / 4522;

  /// Aspect ratio of the A/CAFÉ logo SVG (680.783 x 178.475); sizes the staff
  /// exit hit area to the footprint the logo used to occupy.
  static const double _logoAspect = 680.783 / 178.475;

  bool _orderLoading = false;

  /// Settings → Hardware's offering, resolved once so the row is stable.
  late final List<LanguageModel> _languages =
      KioskLanguageOffering.forThisDevice();

  /// Languages that actually have a flag to show. Starts as every offered
  /// language with a flag path, then drops any whose asset is not bundled.
  late final ValueNotifier<List<LanguageModel>> _flags =
      ValueNotifier<List<LanguageModel>>(_withFlagPath(_languages));

  /// The language code the flag row rings. Mirrors [LocalizationProvider] so
  /// it is right on open, on return, and after any switch.
  late final ValueNotifier<String> _selected;
  late final LocalizationProvider _localization;

  static List<LanguageModel> _withFlagPath(List<LanguageModel> all) => all
      .where((l) =>
          l.languageCode != null && (l.imageUrl ?? '').isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _localization = Provider.of<LocalizationProvider>(context, listen: false);
    _selected = ValueNotifier<String>(_localization.locale.languageCode);
    _localization.addListener(_syncSelected);
    _dropMissingFlags();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMenuPrefetch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode (or hit the cache for) the poster while the video starts.
    KioskIntroImage.warm(context);
  }

  @override
  void dispose() {
    _localization.removeListener(_syncSelected);
    _selected.dispose();
    _flags.dispose();
    super.dispose();
  }

  void _syncSelected() {
    _selected.value = _localization.locale.languageCode;
  }

  /// A language whose flag is not bundled is skipped (and logged), never shown
  /// as a placeholder.
  Future<void> _dropMissingFlags() async {
    try {
      final AssetManifest manifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      final Set<String> bundled = manifest.listAssets().toSet();
      final List<LanguageModel> kept = [];
      for (final LanguageModel l in _flags.value) {
        if (bundled.contains(l.imageUrl)) {
          kept.add(l);
        } else {
          debugPrint(
              'KioskWelcome: no flag asset for "${l.languageCode}" (${l.imageUrl}); skipped');
        }
      }
      if (!mounted || kept.length == _flags.value.length) return;
      _flags.value = kept;
    } catch (e) {
      debugPrint('KioskWelcome: could not check flag assets: $e');
    }
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

    // Everything is a fraction of the window height, or of the portrait
    // column's width (the whole width on a portrait kiosk).
    final double colWidth = math.min(size.width, size.height * _introAspect);
    final double buttonWidth = colWidth * 0.78;
    final double buttonHeight = size.height * 0.05;
    final double buttonTop = size.height * 0.85;
    final double flagsTop = buttonTop + buttonHeight + size.height * 0.015;

    final double logoWidth = (colWidth * 0.26).clamp(120.0, 980.0);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _orderLoading ? null : _onContinue,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _KioskIntroVideo(controllerFactory: widget.videoControllerFactory),

            // Staff way back to POS: invisible, where the logo used to sit.
            Positioned(
              top: MediaQuery.paddingOf(context).top + size.height * 0.035,
              left: 0,
              right: 0,
              child: Center(
                child: KioskStaffExitTrigger(
                  child: SizedBox(
                    key: KioskWelcomeScreen.staffExitKey,
                    width: logoWidth,
                    height: logoWidth / _logoAspect,
                  ),
                ),
              ),
            ),

            Positioned(
              top: buttonTop,
              left: 0,
              right: 0,
              child: Center(
                child: _OrderHereButton(
                  width: buttonWidth,
                  height: buttonHeight,
                  loading: _orderLoading,
                  onPressed: _onContinue,
                ),
              ),
            ),

            Positioned(
              top: flagsTop,
              left: 0,
              right: 0,
              child: _FlagRow(
                flags: _flags,
                selected: _selected,
                enabled: !_orderLoading,
                buttonHeight: buttonHeight,
                maxWidth: colWidth,
                onSelect: _selectLanguage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The looping, muted background video over the still poster.
///
/// The poster is always underneath, so a cold start, a slow decode or a video
/// that fails to initialise all leave the artwork on screen, never black.
/// Playback pauses while another route covers the welcome screen and resumes
/// when it is uncovered.
class _KioskIntroVideo extends StatefulWidget {
  final VideoPlayerController Function()? controllerFactory;

  const _KioskIntroVideo({this.controllerFactory});

  @override
  State<_KioskIntroVideo> createState() => _KioskIntroVideoState();
}

class _KioskIntroVideoState extends State<_KioskIntroVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _disposed = false;
  Animation<double>? _coveredBy;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Animation<double>? covered =
        ModalRoute.of(context)?.secondaryAnimation;
    if (covered == _coveredBy) return;
    _coveredBy?.removeStatusListener(_onCovered);
    _coveredBy = covered?..addStatusListener(_onCovered);
  }

  @override
  void dispose() {
    _disposed = true;
    _coveredBy?.removeStatusListener(_onCovered);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final VideoPlayerController controller = widget.controllerFactory != null
        ? widget.controllerFactory!()
        : VideoPlayerController.asset(
            'assets/video/kiosk_intro.mp4',
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
    _controller = controller;
    try {
      await controller.initialize();
      if (_disposed) return;
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (_disposed) return;
      setState(() => _ready = true);
    } catch (e) {
      debugPrint('KioskWelcome: intro video failed, keeping the poster: $e');
      _controller = null;
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  /// Another route above the welcome screen (anything but "fully uncovered")
  /// pauses the video; uncovering plays it again.
  void _onCovered(AnimationStatus status) {
    final VideoPlayerController? c = _controller;
    if (c == null || !_ready || _disposed) return;
    if (status == AnimationStatus.dismissed) {
      c.play();
    } else {
      c.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? c = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          key: KioskWelcomeScreen.posterKey,
          image: KioskIntroImage.provider,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Missing artwork: the scaffold's near-black shows instead.
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        if (_ready && c != null)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
      ],
    );
  }
}

/// The "ORDER HERE" pill. Rebuilds on its own when the language changes, so
/// the text follows a flag tap without rebuilding the screen.
class _OrderHereButton extends StatelessWidget {
  final double width;
  final double height;
  final bool loading;
  final VoidCallback onPressed;

  const _OrderHereButton({
    required this.width,
    required this.height,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Watching the provider is what re-reads the translation on a switch.
    context.watch<LocalizationProvider>();
    final String label =
        kioskTranslate(context, 'order_here', 'Order here').toUpperCase();
    final double fontSize = height * 0.3;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: KioskWelcomeScreen.orderButtonKey,
        behavior: HitTestBehavior.opaque,
        onTap: loading ? null : onPressed,
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: const ShapeDecoration(
            color: BrandColors.primaryDark,
            shape: StadiumBorder(),
          ),
          child: loading
              ? SizedBox(
                  width: height * 0.45,
                  height: height * 0.45,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: loewBold.copyWith(
                    color: Colors.white,
                    fontSize: fontSize,
                    letterSpacing: fontSize * 0.08,
                    height: 1.0,
                  ),
                ),
        ),
      ),
    );
  }
}

/// One horizontal row of round flags, no labels and no container. The chosen
/// language is slightly larger with a white ring; every flag keeps a slot of
/// the same width, so choosing one never shifts the others.
class _FlagRow extends StatelessWidget {
  final ValueNotifier<List<LanguageModel>> flags;
  final ValueNotifier<String> selected;
  final bool enabled;
  final double buttonHeight;
  final double maxWidth;
  final ValueChanged<LanguageModel> onSelect;

  const _FlagRow({
    required this.flags,
    required this.selected,
    required this.enabled,
    required this.buttonHeight,
    required this.maxWidth,
    required this.onSelect,
  });

  /// Smallest comfortable touch target.
  static const double _minTouch = 48;

  @override
  Widget build(BuildContext context) {
    final double flag = buttonHeight * 0.6;
    final double chosen = buttonHeight * 0.8;
    final double gap = flag * 0.5;
    final double slotWidth = math.max(chosen + gap, _minTouch);
    final double slotHeight = math.max(chosen, _minTouch);

    return ValueListenableBuilder<List<LanguageModel>>(
      valueListenable: flags,
      builder: (context, List<LanguageModel> shown, _) {
        // One language needs no picker.
        if (shown.length < 2) return const SizedBox.shrink();
        return ValueListenableBuilder<String>(
          valueListenable: selected,
          builder: (context, String current, _) {
            return IgnorePointer(
              ignoring: !enabled,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      key: KioskWelcomeScreen.flagRowKey,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final LanguageModel l in shown)
                          _FlagSlot(
                            key: KioskWelcomeScreen.flagKey(l.languageCode!),
                            language: l,
                            isSelected: l.languageCode == current,
                            size: l.languageCode == current ? chosen : flag,
                            slotWidth: slotWidth,
                            slotHeight: slotHeight,
                            onTap: () => onSelect(l),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FlagSlot extends StatelessWidget {
  final LanguageModel language;
  final bool isSelected;
  final double size;
  final double slotWidth;
  final double slotHeight;
  final VoidCallback onTap;

  const _FlagSlot({
    super.key,
    required this.language,
    required this.isSelected,
    required this.size,
    required this.slotWidth,
    required this.slotHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double ring = isSelected ? size * 0.07 : 0;
    return Semantics(
      button: true,
      selected: isSelected,
      label: language.languageName,
      excludeSemantics: true,
      // Opaque and innermost, so a flag tap is a language switch and never the
      // screen's tap-anywhere.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: slotWidth,
          height: slotHeight,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: ring)
                    : null,
              ),
              child: ClipOval(
                child: Image.asset(
                  language.imageUrl!,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
