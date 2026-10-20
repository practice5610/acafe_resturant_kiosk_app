import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every surface POS and kiosk text sits on, by the constant that paints it.
const Map<String, Color> _lightSurfaces = {
  'PosHomeSpec.tileBg (white)': PosHomeSpec.tileBg,
  'PosHomeSpec.panelBg': PosHomeSpec.panelBg,
  'PosHomeSpec.pageBg': PosHomeSpec.pageBg,
  'PosHomeSpec.hairline': PosHomeSpec.hairline,
  'PosUI.surfaceSunken': PosUI.surfaceSunken,
  'KioskUI.pageBg': KioskUI.pageBg,
  'KioskUI.cream': KioskUI.cream,
  'BrandColors.background': BrandColors.background,
  'BrandColors.primaryLight': BrandColors.primaryLight,
};

/// The darkest light fill text is drawn on (unselected pills, chips).
const Color _inactiveFill = PosHomeSpec.inactiveFill;

void main() {
  group('TextLegibility.contrastRatio', () {
    test('matches the WCAG reference values', () {
      expect(
        TextLegibility.contrastRatio(
            const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.001),
      );
      expect(
        TextLegibility.contrastRatio(
            const Color(0xFF777777), const Color(0xFF777777)),
        closeTo(1, 0.001),
      );
      // #767676 is the lightest grey that passes AA on white; #777777 fails.
      expect(
        TextLegibility.contrastRatio(
            const Color(0xFF767676), const Color(0xFFFFFFFF)),
        closeTo(4.54, 0.01),
      );
      expect(
        TextLegibility.contrastRatio(
            const Color(0xFF777777), const Color(0xFFFFFFFF)),
        lessThan(TextLegibility.minContrast),
      );
    });

    test('is symmetric in its arguments', () {
      const Color a = Color(0xFF241F20);
      const Color b = Color(0xFFF7F1DE);
      expect(TextLegibility.contrastRatio(a, b),
          closeTo(TextLegibility.contrastRatio(b, a), 1e-9));
    });

    test('composites a translucent foreground over the surface', () {
      // 0x80 (128/255) black over white shows as #7F7F7F.
      expect(
        TextLegibility.contrastRatio(
            const Color(0x80000000), const Color(0xFFFFFFFF)),
        closeTo(
          TextLegibility.contrastRatio(
              const Color(0xFF7F7F7F), const Color(0xFFFFFFFF)),
          0.01,
        ),
      );
      // Fully transparent text is invisible.
      expect(
        TextLegibility.contrastRatio(
            const Color(0x00000000), const Color(0xFFFFFFFF)),
        closeTo(1, 0.001),
      );
    });

    test('treats a translucent background as sitting on white', () {
      expect(
        TextLegibility.contrastRatio(
            const Color(0xFF000000), const Color(0x00000000)),
        closeTo(21, 0.001),
      );
    });
  });

  group('TextLegibility.isLargeText', () {
    test('uses the WCAG 18 pt / 14 pt bold thresholds', () {
      expect(TextLegibility.isLargeText(24), isTrue);
      expect(TextLegibility.isLargeText(23.9), isFalse);
      expect(TextLegibility.isLargeText(19, FontWeight.w700), isTrue);
      expect(TextLegibility.isLargeText(19, FontWeight.w600), isFalse);
      expect(TextLegibility.isLargeText(18, FontWeight.w800), isFalse);
    });

    test('picks the matching AA floor', () {
      expect(TextLegibility.requiredContrast(12), TextLegibility.minContrast);
      expect(
          TextLegibility.requiredContrast(30), TextLegibility.minLargeContrast);
    });
  });

  group('TextLegibility.legibleOn', () {
    const Color panel = PosHomeSpec.panelBg;

    test('returns a passing colour unchanged', () {
      expect(TextLegibility.legibleOn(TextTones.primary, panel),
          TextTones.primary);
    });

    test('raises opacity first, keeping the hue', () {
      final Color faint = PosHomeSpec.inkAlpha(0.53);
      final Color fixed = TextLegibility.legibleOn(faint, panel);

      expect(TextLegibility.contrastRatio(fixed, panel),
          greaterThanOrEqualTo(TextLegibility.minContrast));
      expect(fixed.r, faint.r);
      expect(fixed.g, faint.g);
      expect(fixed.b, faint.b);
      expect(fixed.a, greaterThan(faint.a));
      expect(fixed.a, lessThan(1));
    });

    test('darkens an opaque grey that is too light', () {
      const Color grey = Color(0xFFA7A19A);
      final Color fixed = TextLegibility.legibleOn(grey, panel);
      expect(TextLegibility.contrastRatio(fixed, panel),
          greaterThanOrEqualTo(TextLegibility.minContrast));
      expect(fixed.computeLuminance(), lessThan(grey.computeLuminance()));
    });

    test('lightens text on a dark surface', () {
      const Color dark = Color(0xFF241F20);
      const Color dim = Color(0xFF5A5556);
      final Color fixed = TextLegibility.legibleOn(dim, dark);
      expect(TextLegibility.contrastRatio(fixed, dark),
          greaterThanOrEqualTo(TextLegibility.minContrast));
      expect(fixed.computeLuminance(), greaterThan(dim.computeLuminance()));
    });

    test('honours a stricter target', () {
      final Color fixed = TextLegibility.legibleOn(
        PosHomeSpec.inkAlpha(0.53),
        panel,
        minRatio: TextLegibility.enhancedContrast,
      );
      expect(TextLegibility.contrastRatio(fixed, panel),
          greaterThanOrEqualTo(TextLegibility.enhancedContrast));
    });
  });

  group('TextTones', () {
    test('every tone is POS ink at its documented opacity', () {
      for (final Color tone in [
        TextTones.primary,
        TextTones.secondary,
        TextTones.hint,
        TextTones.disabled,
      ]) {
        expect(tone.withValues(alpha: 1), PosHomeSpec.ink);
      }
      expect(TextTones.primary.a, 1);
      expect(TextTones.secondary.a, closeTo(0.80, 0.003));
      expect(TextTones.hint.a, closeTo(0.66, 0.003));
      expect(TextTones.disabled.a, closeTo(0.38, 0.003));
    });

    void expectOnEverySurface(Color tone, double floor) {
      for (final MapEntry<String, Color> s in _lightSurfaces.entries) {
        expect(
          TextLegibility.contrastRatio(tone, s.value),
          greaterThanOrEqualTo(floor),
          reason: '${s.key} drops below $floor:1',
        );
      }
    }

    test('primary and secondary reach AAA on every surface', () {
      expectOnEverySurface(TextTones.primary, TextLegibility.enhancedContrast);
      expectOnEverySurface(
          TextTones.secondary, TextLegibility.enhancedContrast);
      expect(TextLegibility.contrastRatio(TextTones.secondary, _inactiveFill),
          greaterThanOrEqualTo(6.5));
    });

    test('hint, danger and success reach AA on every surface', () {
      for (final Color tone in [
        TextTones.hint,
        TextTones.danger,
        TextTones.success,
      ]) {
        expectOnEverySurface(tone, TextLegibility.minContrast);
        expect(TextLegibility.contrastRatio(tone, _inactiveFill),
            greaterThanOrEqualTo(TextLegibility.minContrast));
      }
    });

    test('accent reaches AA on every surface and keeps the brand hue', () {
      expectOnEverySurface(TextTones.accent, TextLegibility.minContrast);
      expectOnEverySurface(TextTones.warning, TextLegibility.minContrast);
      final HSLColor brand = HSLColor.fromColor(BrandColors.secondary);
      final HSLColor accent = HSLColor.fromColor(TextTones.accent);
      expect(accent.hue, closeTo(brand.hue, 2));
      // The raw brand tan is why the accent tone exists.
      expect(
        TextLegibility.contrastRatio(BrandColors.secondary, KioskUI.pageBg),
        lessThan(TextLegibility.minLargeContrast),
      );
    });

    test('opacity constants and colours agree', () {
      expect(PosHomeSpec.inkAlpha(TextTones.secondaryOpacity),
          TextTones.secondary);
      expect(PosHomeSpec.inkAlpha(TextTones.hintOpacity), TextTones.hint);
      expect(
          PosHomeSpec.inkAlpha(TextTones.disabledOpacity), TextTones.disabled);
    });

    test('keep a visible step between each level', () {
      const Color panel = PosHomeSpec.panelBg;
      final double primary =
          TextLegibility.contrastRatio(TextTones.primary, panel);
      final double secondary =
          TextLegibility.contrastRatio(TextTones.secondary, panel);
      final double hint = TextLegibility.contrastRatio(TextTones.hint, panel);
      final double disabled =
          TextLegibility.contrastRatio(TextTones.disabled, panel);

      expect(primary, greaterThan(secondary * 1.5));
      expect(secondary, greaterThan(hint * 1.4));
      expect(disabled, lessThan(TextLegibility.minLargeContrast));
    });

    test('the receipt line tones that were reported as faint now pass', () {
      // Regression for the "add-ons / variations not bright" report: the
      // price line was ink @ 60 % and the pick rows ink @ 53 %.
      const Color panel = PosHomeSpec.panelBg;
      expect(
        TextLegibility.contrastRatio(PosHomeSpec.inkAlpha(0.53), panel),
        lessThan(TextLegibility.minContrast),
      );
      expect(
        TextLegibility.contrastRatio(PosHomeSpec.inkAlpha(0.6), panel),
        lessThan(TextLegibility.minContrast),
      );
      expect(
        TextLegibility.contrastRatio(TextTones.secondary, panel),
        greaterThanOrEqualTo(TextLegibility.enhancedContrast),
      );
    });
  });
}
