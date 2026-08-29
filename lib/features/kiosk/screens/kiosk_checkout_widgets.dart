import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:go_router/go_router.dart';

// ===========================================================================
// Shared building blocks for the kiosk checkout flow (NAME / EMAIL / PAYMENT),
// ported from the Figma designs (nodes 655:2924, 655:3002, …). All sizes come
// from the 2572px-wide artboard and are scaled by `KioskResponsive.scale`.
// Scale logic lives in lib/common/responsive/kiosk_responsive.dart (single
// source of truth); the helpers below delegate to it and are kept for the
// call sites across the checkout / login / language screens.
// ===========================================================================
const double kKioskFormDesignWidth = KioskResponsive.formDesignWidth;
const Color kCheckoutFieldBg = Color(0xFFFBF8EF);
const Color kCheckoutErrorRed = Color(0xFFEF4444);
const Color kCheckoutHintColor = Color(0xFFB9B5A6);
const Color kCheckoutButtonText = Color(0xFFFAF9F5);

bool _goRouterCanPop(BuildContext context) {
  try {
    return GoRouter.of(context).canPop();
  } catch (_) {
    return false;
  }
}

double checkoutScale(double w, [double? h]) => KioskResponsive.scale(w, h);

/// Form screens (login, language picker) cap content at [kKioskFormDesignWidth].
double kioskFormScale(double screenWidth) =>
    KioskResponsive.formScale(screenWidth);

/// Shared row height + corner radius — login button, language rows, save, etc.
double kioskPrimaryRowHeight(double s) => 74 * s;
double kioskPrimaryRowRadius(double s) => 18 * s;

/// Black filled primary action — full width of parent, login-sized footprint.
class KioskPrimaryButton extends StatelessWidget {
  final double s;
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final IconData? icon;

  const KioskPrimaryButton({
    super.key,
    required this.s,
    required this.label,
    this.loading = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(kioskPrimaryRowRadius(s)),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: double.infinity,
          height: kioskPrimaryRowHeight(s),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 30 * s,
                    height: 30 * s,
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(kCheckoutButtonText),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 26 * s, color: kCheckoutButtonText),
                        SizedBox(width: 14 * s),
                      ],
                      Text(
                        label,
                        style: loewExtraBold.copyWith(
                          fontSize: 24 * s,
                          letterSpacing: 1.5 * s,
                          color: kCheckoutButtonText,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// White selectable row — same width/height as [KioskPrimaryButton].
class KioskSelectableRow extends StatelessWidget {
  final double s;
  final String label;
  final String? leadingAsset;
  final bool selected;
  final VoidCallback onTap;

  const KioskSelectableRow({
    super.key,
    required this.s,
    required this.label,
    this.leadingAsset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double flagSize = 48 * s;
    return KioskTap(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: kioskPrimaryRowHeight(s),
        padding: EdgeInsets.symmetric(horizontal: 20 * s),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kioskPrimaryRowRadius(s)),
          border: selected
              ? Border.all(color: Colors.black, width: (2 * s).clamp(1.5, 2.5))
              : null,
        ),
        child: Row(
          children: [
            if (leadingAsset != null && leadingAsset!.isNotEmpty) ...[
              ClipOval(
                child: Image.asset(
                  leadingAsset!,
                  width: flagSize,
                  height: flagSize,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 16 * s),
            ],
            Expanded(
              child: Text(
                label,
                style: loewBold.copyWith(
                  fontSize: 24 * s,
                  height: 1.1,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page layout shared by every checkout step: back button + stepper, a centered
/// title/subtitle prompt, a scrollable field area and a pinned bottom bar.
class KioskCheckoutScaffold extends StatelessWidget {
  final int activeStep; // 0 = NAME, 1 = EMAIL, 2 = PAYMENT
  final String title;
  final String subtitle;
  final double subtitleFontSize;

  /// Builds the label + field + error block (needs the resolved scale).
  final Widget Function(double s) fieldBuilder;

  /// Builds the bottom button bar (one or more [KioskCheckoutButton]s).
  final Widget Function(double s) bottomBuilder;

  const KioskCheckoutScaffold({
    super.key,
    required this.activeStep,
    required this.title,
    required this.subtitle,
    required this.fieldBuilder,
    required this.bottomBuilder,
    this.subtitleFontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop() || _goRouterCanPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          KioskNavigationHelper.popOrNavigate(
            context,
            fallback: RouterHelper.getKioskCartRoute,
          );
        }
      },
      child: Scaffold(
        backgroundColor: KioskUI.pageBg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double s = KioskMetrics.maybeOf(context)?.scale ??
                  checkoutScale(constraints.maxWidth, constraints.maxHeight);
              final bool landscape =
                  constraints.maxWidth > constraints.maxHeight;
              // 62% of a medium landscape window can sit below the 720 floor —
              // use kioskBounded so the column shrinks instead of crashing.
              final double columnMax = landscape
                  ? kioskBounded(
                      constraints.maxWidth * 0.62,
                      min: math.min(720.0, constraints.maxWidth),
                      max: math.min(1600.0, constraints.maxWidth),
                    )
                  : KioskResponsive.designWidth;
              return KioskCenteredContent(
                maxWidth: columnMax,
                child: Column(
                  children: [
                    KioskCheckoutHeader(s: s, activeStep: activeStep),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 107 * s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: landscape ? 48 * s : 150 * s),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: loewExtraBold.copyWith(
                                  fontSize: 128 * s,
                                  height: 1,
                                  color: Colors.black),
                            ),
                            SizedBox(height: 30 * s),
                            Opacity(
                              opacity: 0.75,
                              child: Text(
                                subtitle,
                                textAlign: TextAlign.center,
                                style: loewMedium.copyWith(
                                    fontSize: subtitleFontSize * s,
                                    height: 1.2,
                                    color: Colors.black),
                              ),
                            ),
                            SizedBox(height: landscape ? 80 * s : 380 * s),
                            fieldBuilder(s),
                            SizedBox(height: 100 * s),
                          ],
                        ),
                      ),
                    ),
                    bottomBuilder(s),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Back button + the NAME / EMAIL / PAYMENT progress stepper.
class KioskCheckoutHeader extends StatelessWidget {
  final double s;
  final int activeStep;
  const KioskCheckoutHeader(
      {super.key, required this.s, required this.activeStep});

  static const List<String> _steps = ['NAME', 'EMAIL', 'PAYMENT'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(107 * s, 121 * s, 107 * s, 20 * s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KioskBackButton.scaled(
            s: s,
            size: 141,
            border: 4,
            icon: 56,
            minBorder: 2,
            fallback: RouterHelper.getKioskCartRoute,
          ),
          SizedBox(width: 60 * s),
          Expanded(
              child: _Stepper(s: s, steps: _steps, activeStep: activeStep)),
          SizedBox(
              width: 141 *
                  s), // balance the back button so the stepper stays centred.
        ],
      ),
    );
  }
}

enum _StepState { completed, active, upcoming }

class _Stepper extends StatelessWidget {
  final double s;
  final List<String> steps;
  final int activeStep;
  const _Stepper(
      {required this.s, required this.steps, required this.activeStep});

  @override
  Widget build(BuildContext context) {
    final List<Widget> row = [];
    for (int i = 0; i < steps.length; i++) {
      row.add(_StepNode(s: s, label: steps[i], state: _stateOf(i)));
      if (i < steps.length - 1) row.add(Expanded(child: _Connector(s: s)));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: row);
  }

  _StepState _stateOf(int i) {
    if (i < activeStep) return _StepState.completed;
    if (i == activeStep) return _StepState.active;
    return _StepState.upcoming;
  }
}

class _StepNode extends StatelessWidget {
  final double s;
  final String label;
  final _StepState state;
  const _StepNode({required this.s, required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final double d = 165 * s;
    final bool filled = state != _StepState.upcoming;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.black : Colors.transparent,
            border:
                Border.all(color: Colors.black, width: (4 * s).clamp(2.0, 6.0)),
          ),
          child: switch (state) {
            // Active: a page-bg dot inside the filled black circle.
            _StepState.active => Container(
                width: 79 * s,
                height: 79 * s,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: KioskUI.pageBg)),
            _StepState.completed =>
              Icon(Icons.check, size: 90 * s, color: Colors.white),
            _StepState.upcoming => null,
          },
        ),
        SizedBox(height: 24 * s),
        Text(label,
            style:
                loewExtraBold.copyWith(fontSize: 46 * s, color: Colors.black)),
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  final double s;
  const _Connector({required this.s});

  @override
  Widget build(BuildContext context) {
    // Sit on the circle's vertical centre (circle is 165px tall).
    return Padding(
      padding: EdgeInsets.only(top: 82 * s, left: 20 * s, right: 20 * s),
      child: Container(height: (4 * s).clamp(2.0, 6.0), color: Colors.black),
    );
  }
}

/// Centered label + rounded input + optional inline error. The border turns red
/// when [hasError] is set.
class KioskCheckoutField extends StatelessWidget {
  final double s;
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool hasError;
  final String? errorText;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const KioskCheckoutField({
    super.key,
    required this.s,
    required this.label,
    required this.hint,
    required this.controller,
    this.focusNode,
    this.hasError = false,
    this.errorText,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: loewExtraBold.copyWith(fontSize: 72 * s, color: Colors.black),
        ),
        SizedBox(height: 30 * s),
        Container(
          constraints: BoxConstraints(minHeight: 252 * s),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 64 * s),
          decoration: BoxDecoration(
            color: kCheckoutFieldBg,
            borderRadius: BorderRadius.circular(30 * s),
            border: Border.all(
              color: hasError ? kCheckoutErrorRed : kCheckoutHintColor,
              width:
                  hasError ? (4 * s).clamp(2.0, 6.0) : (2 * s).clamp(1.0, 4.0),
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            textAlign: TextAlign.center,
            cursorColor: Colors.black,
            style: loewRegular.copyWith(fontSize: 64 * s, color: Colors.black),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: loewRegular.copyWith(
                  fontSize: 64 * s, color: kCheckoutHintColor),
            ),
            onChanged: onChanged,
            onSubmitted: onSubmitted,
          ),
        ),
        if (hasError && errorText != null) ...[
          SizedBox(height: 28 * s),
          Text(
            errorText!,
            style: loewMedium.copyWith(
                fontSize: 44 * s, height: 1.1, color: kCheckoutErrorRed),
          ),
        ],
      ],
    );
  }
}

/// Reusable checkout action button — filled (black) or outlined.
class KioskCheckoutButton extends StatelessWidget {
  final double s;
  final String label;
  final bool filled;
  final double fontSize;

  /// Skip the shared wide-screen button and always render the scaled artboard
  /// one. The customize screen's bar is part of its Figma frame — it scales
  /// with the page, so snapping it to a fixed 60px control at the 1100px seam
  /// would break the design it sits in.
  final bool forceScaled;
  final VoidCallback? onTap;
  const KioskCheckoutButton({
    super.key,
    required this.s,
    required this.label,
    required this.filled,
    required this.onTap,
    this.fontSize = 72,
    this.forceScaled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: filled ? Colors.black : Colors.transparent,
        borderRadius: BorderRadius.circular(30 * s),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: onTap,
          child: Container(
            height: 252 * s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30 * s),
              border: filled
                  ? null
                  : Border.all(
                      color: Colors.black, width: (8 * s).clamp(2.0, 10.0)),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (filled ? loewExtraBold : loewBold).copyWith(
                fontSize: fontSize * s,
                height: 1.0,
                color: filled ? kCheckoutButtonText : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

