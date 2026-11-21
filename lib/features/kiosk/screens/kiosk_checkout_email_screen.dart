import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_keyboard.dart';
import 'package:acafe_customer/helper/email_checker_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Widest row of [KioskKeyboard] at scale 1 — the 10-key digit row: 10 keys
/// plus 9 inter-key gaps. Shared layout budget with the keyboard's chip rows.
const double _kKeyboardDesignWidth =
    KioskKeyboard.keyW * 10 + KioskKeyboard.keyGap * 9;

/// Symbol shortcuts (Figma node 2305:17084, keyboard-open state): the symbols
/// a kiosk customer most needs typing an email and cannot reach from the
/// letters-only board.
const List<String> _kSymbolChips = ['@', '.', '-', '_', '.com', '.nl', '.be'];

/// Full-domain shortcuts — one tap finishes the email after the local part.
const List<String> _kDomainChips = [
  '@gmail.com',
  '@hotmail.com',
  '@outlook.com',
  '@icloud.com',
];

/// Checkout step 2 — collect an optional receipt email (Figma node 655:3002,
/// keyboard-open state 2305:17084). Same on-screen [KioskKeyboard] as the name
/// step, plus two rows of email-specific chips (symbols, then full domains)
/// docked above it.
class KioskCheckoutEmailScreen extends StatefulWidget {
  const KioskCheckoutEmailScreen({super.key});

  @override
  State<KioskCheckoutEmailScreen> createState() =>
      _KioskCheckoutEmailScreenState();
}

class _KioskCheckoutEmailScreenState extends State<KioskCheckoutEmailScreen> {
  final TextEditingController _controller =
      TextEditingController(text: KioskSession.instance.customerEmail);
  final FocusNode _focusNode = FocusNode();
  bool _showError = false;

  /// Caps-lock state for the on-screen [KioskKeyboard].
  bool _shift = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // --- on-screen keyboard / chip editing -------------------------------------

  TextSelection get _emailSelection {
    final TextSelection sel = _controller.selection;
    if (!sel.isValid) {
      return TextSelection.collapsed(offset: _controller.text.length);
    }
    return sel;
  }

  void _onEmailChanged(String _) {
    if (_showError) setState(() => _showError = false);
  }

  void _insertFromKeyboard(String text) {
    final TextSelection sel = _emailSelection;
    final String next = _controller.text.replaceRange(sel.start, sel.end, text);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
    _onEmailChanged(next);
  }

  void _backspaceFromKeyboard() {
    final TextSelection sel = _emailSelection;
    if (sel.start != sel.end) {
      final String next = _controller.text.replaceRange(sel.start, sel.end, '');
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      _onEmailChanged(next);
      return;
    }
    if (sel.start <= 0) return;
    final String next =
        _controller.text.replaceRange(sel.start - 1, sel.start, '');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start - 1),
    );
    _onEmailChanged(next);
  }

  void _clearFromKeyboard() {
    _controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _onEmailChanged('');
  }

  void _next() {
    final email = _controller.text.trim();
    // Optional field: a non-empty value must be a valid email.
    if (email.isNotEmpty && EmailCheckerHelper.isNotValid(email)) {
      setState(() => _showError = true);
      return;
    }
    KioskSession.instance.customerEmail = email;
    RouterHelper.getKioskConfirmRoute();
  }

  void _skip() {
    KioskSession.instance.customerEmail = '';
    RouterHelper.getKioskConfirmRoute();
  }

  @override
  Widget build(BuildContext context) {
    return KioskCheckoutScaffold(
      activeStep: 1,
      title: getTranslated('want_a_receipt', context) ?? 'Want a receipt?',
      subtitle:
          getTranslated('well_send_your_receipt_to_this_address', context) ??
              "We'll send your receipt to this address.",
      subtitleFontSize: 44,
      fieldBuilder: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KioskCheckoutField(
            s: s,
            label: getTranslated('email_optional', context)?.toUpperCase() ??
                'EMAIL (OPTIONAL)',
            hint: getTranslated('enter_your_email', context)?.toUpperCase() ??
                'ENTER YOUR EMAIL',
            controller: _controller,
            focusNode: _focusNode,
            hasError: _showError,
            errorText: getTranslated('email_not_correct', context) ??
                'Email not correct',
            // Suppresses the platform keyboard — every key comes from the
            // on-screen board below — while the field stays editable.
            keyboardType: TextInputType.none,
            onChanged: _onEmailChanged,
            onSubmitted: (_) => _next(),
          ),
          SizedBox(height: 44 * s),
          // Keyboard + chip rows are laid out against the width this column
          // actually has (narrower than the scaffold's full 2572 artboard, so
          // reusing `s` straight would overflow them to the right — see
          // kiosk_checkout_name_screen.dart for the same fix).
          LayoutBuilder(
            builder: (context, constraints) {
              final double kbScale = math.min(
                s,
                constraints.maxWidth / _kKeyboardDesignWidth,
              );
              return Column(
                children: [
                  _ChipRow(s: kbScale, chips: _kSymbolChips, onTap: _insertFromKeyboard),
                  SizedBox(height: 20 * kbScale),
                  _ChipRow(s: kbScale, chips: _kDomainChips, onTap: _insertFromKeyboard),
                  SizedBox(height: 36 * kbScale),
                  KioskKeyboard(
                    s: kbScale,
                    shift: _shift,
                    onKey: _insertFromKeyboard,
                    onShift: () => setState(() => _shift = !_shift),
                    onBackspace: _backspaceFromKeyboard,
                    onSpace: () => _insertFromKeyboard(' '),
                    onClear: _clearFromKeyboard,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      bottomBuilder: (s) => Padding(
        padding: EdgeInsets.fromLTRB(74 * s, 16 * s, 74 * s, 24 * s),
        child: Row(
          children: [
            Expanded(
              child: KioskCheckoutButton(
                s: s,
                label: getTranslated('skip', context)?.toUpperCase() ?? 'SKIP',
                filled: false,
                onTap: _skip,
              ),
            ),
            SizedBox(width: 22 * s),
            Expanded(
              child: KioskCheckoutButton(
                s: s,
                label: getTranslated('next', context)?.toUpperCase() ?? 'NEXT',
                filled: true,
                onTap: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of email shortcuts (Figma 2305:17084) — every chip in the row is
/// an equal share of the row's width, same key height/radius/border as
/// [KioskKeyboard]'s own keys, so the row reads as part of the same board
/// rather than a free-floating pill list.
class _ChipRow extends StatelessWidget {
  final double s;
  final List<String> chips;
  final ValueChanged<String> onTap;

  const _ChipRow({required this.s, required this.chips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double gap = KioskKeyboard.keyGap * s;
    return Row(
      children: [
        for (int i = 0; i < chips.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(
            child: _EmailChip(
              s: s,
              label: chips[i],
              onTap: () => onTap(chips[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmailChip extends StatefulWidget {
  final double s;
  final String label;
  final VoidCallback onTap;

  const _EmailChip({required this.s, required this.label, required this.onTap});

  @override
  State<_EmailChip> createState() => _EmailChipState();
}

class _EmailChipState extends State<_EmailChip> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.s;
    final bool dark = _down;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          width: double.infinity,
          height: KioskKeyboard.keyH * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? Colors.black : KioskKeyboard.keyFill,
            borderRadius: BorderRadius.circular(KioskKeyboard.keyRadius * s),
            border: Border.all(
              color: KioskKeyboard.keyBorder,
              width: (KioskKeyboard.keyBorderWidth * s).clamp(1.0, 4.0),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8 * s),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.label,
                maxLines: 1,
                style: loewMedium.copyWith(
                  fontSize: KioskKeyboard.keyFont * s,
                  height: 1.0,
                  color:
                      dark ? KioskKeyboard.keyInverseInk : KioskKeyboard.keyInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
