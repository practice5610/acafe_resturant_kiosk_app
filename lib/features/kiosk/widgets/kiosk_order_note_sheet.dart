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
const Color _kNoteKeyboardBg = Color(0xFFF7F1DE);
const Color _kNoteBorder = Color(0xFFE8E2D5);
const Color _kNoteInk = Color(0xFF1E1E1E);
const Color _kNoteText = Color(0xFF2B2B2B);
const Color _kNoteMuted = Color(0xFF8A8275);
const Color _kNoteCream = Color(0xFFF3F3DD);

const int _kNoteMaxLength = 255;

/// Narrowest the note + keyboard column may get before it stops being usable.
const double _kNoteMinColumn = 280;

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

/// Widest column whose note card and keyboard both fit [height].
///
/// Both the board's height ([_KeyMetrics.height]) and the card's chrome
/// ([_NoteCard.chromeFor]) grow with the column's width, so the widest column
/// that still leaves [_kNoteMinField] for the note is found by bisection
/// rather than by a formula — the clamps inside those two make the relation
/// piecewise, and a closed form would have to duplicate every one of them.
double _fittingColumn({
  required double maxColumn,
  required double height,
  required double gutter,
}) {
  bool fits(double w) =>
      _KeyMetrics.of(w).height +
          _NoteCard.chromeFor(w) +
          _NoteCard.minFieldFor(w) +
          gutter * 3 <=
      height;

  if (fits(maxColumn)) return maxColumn;
  double lo = _kNoteMinColumn;
  double hi = maxColumn;
  for (int i = 0; i < 14; i++) {
    final double mid = (lo + hi) / 2;
    if (fits(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

class KioskOrderNoteSheet extends StatefulWidget {
  const KioskOrderNoteSheet({super.key});

  @override
  State<KioskOrderNoteSheet> createState() => _KioskOrderNoteSheetState();
}

class _KioskOrderNoteSheetState extends State<KioskOrderNoteSheet> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  /// One-shot shift, the way a phone keyboard behaves: it capitalises the next
  /// letter and then releases itself. It only affects the on-screen keys — a
  /// physical keyboard carries its own shift.
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
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The field is editable, so the caret can be anywhere — including wherever a
  /// physical keyboard or a tap on the text left it. Every on-screen key edits
  /// at the current selection rather than blindly appending, so the two input
  /// methods stay in step, and focus is handed straight back to the field.
  TextSelection get _selection {
    final TextEditingValue value = _controller.value;
    return value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
  }

  void _apply(String text, int caret) {
    _controller.value = _controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  void _insert(String value) {
    final TextSelection sel = _selection;
    final String text =
        _controller.text.replaceRange(sel.start, sel.end, value);
    if (text.length > _kNoteMaxLength) return;
    setState(() {
      if (value.trim().isNotEmpty) _shift = false;
    });
    _apply(text, sel.start + value.length);
  }

  void _onLetter(String letter) =>
      _insert(_shift ? letter.toUpperCase() : letter.toLowerCase());

  void _onBackspace() {
    final TextSelection sel = _selection;
    final String current = _controller.text;

    late final String text;
    late final int caret;
    if (sel.start != sel.end) {
      // A selection (drag, or ⌘A from the physical keyboard) deletes wholesale.
      text = current.replaceRange(sel.start, sel.end, '');
      caret = sel.start;
    } else {
      if (sel.start == 0) return;
      text = current.replaceRange(sel.start - 1, sel.start, '');
      caret = sel.start - 1;
    }

    setState(() {
      if (text.isEmpty) _shift = true;
    });
    _apply(text, caret);
  }

  void _onClear() {
    if (_controller.text.isEmpty) return;
    setState(() => _shift = true);
    _apply('', 0);
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

                // ONE column, the note directly above the board that types
                // into it. Landscape used to put the card and the keyboard in
                // opposite corners of a two-pane Row, which read as two
                // unrelated panels — you cannot see the field you are typing
                // into and the keys as one thing when they sit diagonally
                // apart. Stacked, they are a field and its keyboard, and the
                // same arrangement serves every orientation.
                //
                // The column is bounded on BOTH axes. Width alone is not
                // enough: the board's height follows from its width, so a wide
                // column on a short landscape window (1024x768) asked for more
                // height than the window had, squeezed the note field to its
                // floor and pushed CONTINUE off the bottom.
                final double column = _fittingColumn(
                  maxColumn: kioskBounded(
                    width - gutter * 2,
                    min: math.min(_kNoteMinColumn, width - gutter * 2),
                    max: math.min(1040.0, math.max(0.0, width - gutter * 2)),
                  ),
                  height: constraints.maxHeight,
                  gutter: gutter,
                );

                // Room left for the card once the board has taken its share.
                // Derived from the board's own module (see [_KeyMetrics]) —
                // never guessed at, which is the mistake that clipped the key
                // rows for so long.
                final double boardHeight = _KeyMetrics.of(column).height;
                final double cardRoom = constraints.maxHeight -
                    gutter * 3 -
                    boardHeight;

                return Center(
                  // Fits -> the pair is centred as one block. Does not fit (a
                  // short window) -> it scrolls rather than overflowing.
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
                          // No width passed on purpose: the panel measures the
                          // slot it is actually given.
                          _KeyboardPanel(
                            radius: (column * 0.02).clamp(12.0, 26.0),
                            shift: _shift,
                            onLetter: _onLetter,
                            onShift: () => setState(() => _shift = !_shift),
                            onBackspace: _onBackspace,
                            onSpace: () => _insert(' '),
                            onClear: _onClear,
                            onContinue: _save,
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
  /// pushing the keyboard off the bottom of the screen.
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
  ///
  /// The floor has to be stated in terms of what the customer can actually
  /// write in. A flat floor on the box was worth barely one line once the
  /// card's padding — which grows with the card — had taken its share, so a
  /// short landscape window ended up with a field that could not show the
  /// hint it was displaying.
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
              // Editable on purpose: the kiosk also runs as a web app on a
              // machine with a real keyboard, so both input paths have to work.
              // The on-screen keys write through the same controller/selection,
              // so the two stay in sync.
              autofocus: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              // Caps typed input the same way the on-screen keys are capped.
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

/// QWERTY keyboard + the pinned CONTINUE action.
/// The key module for a board [width] wide.
///
/// The board and every caller that has to leave room for it derive from this
/// one function, so the two can never disagree. Both bugs this screen has had
/// were exactly that kind of disagreement: a caller predicting a width the Row
/// did not give, and a layout that had no idea how tall the board would be.
class _KeyMetrics {
  final double pad;
  final double gap;
  final double keyWidth;
  final double keyHeight;
  final double keyRadius;
  final double letterSize;
  final double continueHeight;

  const _KeyMetrics._({
    required this.pad,
    required this.gap,
    required this.keyWidth,
    required this.keyHeight,
    required this.keyRadius,
    required this.letterSize,
    required this.continueHeight,
  });

  factory _KeyMetrics.of(double width) {
    // The top row's ten keys set the module the whole keyboard is built from,
    // so every row lines up regardless of screen width.
    final double pad = (width * 0.03).clamp(10.0, 26.0);
    final double gap = (width * 0.014).clamp(5.0, 12.0);
    final double keyWidth = (width - pad * 2 - gap * 9) / 10;
    // The ceilings stop the key going wide without going tall: past roughly a
    // 1900px board the letters and the key height would otherwise stay put and
    // a large display would draw a row of flat, under-set keys. Nothing below
    // that reaches them.
    final double keyHeight = (keyWidth * 0.86).clamp(38.0, 110.0);
    final double letterSize = (keyWidth * 0.36).clamp(13.0, 34.0);
    return _KeyMetrics._(
      pad: pad,
      gap: gap,
      keyWidth: keyWidth,
      keyHeight: keyHeight,
      keyRadius: (keyWidth * 0.18).clamp(6.0, 20.0),
      letterSize: letterSize,
      continueHeight: (keyHeight * 1.15).clamp(48.0, 126.0),
    );
  }

  /// Rows 2 and 3 are one and two keys short; they keep the same row span and
  /// centre themselves, exactly like a physical keyboard.
  double get row3KeyWidth => (keyWidth * 10 + gap * 9 - gap * 8) / 9;

  /// Half the row, for the Space / Clear pair.
  double get wideKeyWidth => (keyWidth * 10 + gap * 9 - gap) / 2;

  /// Four key rows, the gaps between them, and the CONTINUE button, plus the
  /// panel's own padding.
  double get height =>
      pad + keyHeight * 4 + gap * 3 + pad + continueHeight + pad * 0.9;
}

class _KeyboardPanel extends StatelessWidget {
  /// Corner radius of the panel itself — it is a floating card now, stacked
  /// under the note, rather than a full-bleed strip along the bottom.
  final double radius;
  final bool shift;
  final ValueChanged<String> onLetter;
  final VoidCallback onShift;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onClear;
  final VoidCallback onContinue;

  const _KeyboardPanel({
    required this.radius,
    required this.shift,
    required this.onLetter,
    required this.onShift,
    required this.onBackspace,
    required this.onSpace,
    required this.onClear,
    required this.onContinue,
  });

  static const List<String> _row1 = [
    'q',
    'w',
    'e',
    'r',
    't',
    'y',
    'u',
    'i',
    'o',
    'p'
  ];
  static const List<String> _row2 = [
    'a',
    's',
    'd',
    'f',
    'g',
    'h',
    'j',
    'k',
    'l'
  ];
  static const List<String> _row3 = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // The board is built from the width it is REALLY given. Deriving the key
      // module from a number passed in by the caller means the caller has to
      // predict the slot, and a caller that predicts it even slightly high
      // overflows every row at once — there is no give in a keyboard, ten keys
      // and nine gaps have to add up exactly.
      final _KeyMetrics m = _KeyMetrics.of(constraints.maxWidth);
      final double pad = m.pad;
      final double gap = m.gap;
      final double keyWidth = m.keyWidth;
      final double keyHeight = m.keyHeight;
      final double keyRadius = m.keyRadius;
      final double letterSize = m.letterSize;
      final double row3KeyWidth = m.row3KeyWidth;

        return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _kNoteKeyboardBg,
          borderRadius: BorderRadius.circular(radius),
        ),
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
                  width: m.wideKeyWidth,
                  height: keyHeight,
                  radius: keyRadius,
                  label: getTranslated('space', context) ?? 'Space',
                  fontSize: letterSize,
                  onTap: onSpace,
                ),
                _Key(
                  width: m.wideKeyWidth,
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
              height: (keyHeight * 1.15).clamp(48.0, 126.0),
              radius: keyRadius,
              fontSize: (letterSize * 1.05).clamp(14.0, 34.0),
              onTap: onContinue,
            ),
          ],
        ),
      );
    });
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
                size: fontSize * 1.15, color: dark ? Colors.white : _kNoteText)
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
