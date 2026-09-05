import 'package:acafe_customer/features/pos/domain/pos_settings_list_spec.dart';
import 'package:flutter/material.dart';

/// Design tokens for POS Settings → Add-Ons (Figma node **1641:4088**).
///
/// The frame is the Products frame with different copy, so every card and row
/// number comes from [PosSettingsListSpec] rather than being restated here —
/// the two screens are meant to be indistinguishable apart from their content.
class PosAddonsSettingsSpec {
  PosAddonsSettingsSpec._();

  static const double sectionGap = PosSettingsListSpec.sectionGap;

  static const double cardRadius = PosSettingsListSpec.cardRadius;
  static const Color cardBorder = PosSettingsListSpec.cardBorder;

  static const double rowHeight = PosSettingsListSpec.rowHeight;
  static const EdgeInsets rowPadding = PosSettingsListSpec.rowPadding;
  static const Color rowDivider = PosSettingsListSpec.rowDivider;

  static const double thumbSize = PosSettingsListSpec.thumbSize;
  static const double thumbRadius = PosSettingsListSpec.thumbRadius;

  static const double nameSize = PosSettingsListSpec.nameSize;
  static const double skuSize = PosSettingsListSpec.subSize;
  static const double priceSize = PosSettingsListSpec.priceSize;

  // ── Confirm / refusal dialog ─────────────────────────────────────────
  static const double dialogTitleSize = 16;
  static const double dialogBodySize = 14;
  static const double dialogMaxWidth = 420;
}
