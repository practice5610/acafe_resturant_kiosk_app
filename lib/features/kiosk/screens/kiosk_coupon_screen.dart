import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/domain/models/coupon_apply_result.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_chrome_spec.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart'
    show kCheckoutErrorRed, KioskActionBar, KioskBarAction;
import 'package:acafe_customer/features/kiosk/screens/kiosk_coupon_applied_screen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_keyboard.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Kiosk coupon entry — Figma 2305:16029 ("07 Coupon: enter code").
///
/// Brand mark, prompt, a large code field, an always-visible on-screen
/// [KioskKeyboard], the "SCAN YOUR CODE" panel, and the BACK / CONTINUE pair.
/// The field uses `keyboardType: TextInputType.none` rather than `readOnly`,
/// so it stays genuinely editable: every visible key comes from the on-screen
/// board, the platform's own soft keyboard never opens, and a barcode
/// scanner — a hardware keyboard — can still type into the same field.
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

  /// Set when the backend rejects the code (unknown, expired, limit reached)
  /// — rendered inline under the field (red border + message), matching the
  /// kiosk's other form screens (`_LoginField`, `kiosk_checkout_widgets.dart`)
  /// rather than the transient snackbar a "wrong code" used to get.
  String? _errorText;

  /// Caps-lock state for the on-screen [KioskKeyboard] — Figma 2305:16029.
  bool _shift = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: kioskActiveCouponCode(
          Provider.of<CouponProvider>(context, listen: false)),
    );
  }

  /// Clears a stale error the moment the customer starts correcting the code
  /// — otherwise a red field would sit there through their next attempt.
  void _onCodeChanged(String _) {
    if (_errorText != null) setState(() => _errorText = null);
  }

  // --- on-screen keyboard editing -------------------------------------------
  //
  // The field keeps `keyboardType: TextInputType.none` (not `readOnly`) so it
  // stays genuinely editable — a barcode scanner is a hardware keyboard that
  // types into this same field and finishes with Enter (see class doc) — only
  // the platform's on-screen keyboard is suppressed. Every on-screen key below
  // edits [_controller] directly, same as the order-note sheet.

  TextSelection get _codeSelection {
    final TextSelection sel = _controller.selection;
    if (!sel.isValid) {
      return TextSelection.collapsed(offset: _controller.text.length);
    }
    return sel;
  }

  void _insertFromKeyboard(String text) {
    final TextSelection sel = _codeSelection;
    final String next = _controller.text.replaceRange(sel.start, sel.end, text);
    if (next.length > _kMaxCodeLength) return;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
    _onCodeChanged(next);
  }

  void _backspaceFromKeyboard() {
    final TextSelection sel = _codeSelection;
    if (sel.start != sel.end) {
      final String next = _controller.text.replaceRange(sel.start, sel.end, '');
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      _onCodeChanged(next);
      return;
    }
    if (sel.start <= 0) return;
    final String next =
        _controller.text.replaceRange(sel.start - 1, sel.start, '');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start - 1),
    );
    _onCodeChanged(next);
  }

  void _clearFromKeyboard() {
    _controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _onCodeChanged('');
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

  void _close() =>
      KioskNavigationHelper.backTo(context, RouterHelper.kioskCartScreen);

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
    if (_errorText != null) setState(() => _errorText = null);

    if (code.isEmpty) {
      if (hadCoupon) {
        showCustomSnackBarHelper(
          kioskTranslate(
              context, 'coupon_removed_successfully', 'Coupon removed'),
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

    // Shown inline under the field (red border + message), not a snackbar —
    // this is "your code is wrong," which the customer needs to keep looking
    // at while they re-read/retype it, not a toast that vanishes in a beat.
    setState(() => _errorText = _failureMessage(result.errorMessage));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
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
              // CHROME (header row and action bar) follows the shared chrome
              // scale. Only the keyboard / field / scan block below is sized by
              // this screen, from whatever height the chrome leaves it.
              final double cs = KioskChrome.scaleOf(context);
              // Header and bar sit in the same column as the checkout screens,
              // so the chrome insets are identical on a landscape window too.
              final double band =
                  math.min(constraints.maxWidth, kKioskContentMaxWidth);
              final double column = constraints.maxWidth > constraints.maxHeight
                  ? kioskReadingColumnWidth(width: band, landscape: true)
                  : band;
              final double headerHeight = _headerHeight(context, cs);
              final double barHeight = KioskChromeSpec.barBlock * cs;
              final double regionHeight =
                  constraints.maxHeight - headerHeight - barHeight;
              final bool hasInlineError = _errorText != null;

              return Column(
                children: [
                  KioskCenteredContent(
                    maxWidth: column,
                    child: _Header(cs: cs, onBack: _close),
                  ),
                  // The flexible region: it is handed exactly the height that
                  // is left between the fixed header and the pinned bar, and
                  // the content is RESOLVED to fit it (scale first, then the
                  // whitespace between the blocks), so it cannot overflow and
                  // never needs to scroll.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, region) {
                        final m = _KioskCouponMetrics.resolve(
                          region.maxWidth,
                          math.min(region.maxHeight, regionHeight),
                          hasInlineError: hasInlineError,
                        );
                        return Center(
                          child: SizedBox(
                            width: m.contentWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(height: m.gap(_kLogoToTitle)),
                                _Title(m: m),
                                SizedBox(height: m.gap(_kTitleToField)),
                                _CodeField(
                                  m: m,
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  onSubmit: _submit,
                                  onChanged: _onCodeChanged,
                                  errorText: _errorText,
                                ),
                                SizedBox(height: m.gap(_kFieldToKeyboard)),
                                KioskKeyboard(
                                  s: m.s,
                                  shift: _shift,
                                  onKey: _insertFromKeyboard,
                                  onShift: () =>
                                      setState(() => _shift = !_shift),
                                  onBackspace: _backspaceFromKeyboard,
                                  onSpace: () => _insertFromKeyboard(' '),
                                  onClear: _clearFromKeyboard,
                                ),
                                SizedBox(height: m.gap(_kKeyboardToScan)),
                                _ScanPanel(m: m),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Consumer<CouponProvider>(
                    builder: (context, coupon, _) => KioskCenteredContent(
                      maxWidth: column,
                      child: KioskActionBar(
                        s: cs,
                        actions: [
                          KioskBarAction(
                            label: kioskTranslate(context, 'back', 'Back')
                                .toUpperCase(),
                            filled: false,
                            onTap: _close,
                          ),
                          KioskBarAction(
                            label:
                                kioskTranslate(context, 'continue', 'Continue')
                                    .toUpperCase(),
                            filled: true,
                            loading: coupon.isLoading,
                            onTap: coupon.isLoading ? null : _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
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

const int _kMaxCodeLength = 24;

// Vertical rhythm of the flexible region: whitespace gaps (flexible) and
// element heights (fixed). The gap under the logo and the gaps around the
// action bar are chrome, owned by [KioskChromeSpec], not by this screen.
const double _kLogoToTitle = 618.5;
const double _kTitleToField = 105;
const double _kFieldToKeyboard = 270;
const double _kKeyboardToScan = 190;

const double _kLogoWidth = 680.783;
const double _kLogoHeight = 178.475;
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

/// The inline coupon-rejection line under the field (see [_CodeField]):
/// 18 gap + one 40px line at 1.2.
const double _kErrorExtra = 18 + 40 * 1.2;

/// Sum of the flexible gaps and of the fixed element heights, at scale 1.
const double _kGapTotal =
    _kLogoToTitle + _kTitleToField + _kFieldToKeyboard + _kKeyboardToScan;

const double _kFixedTotal =
    _kTitleFont + _kFieldHeight + KioskKeyboard.designHeight + _kPanelHeight;

/// How far the design's whitespace may be squeezed / stretched before the
/// scale itself has to give way.
const double _kMinGapFactor = 0.5;
const double _kMaxGapFactor = 2.2;

/// Height of the fixed header row at chrome scale [cs]: the top inset, then the
/// taller of the back button and the wordmark.
double _headerHeight(BuildContext context, double cs) =>
    KioskChromeSpec.insetTop * cs +
    math.max(KioskBackButton.diameterFor(context, cs), _kLogoHeight * cs);

/// Resolved sizing of the flexible region for one measured box.
class _KioskCouponMetrics {
  /// Figma pixel → logical pixel.
  final double s;

  /// Multiplier applied to the design's vertical whitespace only.
  final double gapFactor;

  final double contentWidth;

  const _KioskCouponMetrics._({
    required this.s,
    required this.gapFactor,
    required this.contentWidth,
  });

  /// [height] is the height the region has. There is deliberately NO floor on
  /// the scale: a floor is exactly what makes a fixed budget overflow on a
  /// small window. The scale is whatever lets the content fit, and the
  /// whitespace between the blocks takes up the rest.
  factory _KioskCouponMetrics.resolve(double width, double height,
      {bool hasInlineError = false}) {
    final double fixedDesign =
        _kFixedTotal + (hasInlineError ? _kErrorExtra : 0);
    // The shortest height the content can occupy is its fixed elements plus
    // half its whitespace.
    final double minDesignHeight = fixedDesign + _kGapTotal * _kMinGapFactor;

    final double s = math.max(
      0.01,
      math.min(
        1.0,
        math.min(width / _kDesignWidth, height / minDesignHeight),
      ),
    );

    final double fixed = fixedDesign * s;
    final double gapFactor = _kGapTotal * s <= 0
        ? 1.0
        : ((height - fixed) / (_kGapTotal * s))
            .clamp(_kMinGapFactor, _kMaxGapFactor);

    return _KioskCouponMetrics._(
      s: s,
      gapFactor: gapFactor,
      contentWidth: _kDesignWidth * s,
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

/// The fixed header: wordmark centred, the shared back button on the left.
/// CHROME, so it is sized at the chrome scale [cs], not by this screen's
/// content scale.
class _Header extends StatelessWidget {
  final double cs;
  final VoidCallback onBack;
  const _Header({required this.cs, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _headerHeight(context, cs),
      child: Padding(
        padding: EdgeInsets.only(top: KioskChromeSpec.insetTop * cs),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The kiosk ships the wordmark as white artwork; every light kiosk
            // screen tints it with the page ink (see kiosk_welcome_screen).
            SvgPicture.asset(
              Images.kioskLogoWhiteSvg,
              width: _kLogoWidth * cs,
              height: _kLogoHeight * cs,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(_kInk, BlendMode.srcIn),
            ),
            // Top-aligned, not centred: the back button sits at the shared top
            // inset even when the wordmark makes the row taller than it is.
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(left: KioskChromeSpec.insetLeft * cs),
                child: KioskBackButton(
                  s: cs,
                  onTap: onBack,
                  fallback: RouterHelper.getKioskCartRoute,
                ),
              ),
            ),
          ],
        ),
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

  final ValueChanged<String>? onChanged;

  /// Set when the backend rejected the last code (unknown, expired, limit
  /// reached) — reddens the border and prints the reason below it, matching
  /// `_LoginField` / `kiosk_checkout_widgets.dart`'s inline-error convention.
  final String? errorText;

  const _CodeField({
    required this.m,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
              color: hasError ? kCheckoutErrorRed : _kFieldBorder,
              width: m.stroke(_kFieldBorderWidth),
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            readOnly: false,
            showCursor: true,
            // TextInputType.none — not readOnly — so the field stays fully
            // editable (the barcode scanner is a hardware keyboard that types
            // into this same field; see the class doc) while the platform's
            // own on-screen keyboard never opens. Every visible key instead
            // comes from the on-screen KioskKeyboard docked below.
            keyboardType: TextInputType.none,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            maxLines: 1,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            // Keep the caret where the customer left it when focus returns
            // (scanner append / system keyboard). Default web/desktop
            // select-all would replace the whole code on the next key.
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
        ),
        if (hasError) ...[
          SizedBox(height: m.px(18)),
          Padding(
            // Flush with the field's own left border (_kFieldInsetLeft is
            // already the Container's margin, above) — not also offset by
            // the field's inner _kFieldPadH, which pushed the message well
            // past the border instead of starting at it, per Figma.
            padding: EdgeInsets.only(left: m.px(_kFieldInsetLeft)),
            child: Text(
              errorText!,
              style: loewMedium.copyWith(
                fontSize: m.px(40),
                height: 1.2,
                color: kCheckoutErrorRed,
              ),
            ),
          ),
        ],
      ],
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
