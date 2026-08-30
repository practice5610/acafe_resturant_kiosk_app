import 'dart:math' as math;

import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Palette for this modal only, kept in the kiosk's cream family.
const Color _kNoteSurface = Color(0xFFFCFAF4);
const Color _kNoteBorder = Color(0xFFE8E2D5);
const Color _kNoteInk = Color(0xFF1E1E1E);
const Color _kNoteText = Color(0xFF2B2B2B);
const Color _kNoteMuted = Color(0xFF8A8275);
const Color _kNoteCream = Color(0xFFF3F3DD);

const int _kNoteMaxLength = 255;

/// Narrowest the note column may get before it stops being usable.
const double _kNoteMinColumn = 280;

const String _kNoteHint =
    'Anything we should know? Let us know about cutlery, napkins, straws, '
    'sauces, or any special requests you may have.';

/// Opens the order-note editor over the cart. Returns once the modal closes;
/// the note is written straight to [CartProvider] on CONTINUE, so callers do
/// not need the result.
///
/// A full-screen dialog rather than a bottom sheet: the note card floats over
/// a blurred scrim, and tapping the field opens the device keyboard.
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
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: Provider.of<CartProvider>(context, listen: false).orderNote,
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
                final double width = constraints.maxWidth;
                final double gutter = (width * 0.035).clamp(10.0, 28.0);
                final double column = kioskBounded(
                  width - gutter * 2,
                  min: math.min(_kNoteMinColumn, width - gutter * 2),
                  max: math.min(1040.0, math.max(0.0, width - gutter * 2)),
                );

                final double continueHeight =
                    (column * 0.1).clamp(48.0, 96.0);
                final double continueRadius =
                    (column * 0.018).clamp(6.0, 20.0);
                final double continueFont =
                    (column * 0.036).clamp(14.0, 28.0);

                // Room left for the card once CONTINUE and gutters are reserved.
                final double cardRoom = constraints.maxHeight -
                    gutter * 3 -
                    continueHeight;

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(gutter),
                    child: SizedBox(
                      width: column,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {}, // absorb taps inside the card
                            child: _NoteCard(
                              width: column,
                              maxHeight: cardRoom,
                              controller: _controller,
                              focusNode: _focusNode,
                              onBack: _cancel,
                            ),
                          ),
                          SizedBox(height: gutter),
                          _ContinueButton(
                            height: continueHeight,
                            radius: continueRadius,
                            fontSize: continueFont,
                            onTap: _save,
                          ),
                        ],
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
}

/// The floating card: back button, title, and the note field itself.
class _NoteCard extends StatelessWidget {
  final double width;

  /// Height the card may take. The note field spends whatever is left after
  /// the card's own chrome, so a short window shrinks the field instead of
  /// pushing CONTINUE off the bottom of the screen.
  final double maxHeight;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onBack;

  const _NoteCard({
    required this.width,
    required this.maxHeight,
    required this.controller,
    required this.focusNode,
    required this.onBack,
  });

  static double _padFor(double width) => (width * 0.04).clamp(14.0, 32.0);
  static double _titleFor(double width) => (width * 0.038).clamp(15.0, 30.0);
  static double _backFor(double width) => (width * 0.075).clamp(34.0, 60.0);

  static double _bodyFor(double width) => (width * 0.03).clamp(13.0, 22.0);

  /// Everything the card spends on itself: the three paddings and the header
  /// row, budgeted at two title lines so a long translation cannot grow the
  /// card after the field has been sized.
  static double chromeFor(double width) =>
      _padFor(width) * 3 +
      math.max(_backFor(width), _titleFor(width) * 1.1 * 2);

  /// Shortest the field BOX may be: its own inner padding plus two lines of
  /// the note.
  static double minFieldFor(double width) =>
      _padFor(width) * 0.8 * 2 + _bodyFor(width) * 1.45 * 2;

  @override
  Widget build(BuildContext context) {
    final double pad = _padFor(width);
    final double titleSize = _titleFor(width);
    final double bodySize = _bodyFor(width);
    final double backSize = _backFor(width);

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
            height: (maxHeight - chromeFor(width))
                .clamp(minFieldFor(width), 340.0),
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
              focusNode: focusNode,
              autofocus: true,
              readOnly: false,
              showCursor: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              inputFormatters: const [
                _NoteLengthFormatter(_kNoteMaxLength),
              ],
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

/// Caps the note without the character counter a plain `maxLength` would add,
/// and without truncating mid-edit when the caret is not at the end.
class _NoteLengthFormatter extends TextInputFormatter {
  final int max;
  const _NoteLengthFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.text.length > max ? oldValue : newValue;
  }
}
