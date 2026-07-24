import 'package:flutter/material.dart';

/// Central brand palette for Acafe — A/CAFÉ suite.
/// See BRAND_PALETTE.md. Maroon removed → near-black primary + beige + tan accent.
class BrandColors {
  BrandColors._();

  static const Color primary = Color(0xFF2B2B2B);      // near-black (was maroon #971B2F)
  static const Color background = Color(0xFFE8E6DF);   // warm beige page background

  static const Color primaryLight = Color(0xFFFAF7F1); // light cream surface-alt (was #F5E8EA)
  static const Color primaryDark = Color(0xFF1A1A1A);  // primary hover (was #6B1422)
  static const Color backgroundDark = Color(0xFF1E1D1B);

  static const Color onPrimary = Colors.white;
  static const Color onBackground = Color(0xFF2B2B2B); // near-black primary text (was #3D2B2B)
  static const Color secondary = Color(0xFFC8A97E);    // warm tan accent (was #C9A962)
  static const Color cardBorder = Color(0xFFDED9C7);   // warm grey card outline (Figma: 33px radius / 5.5px border)
}
