import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Japanese / Chinese glyphs for the kiosk.
///
/// The brand fonts have no CJK glyphs and Flutter web's own fallback downloads
/// Noto from the internet on demand, so a kiosk that is offline (or just slow)
/// shows empty boxes. These are trimmed Noto Sans JP / SC files (common glyphs,
/// Regular + Bold, SIL OFL — see `assets/fonts/NotoSansCJK-OFL.txt`) bundled as
/// plain assets, so they cost nothing until a language that needs them is in
/// play, and are then loaded with [FontLoader].
///
/// They are used as a *fallback* only ([apply]); the brand font is untouched,
/// so Latin text in every language looks exactly as before.
class CjkFonts {
  CjkFonts._();

  static const String jp = 'NotoSansJP';
  static const String sc = 'NotoSansSC';

  /// Families registered with the engine so far.
  static final ValueNotifier<Set<String>> loaded =
      ValueNotifier<Set<String>>(<String>{});

  static final Map<String, Future<void>> _loading = {};

  /// The CJK family a language code needs, or null for every other language.
  static String? familyFor(String? languageCode) {
    switch (languageCode) {
      case 'ja':
        return jp;
      case 'zh':
        return sc;
    }
    return null;
  }

  /// Loads whatever [languageCodes] need. Safe to call repeatedly; a failure is
  /// logged and leaves the kiosk on the engine's own fallback.
  static Future<void> ensureLoaded(Iterable<String?> languageCodes) {
    final Set<String> families = {
      for (final String? c in languageCodes)
        if (familyFor(c) != null) familyFor(c)!,
    };
    return Future.wait(families.map(_load));
  }

  static Future<void> _load(String family) {
    return _loading.putIfAbsent(family, () async {
      try {
        final FontLoader loader = FontLoader(family)
          ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf'));
        await loader.load();
        loaded.value = {...loaded.value, family};
      } catch (e) {
        debugPrint('CjkFonts: could not load $family: $e');
        _loading.remove(family);
      }
    });
  }

  /// Fallback order for [locale]: the matching CJK family first, so shared
  /// Han characters take that language's glyph shapes.
  static List<String> fallbackFor(Locale locale, [Set<String>? have]) {
    final Set<String> ready = have ?? loaded.value;
    final List<String> order = locale.languageCode == 'zh' ? [sc, jp] : [jp, sc];
    return [for (final String f in order) if (ready.contains(f)) f];
  }

  /// [theme] with the loaded CJK families as the text fallback. Returns [theme]
  /// untouched while none is loaded, i.e. for every kiosk that has no use for
  /// them.
  static ThemeData apply(ThemeData theme, Locale locale) {
    final List<String> fallback = fallbackFor(locale);
    if (fallback.isEmpty) return theme;
    return theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
      primaryTextTheme:
          theme.primaryTextTheme.apply(fontFamilyFallback: fallback),
    );
  }
}
