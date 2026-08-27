import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_combo_match.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

// ===========================================================================
// KIOSK — "MAKE IT A COMBO MEAL?" (Figma 05a, node 1385:14879)
// ===========================================================================
// Modal card, not a route. Same showGeneralDialog + KioskScrim shell as the
// drink/food upsell. Offers a one-tap upgrade when the cart already covers
// an active deal: YES swaps those (already-customized) lines into a combo
// at bundle price; NO leaves the cart alone.
// ===========================================================================

const Color _kCardBg = Color(0xFFFBF7EC);
const Color _kCardBorder = Color(0xFFE6E0CE);
const Color _kUnselectedFill = Color(0xFFF7F1DE);

/// Opens the combo upgrade and resolves to true when the customer accepted,
/// false when they declined or dismissed.
Future<bool> openKioskComboSheet(
  BuildContext context, {
  required KioskComboMatch match,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Make it a combo meal',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _KioskComboSheet(match: match),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result ?? false;
}

enum _ComboChoice { yes, no }

class _KioskComboSheet extends StatefulWidget {
  final KioskComboMatch match;
  const _KioskComboSheet({required this.match});

  @override
  State<_KioskComboSheet> createState() => _KioskComboSheetState();
}

class _KioskComboSheetState extends State<_KioskComboSheet> {
  _ComboChoice? _choice;

  void _confirm() {
    if (_choice == null) return;
    if (_choice == _ComboChoice.yes) {
      Provider.of<CartProvider>(context, listen: false).applyComboUpgrade(
        consume: widget.match.consumeByIndex,
        dealLine: widget.match.dealLine,
      );
      Navigator.of(context).pop(true);
      return;
    }
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          KioskScrim(
            animation:
                ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation,
            onDismiss: () => Navigator.of(context).pop(false),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double s = KioskLayout.scaleOf(context, constraints);
                final m = _ComboMetrics.forSize(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(vertical: 24 * s),
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: m.sheetWidth,
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.86,
                        ),
                        padding: EdgeInsets.all(m.pad),
                        decoration: BoxDecoration(
                          color: _kCardBg,
                          borderRadius: BorderRadius.circular(
                              (36 * s).clamp(18.0, 36.0)),
                          border: Border.all(color: _kCardBorder, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: (60 * s).clamp(24.0, 60.0),
                              offset: Offset(0, (18 * s).clamp(8.0, 18.0)),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Header(s: s, backSize: m.backSize, titleSize: m.titleSize),
                            SizedBox(height: m.optionTopGap),
                            Row(
                              children: [
                                Expanded(
                                  child: _OptionCard(
                                    key: const ValueKey('kiosk-combo-yes'),
                                    metrics: m,
                                    selected: _choice == _ComboChoice.yes,
                                    imageUrl: _yesImage(context),
                                    label: kioskTranslate(
                                      context,
                                      'yes_combo_me',
                                      'Yes, combo me!',
                                    ).toUpperCase(),
                                    caption: _yesCaption(context),
                                    onTap: () => setState(
                                        () => _choice = _ComboChoice.yes),
                                  ),
                                ),
                                SizedBox(width: m.gap),
                                Expanded(
                                  child: _OptionCard(
                                    key: const ValueKey('kiosk-combo-no'),
                                    metrics: m,
                                    selected: _choice == _ComboChoice.no,
                                    imageUrl: _noImage(context),
                                    label: kioskTranslate(
                                      context,
                                      'no_just_my_order',
                                      'No, just my order',
                                    ).toUpperCase(),
                                    onTap: () => setState(
                                        () => _choice = _ComboChoice.no),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: m.nextTopGap),
                            _NextBar(
                              metrics: m,
                              enabled: _choice != null,
                              onTap: _confirm,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _yesImage(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    return KioskProductImageHelper.resolveUrl(
      productImageBaseUrl:
          splash.baseUrls?.dealImageUrl ?? splash.baseUrls?.productImageUrl,
      filename: widget.match.deal.image,
    );
  }

  String _noImage(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final List<CartModel?> cart =
        Provider.of<CartProvider>(context, listen: false).cartList;
    if (widget.match.consume.isEmpty) return '';
    final int index = widget.match.consume.first.cartIndex;
    if (index < 0 || index >= cart.length) return '';
    final Product? product = cart[index]?.product;
    if (product == null) return '';
    return KioskProductImageHelper.heroImageUrl(
      product: product,
      productImageBaseUrl: splash.baseUrls?.productImageUrl,
    );
  }

  String _yesCaption(BuildContext context) {
    final String price = PriceConverterHelper.convertPrice(
        kioskLineTotal(widget.match.dealLine));
    final String saved =
        PriceConverterHelper.convertPrice(widget.match.saving);
    final String saveLabel =
        kioskTranslate(context, 'you_save', 'You save');
    return '$price · $saveLabel $saved';
  }
}

class _Header extends StatelessWidget {
  final double s;
  final double backSize;
  final double titleSize;
  const _Header({
    required this.s,
    required this.backSize,
    required this.titleSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KioskCircleBack(
          size: backSize,
          onTap: () => Navigator.of(context).pop(false),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: (12 * s).clamp(6.0, 12.0)),
            child: Text(
              kioskTranslate(
                context,
                'make_it_a_combo_meal',
                'Make it a Combo Meal?',
              ).toUpperCase(),
              textAlign: TextAlign.center,
              style: loewExtraBold.copyWith(
                fontSize: titleSize,
                height: 1.15,
                color: Colors.black,
              ),
            ),
          ),
        ),
        SizedBox(width: backSize),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final _ComboMetrics metrics;
  final bool selected;
  final String imageUrl;
  final String label;
  final String? caption;
  final VoidCallback onTap;

  const _OptionCard({
    super.key,
    required this.metrics,
    required this.selected,
    required this.imageUrl,
    required this.label,
    this.caption,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = (metrics.cardWidth * 0.06).clamp(12.0, 28.0);
    final double ring = (metrics.cardWidth * 0.062).clamp(16.0, 36.0);

    return Material(
      color: selected ? Colors.white : _kUnselectedFill,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: metrics.cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? Colors.black : _kCardBorder,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  metrics.cardInset,
                  metrics.cardInset,
                  metrics.cardInset,
                  metrics.cardInset * 0.8,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radius * 0.6),
                        child: CustomImageWidget(
                          placeholder: Images.placeholderImage,
                          image: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          useShimmer: true,
                          cacheWidth:
                              CustomImageWidget.kKioskProductCacheWidth,
                        ),
                      ),
                    ),
                    SizedBox(height: metrics.cardInset * 0.7),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: loewBold.copyWith(
                        fontSize: metrics.labelSize,
                        height: 1.1,
                        color: Colors.black,
                      ),
                    ),
                    if (caption != null) ...[
                      SizedBox(height: metrics.cardInset * 0.35),
                      Text(
                        caption!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewMedium.copyWith(
                          fontSize: (metrics.labelSize * 0.72).clamp(10.0, 22.0),
                          height: 1.0,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                Positioned(
                  top: metrics.cardWidth * 0.025,
                  right: metrics.cardWidth * 0.025,
                  child: Container(
                    width: ring,
                    height: ring,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.black,
                        width: (ring * 0.12).clamp(1.5, 3.0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: ring * 0.48,
                      height: ring * 0.48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextBar extends StatelessWidget {
  final _ComboMetrics metrics;
  final bool enabled;
  final VoidCallback onTap;

  const _NextBar({
    required this.metrics,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(metrics.nextRadius),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          key: const ValueKey('kiosk-combo-next'),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: double.infinity,
            height: metrics.nextHeight,
            child: Center(
              child: Text(
                kioskTranslate(context, 'next', 'Next').toUpperCase(),
                style: loewExtraBold.copyWith(
                  fontSize: metrics.nextLabelSize,
                  height: 1.0,
                  color: KioskUI.cream,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Geometry as ratios of the card width, measured off Figma 05a (W = 2078).
class _ComboMetrics {
  final double sheetWidth;
  final double pad;
  final double backSize;
  final double titleSize;
  final double cardWidth;
  final double cardHeight;
  final double gap;
  final double labelSize;
  final double optionTopGap;
  final double nextTopGap;
  final double nextHeight;
  final double nextLabelSize;
  final double nextRadius;
  final double cardInset;

  const _ComboMetrics({
    required this.sheetWidth,
    required this.pad,
    required this.backSize,
    required this.titleSize,
    required this.cardWidth,
    required this.cardHeight,
    required this.gap,
    required this.labelSize,
    required this.optionTopGap,
    required this.nextTopGap,
    required this.nextHeight,
    required this.nextLabelSize,
    required this.nextRadius,
    required this.cardInset,
  });

  static const double _designW = 2078;
  static const double _sheetRatio = 0.81;

  factory _ComboMetrics.forSize(double viewportWidth, double viewportHeight) {
    final bool landscape = viewportWidth > viewportHeight;
    final double usable = viewportWidth.clamp(240.0, double.infinity);
    final double sheetWidth = (usable * (landscape ? 0.72 : _sheetRatio))
        .clamp(300.0, landscape ? 1680.0 : 1600.0);
    final double pad = (sheetWidth * (64 / _designW)).clamp(12.0, 64.0);
    final double gap = (sheetWidth * (30.6 / _designW)).clamp(8.0, 32.0);
    final double inner = sheetWidth - pad * 2;
    final double cardWidth = (inner - gap) / 2;
    final double cardHeight =
        (cardWidth * (790 / 959.7)).clamp(160.0, 520.0);

    return _ComboMetrics(
      sheetWidth: sheetWidth,
      pad: pad,
      backSize: (sheetWidth * (141 / _designW)).clamp(36.0, 86.0),
      titleSize: (sheetWidth * (62 / _designW)).clamp(17.0, 52.0),
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      gap: gap,
      labelSize: (sheetWidth * (34 / _designW)).clamp(11.0, 28.0),
      optionTopGap: (sheetWidth * 0.04).clamp(12.0, 36.0),
      nextTopGap: (sheetWidth * 0.05).clamp(16.0, 48.0),
      nextHeight: (sheetWidth * (252 / _designW)).clamp(48.0, 96.0),
      nextLabelSize: (sheetWidth * (56 / _designW)).clamp(16.0, 42.0),
      nextRadius: (sheetWidth * (30 / _designW)).clamp(12.0, 30.0),
      cardInset: (cardWidth * 0.06).clamp(8.0, 20.0),
    );
  }
}
