import 'dart:ui';

import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Palette for this modal only, kept in the kiosk's cream family.
const Color _kNoteSurface = Color(0xFFFCFAF4);
const Color _kNoteKeyboardBg = Color(0xFFF7F1DE);
const Color _kNoteBorder = Color(0xFFE8E2D5);
const Color _kNoteInk = Color(0xFF1E1E1E);
const Color _kNoteText = Color(0xFF2B2B2B);
const Color _kNoteMuted = Color(0xFF8A8275);
const Color _kNoteCream = Color(0xFFF3F3DD);

const int _kNoteMaxLength = 255;

const String _kNoteHint =
    'Anything we should know? Let us know about cutlery, napkins, straws, '
    'sauces, or any special requests you may have.';

/// Opens the order-note editor over the cart. Returns once the modal closes;
/// the note is written straight to [CartProvider] on CONTINUE, so callers do
/// not need the result.
///
/// A full-screen dialog rather than a bottom sheet: the on-screen keyboard has
/// to own the lower half of the display, and the note card floats above it.
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

  /// One-shot shift, the way a phone keyboard behaves: it capitalises the next
  /// letter and then releases itself.
  bool _shift = true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: Provider.of<CartProvider>(context, listen: false).orderNote,
    );
    // Start lower-case when there is already text to continue.
    _shift = _controller.text.isEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insert(String value) {
    if (_controller.text.length >= _kNoteMaxLength) return;
    setState(() {
      _controller.text = _controller.text + value;
      if (value.trim().isNotEmpty) _shift = false;
    });
  }

  void _onLetter(String letter) =>
      _insert(_shift ? letter.toUpperCase() : letter.toLowerCase());

  void _onBackspace() {
    final String text = _controller.text;
    if (text.isEmpty) return;
    setState(() {
      _controller.text = text.substring(0, text.length - 1);
      // Back at the start, offer a capital again.
      if (_controller.text.isEmpty) _shift = true;
    });
  }

  void _onClear() {
    if (_controller.text.isEmpty) return;
    setState(() {
      _controller.clear();
      _shift = true;
    });
  }

  /// Discards edits — the note in the provider is left as it was.
  void _cancel() => Navigator.of(context).pop();

  void _save() {
    Provider.of<CartProvider>(context, listen: false)
        .setOrderNote(_controller.text);
    Navigator.of(context).pop();
  }

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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cancel,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: _kNoteInk.withValues(alpha: 0.45)),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Every measurement below is derived from the space actually
                // available, so the keyboard fits exactly on a portrait kiosk,
                // a tablet and a resized browser window alike.
                final double width = constraints.maxWidth;
                final double gutter = (width * 0.035).clamp(10.0, 28.0);
                final double cardWidth = (width - gutter * 2).clamp(280.0, 900.0);

                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                              horizontal: gutter, vertical: gutter),
                          child: GestureDetector(
                            onTap: () {}, // absorb taps inside the card
                            child: _NoteCard(
                              width: cardWidth,
                              controller: _controller,
                              onBack: _cancel,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _KeyboardPanel(
                      width: width,
                      shift: _shift,
                      onLetter: _onLetter,
                      onShift: () => setState(() => _shift = !_shift),
                      onBackspace: _onBackspace,
                      onSpace: () => _insert(' '),
                      onClear: _onClear,
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

/// The floating card: back button, title, and the note field itself.
class _NoteCard extends StatelessWidget {
  final double width;
  final TextEditingController controller;
  final VoidCallback onBack;

  const _NoteCard({
    required this.width,
    required this.controller,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final double pad = (width * 0.04).clamp(14.0, 32.0);
    final double titleSize = (width * 0.038).clamp(15.0, 30.0);
    final double bodySize = (width * 0.03).clamp(13.0, 22.0);
    final double backSize = (width * 0.075).clamp(34.0, 60.0);

    return Container(
      width: width,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: _kNoteSurface,
        borderRadius: BorderRadius.circular((width * 0.035).clamp(14.0, 28.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back button sits in the flow's leading slot while the title stays
          // optically centred on the card, not on the space beside the button.
          Row(
            children: [
              _CircleBackButton(size: backSize, onTap: onBack),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad * 0.4),
                  child: Text(
                    getTranslated('anything_we_should_know', context) ??
                        'Anything we should know?',
                    textAlign: TextAlign.center,
                    style: loewBold.copyWith(
                      fontSize: titleSize,
                      height: 1.1,
                      color: _kNoteText,
                    ),
                  ),
                ),
              ),
              // Mirrors the back button so the title's centre is the card's.
              SizedBox(width: backSize),
            ],
          ),
          SizedBox(height: pad),
          Container(
            height: (width * 0.42).clamp(150.0, 340.0),
            width: double.infinity,
            padding: EdgeInsets.all(pad * 0.8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular((width * 0.025).clamp(10.0, 20.0)),
              border: Border.all(color: _kNoteBorder, width: 1.5),
            ),
            child: TextField(
              controller: controller,
              // Driven entirely by the on-screen keys — readOnly keeps the OS
              // keyboard from opening on a touchscreen kiosk, while showCursor
              // keeps a caret visible so typing reads as typing.
              readOnly: true,
              showCursor: true,
              autofocus: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              cursorColor: _kNoteInk,
              cursorWidth: 2,
              style: loewRegular.copyWith(
                fontSize: bodySize,
                height: 1.45,
                color: _kNoteText,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: _kNoteHint,
                hintStyle: loewRegular.copyWith(
                  fontSize: bodySize,
                  height: 1.45,
                  color: _kNoteMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  const _CircleBackButton({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return KioskTap(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _kNoteInk, width: 1.5),
        ),
        child: Icon(Icons.chevron_left_rounded,
            size: size * 0.62, color: _kNoteInk),
      ),
    );
  }
}

/// QWERTY keyboard + the pinned CONTINUE action.
class _KeyboardPanel extends StatelessWidget {
  final double width;
  final bool shift;
  final ValueChanged<String> onLetter;
  final VoidCallback onShift;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onClear;
  final VoidCallback onContinue;

  const _KeyboardPanel({
    required this.width,
    required this.shift,
    required this.onLetter,
    required this.onShift,
    required this.onBackspace,
    required this.onSpace,
    required this.onClear,
    required this.onContinue,
  });

  static const List<String> _row1 = ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
  static const List<String> _row2 = ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'];
  static const List<String> _row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

  @override
  Widget build(BuildContext context) {
    // The top row's ten keys set the module the whole keyboard is built from,
    // so every row lines up regardless of screen width.
    final double pad = (width * 0.03).clamp(10.0, 26.0);
    final double gap = (width * 0.014).clamp(5.0, 12.0);
    final double keyWidth = (width - pad * 2 - gap * 9) / 10;
    final double keyHeight = (keyWidth * 0.86).clamp(38.0, 78.0);
    final double keyRadius = (keyWidth * 0.18).clamp(6.0, 14.0);
    final double letterSize = (keyWidth * 0.36).clamp(13.0, 24.0);

    // Rows 2 and 3 are one and two keys short; they keep the same key module
    // and centre themselves, exactly like a physical keyboard.
    final double row3KeyWidth = (keyWidth * 10 + gap * 9 - gap * 8) / 9;

    return Container(
      width: double.infinity,
      color: _kNoteKeyboardBg,
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad * 0.9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _KeyRow(
            gap: gap,
            children: [
              for (final letter in _row1)
                _Key(
                  width: keyWidth,
                  height: keyHeight,
                  radius: keyRadius,
                  label: shift ? letter.toUpperCase() : letter.toLowerCase(),
                  fontSize: letterSize,
                  onTap: () => onLetter(letter),
                ),
            ],
          ),
          SizedBox(height: gap),
          _KeyRow(
            gap: gap,
            children: [
              for (final letter in _row2)
                _Key(
                  width: keyWidth,
                  height: keyHeight,
                  radius: keyRadius,
                  label: shift ? letter.toUpperCase() : letter.toLowerCase(),
                  fontSize: letterSize,
                  onTap: () => onLetter(letter),
                ),
            ],
          ),
          SizedBox(height: gap),
          _KeyRow(
            gap: gap,
            children: [
              _Key(
                width: row3KeyWidth,
                height: keyHeight,
                radius: keyRadius,
                fontSize: letterSize,
                active: shift,
                icon: Icons.arrow_upward_rounded,
                onTap: onShift,
              ),
              for (final letter in _row3)
                _Key(
                  width: row3KeyWidth,
                  height: keyHeight,
                  radius: keyRadius,
                  label: shift ? letter.toUpperCase() : letter.toLowerCase(),
                  fontSize: letterSize,
                  onTap: () => onLetter(letter),
                ),
              _Key(
                width: row3KeyWidth,
                height: keyHeight,
                radius: keyRadius,
                fontSize: letterSize,
                filled: true,
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
              ),
            ],
          ),
          SizedBox(height: gap),
          _KeyRow(
            gap: gap,
            children: [
              _Key(
                width: (keyWidth * 10 + gap * 9 - gap) / 2,
                height: keyHeight,
                radius: keyRadius,
                label: getTranslated('space', context) ?? 'Space',
                fontSize: letterSize,
                onTap: onSpace,
              ),
              _Key(
                width: (keyWidth * 10 + gap * 9 - gap) / 2,
                height: keyHeight,
                radius: keyRadius,
                label: getTranslated('clear', context) ?? 'Clear',
                fontSize: letterSize,
                onTap: onClear,
              ),
            ],
          ),
          SizedBox(height: pad),
          _ContinueButton(
            height: (keyHeight * 1.15).clamp(48.0, 84.0),
            radius: keyRadius,
            fontSize: (letterSize * 1.05).clamp(14.0, 24.0),
            onTap: onContinue,
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  final double gap;
  final List<Widget> children;
  const _KeyRow({required this.gap, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          children[i],
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final double fontSize;
  final String? label;
  final IconData? icon;

  /// Ink-filled key (backspace) — the one destructive key on the board.
  final bool filled;

  /// Latched state (shift).
  final bool active;
  final VoidCallback onTap;

  const _Key({
    required this.width,
    required this.height,
    required this.radius,
    required this.fontSize,
    this.label,
    this.icon,
    this.filled = false,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = filled || active;
    return KioskTap(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? _kNoteInk : _kNoteSurface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: dark ? _kNoteInk : _kNoteBorder,
            width: 1.5,
          ),
        ),
        child: icon != null
            ? Icon(icon,
                size: fontSize * 1.15,
                color: dark ? Colors.white : _kNoteText)
            : Text(
                label ?? '',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: loewRegular.copyWith(
                  fontSize: fontSize,
                  height: 1.0,
                  color: dark ? Colors.white : _kNoteText,
                ),
              ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  final double height;
  final double radius;
  final double fontSize;
  final VoidCallback onTap;

  const _ContinueButton({
    required this.height,
    required this.radius,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KioskTap(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kNoteInk,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Text(
          (getTranslated('continue', context) ?? 'CONTINUE').toUpperCase(),
          style: loewExtraBold.copyWith(
            fontSize: fontSize,
            letterSpacing: 2,
            color: _kNoteCream,
          ),
        ),
      ),
    );
  }
}
