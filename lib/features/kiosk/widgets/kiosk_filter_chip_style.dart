import 'package:flutter/material.dart';

/// One chip look for the kiosk menu filter pills (POPULAR … CEROMONIAL), shared
/// by the landscape and portrait menus so they cannot drift apart.
///
/// Values are the landscape chip's (landscape_menu_screen.dart `_Pill`), in
/// units of its font size (14): padding 14 × 8, gap 8, black 1.2 outline
/// (clamped to 1–2px), full pill, transparent fill, no shadow; selected =
/// black fill with white text. Each screen passes its own font size and keeps
/// its own font family.
class KioskFilterChipStyle {
  KioskFilterChipStyle._();

  static const Color ink = Colors.black;
  static const Color selectedText = Colors.white;

  /// Reference font size the proportions below are expressed against.
  static const double _refFont = 14;

  static EdgeInsets padding(double fontSize) => EdgeInsets.symmetric(
      horizontal: 14 * fontSize / _refFont, vertical: 8 * fontSize / _refFont);

  static double gap(double fontSize) => 8 * fontSize / _refFont;

  static BoxDecoration decoration({
    required bool selected,
    required double fontSize,
  }) =>
      BoxDecoration(
        color: selected ? ink : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: ink, width: (1.2 * fontSize / _refFont).clamp(1.0, 2.0)),
      );

  static Color textColor(bool selected) => selected ? selectedText : ink;
}
