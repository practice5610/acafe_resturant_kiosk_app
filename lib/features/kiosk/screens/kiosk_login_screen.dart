import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/response_model.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

/// One-time device login for the kiosk, styled to match the new design system
/// (Loew typography, #F7F1DE surface, #FBF8EF fields). The form is a centered
/// card capped at [kKioskFormDesignWidth]: it stays a comfortable size on large/kiosk
/// screens and scales down (via `s`) on smaller ones. After a successful login
/// the device is bound to its branch and goes to the Intro.

/// Warm cream surface shared with the menu screen (#F7F1DE) so the kiosk
/// login screen matches the branded menu background.
const Color _kLoginPageBg = Color(0xFFF7F1DE);

class KioskLoginScreen extends StatefulWidget {
  const KioskLoginScreen({super.key});

  @override
  State<KioskLoginScreen> createState() => _KioskLoginScreenState();
}

class _KioskLoginScreenState extends State<KioskLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscure = true;
  String? _usernameError;
  String? _passwordError;

  // NOTE: the login form is shown every time this screen is reached — even when a
  // valid device session is already stored. Staff must explicitly sign in (so a
  // kiosk can be re-bound / signed in as a different device). We intentionally do
  // NOT auto-skip to the menu on a stored session.

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final usernameEmpty = _usernameController.text.trim().isEmpty;
    final passwordEmpty = _passwordController.text.isEmpty;
    if (usernameEmpty || passwordEmpty) {
      setState(() {
        _usernameError = usernameEmpty ? 'Username is required' : null;
        _passwordError = passwordEmpty ? 'Password is required' : null;
      });
      return;
    }

    final provider = Provider.of<KioskAuthProvider>(context, listen: false);
    final ResponseModel response = await provider.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    if (response.isSuccess) {
      RouterHelper.getKioskWelcomeRoute(action: RouteAction.pushNamedAndRemoveUntil);
    }
    // On failure the error is shown inline via the provider's loginError.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kLoginPageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Form width is capped, so sizes stay comfortable on large screens
            // and shrink only when the screen is narrower than the cap.
            final double formWidth = constraints.maxWidth < kKioskFormDesignWidth
                ? constraints.maxWidth
                : kKioskFormDesignWidth;
            final double s = kioskFormScale(formWidth);

            return Consumer<KioskAuthProvider>(
              builder: (context, provider, _) {
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kKioskFormDesignWidth),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(40 * s, 64 * s, 40 * s, 56 * s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'A/CAFÉ',
                              textAlign: TextAlign.center,
                              style: loewExtraBold.copyWith(fontSize: 64 * s, letterSpacing: 3 * s, color: Colors.black),
                            ),
                            SizedBox(height: 14 * s),
                            Text(
                              'Device login',
                              textAlign: TextAlign.center,
                              style: loewMedium.copyWith(fontSize: 26 * s, color: Colors.black),
                            ),
                            SizedBox(height: 8 * s),
                            Opacity(
                              opacity: 0.6,
                              child: Text(
                                'Sign in once to bind this kiosk to its branch.',
                                textAlign: TextAlign.center,
                                style: loewRegular.copyWith(fontSize: 18 * s, height: 1.3, color: Colors.black),
                              ),
                            ),
                            SizedBox(height: 56 * s),
                            _LoginField(
                              s: s,
                              label: 'USERNAME',
                              hint: 'Enter username',
                              icon: Icons.person_outline,
                              controller: _usernameController,
                              focusNode: _usernameFocus,
                              errorText: _usernameError,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) {
                                if (_usernameError != null) setState(() => _usernameError = null);
                              },
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                            ),
                            SizedBox(height: 26 * s),
                            _LoginField(
                              s: s,
                              label: 'PASSWORD',
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              errorText: _passwordError,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.black54,
                                  size: 26 * s,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              onChanged: (_) {
                                if (_passwordError != null) setState(() => _passwordError = null);
                              },
                              onSubmitted: (_) => _submit(),
                            ),
                            if (provider.loginError.isNotEmpty) ...[
                              SizedBox(height: 24 * s),
                              _ErrorBanner(s: s, message: provider.loginError),
                            ],
                            SizedBox(height: 40 * s),
                            KioskPrimaryButton(
                              s: s,
                              label: 'LOGIN',
                              loading: provider.isLoading,
                              onTap: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// A labelled, rounded text field in the kiosk design system (with prefix icon
/// and optional suffix), plus an inline red error when [errorText] is set.
class _LoginField extends StatelessWidget {
  final double s;
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const _LoginField({
    required this.s,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.focusNode,
    this.errorText,
    this.obscureText = false,
    this.suffix,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: loewExtraBold.copyWith(fontSize: 22 * s, color: Colors.black)),
        SizedBox(height: 10 * s),
        Container(
          constraints: BoxConstraints(minHeight: 74 * s),
          padding: EdgeInsets.symmetric(horizontal: 24 * s),
          decoration: BoxDecoration(
            color: kCheckoutFieldBg,
            borderRadius: BorderRadius.circular(18 * s),
            border: Border.all(
              color: hasError ? kCheckoutErrorRed : kCheckoutHintColor,
              width: hasError ? (2.5 * s).clamp(1.5, 3.0) : (1.5 * s).clamp(1.0, 2.0),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.black, size: 26 * s),
              SizedBox(width: 16 * s),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscureText,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: textInputAction,
                  cursorColor: Colors.black,
                  style: loewRegular.copyWith(fontSize: 24 * s, color: Colors.black),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: loewRegular.copyWith(fontSize: 24 * s, color: kCheckoutHintColor),
                  ),
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                ),
              ),
              if (suffix != null) suffix!,
            ],
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 8 * s),
          Text(errorText!, style: loewMedium.copyWith(fontSize: 16 * s, color: kCheckoutErrorRed)),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final double s;
  final String message;
  const _ErrorBanner({required this.s, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 16 * s),
      decoration: BoxDecoration(
        color: kCheckoutErrorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18 * s),
        border: Border.all(color: kCheckoutErrorRed.withValues(alpha: 0.4), width: (1.5 * s).clamp(1.0, 2.0)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: kCheckoutErrorRed, size: 24 * s),
          SizedBox(width: 12 * s),
          Expanded(
            child: Text(message, style: loewMedium.copyWith(fontSize: 18 * s, height: 1.2, color: kCheckoutErrorRed)),
          ),
        ],
      ),
    );
  }
}
