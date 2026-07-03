import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';

/// Checkout step 1 — collect the customer name (Figma node 655:2924). The
/// focused [TextField] raises the on-screen keyboard automatically on a kiosk.
class KioskCheckoutNameScreen extends StatefulWidget {
  const KioskCheckoutNameScreen({super.key});

  @override
  State<KioskCheckoutNameScreen> createState() => _KioskCheckoutNameScreenState();
}

class _KioskCheckoutNameScreenState extends State<KioskCheckoutNameScreen> {
  final TextEditingController _controller =
      TextEditingController(text: KioskSession.instance.customerName);
  final FocusNode _focusNode = FocusNode();
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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
      fieldBuilder: (s) => KioskCheckoutField(
        s: s,
        label: getTranslated('name', context)?.toUpperCase() ?? 'NAME',
        hint: getTranslated('enter_your_name', context)?.toUpperCase() ?? 'ENTER YOUR NAME',
        controller: _controller,
        focusNode: _focusNode,
        hasError: _showError,
        errorText: getTranslated('please_enter_your_name_to_continue', context) ??
            'Please enter your name to continue',
        textCapitalization: TextCapitalization.words,
        onChanged: (_) {
          if (_showError) setState(() => _showError = false);
        },
        onSubmitted: (_) => _next(),
      ),
      bottomBuilder: (s) => Padding(
        padding: EdgeInsets.fromLTRB(107 * s, 16 * s, 107 * s, 24 * s),
        child: KioskCheckoutButton(
          s: s,
          label: getTranslated('next', context) ?? 'Next',
          filled: true,
          fontSize: 64,
          onTap: _next,
        ),
      ),
    );
  }
}
