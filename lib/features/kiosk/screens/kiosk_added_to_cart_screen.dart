import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// KIOSK — ITEM ADDED TO CART
// ===========================================================================
// The confirmation beat between customizing an item and returning to the menu.
// Shared by BOTH ordering experiences: Version A and Version B both finish at
// `_KioskCustomizeActions._addToCart`, which is the only thing that opens this
// screen, so the two versions cannot drift apart here.
//
// Choreography (one controller, staggered intervals — cheaper and easier to
// keep in sync than four controllers):
//
//   0.00 -> 0.30   logo settles in
//   0.08 -> 0.52   product lifts and scales up from 0.90
//   0.30           success mark starts playing over it
//   0.42 -> 0.72   title rises
//   0.52 -> 0.82   subtitle rises
//   0.62 -> 1.00   total rises and scales up from 0.94
//
// then a short hold before returning to the menu. Tapping anywhere skips
// straight to the menu — a customer adding several items should never be made
// to sit through this.
// ===========================================================================

/// How long the whole entrance takes.
const Duration _kEnterDuration = Duration(milliseconds: 1150);

/// Hold after the entrance finishes, before returning to the menu.
const Duration _kHold = Duration(milliseconds: 1050);

/// Cream page, matching every other kiosk surface.
const Color _kSubtitleColor = Color(0xFF6B6656);

/// Full-screen "Item added to cart!" confirmation.
///
/// Push it with [KioskAddedToCartScreen.route], which replaces the customize
/// screen — so dismissing lands back on the menu with the cart already updated.
class KioskAddedToCartScreen extends StatefulWidget {
  /// Already-resolved product image URL.
  final String heroImage;

  /// Already-formatted cart total AFTER this item was added.
  ///
  /// Both values arrive resolved rather than being looked up here: this screen
  /// only ever REPORTS what just happened, so it holds no provider dependency,
  /// cannot mutate cart state, and can be rendered in a widget test.
  final String totalLabel;

  const KioskAddedToCartScreen({
    super.key,
    required this.heroImage,
    required this.totalLabel,
  });

  /// Route that replaces the customize screen, so the back stack stays
  /// [menu] -> [confirmation] and dismissing returns to the menu.
  ///
  /// Fades rather than sliding: the product photo is already on screen behind
  /// it at the same size, so a slide would break that continuity.
  static Route<void> route({
    required String heroImage,
    required String totalLabel,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) =>
          KioskAddedToCartScreen(heroImage: heroImage, totalLabel: totalLabel),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  @override
  State<KioskAddedToCartScreen> createState() => _KioskAddedToCartScreenState();
}

class _KioskAddedToCartScreenState extends State<KioskAddedToCartScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _exitTimer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _kEnterDuration)
      ..forward();
    _exitTimer = Timer(_kEnterDuration + _kHold, _leave);
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Back to the menu. Guarded so the auto-timer and a customer tap landing at
  /// the same moment cannot pop twice.
  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _exitTimer?.cancel();
    KioskNavigationHelper.popOrNavigate(
      context,
      fallback: RouterHelper.getKioskMenuRoute,
    );
  }

  /// Fade + rise, on a slice of the shared controller.
  Widget _reveal({
    required double begin,
    required double end,
    required double s,

    /// Artboard px the child travels upward into place.
    double rise = 40,
    Widget? child,
    Widget Function(double t)? builder,
  }) {
    final Animation<double> t = CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (context, inner) => Opacity(
        // Fade finishes ahead of the movement so nothing arrives still faint.
        opacity: Curves.easeOut.transform(t.value.clamp(0.0, 1.0)),
        child: Transform.translate(
          offset: Offset(0, (1 - t.value) * rise * s),
          child: builder != null ? builder(t.value) : inner,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Tap anywhere to skip ahead — never trap the customer here.
          onTap: _leave,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double s = KioskResponsive.scale(constraints.maxWidth);
              // One scale for the hero box so the 453×731 artboard aspect is
              // preserved. Independent clamps on width and height used to
              // squash the photo on short viewports (0.62 design → 0.88 clamp).
              final double heroFit = math.min(
                _fit(453 * s, constraints.maxHeight * 0.30) / (453 * s),
                _fit(731 * s, constraints.maxHeight * 0.34) / (731 * s),
              );
              final double heroWidth = 453 * s * heroFit;
              final double heroHeight = 731 * s * heroFit;
              // The tick occupies 32.2% of the gif's 500x500 canvas (the rest is
              // the confetti burst, which reaches ~83% at its peak). The design
              // wants a tick about a quarter of the photo's width, so the BOX is
              // sized from that: 0.75 * 0.322 = 24% of the photo.
              final double markBox = heroWidth * 0.75;

              return KioskCenteredContent(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 86 * s),
                  child: Column(
                    children: [
                      SizedBox(height: (90 * s).clamp(20.0, 90.0)),
                      _reveal(
                        begin: 0.0,
                        end: 0.30,
                        s: s,
                        rise: 20,
                        child: SvgPicture.asset(
                          Images.kioskLogoWhiteSvg,
                          width: _fit(560 * s, constraints.maxWidth * 0.42),
                          fit: BoxFit.contain,
                          // Artwork ships white; the kiosk uses it on cream.
                          colorFilter: const ColorFilter.mode(
                            Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const Spacer(flex: 3),
                      _reveal(
                        begin: 0.08,
                        end: 0.52,
                        s: s,
                        rise: 56,
                        builder: (t) => Transform.scale(
                          // Settles up into place rather than popping.
                          scale: 0.90 + (0.10 * t),
                          child: _HeroWithMark(
                            image: widget.heroImage,
                            width: heroWidth,
                            height: heroHeight,
                            markBox: markBox,
                            controller: _controller,
                          ),
                        ),
                      ),
                      SizedBox(height: (56 * s).clamp(16.0, 56.0)),
                      _reveal(
                        begin: 0.42,
                        end: 0.72,
                        s: s,
                        child: Text(
                          kioskTranslate(context, 'item_added_to_cart',
                              'Item added to cart!'),
                          textAlign: TextAlign.center,
                          style: loewExtraBold.copyWith(
                            fontSize: (88 * s).clamp(20.0, 88.0),
                            height: 1.05,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      SizedBox(height: (18 * s).clamp(6.0, 18.0)),
                      _reveal(
                        begin: 0.52,
                        end: 0.82,
                        s: s,
                        child: Text(
                          kioskTranslate(context, 'your_total_has_been_updated',
                              'Your total has been updated'),
                          textAlign: TextAlign.center,
                          style: swiss721Light.copyWith(
                            fontSize: (41 * s).clamp(11.0, 41.0),
                            height: 1.2,
                            color: _kSubtitleColor,
                          ),
                        ),
                      ),
                      SizedBox(height: (60 * s).clamp(18.0, 60.0)),
                      _reveal(
                        begin: 0.62,
                        end: 1.0,
                        s: s,
                        rise: 30,
                        builder: (t) => Transform.scale(
                          scale: 0.94 + (0.06 * t),
                          child: Text(
                            widget.totalLabel,
                            textAlign: TextAlign.center,
                            style: loewExtraBold.copyWith(
                              fontSize: (129 * s).clamp(26.0, 129.0),
                              height: 1.0,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Never larger than the artboard value, never larger than the room available.
double _fit(double designed, double available) =>
    designed < available ? designed : available;

/// Product photo with the animated success mark sitting on its lower-right,
/// exactly where the design puts the tick.
class _HeroWithMark extends StatelessWidget {
  final String image;
  final double width;
  final double height;
  final double markBox;
  final AnimationController controller;

  const _HeroWithMark({
    required this.image,
    required this.width,
    required this.height,
    required this.markBox,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        // The confetti burst overflows the photo's box on purpose.
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomImageWidget(
              key: ValueKey(image),
              placeholder: Images.placeholderImage,
              image: image,
              fit: BoxFit.contain,
            ),
          ),
          // Held back until the photo has finished arriving, so the tick reads
          // as a response to the item rather than racing it.
          // Offsets are measured to the TICK, not to the box: the tick sits at
          // the box's centre, so these place its centre just inside the photo's
          // lower-right corner, matching the design. The confetti is free to
          // overflow (Clip.none above) rather than being boxed in.
          Positioned(
            right: -markBox * 0.37,
            bottom: -height * 0.06,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final bool started = controller.value >= 0.30;
                return Opacity(opacity: started ? 1 : 0, child: child);
              },
              child: SizedBox(
                width: markBox,
                height: markBox,
                child: Image.asset(
                  Images.confirmedDeliveryAnimation,
                  fit: BoxFit.contain,
                  // No cacheWidth: this is a 240-frame animation, and forcing a
                  // resample would run on every frame. Native 500x500 decodes
                  // one frame at a time and downscales on the GPU instead.
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
