import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:flutter/material.dart';

/// Geometry shared by every Settings "availability list" frame — the white
/// card of toggle rows used by Products (**1641:3975**) and Add-Ons
/// (**1641:4088**).
///
/// Both frames draw the same card and the same row; only the copy and the
/// data source differ. Keeping the numbers here is what lets
/// [PosSettingsAvailabilityCard] serve both without either screen drifting.
/// Section-specific specs re-export these rather than restating them, so a
/// change lands on both screens at once.
class PosSettingsListSpec {
  PosSettingsListSpec._();

  /// header → search → card.
  static const double sectionGap = 24;

  // ── Card ─────────────────────────────────────────────────────────────
  static const double cardRadius = 16;
  static const Color cardBorder = PosSettingsSpec.fieldBorder; // #E1DBC4

  // ── Row ──────────────────────────────────────────────────────────────
  static const double rowHeight = 66; // 34 thumb + 16 padding top/bottom
  static const EdgeInsets rowPadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const Color rowDivider = Color(0xFFF0EBD8);

  static const double thumbSize = 34;
  static const double thumbRadius = 8;
  static const double thumbToTextGap = 16;

  static const double nameSize = 15;
  static const double nameToSubGap = 2;
  static const double subSize = 12;
  static const double priceSize = 14;

  /// Text column → price. Keeps a long name from ever touching the price.
  static const double textToPriceGap = 12;
  static const double priceToToggleGap = 32;

  // ── States ───────────────────────────────────────────────────────────
  static const double spinnerSize = 28;
  static const double spinnerStroke = 2;
  static const EdgeInsets emptyPadding = EdgeInsets.all(24);
}
