import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_keyboard.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Figma 2305:15852 ("06b Order note pop-up") palette.
const Color _kCardBg = Color(0xFFFBF8EF);
const Color _kCardBorder = Color(0xFFB9B5A6);
const Color _kTitleInk = Color(0xFF0D0D0D);
const Color _kInputBg = Color(0xFFFAF9F7);
const Color _kInputBorder = Color(0xFF0D0D0D);
const Color _kInputText = Color(0xFF231F20);
const Color _kInputHint = Color(0xFF706D63);
const Color _kPanelBg = Color(0xFFF7F1DE);

const int _kNoteMaxLength = 255;

const String _kNoteHint =
    'Anything we should know? Let us know about cutlery, napkins, straws, '
    'sauces, or any special requests you may have.';

/// Opens the order-note editor over the cart. Returns once the modal closes;
/// the note is written straight to [CartProvider] on CONTINUE, so callers do
/// not need the result.
///
/// A full-screen dialog rather than a bottom sheet: the note card floats over
/// a blurred scrim, with the on-screen [KioskKeyboard] docked to the bottom
/// of the screen — Figma 2305:15852 ("06b Order note pop-up").
Future<void> openKioskOrderNote(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Order note',
    barrierColor: Colors.transparent, // the sheet paints its own blurred scrim
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const KioskOrderNoteSheet(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}

class KioskOrderNoteSheet extends StatefulWidget {
  const KioskOrderNoteSheet({super.key});

  @override
  State<KioskOrderNoteSheet> createState() => _KioskOrderNoteSheetState();
}

class _KioskOrderNoteSheetState extends State<KioskOrderNoteSheet> {
  late final TextEditingController _controller;

  /// Caps-lock state for [KioskKeyboard] — this field is typed entirely
  /// through the on-screen board (see the class doc), so there is no system
  /// IME shift key to defer to.
  bool _shift = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: Provider.of<CartProvider>(context, listen: false).orderNote,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Discards edits — the note in the provider is left as it was.
  void _cancel() => Navigator.of(context).pop();

  void _save() {
    Provider.of<CartProvider>(context, listen: false)
        .setOrderNote(_controller.text);
    Navigator.of(context).pop();
  }

  // --- Custom keyboard editing ----------------------------------------------
  //
  // The field is `readOnly` (tap-to-position-cursor and drag-to-select still
  // work; only the system IME is suppressed) and every character comes from
  // [KioskKeyboard] instead, so insert/backspace/clear are hand-rolled here
  // rather than routed through TextField's own input pipeline.

  TextSelection get _selection {
    final TextSelection sel = _controller.selection;
    if (!sel.isValid) {
      return TextSelection.collapsed(offset: _controller.text.length);
    }
    return sel;
  }

  void _insert(String text) {
    final TextSelection sel = _selection;
    final String next =
        _controller.text.replaceRange(sel.start, sel.end, text);
    if (next.length > _kNoteMaxLength) return;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  void _backspace() {
    final TextSelection sel = _selection;
    if (sel.start != sel.end) {
      _controller.value = TextEditingValue(
        text: _controller.text.replaceRange(sel.start, sel.end, ''),
        selection: TextSelection.collapsed(offset: sel.start),
      );
      return;
    }
    if (sel.start <= 0) return;
    _controller.value = TextEditingValue(
      text: _controller.text.replaceRange(sel.start - 1, sel.start, ''),
      selection: TextSelection.collapsed(offset: sel.start - 1),
    );
  }

  void _clear() => _controller.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );

  @override
  Widget build(BuildContext context) {
    // Material (transparent) provides the DefaultTextStyle the Text widgets
    // below rely on; without it, text inside showGeneralDialog falls back to
    // the framework debug style.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          KioskScrim(
            animation: ModalRoute.of(context)?.animation ??
                kAlwaysCompleteAnimation,
            onDismiss: _cancel,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double s = KioskResponsive.scale(
                    constraints.maxWidth, constraints.maxHeight);
                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(40 * s),
                          child: GestureDetector(
                            onTap: () {}, // absorb taps inside the card
                            child: _NoteCard(
                              s: s,
                              controller: _controller,
                              onBack: _cancel,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _KeyboardPanel(
                      s: s,
                      shift: _shift,
                      onKey: _insert,
                      onShift: () => setState(() => _shift = !_shift),
                      onBackspace: _backspace,
                      onSpace: () => _insert(' '),
                      onClear: _clear,
                      onContinue: _save,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating "Anything we should know?" card — Figma 2305:15948
/// ("add-a-note"). Just the back button, title, and the text box; the
/// keyboard and CONTINUE are docked to the bottom of the screen instead (see
/// [_KeyboardPanel]), not stacked under this card, matching the Figma frame.
class _NoteCard extends StatelessWidget {
  final double s;
  final TextEditingController controller;
  final VoidCallback onBack;

  const _NoteCard({
    required this.s,
    required this.controller,
    required this.onBack,
  });

  static const double _cardWidth = 2078;
  static const double _pad = 96;
  static const double _gap = 79;
  static const double _backSize = 141;
  static const double _titleSize = 72;
  static const double _inputHeight = 1000;
  static const double _inputPad = 64;
  static const double _inputRadius = 28;
  static const double _inputBorder = 4;
  static const double _hintSize = 44;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cardWidth * s,
      padding: EdgeInsets.all(_pad * s),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(30 * s),
        border:
            Border.all(color: _kCardBorder, width: (6 * s).clamp(2.0, 6.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                // Room for the back button so a long translation never
                // overlaps it — same guard KioskHeaderBar uses.
                padding: EdgeInsets.symmetric(horizontal: _backSize * s),
                child: Text(
                  getTranslated('anything_we_should_know', context) ??
                      'Anything we should know?',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: loewExtraBold.copyWith(
                    fontSize: _titleSize * s,
                    height: 1.1,
                    color: _kTitleInk,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: KioskBackButton.scaled(
                  s: s,
                  size: _backSize,
                  border: 4,
                  icon: 60,
                  minBorder: 1.5,
                  onTap: onBack,
                ),
              ),
            ],
          ),
          SizedBox(height: _gap * s),
          Container(
            width: double.infinity,
            height: _inputHeight * s,
            padding: EdgeInsets.all(_inputPad * s),
            decoration: BoxDecoration(
              color: _kInputBg,
              borderRadius: BorderRadius.circular(_inputRadius * s),
              border: Border.all(
                  color: _kInputBorder,
                  width: (_inputBorder * s).clamp(1.5, 4.0)),
            ),
            child: TextField(
              controller: controller,
              // No system IME — every character comes from the on-screen
              // KioskKeyboard docked below (see _KeyboardPanel). readOnly
              // only blocks the OS keyboard; tap-to-position-cursor and
              // drag-to-select keep working.
              readOnly: true,
              showCursor: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: _kTitleInk,
              cursorWidth: (3 * s).clamp(1.5, 3.0),
              style: loewRegular.copyWith(
                fontSize: _hintSize * s,
                height: 1.5,
                color: _kInputText,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: _kNoteHint,
                hintStyle: loewRegular.copyWith(
                  fontSize: _hintSize * s,
                  height: 1.5,
                  color: _kInputHint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// On-screen keyboard + CONTINUE, docked to the bottom of the screen — Figma
/// 2305:15957 ("Keyboard-Section"). Built on the shared [KioskKeyboard] board
/// (already tokened for the coupon-code screen at these exact key sizes/
/// colors) with its digit row hidden, matching this frame.
class _KeyboardPanel extends StatelessWidget {
  final double s;
  final bool shift;
  final ValueChanged<String> onKey;
  final VoidCallback onShift;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onClear;
  final VoidCallback onContinue;

  const _KeyboardPanel({
    required this.s,
    required this.shift,
    required this.onKey,
    required this.onShift,
    required this.onBackspace,
    required this.onSpace,
    required this.onClear,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(46 * s)),
        border: Border(
          top: BorderSide(color: _kCardBorder, width: (4 * s).clamp(2.0, 4.0)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(40 * s, 116 * s, 40 * s, 72 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FittedBox, not a bare margin guess: the keys-stack's own row math
          // (10 keys × 223 + 9 gaps × 20 = 2410 design px) is wider than the
          // 2332px Figma nominally reserves for it (120px margin each side on
          // a 2572 canvas) — a Figma export quirk that only shows up as a
          // genuine RenderFlex overflow once Flutter actually lays it out, on
          // viewports where `s` skews toward the height axis. FittedBox
          // guarantees the board fits regardless of how that mismatch moves.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: KioskKeyboard(
              s: s,
              shift: shift,
              showDigitRow: false,
              onKey: onKey,
              onShift: onShift,
              onBackspace: onBackspace,
              onSpace: onSpace,
              onClear: onClear,
            ),
          ),
          SizedBox(height: 72 * s),
          KioskTap(
            onTap: onContinue,
            child: Container(
              width: double.infinity,
              height: 252 * s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30 * s),
              ),
              child: Text(
                (getTranslated('continue', context) ?? 'CONTINUE')
                    .toUpperCase(),
                style: loewExtraBold.copyWith(
                  fontSize: 64 * s,
                  height: 1,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
