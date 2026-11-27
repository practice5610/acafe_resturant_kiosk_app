import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_chrome_spec.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_navigation_helper.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';

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

/// Was `#EF4444` (3.8:1 on white): too light for an error message.
const Color kCheckoutErrorRed = TextTones.danger;

/// Was `#B9B5A6` (2:1): placeholders read as empty fields.
const Color kCheckoutHintColor = TextTones.hint;
const Color kCheckoutButtonText = Color(0xFFFAF9F5);

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

  /// Artboard px between the subtitle and the field label (Figma: name step
  /// 507, email step ~393).
  final double fieldGap;

  /// Optional full-bleed block under the field (the name step's keyboard
  /// panel, Figma 2305:16633). Sits outside the 107px content gutters.
  final Widget Function(double s)? panelBuilder;

  /// Artboard px between the field and [panelBuilder] (Figma: 195).
  final double panelGap;

  /// Builds the label + field + error block (needs the resolved scale).
  final Widget Function(double s) fieldBuilder;

  /// The bottom bar's buttons (one or two). The scaffold builds the shared
  /// [KioskActionBar] from them at the chrome scale.
  final List<KioskBarAction> bottomActions;

  const KioskCheckoutScaffold({
    super.key,
    required this.activeStep,
    required this.title,
    required this.subtitle,
    required this.fieldBuilder,
    required this.bottomActions,
    this.subtitleFontSize = 48,
    this.fieldGap = 380,
    this.panelBuilder,
    this.panelGap = 195,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System/browser back takes the same explicit step as the on-screen
      // arrow, so the two can never disagree.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          KioskNavigationHelper.backTo(
              context, KioskCheckoutHeader.parentPathOf(activeStep));
        }
      },
      child: Scaffold(
        backgroundColor: KioskUI.pageBg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool landscape =
                  constraints.maxWidth > constraints.maxHeight;
              final double s = KioskMetrics.maybeOf(context)?.scale ??
                  checkoutScale(constraints.maxWidth, constraints.maxHeight);
              final double columnMax = landscape
                  ? kioskReadingColumnWidth(
                      width: constraints.maxWidth, landscape: true)
                  : KioskResponsive.designWidth;
              return KioskCenteredContent(
                maxWidth: columnMax,
                child: Column(
                  children: [
                    KioskCheckoutHeader(activeStep: activeStep),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 107 * s),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Figma: header ends ~396, title top 559.
                                  SizedBox(height: landscape ? 48 * s : 163 * s),
                                  Text(
                                    title,
                                    textAlign: TextAlign.center,
                                    style: loewExtraBold.copyWith(
                                        fontSize: 128 * s,
                                        height: 1,
                                        color: Colors.black),
                                  ),
                                  SizedBox(height: 27 * s),
                                  Text(
                                    subtitle,
                                    textAlign: TextAlign.center,
                                    style: loewMedium.copyWith(
                                        fontSize: subtitleFontSize * s,
                                        height: 1.2,
                                        color: TextTones.secondary),
                                  ),
                                  SizedBox(
                                      height:
                                          landscape ? 80 * s : fieldGap * s),
                                  fieldBuilder(s),
                                ],
                              ),
                            ),
                            if (panelBuilder != null) ...[
                              SizedBox(height: panelGap * s),
                              panelBuilder!(s),
                            ],
                            SizedBox(height: 100 * s),
                          ],
                        ),
                      ),
                    ),
                    KioskActionBar(
                      s: KioskChrome.scaleOf(context),
                      actions: bottomActions,
                    ),
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
///
/// A `Row`: the shared [KioskBackButton], a fixed gap, then the stepper in an
/// `Expanded`. The stepper therefore starts after the back button
/// structurally, so the two cannot overlap at any width; when the room left is
/// narrower than the stepper's natural width it scales down to fit rather than
/// reaching back under the button. Moving between the steps animates only this
/// row: the step pages swap instantly (see RouterHelper._kioskStepPage) and the
/// circles fill / tick / draw in here.
///
/// Back button size and insets are chrome ([KioskChromeSpec]) at the shared
/// chrome scale, identical to every other screen.
class KioskCheckoutHeader extends StatefulWidget {
  final int activeStep;

  const KioskCheckoutHeader({
    super.key,
    required this.activeStep,
  });

  static const List<String> _steps = ['NAME', 'EMAIL', 'PAYMENT'];

  /// The screen each step came from: name <- cart, email <- name,
  /// order summary <- email.
  static String parentPathOf(int step) {
    switch (step) {
      case 2:
        return RouterHelper.kioskCheckoutEmailScreen;
      case 1:
        return RouterHelper.kioskCheckoutScreen;
      default:
        return RouterHelper.kioskCartScreen;
    }
  }

  // Stepper geometry, artboard px (Figma 2305:16610).
  static const double _circle = 100;
  static const double _circleStroke = 4;
  // The circles' centres sit on the back button's centre line.
  // 40 design px between circle and label (Figma: 47 on a 165 circle).
  static const double _labelGap = 40;
  static const double _labelH = 48;
  static const double _groupW = 1398;
  // Circle centres inside the group, connectors between.
  static const List<double> _centers = [82.5, 726, 1315.5];
  static const double _connW = 252.5;

  @override
  State<KioskCheckoutHeader> createState() => _KioskCheckoutHeaderState();
}

class _KioskCheckoutHeaderState extends State<KioskCheckoutHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  double _from = 0;
  Animation<double>? _secondary;

  @override
  void initState() {
    super.initState();
    _from = widget.activeStep.toDouble();
    _ctrl.value = 1;
    // Arriving from the previous step: play previous -> this one.
    if (widget.activeStep > 0) _play(widget.activeStep - 1);
  }

  void _play(int from) {
    _from = from.toDouble();
    _ctrl.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When the page above this one is popped (back from the next step) this
    // page is revealed again without being rebuilt: play next -> this one.
    final Animation<double>? sec = ModalRoute.of(context)?.secondaryAnimation;
    if (!identical(sec, _secondary)) {
      _secondary?.removeStatusListener(_onSecondary);
      sec?.addStatusListener(_onSecondary);
      _secondary = sec;
    }
  }

  void _onSecondary(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        mounted &&
        widget.activeStep < 2) {
      _play(widget.activeStep + 1);
    }
  }

  @override
  void dispose() {
    _secondary?.removeStatusListener(_onSecondary);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double cs = KioskChrome.scaleOf(context);
    final double back = KioskBackButton.diameterFor(context, cs);
    // The circles' centres sit on the back button's centre line, whatever its
    // size (the back button is 10% larger on portrait).
    final double backArt =
        KioskChromeSpec.backDiameter * KioskChrome.backFactorOf(context);
    final double circleTop = (backArt - KioskCheckoutHeader._circle) / 2;
    final double labelTop =
        circleTop + KioskCheckoutHeader._circle + KioskCheckoutHeader._labelGap;
    final double gap = KioskChromeSpec.backToContentGap * cs;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KioskChromeSpec.insetLeft * cs,
        KioskChromeSpec.insetTop * cs,
        KioskChromeSpec.insetLeft * cs,
        20 * cs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KioskBackButton(
            s: cs,
            onTap: () => KioskNavigationHelper.backTo(
                context, KioskCheckoutHeader.parentPathOf(widget.activeStep)),
          ),
          SizedBox(width: gap),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: KioskCheckoutHeader._groupW * cs,
                height: (labelTop + KioskCheckoutHeader._labelH) * cs,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final double p = _from +
                        (widget.activeStep - _from) *
                            Curves.easeInOutCubic.transform(_ctrl.value);
                    return _Stepper(
                        s: cs, p: p, circleTop: circleTop, labelTop: labelTop);
                  },
                ),
              ),
            ),
          ),
          // Balances the back button so the stepper stays optically centred.
          SizedBox(width: back + gap),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final double s;

  /// Continuous progress: 0 = NAME active, 1 = EMAIL, 2 = PAYMENT.
  final double p;
  final double circleTop;
  final double labelTop;
  const _Stepper({
    required this.s,
    required this.p,
    required this.circleTop,
    required this.labelTop,
  });

  @override
  Widget build(BuildContext context) {
    const double cw = KioskCheckoutHeader._circle;
    const double lw = 350;
    const List<double> c = KioskCheckoutHeader._centers;
    final double stroke =
        (KioskCheckoutHeader._circleStroke * s).clamp(1.0, 6.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int i = 0; i < 2; i++)
          Positioned(
            left: ((c[i] + c[i + 1]) / 2 - KioskCheckoutHeader._connW / 2) * s,
            top: (circleTop + cw / 2) * s - stroke / 2,
            width: KioskCheckoutHeader._connW * s,
            child: Container(height: stroke, color: Colors.black),
          ),
        for (int i = 0; i < 3; i++) ...[
          Positioned(
            left: (c[i] - cw / 2) * s,
            top: circleTop * s,
            child: _StepNode(s: s, stroke: stroke, p: p, index: i),
          ),
          Positioned(
            left: (c[i] - lw / 2) * s,
            top: labelTop * s,
            width: lw * s,
            child: Text(
              KioskCheckoutHeader._steps[i],
              textAlign: TextAlign.center,
              maxLines: 1,
              style: loewExtraBold.copyWith(
                  fontSize: 40 * s, height: 1, color: Colors.black),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  final double s;
  final double stroke;
  final double p;
  final int index;
  const _StepNode(
      {required this.s,
      required this.stroke,
      required this.p,
      required this.index});

  @override
  Widget build(BuildContext context) {
    final double d = KioskCheckoutHeader._circle * s;
    final double reached = (p - index + 1).clamp(0.0, 1.0);
    final double dot = (1 - (p - index).abs()).clamp(0.0, 1.0);
    final double done = (p - index).clamp(0.0, 1.0);
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(Colors.transparent, Colors.black, reached),
        border: Border.all(color: Colors.black, width: stroke),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Active: a page-bg dot inside the filled black circle.
          Container(
            width: 48 * s * dot,
            height: 48 * s * dot,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: KioskUI.pageBg),
          ),
          // Completed: tick.
          Opacity(
            opacity: done,
            child: Transform.scale(
              scale: 0.5 + 0.5 * done,
              child: Icon(Icons.check, size: 56 * s, color: Colors.white),
            ),
          ),
        ],
      ),
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
          style: loewExtraBold.copyWith(
              fontSize: 72 * s, height: 1.2, color: Colors.black),
        ),
        // Figma: label top -> field top is ~141 (86 line + 55).
        SizedBox(height: 55 * s),
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

/// Reusable action button — filled (black) or outlined.
///
/// No size or type overrides: height, radius, border and label come from
/// [KioskChromeSpec] at the chrome scale [s]. Use it through [KioskActionBar].
class KioskCheckoutButton extends StatelessWidget {
  /// Chrome scale ([KioskChrome.scaleOf]).
  final double s;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  /// When set, a disabled FILLED button renders as a `rgba(0,0,0,0.25)` fill
  /// with the cream label still showing (Figma step-flow NEXT), instead of the
  /// default 0.5-opacity dim. Opt-in so other callers are unchanged.
  final bool disabledUsesFillAlpha;

  /// Shows a spinner in place of the label. A loading button is inert but is
  /// not dimmed, so the customer sees work in progress rather than "disabled".
  final bool loading;

  const KioskCheckoutButton({
    super.key,
    required this.s,
    required this.label,
    required this.filled,
    required this.onTap,
    this.disabledUsesFillAlpha = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;
    final bool figmaDisabled = disabled && filled && disabledUsesFillAlpha;
    final double radius = KioskChromeSpec.barRadius * s;
    final Color ink = filled ? kCheckoutButtonText : Colors.black;
    final double fontSize = KioskChromeSpec.barFontSize * s;
    return Opacity(
      opacity: (disabled && !figmaDisabled && !loading) ? 0.5 : 1,
      child: Material(
        color: filled
            ? (figmaDisabled
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: onTap,
          child: Container(
            height: KioskChromeSpec.barHeight * s,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: filled
                  ? null
                  : Border.all(
                      color: Colors.black,
                      width: KioskChromeSpec.barBorderWidth(s)),
            ),
            child: loading
                ? SizedBox(
                    width: fontSize,
                    height: fontSize,
                    child: CircularProgressIndicator(
                      strokeWidth: (KioskChromeSpec.barBorder * s)
                          .clamp(1.0, KioskChromeSpec.barBorder)
                          .toDouble(),
                      valueColor: AlwaysStoppedAnimation<Color>(ink),
                    ),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (filled ? loewExtraBold : loewBold).copyWith(
                      fontSize: fontSize,
                      height: 1.0,
                      color: ink,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// One button of a [KioskActionBar].
class KioskBarAction {
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final bool disabledUsesFillAlpha;
  final bool loading;

  const KioskBarAction({
    required this.label,
    required this.filled,
    required this.onTap,
    this.disabledUsesFillAlpha = false,
    this.loading = false,
  });
}

/// THE kiosk bottom action bar: one button (full width) or two (equal width,
/// [KioskChromeSpec.barGap] apart), with the spec's horizontal inset, top gap
/// and bottom gap. Every kiosk screen with a bottom bar builds it here.
///
/// [s] is the chrome scale, always [KioskChrome.scaleOf] (the reference scale
/// capped by the screen's own page scale).
///
/// The `Row` deliberately does NOT stretch: this sits in a screen `Column`
/// whose children get unbounded height, and stretch would hand each button a
/// tight infinite height. [KioskCheckoutButton] sizes itself.
class KioskActionBar extends StatelessWidget {
  final double s;
  final List<KioskBarAction> actions;

  const KioskActionBar({super.key, required this.s, required this.actions})
      : assert(actions.length == 1 || actions.length == 2);

  @override
  Widget build(BuildContext context) {
    final List<Widget> row = [];
    for (int i = 0; i < actions.length; i++) {
      final KioskBarAction a = actions[i];
      if (i > 0) row.add(SizedBox(width: KioskChromeSpec.barGap * s));
      row.add(Expanded(
        child: KioskCheckoutButton(
          s: s,
          label: a.label,
          filled: a.filled,
          onTap: a.onTap,
          disabledUsesFillAlpha: a.disabledUsesFillAlpha,
          loading: a.loading,
        ),
      ));
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(
        KioskChromeSpec.barInsetHorizontal * s,
        KioskChromeSpec.barTopGap * s,
        KioskChromeSpec.barInsetHorizontal * s,
        KioskChromeSpec.barBottomGap * s,
      ),
      child: Row(children: row),
    );
  }
}

/// Full-bleed keyboard panel under the field (Figma 2305:16633): page-coloured
/// block with a 4px #B9B5A6 top edge whose corners curve away at r=46, and
/// 120px inner padding. Keys are laid out on the artboard scale `s`.
class KioskKeyboardPanel extends StatelessWidget {
  final double s;

  /// Receives the scale the keyboard must use: the page scale, capped so the
  /// 2410px key row always fits inside the panel with Figma's 80px margins
  /// (panel width / 2572). Without the cap, a window narrower than the scale
  /// floor (0.24) pushed the right-hand keys off screen.
  final Widget Function(double keyboardScale) builder;
  const KioskKeyboardPanel({super.key, required this.s, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final double ks = math.min(s, c.maxWidth / KioskResponsive.designWidth);
      return CustomPaint(
        foregroundPainter: _PanelEdgePainter(
            radius: 46 * ks, stroke: (4 * ks).clamp(1.0, 4.0)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(0, 124 * ks, 0, 120 * ks),
          child: Center(child: builder(ks)),
        ),
      );
    });
  }
}

class _PanelEdgePainter extends CustomPainter {
  final double radius;
  final double stroke;
  _PanelEdgePainter({required this.radius, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = const Color(0xFFB9B5A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final double y = stroke / 2;
    final Path path = Path()
      ..moveTo(0, radius)
      ..arcToPoint(Offset(radius, y), radius: Radius.circular(radius))
      ..lineTo(size.width - radius, y)
      ..arcToPoint(Offset(size.width, radius), radius: Radius.circular(radius));
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_PanelEdgePainter old) =>
      old.radius != radius || old.stroke != stroke;
}
