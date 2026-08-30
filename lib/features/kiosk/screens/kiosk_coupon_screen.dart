import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_apply_result.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_coupon_applied_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Kiosk coupon entry — Figma POS node 1385:15500 ("07 – Coupon: Enter Code").
///
/// Brand mark, prompt, a large code field, the "SCAN YOUR CODE" panel and the
/// BACK / CONTINUE pair. Customers type with the device keyboard (tap the
/// field) or scan a barcode into the same field.
///
/// CONTINUE (and Enter, which is how a barcode scanner finishes a code) hands
/// the code to [CouponProvider.applyCouponDetailed]. A code that grants
/// something opens [KioskCouponAppliedScreen] — the confirmation beat that
/// shows the benefit — and the screen then closes back to the cart; a code that
/// does not is reported in place, saying *why*, so the customer can act on it.
///
/// ## Sizing
/// The artboard is 2572 x 4530 (a portrait kiosk). Rather than hard-coding
/// positions, the screen resolves one Figma-pixel scale [_KioskCouponMetrics.s]
/// from *both* axes and then re-distributes whatever height is left over into
/// the design's whitespace gaps only ([_KioskCouponMetrics.gapFactor]) — the
/// cards and buttons never stretch. A portrait kiosk therefore fills the
/// width exactly as drawn, while a short landscape display keeps every
/// component's proportion, tightens the whitespace, and centres the column.
class KioskCouponScreen extends StatefulWidget {
  /// Subtotal used for the coupon's min-purchase check. Falls back to the live
  /// cart when the screen is reached by URL without an amount.
  final double orderAmount;

  const KioskCouponScreen({super.key, this.orderAmount = 0});

  @override
  State<KioskCouponScreen> createState() => _KioskCouponScreenState();
}

class _KioskCouponScreenState extends State<KioskCouponScreen> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: kioskActiveCouponCode(
          Provider.of<CouponProvider>(context, listen: false)),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  double get _orderAmount => widget.orderAmount > 0
      ? widget.orderAmount
      : kioskOrderAmountBeforeCoupon(
          Provider.of<CartProvider>(context, listen: false).cartList,
        );

  // --- actions -------------------------------------------------------------

  void _close() => KioskNavigationHelper.popOrNavigate(
        context,
        fallback: RouterHelper.getKioskCartRoute,
      );

  /// The backend answers with `translate(...)` output, so a key the kiosk's own
  /// language files do not carry arrives as the raw identifier
  /// ("coupon_not_found"). Run it back through the kiosk lookup and prettify
  /// whatever is still snake_case, so the customer never reads an identifier.
  String _failureMessage(String? raw) {
    final String message = raw?.trim() ?? '';
    if (message.isEmpty) {
      return kioskTranslate(context, 'invalid_code_or', 'Invalid code');
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(message)) return message;

    final String prettified = message.replaceAll('_', ' ');
    return kioskTranslate(
      context,
      message,
      prettified[0].toUpperCase() + prettified.substring(1),
    );
  }

  /// CONTINUE. An empty field clears an applied coupon; otherwise the code is
  /// validated, and a code that grants something opens the confirmation beat
  /// ([KioskCouponAppliedScreen]) before the screen closes back to the cart.
  Future<void> _submit() async {
    final coupon = Provider.of<CouponProvider>(context, listen: false);
    if (coupon.isLoading) return;

    final String code = _controller.text.trim();
    final bool hadCoupon = (coupon.discount ?? 0) > 0;
    coupon.removeCouponData(true);

    if (code.isEmpty) {
      if (hadCoupon) {
        showCustomSnackBarHelper(
          kioskTranslate(context, 'coupon_removed_successfully', 'Coupon removed'),
          isError: false,
        );
        _close();
      } else {
        showCustomSnackBarHelper(
          kioskTranslate(context, 'enter_a_Coupon_code', 'Enter a coupon code'),
        );
      }
      return;
    }

    final double amount = _orderAmount;
    final CouponApplyResult result =
        await coupon.applyCouponDetailed(code, amount);
    if (!mounted) return;

    if (result.status == CouponApplyStatus.applied) {
      // What the customer just earned, in their own terms — a rate, a sum, or
      // the free item the coupon names.
      final KioskCouponReward reward = KioskCouponReward.resolve(
        coupon: result.coupon,
        discount: result.discount,
        orderAmount: amount,
        formatPrice: (value) => PriceConverterHelper.convertPrice(value),
        translate: (key, fallback) => kioskTranslate(context, key, fallback),
      );
      // The confirmation beat pops itself after its hold (or on a tap), and
      // this screen then closes back to the cart exactly as it always did.
      await Navigator.of(context).push(KioskCouponAppliedScreen.route(reward));
      if (!mounted) return;
      _close();
      return;
    }

    if (result.status == CouponApplyStatus.belowMinPurchase) {
      // The code is real; the basket is just too small. Saying "invalid" here
      // sent customers off to find another code that would fail the same way.
      showCustomSnackBarHelper(
        '${kioskTranslate(context, 'minimum_purchase_amount_is', 'Minimum purchase amount is')} '
        '${PriceConverterHelper.convertPrice(result.minPurchase)}',
      );
      return;
    }

    showCustomSnackBarHelper(_failureMessage(result.errorMessage), isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop() ||
          (GoRouter.maybeOf(context)?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: _kPageBg,
        // Keep the column above the system keyboard when the field is focused.
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final m = _KioskCouponMetrics.resolve(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              final Widget column = Column(
                children: [
                  SizedBox(height: m.gap(_kTopGap)),
                  _Logo(m: m, onBack: _close),
                  SizedBox(height: m.gap(_kLogoToTitle)),
                  _Title(m: m),
                  SizedBox(height: m.gap(_kTitleToField)),
                  _CodeField(
                    m: m,
                    controller: _controller,
                    focusNode: _focusNode,
                    onSubmit: _submit,
                  ),
                  SizedBox(height: m.gap(_kFieldToScan)),
                  _ScanPanel(m: m),
                  SizedBox(height: m.gap(_kScanToButtons)),
                  _ActionBar(m: m, onBack: _close, onContinue: _submit),
                  SizedBox(height: m.gap(_kBottomGap)),
                ],
              );

              final Widget content = SizedBox(
                width: m.contentWidth,
                height: m.contentHeight,
                child: column,
              );

              // Only reachable once the scale has bottomed out on a very small
              // viewport; everywhere else the column is sized to fit exactly.
              if (m.contentHeight > constraints.maxHeight) {
                return SingleChildScrollView(
                  child: Center(child: content),
                );
              }
              return Center(child: content);
            },
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Figma metrics — every number below is a raw pixel from the 2572 x 4530
// artboard (node 1385:15500).
// ===========================================================================

const double _kDesignWidth = 2572;

const Color _kPageBg = KioskUI.pageBg; // #F7F1DE
const Color _kInk = Color(0xFF231F20);
const Color _kFieldBg = Color(0xFFFBF8EF);
const Color _kFieldBorder = Color(0xFFDED9C7);
const Color _kPanelBg = Color(0xFFFBF8EF);
const Color _kButtonLabel = Color(0xFFFAF9F5);

const int _kMaxCodeLength = 24;

// Vertical rhythm: whitespace gaps (flexible) and element heights (fixed).
// Field→scan was field→keyboard (270) + keyboard→scan (190) in the artboard.
const double _kTopGap = 136;
const double _kLogoToTitle = 618.5;
const double _kTitleToField = 105;
const double _kFieldToScan = 460;
const double _kScanToButtons = 517;
const double _kBottomGap = 124;

const double _kLogoWidth = 680.783;
const double _kLogoHeight = 178.475;
/// Same circular back control as [KioskHeaderBar] (cart / manager screens).
const double _kHeaderBackInset = 132;
const double _kHeaderBackSize = 100;
const double _kHeaderBackBorder = 4;
const double _kHeaderBackIcon = 50;
const double _kTitleFont = 120;
const double _kTitleWidth = 1800;

// The artboard nudges the field and the scan panel ~26px off centre; these are
// the measured Figma insets rather than a symmetric approximation.
const double _kFieldInsetLeft = 330;
const double _kFieldInsetRight = 356;
const double _kFieldHeight = 295;
const double _kFieldRadius = 28;
const double _kFieldBorderWidth = 6;
const double _kFieldPadH = 64;
const double _kFieldFont = 180;

const double _kPanelInsetLeft = 62;
const double _kPanelInsetRight = 88;
const double _kPanelHeight = 560;
const double _kPanelRadius = 40;
const double _kPanelBorderWidth = 9;
// Insets are measured from the card's outer edge in Figma; a Flutter
// `Container` lays its padding out *inside* the border, so the stroke is
// subtracted here — otherwise the copy and the QR drift inward by the border.
const double _kPanelPadLeft = 101 - _kPanelBorderWidth;
const double _kPanelPadRight = 207 - _kPanelBorderWidth;

/// Gap between the copy column and the QR: the Figma text box is 1411 wide and
/// the QR starts at x=1877, which leaves exactly this much between them.
const double _kPanelTextGap = 303;
const double _kPanelTitleFont = 128;
const double _kPanelSubtitleFont = 64;
const double _kPanelTitleGap = 21;
const double _kQrSize = 400;

const double _kButtonInset = 74;
const double _kButtonHeight = 252;
const double _kButtonRadius = 30;
const double _kButtonBorderWidth = 8;
const double _kButtonGap = 22;
const double _kButtonFont = 72;
const double _kButtonPadH = 64;

/// Sum of the flexible gaps and of the fixed element heights, at scale 1.
const double _kGapTotal = _kTopGap +
    _kLogoToTitle +
    _kTitleToField +
    _kFieldToScan +
    _kScanToButtons +
    _kBottomGap; // 1960.5

const double _kFixedTotal = _kLogoHeight +
    _kTitleFont +
    _kFieldHeight +
    _kPanelHeight +
    _kButtonHeight; // 1405.475

/// How far the design's whitespace may be squeezed / stretched before the
/// scale itself has to give way.
const double _kMinGapFactor = 0.5;
const double _kMaxGapFactor = 2.2;

/// Resolved sizing for one viewport.
class _KioskCouponMetrics {
  /// Figma pixel → logical pixel.
  final double s;

  /// Multiplier applied to the design's vertical whitespace only.
  final double gapFactor;

  final double contentWidth;
  final double contentHeight;

  const _KioskCouponMetrics._({
    required this.s,
    required this.gapFactor,
    required this.contentWidth,
    required this.contentHeight,
  });

  factory _KioskCouponMetrics.resolve(double width, double height) {
    // The shortest height the design can occupy is its fixed elements plus
    // half its whitespace; sizing against that (rather than the full 4530)
    // lets short displays keep usable field/button sizes.
    final double minDesignHeight =
        _kFixedTotal + _kGapTotal * _kMinGapFactor; // 2385.725

    final double s = math
        .min(width / _kDesignWidth, height / minDesignHeight)
        .clamp(0.16, 1.0);

    final double fixed = _kFixedTotal * s;
    final double gapFactor = _kGapTotal * s <= 0
        ? 1.0
        : ((height - fixed) / (_kGapTotal * s))
            .clamp(_kMinGapFactor, _kMaxGapFactor);

    return _KioskCouponMetrics._(
      s: s,
      gapFactor: gapFactor,
      contentWidth: _kDesignWidth * s,
      contentHeight: fixed + _kGapTotal * s * gapFactor,
    );
  }

  /// A designed whitespace gap, in logical pixels.
  double gap(double designGap) => designGap * s * gapFactor;

  /// A designed element measurement, in logical pixels.
  double px(double design) => design * s;

  /// Hairline-safe stroke width for a designed border.
  double stroke(double design) => (design * s).clamp(1.0, design);
}

// ===========================================================================
// Sections
// ===========================================================================

class _Logo extends StatelessWidget {
  final _KioskCouponMetrics m;
  final VoidCallback onBack;
  const _Logo({required this.m, required this.onBack});

  @override
  Widget build(BuildContext context) {
    // Wordmark stays centred; the circular back control sits on the left of
    // the same row, matching [KioskHeaderBar] on cart / manager screens.
    return SizedBox(
      width: double.infinity,
      height: math.max(m.px(_kLogoHeight), m.px(_kHeaderBackSize)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The kiosk ships the wordmark as white artwork; every light kiosk
          // screen tints it with the page ink (see kiosk_welcome_screen).
          SvgPicture.asset(
            Images.kioskLogoWhiteSvg,
            width: m.px(_kLogoWidth),
            height: m.px(_kLogoHeight),
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(_kInk, BlendMode.srcIn),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: m.px(_kHeaderBackInset)),
              child: KioskBackButton.scaled(
                s: m.s,
                size: _kHeaderBackSize,
                border: _kHeaderBackBorder,
                icon: _kHeaderBackIcon,
                minBorder: 1,
                onTap: onBack,
                fallback: RouterHelper.getKioskCartRoute,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final _KioskCouponMetrics m;
  const _Title({required this.m});

  @override
  Widget build(BuildContext context) {
    // The Figma text box is 1800 wide and centred; constraining to it lets a
    // longer translation shrink to fit instead of running off the artboard.
    return SizedBox(
      width: m.px(_kTitleWidth),
      height: m.px(_kTitleFont),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          kioskTranslate(context, 'enter_your_code', 'Enter your code'),
          textAlign: TextAlign.center,
          maxLines: 1,
          style: loewExtraBold.copyWith(
            fontSize: m.px(_kTitleFont),
            height: 1.0,
            color: _kInk,
          ),
        ),
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  final _KioskCouponMetrics m;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// Same action as CONTINUE. The "SCAN YOUR CODE" panel means a barcode
  /// scanner types the code in and finishes with Enter, so the field has to
  /// submit on its own — otherwise a scanned coupon just sat there.
  final Future<void> Function() onSubmit;

  const _CodeField({
    required this.m,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: m.px(_kFieldHeight),
      margin: EdgeInsets.only(
        left: m.px(_kFieldInsetLeft),
        right: m.px(_kFieldInsetRight),
      ),
      padding: EdgeInsets.symmetric(horizontal: m.px(_kFieldPadH)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kFieldBg,
        borderRadius: BorderRadius.circular(m.px(_kFieldRadius)),
        border: Border.all(
          color: _kFieldBorder,
          width: m.stroke(_kFieldBorderWidth),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        readOnly: false,
        showCursor: true,
        keyboardType: TextInputType.visiblePassword,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        maxLines: 1,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmit(),
        // Keep the caret where the customer left it when focus returns (scanner
        // append / system keyboard). Default web/desktop select-all would
        // replace the whole code on the next key.
        selectAllOnFocus: false,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        cursorColor: _kInk,
        cursorWidth: m.stroke(6),
        inputFormatters: [
          LengthLimitingTextInputFormatter(_kMaxCodeLength),
        ],
        style: loewMedium.copyWith(
          fontSize: m.px(_kFieldFont),
          height: 1.0,
          color: _kInk,
        ),
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _ScanPanel extends StatelessWidget {
  final _KioskCouponMetrics m;
  const _ScanPanel({required this.m});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: m.px(_kPanelHeight),
      margin: EdgeInsets.only(
        left: m.px(_kPanelInsetLeft),
        right: m.px(_kPanelInsetRight),
      ),
      padding: EdgeInsets.only(
        left: m.px(_kPanelPadLeft),
        right: m.px(_kPanelPadRight),
      ),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(m.px(_kPanelRadius)),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.25),
          width: m.stroke(_kPanelBorderWidth),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    kioskTranslate(context, 'scan_your_code', 'Scan your code')
                        .toUpperCase(),
                    maxLines: 1,
                    style: loewExtraBold.copyWith(
                      fontSize: m.px(_kPanelTitleFont),
                      height: 1.0,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(height: m.px(_kPanelTitleGap)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    kioskTranslate(context, 'use_the_scanner_below_you',
                        'Use the scanner below you'),
                    maxLines: 1,
                    style: swiss721Light.copyWith(
                      fontSize: m.px(_kPanelSubtitleFont),
                      height: 1.0,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: m.px(_kPanelTextGap)),
          SvgPicture.asset(
            Images.kioskCouponQrSvg,
            width: m.px(_kQrSize),
            height: m.px(_kQrSize),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final _KioskCouponMetrics m;
  final VoidCallback onBack;
  final Future<void> Function() onContinue;

  const _ActionBar({
    required this.m,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: m.px(_kButtonInset)),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              m: m,
              label: kioskTranslate(context, 'back', 'Back').toUpperCase(),
              filled: false,
              onTap: onBack,
            ),
          ),
          SizedBox(width: m.px(_kButtonGap)),
          Expanded(
            child: Consumer<CouponProvider>(
              builder: (context, coupon, _) => _ActionButton(
                m: m,
                label: kioskTranslate(context, 'continue', 'Continue').toUpperCase(),
                filled: true,
                loading: coupon.isLoading,
                onTap: coupon.isLoading ? null : onContinue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final _KioskCouponMetrics m;
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.m,
    required this.label,
    required this.filled,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = m.px(_kButtonRadius);

    return Opacity(
      opacity: onTap == null && !loading ? 0.5 : 1,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          height: m.px(_kButtonHeight),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: filled
                ? null
                : Border.all(
                    color: Colors.black,
                    width: m.stroke(_kButtonBorderWidth),
                  ),
          ),
          child: loading
              ? SizedBox(
                  width: m.px(_kButtonFont),
                  height: m.px(_kButtonFont),
                  child: CircularProgressIndicator(
                    strokeWidth: m.stroke(8),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      filled ? _kButtonLabel : Colors.black,
                    ),
                  ),
                )
              : Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: m.px(_kButtonPadH)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: (filled ? loewExtraBold : loewBold).copyWith(
                        fontSize: m.px(_kButtonFont),
                        height: 1.0,
                        color: filled ? _kButtonLabel : Colors.black,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
