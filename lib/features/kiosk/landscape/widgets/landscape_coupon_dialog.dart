import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/features/coupon/domain/models/coupon_apply_result.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_reward.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/landscape/landscape_metrics.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_coupon_applied_dialog.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_keyboard.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// LANDSCAPE KIOSK — "Add a coupon" pop-up (Option B).
// Figma TABLET Final Designs (option B), nodes:
//   2305:7603 — B-08 "Coupon: enter code"   (empty field, APPLY disabled)
//   2305:7939 — B-09 "Coupon: code typed"   (APPLY active)
//   2305:8275 — B-10 "Coupon: invalid code" (red border + inline message)
// Card is 640 design px wide, centred at x=363 (dead-centre of the 1366
// canvas) and y=28; height grows from 338.208 to 376.208 when the error row
// is shown. Portrait's full-screen coupon flow (kiosk_coupon_screen.dart) is
// untouched — this is a separate, landscape-only pop-up.
// ===========================================================================

const double _kCardWidth = 640;
const double _kCardTop = 28;
const double _kCardRadius = 24;
const Color _kCardBg = Color(0xFFFBF8EF);
const Color _kInk = Color(0xFF0D0D0D);
const Color _kSubtitleInk = Color(0xFF73736E);
const Color _kFieldText = Color(0xFF231F20);
const Color _kErrorBorder = Color(0xFFC72921);
const Color _kErrorText = Color(0xFFEF4444);

const double _kPadLeft = 48;
const double _kPadRight = 48; // 640 - 544 - 48
const double _kTitleTop = 40;
const double _kTitleFont = 26;
const double _kCloseSize = 48;
const double _kCloseTop = 34;
const double _kCloseFont = 17;
const double _kSubtitleTop = 96;
const double _kSubtitleFont = 18;

const double _kFieldTop = 136;
const double _kFieldWidth = 544;
const double _kFieldHeight = 78.20784759521484;
const double _kFieldRadius = 7.423;
const double _kFieldBorder = 2;
const double _kFieldBorderError = 3;
const double _kFieldPad = 16.967;
const double _kFieldFont = 26;
const double _kPlaceholderFont = 18;

const double _kErrorTop = 226.20785522460938;
const double _kErrorFont = 16;

const double _kButtonsTop = 238.20785522460938;
const double _kButtonsTopError = 276.2078552246094;
const double _kButtonHeight = 60;
const double _kButtonWidth = 264;
const double _kButtonGap = 16; // 328 - 48 - 264
const double _kButtonRadius = 10;
const double _kButtonFont = 16;

const double _kCardHeight = 338.2078552246094;
const double _kCardHeightError = 376.2078552246094;

const int _kMaxCodeLength = 24;

// ---------------------------------------------------------------------------
// Docked on-screen keyboard — Figma node 2305:7616 ("Keyboard (docked, letters
// + numbers)") inside the "Keyboard tray" (2305:7615), full width, flush with
// the bottom of the 1366x1024 canvas. No shift/caps key in this artboard — the
// field's own `textCapitalization` renders the code upper-case regardless.
// ---------------------------------------------------------------------------
const double _kTrayRadius = 24;
const double _kTrayBorderWidth = 2;
const double _kTrayHeight = 595.7921142578125;

const double _kKeyW = 91.827880859375;
const double _kKeyH = 82.3568344116211;
const double _kKeyGap = 8.235;
const double _kKeyRowGap = 16.47;
const double _kKeyRadius = 6.589;
const double _kKeyBorderWidth = 1.647;
const double _kKeyFont = 20.485;

const double _kSpaceRowGap = 19.765;
const double _kSpaceW = 472.316;
const double _kClearW = 405.607;
const double _kSpaceClearGap = 11.119;
const double _kSpaceClearFont = 15.364;
const double _kBackspaceIcon = 32.943;

/// Opens the landscape "Add a coupon" pop-up over the current screen.
Future<void> showLandscapeCouponDialog(
  BuildContext context, {
  required double orderAmount,
}) async {
  await ensureKioskGuestForCoupon(context);
  if (!context.mounted) return;
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'coupon',
    barrierColor: Colors.transparent, // the scrim is painted below, in-canvas
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, __, ___) =>
        _LandscapeCouponDialog(orderAmount: orderAmount),
    transitionBuilder: (ctx, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

class _LandscapeCouponDialog extends StatefulWidget {
  final double orderAmount;
  const _LandscapeCouponDialog({required this.orderAmount});

  @override
  State<_LandscapeCouponDialog> createState() =>
      _LandscapeCouponDialogState();
}

class _LandscapeCouponDialogState extends State<_LandscapeCouponDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  String? _errorText;

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

  void _onChanged(String _) {
    if (_errorText != null) setState(() => _errorText = null);
    // APPLY's enabled state tracks the field, which lives outside setState.
    setState(() {});
  }

  // --- on-screen keyboard editing -------------------------------------------
  //
  // The field keeps `keyboardType: TextInputType.none` so it stays genuinely
  // editable while the platform's own on-screen keyboard never opens — every
  // visible key comes from the docked board below (see class doc), same
  // convention as the portrait coupon screen's `KioskKeyboard`.

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
    _onChanged(next);
  }

  void _backspaceFromKeyboard() {
    final TextSelection sel = _codeSelection;
    if (sel.start != sel.end) {
      final String next = _controller.text.replaceRange(sel.start, sel.end, '');
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      _onChanged(next);
      return;
    }
    if (sel.start <= 0) return;
    final String next =
        _controller.text.replaceRange(sel.start - 1, sel.start, '');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start - 1),
    );
    _onChanged(next);
  }

  void _clearFromKeyboard() {
    _controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _onChanged('');
  }

  void _cancel() => Navigator.of(context).pop();

  /// The backend answers with `translate(...)` output, so a key the kiosk's
  /// own language files do not carry arrives as the raw identifier — same
  /// prettifying the portrait coupon screen applies.
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

  Future<void> _submit() async {
    final String code = _controller.text.trim();
    if (code.isEmpty) return;

    final coupon = Provider.of<CouponProvider>(context, listen: false);
    if (coupon.isLoading) return;
    if (_errorText != null) setState(() => _errorText = null);

    final CouponApplyResult result =
        await coupon.applyCouponDetailed(code, widget.orderAmount);
    if (!mounted) return;

    if (result.status == CouponApplyStatus.applied) {
      // B-11/B-11a: a separate "Coupon applied!" pop-up names the benefit and
      // closes itself after 3 s (or a tap); this "Add a coupon" pop-up closes
      // behind it, back to the menu with the coupon line now in the panel.
      final KioskCouponReward reward = KioskCouponReward.resolve(
        coupon: result.coupon,
        discount: result.discount,
        orderAmount: widget.orderAmount,
        formatPrice: (value) => PriceConverterHelper.convertPrice(value),
        translate: (key, fallback) => kioskTranslate(context, key, fallback),
      );
      await showLandscapeCouponAppliedDialog(context, reward);
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    if (result.status == CouponApplyStatus.belowMinPurchase) {
      showCustomSnackBarHelper(
        '${kioskTranslate(context, 'minimum_purchase_amount_is', 'Minimum purchase amount is')} '
        '${result.minPurchase}',
      );
      return;
    }

    setState(() => _errorText = _failureMessage(result.errorMessage));
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = _errorText != null;
    final double cardHeight = hasError ? _kCardHeightError : _kCardHeight;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _cancel,
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          width: double.infinity,
          height: double.infinity,
          child: LayoutBuilder(
            builder: (context, c) {
              final double s =
                  LandscapeMetrics.scaleFor(c.maxWidth, c.maxHeight);
              final double cardWidth = _kCardWidth * s;
              final double scaledHeight = cardHeight * s;
              final double top = (_kCardTop * s)
                  .clamp(8.0, (c.maxHeight - scaledHeight).clamp(0.0, c.maxHeight));
              final double left =
                  ((c.maxWidth - cardWidth) / 2).clamp(0.0, c.maxWidth);

              return Stack(
                children: [
                  Positioned(
                    left: left,
                    top: top,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // swallow — don't close on card taps
                      child: _Card(
                        s: s,
                        width: cardWidth,
                        height: scaledHeight,
                        hasError: hasError,
                        errorText: _errorText,
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onChanged,
                        onSubmit: _submit,
                        onCancel: _cancel,
                        onApply: _submit,
                        applying:
                            context.watch<CouponProvider>().isLoading,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // swallow — don't close on keyboard taps
                      child: LandscapeKeyboard(
                        s: s,
                        onKey: _insertFromKeyboard,
                        onBackspace: _backspaceFromKeyboard,
                        onSpace: () => _insertFromKeyboard(' '),
                        onClear: _clearFromKeyboard,
                        showDigitRow: true,
                        keyWidth: _kKeyW,
                        keyHeight: _kKeyH,
                        keyGap: _kKeyGap,
                        rowGap: _kKeyRowGap,
                        keyRadius: _kKeyRadius,
                        keyBorderWidth: _kKeyBorderWidth,
                        keyFont: _kKeyFont,
                        iconSize: _kBackspaceIcon,
                        trayHeight: _kTrayHeight,
                        trayPaddingV: 49.414,
                        trayRadius: _kTrayRadius,
                        trayBorderWidth: _kTrayBorderWidth,
                        spaceRowGap: _kSpaceRowGap,
                        spaceWidth: _kSpaceW,
                        clearWidth: _kClearW,
                        spaceClearGap: _kSpaceClearGap,
                        spaceClearFont: _kSpaceClearFont,
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

class _Card extends StatelessWidget {
  final double s;
  final double width;
  final double height;
  final bool hasError;
  final String? errorText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSubmit;
  final VoidCallback onCancel;
  final Future<void> Function() onApply;
  final bool applying;

  const _Card({
    required this.s,
    required this.width,
    required this.height,
    required this.hasError,
    required this.errorText,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
    required this.onCancel,
    required this.onApply,
    required this.applying,
  });

  @override
  Widget build(BuildContext context) {
    final double buttonsTop =
        (hasError ? _kButtonsTopError : _kButtonsTop) * s;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(_kCardRadius * s),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: _kPadLeft * s,
            top: _kTitleTop * s,
            child: Text(
              kioskTranslate(context, 'add_a_coupon', 'Add a coupon'),
              style: loewBold.copyWith(
                  fontSize: _kTitleFont * s, height: 1.0, color: _kInk),
            ),
          ),
          Positioned(
            left: width - _kCloseSize * s - _kPadRight * s,
            top: _kCloseTop * s,
            child: KioskTap(
              onTap: onCancel,
              child: Container(
                width: _kCloseSize * s,
                height: _kCloseSize * s,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  'X',
                  style: loewBold.copyWith(
                      fontSize: _kCloseFont * s,
                      height: 1.0,
                      color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            left: _kPadLeft * s,
            top: _kSubtitleTop * s,
            width: _kFieldWidth * s,
            child: Text(
              kioskTranslate(context, 'enter_the_code_from_your_voucher',
                  'Enter the code from your voucher or the A/Café app.'),
              style: swiss721Light.copyWith(
                  fontSize: _kSubtitleFont * s,
                  height: 1.1,
                  color: _kSubtitleInk),
            ),
          ),
          Positioned(
            left: _kPadLeft * s,
            top: _kFieldTop * s,
            child: _Field(
              s: s,
              hasError: hasError,
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              onSubmit: onSubmit,
            ),
          ),
          if (hasError)
            Positioned(
              left: _kPadLeft * s,
              top: _kErrorTop * s,
              width: _kFieldWidth * s,
              child: Text(
                errorText!,
                style: loewMedium.copyWith(
                    fontSize: _kErrorFont * s,
                    height: 1.1,
                    color: _kErrorText),
              ),
            ),
          Positioned(
            left: _kPadLeft * s,
            top: buttonsTop,
            child: Row(
              children: [
                _ActionButton(
                  s: s,
                  label: kioskTranslate(context, 'cancel', 'CANCEL'),
                  filled: false,
                  onTap: onCancel,
                ),
                SizedBox(width: _kButtonGap * s),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => _ActionButton(
                    s: s,
                    label: kioskTranslate(context, 'apply', 'APPLY'),
                    filled: true,
                    loading: applying,
                    onTap: value.text.trim().isEmpty || applying
                        ? null
                        : onApply,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final double s;
  final bool hasError;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSubmit;

  const _Field({
    required this.s,
    required this.hasError,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kFieldWidth * s,
      height: _kFieldHeight * s,
      padding: EdgeInsets.all(_kFieldPad * s),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(_kFieldRadius * s),
        border: Border.all(
          color: hasError ? _kErrorBorder : _kInk,
          width: (hasError ? _kFieldBorderError : _kFieldBorder) * s,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        showCursor: true,
        // Suppress the platform's own on-screen keyboard — every visible key
        // comes from the docked board (_KeyboardTray) instead, matching the
        // portrait coupon screen's convention.
        keyboardType: TextInputType.none,
        textAlignVertical: TextAlignVertical.center,
        maxLines: 1,
        textCapitalization: TextCapitalization.characters,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        onSubmitted: (_) => onSubmit(),
        selectAllOnFocus: false,
        autocorrect: false,
        enableSuggestions: false,
        cursorColor: _kInk,
        cursorWidth: (2 * s).clamp(1.0, 4.0),
        inputFormatters: [
          LengthLimitingTextInputFormatter(_kMaxCodeLength),
        ],
        style: loewBold.copyWith(
            fontSize: _kFieldFont * s, height: 1.0, color: _kFieldText),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText:
              kioskTranslate(context, 'type_your_code', 'Type your code'),
          hintStyle: loewRegular.copyWith(
              fontSize: _kPlaceholderFont * s,
              height: 1.0,
              color: _kSubtitleInk),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final double s;
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.s,
    required this.label,
    required this.filled,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null && !loading;
    return Opacity(
      opacity: disabled ? 0.3 : 1,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: _kButtonWidth * s,
          height: _kButtonHeight * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(_kButtonRadius * s),
            border: filled
                ? null
                : Border.all(color: Colors.black, width: (2 * s).clamp(1.0, 3.0)),
          ),
          child: loading
              ? SizedBox(
                  width: _kButtonFont * s,
                  height: _kButtonFont * s,
                  child: CircularProgressIndicator(
                    strokeWidth: (3 * s).clamp(1.5, 4.0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        filled ? Colors.white : Colors.black),
                  ),
                )
              : Text(
                  label,
                  maxLines: 1,
                  style: loewBold.copyWith(
                      fontSize: _kButtonFont * s,
                      height: 1.0,
                      color: filled ? Colors.white : Colors.black),
                ),
        ),
      ),
    );
  }
}

