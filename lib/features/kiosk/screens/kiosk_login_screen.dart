import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/response_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_intro_image.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_checkout_widgets.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

/// One-time device login for the kiosk: a fixed-width card, centred on both
/// axes, on the #F7F1DE page surface.
///
/// Nothing here scales with the window. Type, field height and the card width
/// are constants, so the form is the same physical object on a 375px browser
/// window, an 800x1280 portrait tablet and a 1920x1080 POS monitor — a wide
/// screen buys breathing room around the card, never a stretched form.
///
/// After a successful login the device is bound to its branch and goes to the
/// Intro.

// ---------------------------------------------------------------------------
// Layout constants. Spacing follows an 8 / 16 / 24 / 32 scale.
// ---------------------------------------------------------------------------

/// Width of the card from the tablet breakpoint upwards.
const double _kCardMaxWidth = 440;

/// Below this the card gives up its fixed width and takes ~90% of the screen.
const double _kNarrowBreakpoint = 600;

/// Above this the card keeps its width and simply gets more room around it.
const double _kWideBreakpoint = 1100;

/// Short windows (landscape tablets, a browser with the keyboard up) drop the
/// generous vertical rhythm so the card is never clipped.
const double _kCompactHeight = 700;

/// Minimum touch target on a kiosk screen — fields and the button.
const double _kControlHeight = 60;

const double _kCardRadius = 28;
const double _kFieldRadius = 18;

const Color _kCardBg = Color(0xFFFFFDF8);
const Color _kCardBorder = Color(0xFFE9E1CC);
const Color _kFieldBg = Colors.white;
const Color _kFieldBorder = Color(0xFFDDD4BA);

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

  bool _introWarmStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the next screen's artwork while staff type credentials — no UI
    // cost, and login → intro then hits Flutter's image cache.
    if (!_introWarmStarted) {
      _introWarmStarted = true;
      KioskIntroImage.warm(context);
    }
  }

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
    final passwordEmpty = _passwordController.text.trim().isEmpty;
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
      await context.read<CategoryProvider>().clearKioskMenu();
      if (!mounted) return;
      context.read<KioskDealProvider>().clearDeals();
      await RouterHelper.openKioskWelcome(
        context: context,
        action: RouteAction.pushNamedAndRemoveUntil,
      );
    }
    // On failure the error is shown inline via the provider's loginError.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Keyboard shrinks the body; the scroll view below takes care of the rest.
      resizeToAvoidBottomInset: true,
      backgroundColor: KioskUI.pageBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          final double height = constraints.maxHeight;

          final bool narrow = width < _kNarrowBreakpoint;
          final bool wide = width >= _kWideBreakpoint;
          final bool compact = height < _kCompactHeight;

          // Narrow: ~90% of the screen. Tablet and up: the fixed card width.
          final double cardWidth =
              narrow ? math.min(width * 0.9, _kCardMaxWidth) : _kCardMaxWidth;
          final double gutter = narrow
              ? 16.0
              : wide
                  ? 64.0
                  : 32.0;

          return DecoratedBox(
            // A large display gets a barely-there wash instead of a flat field
            // of cream around the card.
            decoration: BoxDecoration(
              gradient: wide
                  ? const RadialGradient(
                      center: Alignment.center,
                      radius: 0.95,
                      colors: [Color(0xFFFCF8EC), KioskUI.pageBg],
                    )
                  : null,
              color: wide ? null : KioskUI.pageBg,
            ),
            child: SafeArea(
              child: Consumer<KioskAuthProvider>(
                builder: (context, provider, _) {
                  // Centre on both axes; scroll only when the card cannot fit.
                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: gutter,
                        vertical: compact ? 24 : 40,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardWidth),
                        child:
                            _card(provider, narrow: narrow, compact: compact),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card(
    KioskAuthProvider provider, {
    required bool narrow,
    required bool compact,
  }) {
    return Container(
      // Named so the layout test can measure the card itself.
      key: const ValueKey('kioskLoginCard'),
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 24 : 32,
        vertical: compact ? 32 : 40,
      ),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _kCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 40,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Wordmark. scaleDown only guards a pathologically narrow window; it
          // is at its full size on every real device.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'A/CAFÉ',
              maxLines: 1,
              style: loewExtraBold.copyWith(
                fontSize: compact ? 38 : 48,
                letterSpacing: 2,
                height: 1.1,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : 16),
          Text(
            'Device login',
            textAlign: TextAlign.center,
            style: loewMedium.copyWith(fontSize: 22, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: 0.6,
            child: Text(
              'Sign in once to bind this kiosk to its branch.',
              textAlign: TextAlign.center,
              style: loewRegular.copyWith(
                fontSize: 15,
                height: 1.35,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: compact ? 24 : 32),
          _LoginField(
            label: 'USERNAME',
            hint: 'Enter username',
            icon: Icons.person_outline,
            controller: _usernameController,
            focusNode: _usernameFocus,
            errorText: _usernameError,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_usernameError != null) {
                setState(() => _usernameError = null);
              }
            },
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 24),
          _LoginField(
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
                size: 22,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            onChanged: (_) {
              if (_passwordError != null) {
                setState(() => _passwordError = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
          if (provider.loginError.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ErrorBanner(message: provider.loginError),
          ],
          SizedBox(height: compact ? 24 : 32),
          _LoginButton(loading: provider.isLoading, onTap: _submit),
        ],
      ),
    );
  }
}

/// A labelled, rounded text field in the kiosk design system (with prefix icon
/// and optional suffix), plus an inline red error when [errorText] is set.
///
/// Metrics are fixed: [_kControlHeight] tall and 17pt text on every screen.
class _LoginField extends StatelessWidget {
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
        Text(
          label,
          style: loewExtraBold.copyWith(
            fontSize: 14,
            letterSpacing: 1,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: _kControlHeight),
          padding: EdgeInsets.only(left: 18, right: suffix == null ? 18 : 8),
          decoration: BoxDecoration(
            color: _kFieldBg,
            borderRadius: BorderRadius.circular(_kFieldRadius),
            border: Border.all(
              color: hasError ? kCheckoutErrorRed : _kFieldBorder,
              width: hasError ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.black, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscureText,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: textInputAction,
                  cursorColor: Colors.black,
                  style:
                      loewRegular.copyWith(fontSize: 17, color: Colors.black),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: loewRegular.copyWith(
                        fontSize: 17, color: kCheckoutHintColor),
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
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: loewMedium.copyWith(fontSize: 14, color: kCheckoutErrorRed),
          ),
        ],
      ],
    );
  }
}

/// Black primary action, [_kControlHeight] tall on every screen.
class _LoginButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _LoginButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(_kFieldRadius),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: loading ? null : onTap,
        child: SizedBox(
          height: _kControlHeight,
          width: double.infinity,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(kCheckoutButtonText),
                    ),
                  )
                : Text(
                    'LOGIN',
                    style: loewExtraBold.copyWith(
                      fontSize: 18,
                      letterSpacing: 1.4,
                      color: kCheckoutButtonText,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kCheckoutErrorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_kFieldRadius),
        border: Border.all(color: kCheckoutErrorRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kCheckoutErrorRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: loewMedium.copyWith(
                  fontSize: 15, height: 1.25, color: kCheckoutErrorRed),
            ),
          ),
        ],
      ),
    );
  }
}
