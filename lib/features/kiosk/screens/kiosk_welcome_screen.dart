import 'package:acafe_customer/common/responsive/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_image_helper.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

/// Kiosk intro screen — a full-screen background video with the white A/CAFÉ
/// logo pinned to the top, a "FOLLOW THE INSTRUCTIONS" prompt in the middle and
/// an animated down-arrow at the bottom (per the Figma "Overlay-Content"
/// design). Tapping anywhere on the screen goes to the menu.
///
/// Menu data (categories + products) is prefetched in the background so the
/// menu screen renders instantly when the user taps to continue.
class KioskWelcomeScreen extends StatefulWidget {
  const KioskWelcomeScreen({super.key});

  @override
  State<KioskWelcomeScreen> createState() => _KioskWelcomeScreenState();
}

class _KioskWelcomeScreenState extends State<KioskWelcomeScreen> {
  static const String _videoAsset = 'assets/video/kiosk_intro.mp4';

  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _orderLoading = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startMenuPrefetch());
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(_videoAsset);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _videoReady = true;
      });
    } catch (_) {
      // No video asset bundled (or it failed to load) -> use the fallback
      // background instead of crashing the kiosk.
      controller.dispose();
      if (mounted) setState(() => _videoReady = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startMenuPrefetch() {
    if (!mounted) return;
    final locale =
        Provider.of<LocalizationProvider>(context, listen: false).locale.languageCode;
    final categories = Provider.of<CategoryProvider>(context, listen: false);
    final splash = Provider.of<SplashProvider>(context, listen: false);

    // Show disk-cached data instantly and kick a background refresh.
    categories.warmKioskMenuFromDisk(locale);

    // Precache once data is ready. Using the prefetch future (not just the disk
    // hydrate) covers a COLD first launch too: the disk cache is empty, so this
    // resolves only after the network prefetch lands — then we warm the images
    // while the intro video is still playing.
    categories.prefetchKioskMenu(localeCode: locale).then((_) {
      if (!mounted) return;
      KioskMenuImageHelper.precacheAroundSelected(context, categories, splash);
    });
  }

  Future<void> _onContinue() async {
    if (_orderLoading) return;
    setState(() => _orderLoading = true);

    final locale =
        Provider.of<LocalizationProvider>(context, listen: false).locale.languageCode;
    final categories = Provider.of<CategoryProvider>(context, listen: false);
    final splash = Provider.of<SplashProvider>(context, listen: false);

    await categories.ensureKioskMenuReady(localeCode: locale);
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
    final Size size = MediaQuery.of(context).size;
    // Sizes taken from the Figma artboard (2572px wide) as fractions of the
    // screen, clamped so the intro looks right on phones, tablets and the 4K
    // kiosk alike.
    final double logoWidth = Responsive.isWide(context)
        ? 360.0
        : (size.width * 0.26).clamp(150.0, 720.0);
    final double instructionFont = Responsive.isWide(context)
        ? 28.0
        : (size.width * 0.054).clamp(20.0, 150.0);
    final double arrowSize = Responsive.isWide(context)
        ? 80.0
        : (size.height * 0.12).clamp(52.0, 300.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _orderLoading ? null : _onContinue,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: video if available, otherwise a solid dark fill.
            _buildBackground(),

            // Gentle top + bottom dark scrim so the logo, prompt and arrow stay
            // readable over the (potentially bright) video.
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
                    // A/CAFÉ white logo pinned to the top.
                    SvgPicture.asset(
                      Images.kioskLogoWhiteSvg,
                      width: logoWidth,
                      fit: BoxFit.contain,
                    ),
                    const Spacer(),
                    // Center prompt.
                    Text(
                      'FOLLOW THE INSTRUCTIONS',
                      textAlign: TextAlign.center,
                      style: loewExtraBold.copyWith(
                        color: Colors.white,
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
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Image.asset(
                                Images.kioskDownArrow,
                                height: arrowSize,
                                fit: BoxFit.contain,
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
    final bool ready = _videoReady && _controller != null;
    // Solid background that matches the video's dark first frame — no default
    // image is ever shown, so there is no poster->video swap/flicker. The video
    // then fades in once initialized and the first frame is ready.
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        AnimatedOpacity(
          opacity: ready ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: ready
              ? FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
