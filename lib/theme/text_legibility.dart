import 'package:flutter/painting.dart';

/// WCAG 2.x contrast maths for text, shared by the POS and kiosk screens.
///
/// Muted copy used to be set per screen as "ink at 53–60 %" or an opaque grey
/// picked by eye. On the cream POS/kiosk surfaces that lands at 2–4.2:1, under
/// the 4.5:1 WCAG AA floor, and on 1× large displays (kiosk panels, desktop
/// monitors) the 11–12 px strokes anti-alias lighter still: add-on and
/// variation lines read as washed out. Draw secondary copy in [TextTones]
/// instead; this class is the arithmetic those tones are verified with.
abstract final class TextLegibility {
  /// WCAG 2.x SC 1.4.3 (AA) minimum for normal-size text.
  static const double minContrast = 4.5;

  /// WCAG 2.x SC 1.4.3 (AA) minimum for large text (see [isLargeText]).
  static const double minLargeContrast = 3.0;

  /// WCAG 2.x SC 1.4.6 (AAA) enhanced minimum for normal-size text.
  static const double enhancedContrast = 7.0;

  /// Contrast ratio (1–21) of [foreground] drawn over [background].
  ///
  /// A translucent [foreground] is composited over [background] first, which
  /// is what the screen actually shows. A translucent [background] is treated
  /// as sitting on white: pass the composited surface when it sits on
  /// something else.
  static double contrastRatio(Color foreground, Color background) {
    final Color surface = background.a >= 1
        ? background
        : Color.alphaBlend(background, const Color(0xFFFFFFFF));
    final Color shown = Color.alphaBlend(foreground, surface);
    final double a = shown.computeLuminance();
    final double b = surface.computeLuminance();
    final double lighter = a > b ? a : b;
    final double darker = a > b ? b : a;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// WCAG "large text": 18 pt (24 logical px), or 14 pt (≈18.66 px) bold.
  static bool isLargeText(double fontSize, [FontWeight? fontWeight]) {
    if (fontSize >= 24) return true;
    return fontSize >= 18.66 && (fontWeight?.value ?? 400) >= 700;
  }

  /// The AA floor that applies to text of this size and weight.
  static double requiredContrast(double fontSize, [FontWeight? fontWeight]) =>
      isLargeText(fontSize, fontWeight) ? minLargeContrast : minContrast;

  /// True when [foreground] on [background] meets [minRatio].
  static bool meets(
    Color foreground,
    Color background, {
    double minRatio = minContrast,
  }) =>
      contrastRatio(foreground, background) >= minRatio;

  /// The colour nearest to [foreground] that reaches [minRatio] on
  /// [background], for text whose colour arrives as data (a station or
  /// category colour from the backend) rather than from [TextTones].
  ///
  /// Opacity is raised first, so a muted tone keeps its hue. If the opaque
  /// colour still falls short, it is mixed toward black or white, whichever
  /// side of [background] has the room. A colour that already passes is
  /// returned unchanged; a ratio no colour can reach on [background] returns
  /// that pole, the closest there is.
  static Color legibleOn(
    Color foreground,
    Color background, {
    double minRatio = minContrast,
  }) {
    if (meets(foreground, background, minRatio: minRatio)) return foreground;

    final Color opaque = foreground.withValues(alpha: 1);
    if (meets(opaque, background, minRatio: minRatio)) {
      return _search(
        (t) => foreground.withValues(
          alpha: foreground.a + (1 - foreground.a) * t,
        ),
        background,
        minRatio,
      );
    }

    final bool darken = Color.alphaBlend(background, const Color(0xFFFFFFFF))
            .computeLuminance() >
        0.18;
    final Color pole =
        darken ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    return _search((t) => Color.lerp(opaque, pole, t)!, background, minRatio);
  }

  /// Smallest `t` in 0..1 whose colour passes; [at] must pass at `t == 1`
  /// whenever the target is reachable at all.
  static Color _search(
    Color Function(double t) at,
    Color background,
    double minRatio,
  ) {
    double lo = 0;
    double hi = 1;
    for (int i = 0; i < 24; i++) {
      final double mid = (lo + hi) / 2;
      if (meets(at(mid), background, minRatio: minRatio)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return at(hi);
  }
}

/// The text tones every POS and kiosk screen draws in.
///
/// All are the POS ink `#241F20` at a fixed opacity, so muted copy is muted by
/// the same amount everywhere and keeps the warm cast of whatever surface it
/// sits on. The ratios below are verified for every surface the two apps draw
/// on by `test/theme/text_legibility_test.dart`; pick a tone by role, never by
/// an inline `withValues(alpha: …)` on ink.
abstract final class TextTones {
  /// Opacity of [secondary]. Spec files that name a Figma opacity for a text
  /// role point it here instead of at the raw Figma value.
  static const double secondaryOpacity = 0.80;

  /// Opacity of [hint].
  static const double hintOpacity = 0.66;

  /// Opacity of [disabled].
  static const double disabledOpacity = 0.38;

  /// Names, totals, entered values.
  static const Color primary = Color(0xFF241F20);

  /// Secondary copy: the price/variation line and add-on picks under an item,
  /// captions, field labels, meta lines. 80 % ink, at least 7.3:1 (WCAG AAA)
  /// on every page, panel and tile surface, 6.7:1 on the inactive pill fill.
  static const Color secondary =
      Color.fromRGBO(0x24, 0x1F, 0x20, secondaryOpacity);

  /// Placeholders, empty-state sublines and other tertiary copy. 66 % ink,
  /// at least 4.5:1 (WCAG AA) on every surface, so a hint still reads as text
  /// while staying visibly lighter than the value typed over it.
  static const Color hint = Color.fromRGBO(0x24, 0x1F, 0x20, hintOpacity);

  /// Labels of disabled controls, and nothing else. WCAG 1.4.3 exempts
  /// inactive components, and the low contrast is what says "unavailable".
  static const Color disabled =
      Color.fromRGBO(0x24, 0x1F, 0x20, disabledOpacity);

  /// Error and destructive copy. At least 5.2:1 on every page, panel and
  /// tile surface, 4.6:1 on the inactive pill fill.
  static const Color danger = Color(0xFFB3261E);

  /// Success / confirmation copy. At least 5.1:1 on every page, panel and
  /// tile surface, 4.5:1 on the inactive pill fill.
  static const Color success = Color(0xFF2E6B31);

  /// Amber for "to charge" / warning copy. Figma's `#D98C1A` is 2.4:1 on the
  /// warning banner; this is the same hue darkened to at least 4.5:1 there
  /// and on every light surface. The original stays right for badge fills.
  static const Color warning = Color(0xFF8F5C11);

  /// Brand tan for copy ("Included", ghost keys). `BrandColors.secondary`
  /// (`#C8A97E`) is about 2:1 on cream, fine for fills but not for type. This
  /// is the same hue darkened until it clears 4.5:1 on every light surface.
  static const Color accent = Color(0xFF76644A);
}
