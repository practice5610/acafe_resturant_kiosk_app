import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_keyboard.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';

/// Checkout step 1 — collect the customer name (Figma node 655:2924,
/// keyboard-open state 2305:16610). Same on-screen [KioskKeyboard] pattern as
/// the coupon screen: `TextInputType.none` keeps the field genuinely editable
/// (a hardware keyboard still types into it) while every visible key comes
/// from the board docked under the field.
class KioskCheckoutNameScreen extends StatefulWidget {
  const KioskCheckoutNameScreen({super.key});

  @override
  State<KioskCheckoutNameScreen> createState() =>
      _KioskCheckoutNameScreenState();
}

class _KioskCheckoutNameScreenState extends State<KioskCheckoutNameScreen> {
  final TextEditingController _controller =
      TextEditingController(text: KioskSession.instance.customerName);
  final FocusNode _focusNode = FocusNode();
  bool _showError = false;

  /// Caps-lock state for the on-screen [KioskKeyboard].
  bool _shift = true;

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

  // --- on-screen keyboard editing -------------------------------------------

  TextSelection get _nameSelection {
    final TextSelection sel = _controller.selection;
    if (!sel.isValid) {
      return TextSelection.collapsed(offset: _controller.text.length);
    }
    return sel;
  }

  void _onNameChanged(String _) {
    if (_showError) setState(() => _showError = false);
  }

  void _insertFromKeyboard(String text) {
    final TextSelection sel = _nameSelection;
    final String next = _controller.text.replaceRange(sel.start, sel.end, text);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
    _onNameChanged(next);
  }

  void _backspaceFromKeyboard() {
    final TextSelection sel = _nameSelection;
    if (sel.start != sel.end) {
      final String next = _controller.text.replaceRange(sel.start, sel.end, '');
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      _onNameChanged(next);
      return;
    }
    if (sel.start <= 0) return;
    final String next =
        _controller.text.replaceRange(sel.start - 1, sel.start, '');
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start - 1),
    );
    _onNameChanged(next);
  }

  void _clearFromKeyboard() {
    _controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _onNameChanged('');
  }

  void _next() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    KioskSession.instance.customerName = name;
    RouterHelper.getKioskCheckoutEmailRoute();
  }

  @override
  Widget build(BuildContext context) {
    return KioskCheckoutScaffold(
      activeStep: 0,
      title: "What's your name?",
      subtitle: "We'll use your name when your order is ready for pick up.",
      subtitleFontSize: 48,
      // Same subtitle -> field gap as the email step (the scaffold default).
      fieldBuilder: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KioskCheckoutField(
            s: s,
            label: getTranslated('name', context)?.toUpperCase() ?? 'NAME',
            hint: getTranslated('enter_your_name', context)?.toUpperCase() ??
                'ENTER YOUR NAME',
            controller: _controller,
            focusNode: _focusNode,
            hasError: _showError,
            errorText:
                getTranslated('please_enter_your_name_to_continue', context) ??
                    'Please enter your name to continue',
            // Suppresses the platform keyboard — every key comes from the
            // on-screen board below — while the field stays editable.
            keyboardType: TextInputType.none,
            textCapitalization: TextCapitalization.words,
            onChanged: _onNameChanged,
            onSubmitted: (_) => _next(),
          ),
        ],
      ),
      // Figma 2305:16633 — full-bleed panel, no digit row, 40/48/26 spacing.
      panelBuilder: (s) => KioskKeyboardPanel(
        s: s,
        builder: (ks) => KioskKeyboard(
          s: ks,
          shift: _shift,
          showDigitRow: false,
          rowGapDesign: 40,
          spaceRowGapDesign: 48,
          spaceClearGapDesign: 26,
          onKey: _insertFromKeyboard,
          onShift: () => setState(() => _shift = !_shift),
          onBackspace: _backspaceFromKeyboard,
          onSpace: () => _insertFromKeyboard(' '),
          onClear: _clearFromKeyboard,
        ),
      ),
      bottomActions: [
        KioskBarAction(
          label: getTranslated('next', context) ?? 'Next',
          filled: true,
          onTap: _next,
        ),
      ],
    );
  }
}
