import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';

/// "This contains nuts" — the always-on allergen disclosure on the product
/// customize screen.
///
/// Deliberately independent of [KioskAllergenPreferences]. The filter answers
/// "hide what I cannot eat"; this answers "tell me what is in it", and the
/// second question is asked by people who never touched the filter — someone
/// ordering for a friend, someone who skipped the popup, someone who is merely
/// curious. So it shows for every customer, whether or not they filtered, and
/// it never hides a product: it is information, not a gate.
///
/// A product that declares no allergens renders nothing at all — see
/// [KioskAllergenNotice.maybe].
class KioskAllergenNotice extends StatelessWidget {
  final double s;
  final Set<KioskAllergen> allergens;

  const KioskAllergenNotice({
    super.key,
    required this.s,
    required this.allergens,
  });

  /// Builds the strip for [product], or null when it declares no allergens.
  /// Callers use this so an ordinary product costs no layout at all.
  static Widget? maybe({required double s, required Product product}) {
    final Set<KioskAllergen> found = kioskProductAllergens(product);
    if (found.isEmpty) return null;
    return KioskAllergenNotice(s: s, allergens: found);
  }

  /// Design order, so two products that share an allergen list it in the same
  /// place — the strip should not reshuffle as the customer moves between
  /// products.
  List<KioskAllergen> get _ordered =>
      KioskAllergen.values.where(allergens.contains).toList();

  @override
  Widget build(BuildContext context) {
    final double chip = _Spec.chipSize * s;
    final double glyph = _Spec.chipGlyph * s;

    return Align(
      alignment: Alignment.centerLeft,
      child: KioskTap(
        onTap: () => showKioskAllergenInfo(context, allergens),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _Spec.padH * s,
            vertical: _Spec.padV * s,
          ),
          decoration: BoxDecoration(
            color: _Spec.bg,
            borderRadius: BorderRadius.circular(_Spec.radius * s),
            border: Border.all(color: _Spec.border, width: _hairline(s)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kioskTranslate(context, 'allergen_contains', 'CONTAINS')
                    .toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Loew',
                  fontWeight: FontWeight.w800,
                  fontSize: _Spec.labelSize * s,
                  letterSpacing: _Spec.labelSize * s * 0.12,
                  height: 1.0,
                  color: _Spec.label,
                ),
              ),
              SizedBox(width: _Spec.labelGap * s),
              // Overlapping discs read as one badge rather than a list, which
              // keeps the strip short when a product declares four allergens.
              for (int i = 0; i < _ordered.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : _Spec.chipGap * s),
                  child: _AllergenDisc(
                    allergen: _ordered[i],
                    size: chip,
                    glyph: glyph,
                  ),
                ),
              SizedBox(width: _Spec.labelGap * s),
              // The affordance. Without it the discs look decorative and
              // nobody discovers there is more to read.
              _InfoDot(s: s),
            ],
          ),
        ),
      ),
    );
  }
}

/// One allergen as a coloured disc with its white glyph.
class _AllergenDisc extends StatelessWidget {
  final KioskAllergen allergen;
  final double size;
  final double glyph;

  const _AllergenDisc({
    required this.allergen,
    required this.size,
    required this.glyph,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: allergen.swatch,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: allergen.swatch.withValues(alpha: 0.35),
            offset: Offset(0, size * 0.06),
            blurRadius: size * 0.16,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(allergen.icon, width: glyph, height: glyph),
    );
  }
}

/// Outlined "i", drawn rather than exported: it is a letter in the page's own
/// typeface inside a ring, not an icon with vector data to be faithful to.
class _InfoDot extends StatelessWidget {
  final double s;
  const _InfoDot({required this.s});

  @override
  Widget build(BuildContext context) {
    final double size = _Spec.infoSize * s;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _Spec.label, width: _hairline(s)),
      ),
      alignment: Alignment.center,
      child: Text(
        'i',
        style: TextStyle(
          fontFamily: 'Loew',
          fontWeight: FontWeight.w800,
          fontSize: size * 0.62,
          height: 1.0,
          color: _Spec.label,
        ),
      ),
    );
  }
}

/// The informational dialog behind the strip.
///
/// Shares the allergen popup's shell — cream card, heavy ink border — so the
/// two read as the same subject, but it asks for nothing: one button, and no
/// effect on what the customer can order.
class KioskAllergenInfoDialog extends StatelessWidget {
  final Set<KioskAllergen> allergens;

  const KioskAllergenInfoDialog({super.key, required this.allergens});

  List<KioskAllergen> get _ordered =>
      KioskAllergen.values.where(allergens.contains).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Constraints, never the window — see the kiosk responsive guardrail.
      body: LayoutBuilder(
        builder: (context, constraints) {
          // The dialog is authored against the same 2572 artboard as the
          // filter popup, at roughly two thirds its width: it carries a list
          // and one button, not a form.
          final double s = math.min(
            constraints.maxWidth / _Spec.artboardWidth,
            constraints.maxHeight / _Spec.artboardHeight,
          );
          final double cardWidth = math.min(
            _Spec.cardWidth * s,
            constraints.maxWidth - _Spec.cardMargin * s,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: KioskScrim(
                  animation:
                      ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation,
                  onDismiss: () => Navigator.of(context).pop(),
                ),
              ),
              Center(
                child: SizedBox(width: cardWidth, child: _card(context, s)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, double s) {
    return Container(
      decoration: BoxDecoration(
        color: _Spec.cardBg,
        borderRadius: BorderRadius.circular(_Spec.cardRadius * s),
        border: Border.all(color: _Spec.ink, width: _Spec.cardBorder * s),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(_Spec.cardPad * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            kioskTranslate(
              context,
              'allergen_info_title',
              'CONTAINS ALLERGENS',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Loew',
              fontWeight: FontWeight.w800,
              fontSize: _Spec.titleSize * s,
              height: 1.0,
              color: _Spec.ink,
            ),
          ),
          SizedBox(height: _Spec.gap * s),
          Text(
            kioskTranslate(
              context,
              'allergen_info_body',
              'This item contains the following. Please let us know if you have any allergies.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Loew',
              fontWeight: FontWeight.w400,
              fontSize: _Spec.bodySize * s,
              height: 1.25,
              color: _Spec.ink,
            ),
          ),
          SizedBox(height: _Spec.gap * s),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _ordered.length; i++) ...[
                    if (i > 0) SizedBox(height: _Spec.rowGap * s),
                    _InfoRow(s: s, allergen: _ordered[i]),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: _Spec.gap * s),
          KioskTap(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              height: _Spec.buttonHeight * s,
              decoration: BoxDecoration(
                color: _Spec.ink,
                borderRadius: BorderRadius.circular(_Spec.cardRadius * s),
              ),
              alignment: Alignment.center,
              child: Text(
                kioskTranslate(context, 'allergen_info_dismiss', 'GOT IT')
                    .toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Loew',
                  fontWeight: FontWeight.w800,
                  fontSize: _Spec.buttonLabelSize * s,
                  height: 1.0,
                  color: _Spec.cardBg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the dialog: disc, name.
class _InfoRow extends StatelessWidget {
  final double s;
  final KioskAllergen allergen;

  const _InfoRow({required this.s, required this.allergen});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _Spec.rowHeight * s,
      padding: EdgeInsets.symmetric(horizontal: _Spec.rowPadH * s),
      decoration: BoxDecoration(
        color: _Spec.rowBg,
        borderRadius: BorderRadius.circular(_Spec.rowRadius * s),
        border: Border.all(color: _Spec.border, width: _Spec.rowBorder * s),
      ),
      child: Row(
        children: [
          _AllergenDisc(
            allergen: allergen,
            size: _Spec.rowDisc * s,
            glyph: _Spec.rowGlyph * s,
          ),
          SizedBox(width: _Spec.rowPadH * s * 0.5),
          Expanded(
            child: Text(
              kioskTranslate(context, allergen.translationKey, allergen.label),
              style: TextStyle(
                fontFamily: 'Loew',
                fontWeight: FontWeight.w700,
                fontSize: _Spec.rowLabelSize * s,
                height: 1.0,
                color: _Spec.rowLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Borders are authored in artboard px like everything else, but a scaled
/// hairline can land below one device pixel and vanish. Keep a floor.
double _hairline(double s) => math.max(1.0, 3 * s);

/// Every measurement in this file, in artboard px.
class _Spec {
  _Spec._();

  // Strip
  static const double chipSize = 84;
  static const double chipGlyph = 48;
  static const double chipGap = 18;
  static const double padH = 40;
  static const double padV = 24;
  static const double radius = 999;
  static const double labelSize = 40;
  static const double labelGap = 28;
  static const double infoSize = 56;

  // Dialog
  static const double artboardWidth = 2572;
  static const double artboardHeight = 4530;
  static const double cardWidth = 1700;
  static const double cardMargin = 96;
  static const double cardPad = 96;
  static const double cardRadius = 30;
  static const double cardBorder = 6;
  static const double gap = 56;
  static const double titleSize = 64;
  static const double bodySize = 40;
  static const double buttonHeight = 200;
  static const double buttonLabelSize = 56;
  static const double rowHeight = 150;
  static const double rowGap = 20;
  static const double rowRadius = 24;
  static const double rowBorder = 3;
  static const double rowPadH = 40;
  static const double rowDisc = 84;
  static const double rowGlyph = 48;
  static const double rowLabelSize = 40;

  // Colours — the allergen popup's palette, so the two read as one subject.
  static const Color bg = Color(0xFFFBF8EF);
  static const Color border = Color(0xFFDED9C7);
  static const Color label = Color(0xFF6B6459);
  static const Color ink = Color(0xFF0D0D0D);
  static const Color cardBg = Color(0xFFFBF8EF);
  static const Color rowBg = Color(0xFFFAF9F7);
  static const Color rowLabel = Color(0xFF1F1F1F);
}

/// Opens the informational allergen dialog.
Future<void> showKioskAllergenInfo(
  BuildContext context,
  Set<KioskAllergen> allergens,
) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => KioskAllergenInfoDialog(allergens: allergens),
      transitionsBuilder: (_, animation, __, child) {
        final Animation<double> eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(eased),
            child: child,
          ),
        );
      },
    ),
  );
}
