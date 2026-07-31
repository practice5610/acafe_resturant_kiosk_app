import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Fixed design tokens for the kiosk's *wide* (>= 1100px) layouts.
///
/// Unlike the narrow screens — which scale every value by `s = width/2572` —
/// these are HARD pixel values that never grow with the screen. Large displays
/// fit more content per row; they do not enlarge type or controls. This is the
/// deliberate fix for the "everything gets huge on big screens" problem.
class KioskUI {
  KioskUI._();

  // Palette (identical to the existing kiosk screens — colours are unchanged).
  /// Single global kiosk background — use this everywhere instead of a
  /// local/duplicate constant.
  static const Color pageBg = Color(0xFFF7F1DE);
  static const Color card = Colors.white;
  static const Color dark = Color(0xFF1E1E1E);
  static const Color cream = Color(0xFFF3F3DD);
  static const Color popularGreen = Color(0xFF357937);
  static const Color text = Color(0xFF2B2B2B);
  static const Color categorySelectedBg = Colors.black;

  // Fixed type scale (never scales with width).
  static const double pageTitle = 32;
  static const double heading = 28;
  static const double section = 20;
  static const double body = 16;
  static const double caption = 14;

  // Control sizing caps.
  static const double primaryButtonHeight = 60;
  static const double secondaryButtonHeight = 56;
  static const double buttonMaxWidth = 720;
  static const double categoryTileHeight = 96;
  static const double productCardMaxWidth = 300;
  static const double headerHeight = 72;
  static const double cartBarHeight = 88;
  static const double radius = 18;
  static const double checkoutColumnMaxWidth = 720;
  static const double filterSheetMaxWidth = 640;
  static const double qtyButtonSize = 48;
  static const double checkoutStepCircle = 48;

  /// Product grid columns per breakpoint (wide layouts only).
  static int productGridColumns(BuildContext context) => Responsive.value(
        context,
        phone: 2,
        tablet: 3,
        desktop: 3,
        large: 4,
      );
}

/// Fixed −/qty/+ stepper used on cart, product detail, and wide layouts.
class KioskQtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double buttonSize;

  const KioskQtyStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.buttonSize = KioskUI.qtyButtonSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QtyButton(
          label: '−',
          filled: false,
          size: buttonSize,
          onTap: onDecrement,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$quantity',
            style: loewExtraBold.copyWith(
              fontSize: KioskUI.section,
              color: Colors.black,
            ),
          ),
        ),
        _QtyButton(
          label: '+',
          filled: true,
          size: buttonSize,
          onTap: onIncrement,
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final String label;
  final bool filled;
  final double size;
  final VoidCallback onTap;

  const _QtyButton({
    required this.label,
    required this.filled,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? KioskUI.dark : Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: Colors.black, width: 2),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: KioskUI.section,
              color: filled ? KioskUI.cream : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

/// NAME → EMAIL → PAYMENT stepper capped at 720px with fixed circle/label sizes.
class KioskCheckoutStepper extends StatelessWidget {
  final int activeStep;
  static const List<String> steps = ['NAME', 'EMAIL', 'PAYMENT'];

  const KioskCheckoutStepper({super.key, required this.activeStep});

  @override
  Widget build(BuildContext context) {
    final List<Widget> row = [];
    for (int i = 0; i < steps.length; i++) {
      row.add(_StepNode(
        label: steps[i],
        state: i < activeStep
            ? _StepState.completed
            : i == activeStep
                ? _StepState.active
                : _StepState.upcoming,
      ));
      if (i < steps.length - 1) {
        row.add(const Expanded(child: _Connector()));
      }
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: KioskUI.checkoutColumnMaxWidth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: row,
      ),
    );
  }
}

enum _StepState { completed, active, upcoming }

class _StepNode extends StatelessWidget {
  final String label;
  final _StepState state;
  const _StepNode({required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: KioskUI.checkoutStepCircle,
          height: KioskUI.checkoutStepCircle,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state != _StepState.upcoming ? KioskUI.dark : Colors.transparent,
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: switch (state) {
            _StepState.active => Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: KioskUI.pageBg,
                ),
              ),
            _StepState.completed =>
              const Icon(Icons.check, size: 24, color: Colors.white),
            _StepState.upcoming => null,
          },
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: loewExtraBold.copyWith(
            fontSize: KioskUI.caption,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 23, left: 8, right: 8),
      child: Container(height: 2, color: Colors.black),
    );
  }
}

/// Primary / secondary action button with a HARD height + width cap. Used by
/// every wide screen so button sizing is fixed once here.
class KioskButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final double height;
  final double? maxWidth;
  final int? badgeCount;

  const KioskButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.height = KioskUI.primaryButtonHeight,
    this.maxWidth = KioskUI.buttonMaxWidth,
    this.badgeCount,
  });

  const KioskButton.secondary({
    super.key,
    required this.label,
    required this.onTap,
    this.maxWidth = KioskUI.buttonMaxWidth,
    this.badgeCount,
  })  : filled = false,
        height = KioskUI.secondaryButtonHeight;

  @override
  Widget build(BuildContext context) {
    final Color bg = filled ? KioskUI.dark : Colors.white;
    final Color fg = filled ? KioskUI.cream : KioskUI.text;

    Widget button = Material(
      color: bg,
      borderRadius: BorderRadius.circular(KioskUI.radius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(KioskUI.radius),
                  border: Border.all(color: KioskUI.text, width: 2),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewExtraBold.copyWith(
                      fontSize: KioskUI.body, color: fg, letterSpacing: 0.5),
                ),
              ),
              if (badgeCount != null) ...[
                const SizedBox(width: 12),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filled ? Colors.white24 : KioskUI.dark,
                    shape: BoxShape.circle,
                  ),
                  child: Text('$badgeCount',
                      style: loewExtraBold.copyWith(
                          fontSize: KioskUI.caption,
                          color: filled ? fg : KioskUI.cream)),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (maxWidth != null) {
      button = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: SizedBox(width: double.infinity, child: button),
      );
    }
    return button;
  }
}

/// Circular icon tap target for wide headers — fixed 44px.
class KioskCircleIcon extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final double size;
  const KioskCircleIcon(
      {super.key, required this.child, required this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: KioskTap(onTap: onTap, child: Center(child: child)),
    );
  }
}

/// Category rail tile with a FIXED 96px height (never stretches vertically).
/// Plain text on the page background with a divider below; selected fills
/// with yellow and flips the text to white (per the Figma text-list style —
/// no image, no card background).
class KioskCategoryTile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const KioskCategoryTile({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? KioskUI.categorySelectedBg : Colors.transparent,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          height: KioskUI.categoryTileHeight,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                        fontSize: KioskUI.caption,
                        height: 1.1,
                        color: selected ? Colors.white : Colors.black),
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

/// Product card with a SQUARE image (AspectRatio 1.0) — the key fix for the
/// "giant portrait rectangle" problem — and fixed name/price type. Max width is
/// capped by the grid (300px); on wider screens the grid adds columns/gap
/// rather than growing the card. Shared by the menu and search-results grids.
class KioskProductCard extends StatelessWidget {
  final Product product;
  final String? badgeLabel;
  final Color? badgeColor;
  const KioskProductCard({
    super.key,
    required this.product,
    this.badgeLabel,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String image = '${splash.baseUrls?.productImageUrl}/${product.image}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: () => openKioskCustomize(context, product),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CustomImageWidget(
                    placeholder: Images.placeholderImage,
                    image: image,
                    fit: BoxFit.cover,
                    useShimmer: true,
                    cacheWidth: CustomImageWidget.kKioskProductCacheWidth,
                  ),
                ),
                if (badgeLabel != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor ?? KioskUI.popularGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeLabel!,
                        style: loewBold.copyWith(
                            fontSize: KioskUI.caption, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                        fontSize: KioskUI.body, height: 1.15, color: Colors.black),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    PriceConverterHelper.convertPrice(product.price),
                    style: loewExtraBold.copyWith(
                        fontSize: KioskUI.body, color: KioskUI.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Black-outlined circular back control — kiosk standard (see language screen).
///
/// Always routes through [KioskNavigationHelper.popOrNavigate] so back never
/// silently fails when `canPop` is false (e.g. direct URL to cart). Pass
/// [fallback] for screen-specific targets (cart → menu, checkout → cart, …).
class KioskBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? fallback;
  final double size;
  final double borderWidth;
  final double iconSize;

  const KioskBackButton({
    super.key,
    this.onTap,
    this.fallback,
    this.size = 52,
    this.borderWidth = 2,
    this.iconSize = 22,
  });

  /// Scaled variant for narrow kiosk layouts (`s` = width / design width).
  factory KioskBackButton.scaled({
    Key? key,
    VoidCallback? onTap,
    VoidCallback? fallback,
    required double s,
    double size = 52,
    double border = 2,
    double icon = 22,
    double minBorder = 1.5,
    double maxBorder = 6.0,
  }) {
    return KioskBackButton(
      key: key,
      onTap: onTap,
      fallback: fallback,
      size: size * s,
      borderWidth: (border * s).clamp(minBorder, maxBorder),
      iconSize: icon * s,
    );
  }

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    KioskNavigationHelper.popOrNavigate(context, fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    return KioskTap(
      onTap: () => _handleTap(context),
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(color: Colors.black, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.arrow_back_ios_new,
            size: iconSize,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

/// Shared narrow-layout kiosk header: back button (left) + centered brand
/// title, underlined by a divider. Top and bottom padding are always equal
/// (both driven by [verticalPadding]) so callers never have to re-balance
/// spacing against their own content padding — see cart/menu/login screens.
class KioskHeaderBar extends StatelessWidget {
  final double s;
  final String title;
  final VoidCallback? onBack;
  final VoidCallback? fallback;
  final double verticalPadding;
  final double horizontalPadding;
  final double rowHeight;
  final double titleFontSize;
  final double backSize;
  final double backBorder;
  final double backIconSize;
  /// Optional right-aligned content (e.g. summary chips) rendered in the same
  /// row as the back button and title, so screens don't need a second row
  /// of chrome competing with the page content below.
  final Widget? trailing;

  const KioskHeaderBar({
    super.key,
    required this.s,
    this.title = 'A/CAFÉ',
    this.onBack,
    this.fallback,
    this.verticalPadding = 60,
    this.horizontalPadding = 132,
    this.rowHeight = 141,
    this.titleFontSize = 120,
    this.backSize = 100,
    this.backBorder = 4,
    this.backIconSize = 50,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding * s,
        vertical: verticalPadding * s,
      ),
      child: Column(
        children: [
          SizedBox(
            height: rowHeight * s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IgnorePointer(
                  child: Text(title,
                      style: loewExtraBold.copyWith(
                          fontSize: titleFontSize * s,
                          letterSpacing: 2 * s,
                          color: Colors.black)),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: KioskBackButton.scaled(
                    s: s,
                    size: backSize,
                    border: backBorder,
                    icon: backIconSize,
                    minBorder: 1,
                    onTap: onBack,
                    fallback: fallback,
                  ),
                ),
                if (trailing != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
              ],
            ),
          ),
          // Same gap as the padding above the row, so the divider sits
          // exactly as far below the logo as the logo sits below the top.
          SizedBox(height: verticalPadding * s),
          Container(height: (2 * s).clamp(1.0, 2.0), color: Colors.black),
        ],
      ),
    );
  }
}

/// Premium pill toggle for availability rows (stock screen, etc).
///
/// Flutter's stock `Switch` is a fixed Material size that never scales with
/// `s` -- on kiosk layouts, where every surrounding font/image is scaled down
/// by `s`, that fixed size reads as oversized next to everything else. This
/// widget is built from scratch so its track/thumb scale exactly like the
/// rest of the screen.
class KioskSwitch extends StatelessWidget {
  final bool value;
  final double s;
  final ValueChanged<bool>? onChanged;

  const KioskSwitch({
    super.key,
    required this.value,
    required this.s,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final double width = 68 * s;
    final double height = 38 * s;
    final double thumbSize = height - 6 * s;

    return KioskTap(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: EdgeInsets.all(3 * s),
        decoration: BoxDecoration(
          color: value ? BrandColors.secondary : const Color(0xFFE3DFD3),
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: thumbSize,
            height: thumbSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 3 * s,
                  offset: Offset(0, 1 * s),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular flag button for the active kiosk locale (matches menu top bar).
class KioskLanguageFlagButton extends StatelessWidget {
  final double size;
  final double borderWidth;

  const KioskLanguageFlagButton({
    super.key,
    this.size = 44,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final String code =
        Provider.of<LocalizationProvider>(context).locale.languageCode;
    final language = AppConstants.languages.firstWhere(
      (l) => l.languageCode == code,
      orElse: () => AppConstants.languages.first,
    );

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(
          side: BorderSide(color: Colors.black, width: borderWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: () => RouterHelper.getLanguageRoute(true),
          child: Image.asset(
            language.imageUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
