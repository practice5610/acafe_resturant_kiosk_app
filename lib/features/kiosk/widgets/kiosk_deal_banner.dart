import 'dart:math' as math;

import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/common/widgets/network_image_aspect.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_deal_detail_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Identifies the laid-out artwork card inside the banner slot.
///
/// The slot fills the product area; the card inside it is what the half-window
/// cap actually sizes. Tests measure the card, since that is the box the
/// artwork is painted into.
const Key kKioskDealBannerCardKey = Key('kiosk-deal-banner-card');

/// Data-driven promotional deal banner inserted mid-grid after the first two
/// product rows. Hidden when there are no active deals for this branch.
///
/// The slot is sized from the artwork, not the other way round — see
/// [KioskDealBannerGeometry]. Ratios are resolved once per URL and cached, so
/// the first paint uses the design default and every paint after that uses the
/// real shape without the grid jumping.
class KioskDealPromoBanner extends StatefulWidget {
  final double s;
  final List<KioskDeal> deals;
  const KioskDealPromoBanner({super.key, required this.s, required this.deals});

  @override
  State<KioskDealPromoBanner> createState() => _KioskDealPromoBannerState();
}

class _KioskDealPromoBannerState extends State<KioskDealPromoBanner> {
  /// Ratios keyed by image URL. Seeded synchronously from the shared cache so
  /// a rebuild (scroll, category switch) never reverts to the default.
  final Map<String, double> _aspects = <String, double>{};

  @override
  void initState() {
    super.initState();
    _loadAspects();
  }

  @override
  void didUpdateWidget(covariant KioskDealPromoBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(
      oldWidget.deals.map((d) => d.image).toList(),
      widget.deals.map((d) => d.image).toList(),
    )) {
      _loadAspects();
    }
  }

  Future<void> _loadAspects() async {
    final List<String> urls = _imageUrls();
    for (final url in urls) {
      final double? cached = NetworkImageAspect.peek(url);
      if (cached != null) _aspects[url] = cached;
    }
    for (final url in urls) {
      if (_aspects.containsKey(url)) continue;
      final double? aspect = await NetworkImageAspect.resolve(url);
      if (!mounted || aspect == null) continue;
      setState(() => _aspects[url] = aspect);
    }
  }

  List<String> _imageUrls() {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String? base =
        splash.baseUrls?.dealImageUrl ?? splash.baseUrls?.productImageUrl;
    return widget.deals
        .map((deal) => KioskProductImageHelper.resolveUrl(
              productImageBaseUrl: base,
              filename: deal.image,
            ))
        .where((url) => url.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<KioskDeal> deals = widget.deals;
    if (deals.isEmpty) return const SizedBox.shrink();

    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String? base =
        splash.baseUrls?.dealImageUrl ?? splash.baseUrls?.productImageUrl;
    // Window size comes from the shell's resolved metrics, not from the
    // window directly — the kiosk keeps one source of layout size (see
    // kiosk_responsive_guardrails_test). Outside the shell there is nothing
    // to cap against, so the banner simply fills the area it was given.
    final KioskMetrics? metrics = KioskMetrics.maybeOf(context);
    final Size window = metrics?.window ?? Size.infinite;

    return LayoutBuilder(
      builder: (context, constraints) {
        final List<String> urls = deals
            .map((deal) => KioskProductImageHelper.resolveUrl(
                  productImageBaseUrl: base,
                  filename: deal.image,
                ))
            .toList();

        // Gap between carousel pages. Taken off the area BEFORE the slot is
        // sized: each page is padded by it, so a slot measured against the
        // unpadded width would overflow its own page by exactly this much.
        final double pageGap = deals.length > 1 ? 16 * widget.s : 0;

        // One slot for the whole carousel, tall enough for the tallest banner,
        // so paging never resizes the products underneath it.
        final KioskDealBannerGeometry slot = KioskDealBannerGeometry.forAll(
          areaWidth: constraints.maxWidth - pageGap,
          windowWidth: window.width,
          windowHeight: window.height,
          imageAspects: urls.map((url) => _aspects[url]),
        );

        if (slot.height <= 0) return const SizedBox.shrink();

        Widget tile(int index) => _DealBannerTile(
              s: widget.s,
              deal: deals[index],
              imageUrl: urls[index],
              slot: slot,
              imageAspect: _aspects[urls[index]],
            );

        if (deals.length == 1) {
          return SizedBox(height: slot.height, child: tile(0));
        }

        return SizedBox(
          height: slot.height,
          child: PageView.builder(
            itemCount: deals.length,
            itemBuilder: (context, index) => Padding(
              padding: EdgeInsets.only(
                right: index == deals.length - 1 ? 0 : pageGap,
              ),
              child: tile(index),
            ),
          ),
        );
      },
    );
  }
}

/// The artwork card itself: a box of exactly [box]'s size, clipped to [radius],
/// aligned to the leading edge of whatever room it was given.
///
/// Shared by the menu carousel and the deal detail hero so the two cannot
/// drift apart. Both feed it a [KioskDealBannerGeometry] whose ratio came from
/// the artwork, which is what makes `BoxFit.cover` a no-op rather than a crop.
Widget _dealBannerCard({
  required KioskDealBannerGeometry box,
  required String imageUrl,
  required double radius,
  required Widget fallback,
  VoidCallback? onTap,
}) {
  // A capped banner is narrower than the room it sits in, and that spare width
  // goes on the trailing side: the card's leading edge then lines up with the
  // content above it instead of floating in the middle. Directional rather
  // than `centerLeft` so an RTL locale aligns to its own reading edge.
  // Vertically it stays centred, which keeps a short banner in the middle of a
  // taller carousel slot.
  final Widget artwork = ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: imageUrl.isEmpty
        ? fallback
        : CustomImageWidget(
            placeholder: Images.placeholderImage,
            image: imageUrl,
            width: box.width,
            height: box.height,
            // The box is the image's own shape, so cover neither crops
            // nor stretches; it only guards the clamped edge cases
            // (a near-square or ultra-wide upload).
            fit: BoxFit.cover,
          ),
  );

  return Align(
    alignment: AlignmentDirectional.centerStart,
    child: SizedBox(
      key: kKioskDealBannerCardKey,
      width: box.width,
      height: box.height,
      // A static image deal passes no onTap. It gets the bare artwork rather
      // than a no-op KioskTap: the previous `onTap ?? () {}` still built an
      // opaque GestureDetector, which swallowed the tap instead of leaving the
      // banner inert.
      child: onTap == null ? artwork : KioskTap(onTap: onTap, child: artwork),
    ),
  );
}

/// A single deal banner sized to its own artwork — the deal detail hero.
///
/// The menu's carousel cannot use this directly (it needs ONE slot sized
/// around several banners at once), but both go through the same geometry and
/// the same card builder, so a fix in one is a fix in both.
class KioskDealBannerImage extends StatefulWidget {
  final String imageUrl;

  /// Drawn instead of the image when the deal has no artwork.
  final Widget fallback;

  /// Corner radius of the card.
  final double radius;

  final VoidCallback? onTap;

  const KioskDealBannerImage({
    super.key,
    required this.imageUrl,
    required this.fallback,
    this.radius = 28,
    this.onTap,
  });

  @override
  State<KioskDealBannerImage> createState() => _KioskDealBannerImageState();
}

class _KioskDealBannerImageState extends State<KioskDealBannerImage> {
  double? _aspect;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant KioskDealBannerImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _aspect = null;
      _load();
    }
  }

  Future<void> _load() async {
    // Synchronous first: a ratio resolved earlier (the menu banner uses the
    // same URL) means this hero never starts at the default and then jump.
    final double? cached = NetworkImageAspect.peek(widget.imageUrl);
    if (cached != null) {
      _aspect = cached;
      return;
    }
    final double? resolved = await NetworkImageAspect.resolve(widget.imageUrl);
    if (!mounted || resolved == null) return;
    setState(() => _aspect = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final KioskMetrics? metrics = KioskMetrics.maybeOf(context);
    final Size window = metrics?.window ?? Size.infinite;

    return LayoutBuilder(
      builder: (context, constraints) {
        final KioskDealBannerGeometry box = KioskDealBannerGeometry.resolve(
          areaWidth: constraints.maxWidth,
          windowWidth: window.width,
          windowHeight: window.height,
          imageAspect: _aspect,
        );
        if (box.height <= 0) return const SizedBox.shrink();

        return _dealBannerCard(
          box: box,
          imageUrl: widget.imageUrl,
          radius: math.min(widget.radius, box.height * 0.12),
          fallback: widget.fallback,
          onTap: widget.onTap,
        );
      },
    );
  }
}

class _DealBannerTile extends StatelessWidget {
  final double s;
  final KioskDeal deal;
  final String imageUrl;

  /// The shared carousel slot. This tile centres its own box inside it.
  final KioskDealBannerGeometry slot;

  /// This banner's own ratio, or null while it is still resolving.
  final double? imageAspect;

  const _DealBannerTile({
    required this.s,
    required this.deal,
    required this.imageUrl,
    required this.slot,
    this.imageAspect,
  });

  @override
  Widget build(BuildContext context) {
    // The tile's own box: the slot's width, at THIS artwork's ratio. A banner
    // wider than the tallest one in the carousel is simply a shorter card in
    // the slot — the surrounding page shows through, so there is no letterbox
    // bar and, because the box matches the image, no crop either.
    // The slot already applied both caps, and this artwork is never taller
    // than the one the slot was sized for, so no cap is re-applied here.
    final KioskDealBannerGeometry box = KioskDealBannerGeometry.resolve(
      areaWidth: slot.width,
      windowWidth: double.infinity,
      imageAspect: imageAspect,
    );

    return _dealBannerCard(
      box: box,
      imageUrl: imageUrl,
      // Corner radius is a Figma value at s = 1; on a capped banner it must
      // shrink with the card or it eats the artwork.
      radius: math.min(60 * s, box.height * 0.12),
      fallback: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF6B4A2F), Color(0xFFB98E5E)],
          ),
        ),
      ),
      // Product bundles open the detail sheet exactly as before. A static
      // image is artwork with nothing behind it, so it gets no tap target.
      onTap: deal.isStaticImage ? null : () => openKioskDealDetail(context, deal),
    );
  }
}

