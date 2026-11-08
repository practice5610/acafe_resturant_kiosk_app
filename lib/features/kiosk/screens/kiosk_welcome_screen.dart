import 'dart:async';
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
import 'package:acafe_customer/utill/cjk_fonts.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

/// Kiosk intro screen: the looping intro video filling the whole screen, an
/// "ORDER HERE" pill and a row of round language flags. Tapping anywhere that
/// is not a flag goes to the menu.
///
/// The languages are the ones Settings → Hardware offers on this device;
/// English is chosen until a guest picks another (see
/// [KioskLanguageOffering.selectionFor]). A switch applies at once and starts
/// loading that language's menu in the background, so the tap to order stays
/// fast. A flag tap only ever switches language; it never starts an order.
///
/// The video is a centre-cropped cover on every screen, so there are never
/// bars; the intro artwork is the poster until its first frame. Every size
/// comes from [KioskIntroMetrics], one rule off the screen's shortest side.
///
/// Menu data (categories + products) is prefetched in the background so the
/// menu screen renders instantly when the user taps to continue.
class KioskWelcomeScreen extends StatefulWidget {
  const KioskWelcomeScreen({super.key});

  /// The portrait intro video. Also the fallback everywhere.
  static String get introVideoAsset => 'assets/video/kiosk_intro.mp4';

  /// The 16:9 "wide" intro video: the full portrait picture centred, the sides
  /// a soft extension of the background. Used on every screen that is not tall
  /// and narrow (see [wideFrom]) when it is bundled.
  static String get introLandscapeVideoAsset =>
      'assets/video/kiosk_intro_landscape.mp4';

  /// The video follows width / height: wide from [wideFrom], tall up to
  /// [tallUpTo], and in between the current one stays so a window dragged
  /// through the band never flip-flops. [firstLoadWide] decides the first load.
  static const double wideFrom = 0.62;
  static const double tallUpTo = 0.59;
  static const double firstLoadWide = 0.605;

  /// Cross-fade time, and the wait after the last resize before a switch.
  static const Duration videoFade = Duration(milliseconds: 300);
  static const Duration switchDebounce = Duration(milliseconds: 300);

  /// The video for a shape. The wide file is only chosen when the asset
  /// manifest lists it; otherwise the tall one is used everywhere.
  static String introVideoAssetFor({
    required bool wide,
    required Set<String> bundled,
  }) =>
      wide && bundled.contains(introLandscapeVideoAsset)
          ? introLandscapeVideoAsset
          : introVideoAsset;

  /// Keys for tests.
  static const Key orderButtonKey = ValueKey('kiosk_welcome_order_button');
  static const Key flagRowKey = ValueKey('kiosk_welcome_flag_row');
  static Key flagKey(String code) => ValueKey('kiosk_welcome_flag_$code');
  static const Key videoKey = ValueKey('kiosk_welcome_video');
  static const Key staffExitKey = ValueKey('kiosk_welcome_staff_exit');

  @override
  State<KioskWelcomeScreen> createState() => _KioskWelcomeScreenState();
}

/// Every size on the welcome screen, from the screen's shortest side `s`.
/// No width-only or height-only fractions, so every shape agrees.
@immutable
class KioskIntroMetrics {
  /// Shortest side of the screen.
  final double s;

  /// Space kept free on each side of the flag row.
  static const double sidePadding = 16;

  /// Diameter of an unselected / the selected flag circle.
  final double circle;
  final double chosen;

  /// Centre-to-centre distance between flags.
  final double pitch;

  final double buttonWidth;
  final double buttonHeight;
  final double buttonFont;

  /// Row centre, and the button's bottom edge, above the bottom safe edge.
  final double flagCentreFromBottom;
  final double buttonBottomFromBottom;

  /// Staff-exit hit area at the top centre.
  final double exitWidth;
  final double exitHeight;

  const KioskIntroMetrics._({
    required this.s,
    required this.circle,
    required this.chosen,
    required this.pitch,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.buttonFont,
    required this.flagCentreFromBottom,
    required this.buttonBottomFromBottom,
    required this.exitWidth,
    required this.exitHeight,
  });

  factory KioskIntroMetrics.from(Size screen, {int flagCount = 8}) {
    // Sized as if a 9:16 kiosk screen sat in the middle of any screen, and
    // never bigger than on the 1080x1920 kiosk.
    final double s =
        math.min(math.min(screen.width, screen.height * 9 / 16), 1080.0);

    // Every flag is the same size; selection only changes the backdrop.
    double circle = math.max(0.10 * s, 48);
    double chosen = circle;
    // Neighbouring circles never touch, even where the minimums win.
    double pitch = math.max(0.11 * s, circle + 0.01 * s);

    // Shrink spacing and circles together when the row would not fit.
    final double rowWidth = (flagCount - 1) * pitch + chosen;
    final double room = screen.width - 2 * sidePadding;
    if (flagCount > 1 && rowWidth > room && room > 0) {
      final double k = room / rowWidth;
      circle *= k;
      chosen *= k;
      pitch *= k;
    }

    final double flagCentre = 0.10 * s;
    final double buttonHeight = math.max(0.085 * s, 48);
    return KioskIntroMetrics._(
      s: s,
      circle: circle,
      chosen: chosen,
      pitch: pitch,
      buttonWidth: math.min(
        0.78 * s,
        math.max(0, screen.width - 2 * sidePadding),
      ),
      buttonHeight: buttonHeight,
      buttonFont: math.max(0.026 * s, 14),
      flagCentreFromBottom: flagCentre,
      buttonBottomFromBottom: flagCentre + chosen / 2 + 0.07 * s,
      exitWidth: 0.25 * s,
      exitHeight: 0.10 * s,
    );
  }
}

class _KioskWelcomeScreenState extends State<KioskWelcomeScreen> {
  /// Looping intro video, owned by this State: a language switch rebuilds the
  /// widget but never this State, so it never recreates a controller. Only an
  /// orientation change swaps it (see [_reconcileVideo]).
  VideoPlayerController? _video;
  String? _videoAsset;

  /// Controllers fading out under the new one; each is disposed once.
  final List<VideoPlayerController> _fadingOut = [];

  Set<String>? _bundled;
  bool? _wide;
  Size? _lastSize;
  Timer? _switchTimer;
  bool _reconciling = false;
  final Set<String> _failed = {};

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
          l.languageCode != null && Images.roundFlagFor(l.languageCode) != null)
      .toList();

  @override
  void initState() {
    super.initState();
    _localization = Provider.of<LocalizationProvider>(context, listen: false);
    _selected = ValueNotifier<String>(_localization.locale.languageCode);
    _localization.addListener(_syncSelected);
    _dropMissingFlags();
    _loadManifest();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMenuPrefetch());
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    _video?.dispose();
    for (final VideoPlayerController c in _fadingOut) {
      c.dispose();
    }
    _fadingOut.clear();
    _localization.removeListener(_syncSelected);
    _selected.dispose();
    _flags.dispose();
    super.dispose();
  }

  Future<void> _loadManifest() async {
    Set<String> bundled = const {};
    try {
      final AssetBundle bundle =
          context.getInheritedWidgetOfExactType<DefaultAssetBundle>()?.bundle ??
              rootBundle;
      final AssetManifest manifest =
          await AssetManifest.loadFromAssetBundle(bundle);
      bundled = manifest.listAssets().toSet();
    } catch (e) {
      debugPrint('KioskWelcome: could not read the asset manifest: $e');
    }
    if (!mounted) return;
    _bundled = bundled;
    _reconcileVideo();
  }

  /// Shape with hysteresis: tall -> wide from 0.62, wide -> tall up to 0.59,
  /// in between nothing changes.
  void _noteSize(Size size) {
    final double aspect = size.height <= 0 ? 0 : size.width / size.height;
    final bool? current = _wide;
    if (current == null) {
      _wide = aspect > KioskWelcomeScreen.firstLoadWide;
    } else if (!current && aspect >= KioskWelcomeScreen.wideFrom) {
      _wide = true;
    } else if (current && aspect <= KioskWelcomeScreen.tallUpTo) {
      _wide = false;
    }
    if (_lastSize != size) {
      _lastSize = size;
      _scheduleSwitch();
    }
  }

  String get _wantedAsset {
    final String asset = KioskWelcomeScreen.introVideoAssetFor(
      wide: _wide ?? false,
      bundled: _bundled ?? const {},
    );
    return _failed.contains(asset) ? KioskWelcomeScreen.introVideoAsset : asset;
  }

  /// First video starts at once; later switches wait for the resize to settle.
  void _scheduleSwitch() {
    if (_bundled == null) return;
    _switchTimer?.cancel();
    if (_wantedAsset == _videoAsset) return;
    if (_video == null) {
      _reconcileVideo();
      return;
    }
    _switchTimer = Timer(KioskWelcomeScreen.switchDebounce, _reconcileVideo);
  }

  /// Muted, looping, autoplay. A new controller is initialised and playing
  /// before it replaces the old one, which keeps showing underneath while the
  /// new one fades in and is disposed afterwards. Any controller that does not
  /// make it into place is disposed here, so each is disposed exactly once. A
  /// video that cannot play leaves the poster (or the previous video) showing.
  Future<void> _reconcileVideo() async {
    if (_reconciling || !mounted || _bundled == null) return;
    _reconciling = true;
    try {
      while (mounted && _wantedAsset != _videoAsset) {
        final String asset = _wantedAsset;
        VideoPlayerController? controller = VideoPlayerController.asset(asset);
        try {
          await controller.initialize();
          await controller.setVolume(0);
          await controller.setLooping(true);
          await controller.play();
          if (!mounted) break;
          if (asset != _wantedAsset) continue; // orientation moved on meanwhile
          final VideoPlayerController? previous = _video;
          _video = controller;
          _videoAsset = asset;
          controller = null;
          if (previous != null) {
            _fadingOut.add(previous);
            Timer(KioskWelcomeScreen.videoFade * 1.5, () => _release(previous));
          }
          setState(() {});
        } catch (_) {
          // Missing asset / unsupported codec -> fall back to portrait / poster.
          _failed.add(asset);
          if (asset == KioskWelcomeScreen.introVideoAsset) break;
        } finally {
          await controller?.dispose();
        }
      }
    } finally {
      _reconciling = false;
    }
  }

  void _release(VideoPlayerController c) {
    if (!_fadingOut.remove(c)) return; // already released by dispose()
    if (mounted) setState(() {});
    c.dispose();
  }

  void _syncSelected() {
    _selected.value = _localization.locale.languageCode;
    // A ja/zh guest needs the CJK font before the screen re-renders in it.
    CjkFonts.ensureLoaded([_selected.value]);
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
        final String? flag = Images.roundFlagFor(l.languageCode);
        if (flag != null && bundled.contains(flag)) {
          kept.add(l);
        } else {
          debugPrint(
              'KioskWelcome: no flag asset for "${l.languageCode}" ($flag); skipped');
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
    _noteSize(size);
    final KioskIntroMetrics m =
        KioskIntroMetrics.from(size, flagCount: _flags.value.length);
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    // The OS text scale must not be able to break this layout.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _orderLoading ? null : _onContinue,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildBackground(),

              // Invisible staff exit: on a POS till serving as a kiosk, three
              // quick taps here are the way back to POS; inert everywhere else.
              Positioned(
                top: safe.top,
                left: 0,
                right: 0,
                child: Center(
                  child: KioskStaffExitTrigger(
                    child: SizedBox(
                      key: KioskWelcomeScreen.staffExitKey,
                      width: m.exitWidth,
                      height: m.exitHeight,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: safe.bottom + m.buttonBottomFromBottom,
                left: 0,
                right: 0,
                child: Center(
                  child: _OrderHereButton(
                    width: m.buttonWidth,
                    height: m.buttonHeight,
                    fontSize: m.buttonFont,
                    loading: _orderLoading,
                    onPressed: _onContinue,
                  ),
                ),
              ),

              _FlagRow(
                flags: _flags,
                selected: _selected,
                enabled: !_orderLoading,
                metrics: m,
                bottomInset: safe.bottom,
                onSelect: _selectLanguage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final VideoPlayerController? video = _video;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Poster: the intro artwork, cover, until the video has a frame and
        // underneath every switch.
        Image(
          image: KioskIntroImage.provider,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
        for (final VideoPlayerController old in _fadingOut)
          _VideoLayer(key: ObjectKey(old), controller: old, fadeIn: false),
        if (video != null)
          _VideoLayer(
            key: ObjectKey(video),
            controller: video,
            fadeIn: true,
            contentKey: KioskWelcomeScreen.videoKey,
          ),
      ],
    );
  }
}

/// One playing video: a true cover, centre-cropped. The box is exactly the
/// video's own size and FittedBox scales it to fill the screen. Fades in over
/// whatever is beneath it.
class _VideoLayer extends StatefulWidget {
  final VideoPlayerController controller;
  final bool fadeIn;
  final Key? contentKey;

  const _VideoLayer({
    super.key,
    required this.controller,
    required this.fadeIn,
    this.contentKey,
  });

  @override
  State<_VideoLayer> createState() => _VideoLayerState();
}

class _VideoLayerState extends State<_VideoLayer> {
  late bool _visible = !widget.fadeIn;

  @override
  void initState() {
    super.initState();
    if (!_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = widget.controller.value.size;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: KioskWelcomeScreen.videoFade,
      child: ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            key: widget.contentKey,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(widget.controller),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "ORDER HERE" pill. Rebuilds on its own when the language changes, so
/// the text follows a flag tap without rebuilding the screen.
class _OrderHereButton extends StatelessWidget {
  final double width;
  final double height;
  final double fontSize;
  final bool loading;
  final VoidCallback onPressed;

  const _OrderHereButton({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Watching the provider is what re-reads the translation on a switch.
    context.watch<LocalizationProvider>();
    final String label =
        kioskTranslate(context, 'order_here', 'Order here').toUpperCase();

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
          padding: EdgeInsets.symmetric(horizontal: height * 0.4),
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
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: FittedBox(
                    key: ValueKey<String>(label),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: loewBold.copyWith(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: fontSize * 0.08,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// One horizontal row of round flags, no labels and no container behind it,
/// centred [KioskIntroMetrics.flagCentreFromBottom] above the bottom safe edge.
///
/// Each flag sits in a circle: soft see-through white (30%) when unselected,
/// larger and solid white when chosen. The flag itself is 72% of its circle.
/// Every flag keeps a slot of the same width, so choosing one never shifts the
/// others.
class _FlagRow extends StatelessWidget {
  final ValueNotifier<List<LanguageModel>> flags;
  final ValueNotifier<String> selected;
  final bool enabled;
  final KioskIntroMetrics metrics;
  final double bottomInset;
  final ValueChanged<LanguageModel> onSelect;

  const _FlagRow({
    required this.flags,
    required this.selected,
    required this.enabled,
    required this.metrics,
    required this.bottomInset,
    required this.onSelect,
  });

  /// Smallest comfortable touch height.
  static const double _minTouch = 48;

  @override
  Widget build(BuildContext context) {
    final double slotHeight = math.max(metrics.chosen, _minTouch);

    return Positioned(
      bottom: bottomInset + metrics.flagCentreFromBottom - slotHeight / 2,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<List<LanguageModel>>(
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
                  child: Row(
                    key: KioskWelcomeScreen.flagRowKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final LanguageModel l in shown)
                        _FlagSlot(
                          key: KioskWelcomeScreen.flagKey(l.languageCode!),
                          language: l,
                          isSelected: l.languageCode == current,
                          size: metrics.circle,
                          slotWidth: metrics.pitch,
                          slotHeight: slotHeight,
                          onTap: () => onSelect(l),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
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

  /// Flag diameter as a share of its circle.
  static const double _flagShare = 0.72;

  @override
  Widget build(BuildContext context) {
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
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.30),
              ),
              child: Container(
                width: size * _flagShare,
                height: size * _flagShare,
                foregroundDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Faint rim so white-edged flags (Japan) read as full size.
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    Images.roundFlagFor(language.languageCode)!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
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
