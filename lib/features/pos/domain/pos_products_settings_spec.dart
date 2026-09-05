import 'package:acafe_customer/features/pos/domain/pos_settings_list_spec.dart';
import 'package:flutter/material.dart';

/// Design tokens for POS Settings → Products (Figma node **1641:3975**).
///
/// The card and row geometry is shared with Settings → Add-Ons and lives in
/// [PosSettingsListSpec]; this class re-exports it under the names this screen
/// already used, so the two frames cannot drift apart. Palette and panel
/// padding stay in `PosSettingsSpec` so every Settings section keeps one look.
class PosProductsSettingsSpec {
  PosProductsSettingsSpec._();

  // ── Header ───────────────────────────────────────────────────────────
  // Title/subtitle sizes and the 4px gap come from PosSettingsSpec so this
  // page's header matches General and Staff exactly.
  static const double sectionGap = PosSettingsListSpec.sectionGap;

  // ── Card (1641:4007) ─────────────────────────────────────────────────
  static const double cardRadius = PosSettingsListSpec.cardRadius;
  static const Color cardBorder = PosSettingsListSpec.cardBorder; // #E1DBC4

  // ── Row (1641:4008) ──────────────────────────────────────────────────
  static const double rowHeight = PosSettingsListSpec.rowHeight;
  static const EdgeInsets rowPadding = PosSettingsListSpec.rowPadding;
  static const Color rowDivider = PosSettingsListSpec.rowDivider;

  static const double thumbSize = PosSettingsListSpec.thumbSize;
  static const double thumbRadius = PosSettingsListSpec.thumbRadius;
  static const double thumbToTextGap = PosSettingsListSpec.thumbToTextGap;

  static const double nameSize = PosSettingsListSpec.nameSize;
  static const double nameToSkuGap = PosSettingsListSpec.nameToSubGap;
  static const double skuSize = PosSettingsListSpec.subSize;
  static const double priceSize = PosSettingsListSpec.priceSize;
  static const double priceToToggleGap = PosSettingsListSpec.priceToToggleGap;
}
