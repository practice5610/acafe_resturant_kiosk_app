import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/helper/email_checker_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';

/// Checkout step 2 — collect an optional receipt email (Figma node 655:3002).
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
      fieldBuilder: (s) => KioskCheckoutField(
        s: s,
        label: getTranslated('email_optional', context)?.toUpperCase() ??
            'EMAIL (OPTIONAL)',
        hint: getTranslated('enter_your_email', context)?.toUpperCase() ??
            'ENTER YOUR EMAIL',
        controller: _controller,
        focusNode: _focusNode,
        hasError: _showError,
        errorText:
            getTranslated('email_not_correct', context) ?? 'Email not correct',
        keyboardType: TextInputType.emailAddress,
        onChanged: (_) {
          if (_showError) setState(() => _showError = false);
        },
        onSubmitted: (_) => _next(),
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
