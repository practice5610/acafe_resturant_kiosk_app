import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_keyboard.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Kiosk coupon entry — Figma POS node 1385:15500 ("07 – Coupon: Enter Code").
///
/// Replaces the old bottom-sheet coupon picker with the designed full screen:
/// brand mark, prompt, a large code field, the on-screen keyboard, the
/// "SCAN YOUR CODE" panel and the BACK / CONTINUE pair. The business logic is
/// unchanged — it still drives [CouponProvider.applyCoupon] /
/// [CouponProvider.removeCouponData] and reports through the shared snackbar.
///
/// ## Sizing
/// The artboard is 2572 x 4530 (a portrait kiosk). Rather than hard-coding
/// positions, the screen resolves one Figma-pixel scale [_KioskCouponMetrics.s]
/// from *both* axes and then re-distributes whatever height is left over into
/// the design's whitespace gaps only ([_KioskCouponMetrics.gapFactor]) — the
/// cards, keys and buttons never stretch. A portrait kiosk therefore fills the
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

  /// Coupon codes are upper case (the Figma field reads "A81739266"), so the
  /// board starts shifted; the key caps mirror this the way a soft keyboard
  /// does, and Shift releases it for the rare mixed-case code.
  bool _shift = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: Provider.of<CouponProvider>(context, listen: false).coupon?.code ??
          '',
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

  // --- text editing --------------------------------------------------------
  // The field stays editable so the kiosk's web build also accepts a physical
  // keyboard; every on-screen key edits at the live selection so both input
  // paths share one controller (same contract as the order-note keyboard).

  TextSelection get _selection {
    final TextEditingValue value = _controller.value;
    return value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
  }

  void _write(String text, int caret) {
    _controller.value = _controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
  }

  void _insert(String value) {
    final TextSelection sel = _selection;
    final String text = _controller.text.replaceRange(sel.start, sel.end, value);
    if (text.length > _kMaxCodeLength) return;
    _write(text, sel.start + value.length);
  }

  void _backspace() {
    final TextSelection sel = _selection;
    final String current = _controller.text;
    if (sel.start != sel.end) {
      _write(current.replaceRange(sel.start, sel.end, ''), sel.start);
      return;
    }
    if (sel.start == 0) return;
    _write(current.replaceRange(sel.start - 1, sel.start, ''), sel.start - 1);
  }

  void _clear() {
    if (_controller.text.isEmpty) return;
    _write('', 0);
  }

  // --- actions -------------------------------------------------------------

  void _close() => KioskNavigationHelper.popOrNavigate(
        context,
        fallback: RouterHelper.getKioskCartRoute,
      );

  /// CONTINUE. An empty field clears an applied coupon (the Clear key + CONTINUE
  /// is the redesign's "remove"); otherwise the code is applied exactly as the
  /// old sheet did.
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

    final double? discount = await coupon.applyCoupon(code, _orderAmount);
    if (!mounted) return;

    if ((discount ?? 0) > 0) {
      showCustomSnackBarHelper(
        '${kioskTranslate(context, 'you_got', 'You got')} '
        '${PriceConverterHelper.convertPrice(discount)} '
        '${kioskTranslate(context, 'discount', 'discount')}',
        isError: false,
      );
      _close();
    } else {
      showCustomSnackBarHelper(
        kioskTranslate(context, 'invalid_code_or', 'Invalid code'),
        isError: true,
      );
    }
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
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final m = _KioskCouponMetrics.resolve(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              final Widget content = SizedBox(
                width: m.contentWidth,
                height: m.contentHeight,
                child: Column(
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
                    ),
                    SizedBox(height: m.gap(_kFieldToKeyboard)),
                    KioskKeyboard(
                      s: m.s,
                      shift: _shift,
                      onKey: _insert,
                      onShift: () => setState(() => _shift = !_shift),
                      onBackspace: _backspace,
                      onSpace: () => _insert(' '),
                      onClear: _clear,
                    ),
                    SizedBox(height: m.gap(_kKeyboardToScan)),
                    _ScanPanel(m: m),
                    SizedBox(height: m.gap(_kScanToButtons)),
                    _ActionBar(m: m, onBack: _close, onContinue: _submit),
                    SizedBox(height: m.gap(_kBottomGap)),
                  ],
                ),
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
const double _kTopGap = 136;
const double _kLogoToTitle = 618.5;
const double _kTitleToField = 105;
const double _kFieldToKeyboard = 270;
const double _kKeyboardToScan = 190;
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
    _kFieldToKeyboard +
    _kKeyboardToScan +
    _kScanToButtons +
    _kBottomGap; // 1960.5

const double _kFixedTotal = _kLogoHeight +
    _kTitleFont +
    _kFieldHeight +
    KioskKeyboard.designHeight +
    _kPanelHeight +
    _kButtonHeight; // 2569.475

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
    // lets landscape displays keep usable key/button sizes.
    const double minDesignHeight =
        _kFixedTotal + _kGapTotal * _kMinGapFactor; // 3549.725

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

  const _CodeField({
    required this.m,
    required this.controller,
    required this.focusNode,
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
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        maxLines: 1,
        textCapitalization: TextCapitalization.characters,
        // A tap on the kiosk's own keyboard is a tap "outside" this field. Left
        // to the framework that blurs it, and re-focusing then selects the whole
        // value (`selectAllOnFocus` defaults to true on web and desktop) — so
        // the next key replaced the code instead of appending. Hold the focus,
        // and keep the caret even if focus is regained some other way.
        onTapOutside: (_) {},
        selectAllOnFocus: false,
        autocorrect: false,
        enableSuggestions: false,
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
