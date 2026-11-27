import 'dart:convert';

import 'package:flutter/material.dart';

/// Per-kiosk Theme overrides for the PORTRAIT menu screen, as saved by admin on
/// the device's Theme editor (`devices.theme`).
///
/// Sparse by design: every field is null unless the admin overrode it, and a
/// null field means "keep the kiosk's built-in look". The defaults live at the
/// style sites in the menu screen / product card, NOT here, so a device with no
/// theme renders exactly as it did before this existed.
@immutable
class KioskTheme {
  final Color? screenBg;
  final Color? sidebarBg;
  final Color? sidebarText;
  final bool? sidebarBold;
  final KioskTextTheme? name;
  final KioskTextTheme? description;
  final KioskTextTheme? price;

  const KioskTheme({
    this.screenBg,
    this.sidebarBg,
    this.sidebarText,
    this.sidebarBold,
    this.name,
    this.description,
    this.price,
  });

  static const KioskTheme none = KioskTheme();

  bool get isEmpty =>
      screenBg == null &&
      sidebarBg == null &&
      sidebarText == null &&
      sidebarBold == null &&
      name == null &&
      description == null &&
      price == null;

  /// Parse the wire/stored form. Anything malformed or unknown is dropped, so a
  /// bad value can never reach a style site. Null / non-map = no overrides.
  factory KioskTheme.fromJson(dynamic raw) {
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return none;
      }
    }
    if (raw is! Map) return none;
    final Map<dynamic, dynamic> screen =
        raw['screen'] is Map ? raw['screen'] as Map : const {};
    final Map<dynamic, dynamic> side =
        raw['sidebar'] is Map ? raw['sidebar'] as Map : const {};
    return KioskTheme(
      screenBg: _color(screen['bg']),
      sidebarBg: _color(side['bg']),
      sidebarText: _color(side['text']),
      sidebarBold: side['bold'] is bool ? side['bold'] as bool : null,
      name: KioskTextTheme.fromJson(raw['name']),
      description: KioskTextTheme.fromJson(raw['description']),
      price: KioskTextTheme.fromJson(raw['price']),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> out = {};
    if (screenBg != null) out['screen'] = {'bg': _hex(screenBg!)};
    final Map<String, dynamic> side = {
      if (sidebarBg != null) 'bg': _hex(sidebarBg!),
      if (sidebarText != null) 'text': _hex(sidebarText!),
      if (sidebarBold != null) 'bold': sidebarBold,
    };
    if (side.isNotEmpty) out['sidebar'] = side;
    for (final e in {'name': name, 'description': description, 'price': price}
        .entries) {
      final Map<String, dynamic>? j = e.value?.toJson();
      if (j != null && j.isNotEmpty) out[e.key] = j;
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is KioskTheme && jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Overrides for one product text block (name / description / price).
@immutable
class KioskTextTheme {
  /// Flutter family name, always one of [kKioskThemeFonts].
  final String? font;

  /// Size in the card's 300px reference units (scaled by the card like today).
  final double? size;
  final Color? color;

  /// Background of THIS text block only -- never the whole card.
  final Color? bg;

  const KioskTextTheme({this.font, this.size, this.color, this.bg});

  static KioskTextTheme? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final dynamic f = raw['font'];
    final double? s = raw['size'] is num ? (raw['size'] as num).toDouble() : null;
    final t = KioskTextTheme(
      font: f is String && kKioskThemeFonts.containsKey(f) ? f : null,
      size: s != null && s >= 6 && s <= 40 ? s : null,
      color: _color(raw['color']),
      bg: _color(raw['bg']),
    );
    return t.font == null && t.size == null && t.color == null && t.bg == null
        ? null
        : t;
  }

  Map<String, dynamic> toJson() => {
        if (font != null) 'font': font,
        if (size != null) 'size': size,
        if (color != null) 'color': _hex(color!),
        if (bg != null) 'bg': _hex(bg!),
      };

  /// [base] with this block's font / size / colour laid over it. [scale] is the
  /// card's reference-to-pixel factor, so a themed size scales exactly like the
  /// built-in one. [color] is passed separately so a caller can keep its own
  /// state colour (e.g. out-of-stock grey) in charge.
  TextStyle apply(TextStyle base, {required double scale, Color? color}) {
    final List<String>? fallback =
        font == null ? null : kKioskThemeFonts[font]!.fallback;
    return base.copyWith(
      fontFamily: font == null ? null : kKioskThemeFonts[font]!.family,
      fontFamilyFallback: fallback,
      fontSize: size == null ? null : size! * scale,
      color: color,
    );
  }
}

/// A font the theme may select: the registered family and its per-glyph
/// fallback. Keys match the backend's `Device::THEME_FONTS`; a key the kiosk
/// does not know is ignored, never rendered.
class KioskThemeFont {
  final String family;
  final List<String>? fallback;
  const KioskThemeFont(this.family, [this.fallback]);
}

const Map<String, KioskThemeFont> kKioskThemeFonts = {
  'Poppins': KioskThemeFont('Poppins'),
  'Loew': KioskThemeFont('Loew'),
  // Swiss 721 has no euro sign: "€" falls back to Nunito Sans (see styles.dart).
  'Swiss721Light': KioskThemeFont('Swiss721Light', ['NunitoSans']),
  'NunitoSans': KioskThemeFont('NunitoSans'),
  'Inter': KioskThemeFont('Inter'),
  'Roboto': KioskThemeFont('Roboto'),
  'ScotchDisplay': KioskThemeFont('ScotchDisplay'),
  'ScotchDisplayCond': KioskThemeFont('ScotchDisplayCond'),
};

Color? _color(dynamic v) {
  if (v is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(v)) return null;
  return Color(0xFF000000 | int.parse(v.substring(1), radix: 16));
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
