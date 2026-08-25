import 'dart:ui';

import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ===========================================================================
// KIOSK LANGUAGE PICKER — Figma `language-selector-screen` (node 1385:16986).
//
// Authored against the 2572px kiosk artboard and scaled by
// `s = KioskResponsive.scale(width)`, the same as every other kiosk screen.
// Values marked (inspect) are read straight off Figma's Inspect panel; the rest
// are measured from the same frame.
// ===========================================================================

/// Card footprint. 2078 of the 2572 artboard = 81% of the screen — the design's
/// "nearly full width, with a margin either side".
const double _kCardWidth = 2078; // (inspect) Width Fixed
const double _kCardPadding = 96; // (inspect) Padding
const double _kCardGap = 64; // (inspect) Gap
const double _kCardRadius = 30; // (inspect) Radius
const double _kCardBorder = 6; // (inspect) Border, alignment Inside

/// Sits near the top of the screen rather than centred, so it reads as a sheet
/// dropping in from the top edge.
const double _kCardTopMargin = 120;

const double _kRowHeight = 186;
const double _kRowGap = 24;
const double _kRowRadius = 24;
const double _kFlagSize = 91; // Figma layer: `Frame · 91 × 91`
const double _kTitleSize = 80;
const double _kSubtitleSize = 40;
const double _kLabelSize = 48;
const double _kBackButtonSize = 160;

// Palette — (inspect) Background colors #FBF8EF.
const Color _kSheetSurface = Color(0xFFFBF8EF);
const Color _kSheetRowIdle = Color(0xFFF6F3EA);
const Color _kSheetBorder = Color(0xFFE8E2D5);
const Color _kSheetInk = Color(0xFF1E1E1E);
const Color _kSheetText = Color(0xFF2B2B2B);

/// Unselected languages sit back rather than compete: muted label, flatter
/// surface, and the flag dimmed.
const Color _kSheetMuted = Color(0xFF8A8275);

/// `getTranslated` echoes the key back when the lookup fails — its `translate`
/// throws on a missing key and the catch leaves the key in place — so a plain
/// `?? fallback` never fires and the card renders "SELECT_LANGUAGE". Treat a
/// key-shaped result as missing and use the readable fallback instead.
String _t(BuildContext context, String key, String fallback) {
  final String? value = getTranslated(key, context);
  if (value == null || value == key) return fallback;
  return value;
}

/// Opens the language picker over whatever screen invoked it.
///
/// The sheet writes the choice itself and closes, so callers only need to fire
/// and forget from the flag button.
Future<void> openKioskLanguageSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Select language',
    barrierColor: Colors.transparent, // the sheet paints its own scrim
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const KioskLanguageSheet(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Drops in from above and settles — easeOutCubic so it decelerates into
      // place instead of stopping dead.
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.14), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

class KioskLanguageSheet extends StatefulWidget {
  const KioskLanguageSheet({super.key});

  @override
  State<KioskLanguageSheet> createState() => _KioskLanguageSheetState();
}

class _KioskLanguageSheetState extends State<KioskLanguageSheet> {
  bool _saving = false;

  Future<void> _select(LanguageModel language) async {
    // One tap only: the menu prefetch below is awaited, and a second tap
    // mid-flight would race two locales into the cache.
    if (_saving) return;
    setState(() => _saving = true);

    final navigator = Navigator.of(context);
    final localization =
        Provider.of<LocalizationProvider>(context, listen: false);
    final category = Provider.of<CategoryProvider>(context, listen: false);
    final Locale locale = Locale(language.languageCode!, language.countryCode);

    await localization.setKioskLanguage(locale);
    await category.prefetchKioskMenu(
      localeCode: locale.languageCode,
      force: true,
    );

    // Closes itself once the choice is applied — the customer never has to find
    // a confirm button.
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final String current =
        Provider.of<LocalizationProvider>(context).locale.languageCode;

    // Material (transparent) provides the DefaultTextStyle the Text widgets
    // below rely on; without it, text inside showGeneralDialog falls back to
    // the framework debug style.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _saving ? null : () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: _kSheetInk.withValues(alpha: 0.45)),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The kiosk artboard scale every other kiosk screen uses, so
                // the card holds the design's 81%-of-screen footprint instead
                // of being sized as an arbitrary fraction of the window.
                final double s = KioskResponsive.scale(constraints.maxWidth);
                return SingleChildScrollView(
                  child: Padding(
                    // Top-anchored, per the design.
                    padding: EdgeInsets.only(top: _kCardTopMargin * s),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () {}, // absorb taps inside the card
                        child: KioskLanguageCard(
                          s: s,
                          current: current,
                          saving: _saving,
                          onSelect: _select,
                          onClose: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The picker card itself. Public so widget tests can drive the part that
/// carries the design rules — which row is highlighted, which are greyed out —
/// without standing up the providers and network prefetch the full sheet needs.
class KioskLanguageCard extends StatelessWidget {
  /// Kiosk artboard scale (see [KioskResponsive.scale]).
  final double s;
  final String current;
  final bool saving;
  final ValueChanged<LanguageModel> onSelect;
  final VoidCallback? onClose;

  const KioskLanguageCard({
    super.key,
    this.s = 1,
    required this.current,
    this.saving = false,
    required this.onSelect,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kCardWidth * s,
      // Height is content-driven rather than the Figma frame's fixed 1356: that
      // frame reserves scroll room for a longer list, and pinning it here would
      // leave dead space under four rows.
      padding: EdgeInsets.all(_kCardPadding * s),
      decoration: BoxDecoration(
        color: _kSheetSurface,
        borderRadius: BorderRadius.circular(_kCardRadius * s),
        border: Border.all(
          color: _kSheetBorder,
          width: (_kCardBorder * s).clamp(1.0, _kCardBorder),
        ),
        // Lifts the card off the blurred backdrop.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 120 * s,
            offset: Offset(0, 40 * s),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _CircleBackButton(s: s, onTap: onClose ?? () {}),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * s),
                  child: Text(
                    _t(context, 'select_language', 'Select language')
                        .toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewExtraBold.copyWith(
                      fontSize: _kTitleSize * s,
                      height: 1.1,
                      color: _kSheetText,
                    ),
                  ),
                ),
              ),
              // Mirrors the back button so the title centres on the card.
              SizedBox(width: _kBackButtonSize * s),
            ],
          ),
          SizedBox(height: _kCardGap * s),
          Opacity(
            opacity: 0.7,
            child: Text(
              _t(context, 'choose_your_preferred_language',
                  'Choose your preferred language'),
              textAlign: TextAlign.center,
              style: loewRegular.copyWith(
                fontSize: _kSubtitleSize * s,
                height: 1.3,
                color: _kSheetText,
              ),
            ),
          ),
          SizedBox(height: _kCardGap * s),
          for (int i = 0; i < AppConstants.languages.length; i++) ...[
            if (i > 0) SizedBox(height: _kRowGap * s),
            _LanguageRow(
              s: s,
              language: AppConstants.languages[i],
              selected: AppConstants.languages[i].languageCode == current,
              enabled: !saving,
              onTap: () => onSelect(AppConstants.languages[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  final double s;
  final LanguageModel language;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _LanguageRow({
    required this.s,
    required this.language,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double flag = _kFlagSize * s;

    return KioskTap(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: _kRowHeight * s,
        padding: EdgeInsets.symmetric(horizontal: 40 * s),
        decoration: BoxDecoration(
          color: selected ? Colors.white : _kSheetRowIdle,
          borderRadius: BorderRadius.circular(_kRowRadius * s),
          // The chosen language is the only row with an ink border, at the same
          // 6px weight the card frame uses; the rest keep a hairline so they
          // still read as rows, not as gaps.
          border: Border.all(
            color: selected ? _kSheetInk : _kSheetBorder,
            width: selected
                ? (_kCardBorder * s).clamp(1.5, _kCardBorder)
                : (2 * s).clamp(1.0, 2.0),
          ),
        ),
        child: Row(
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: selected ? 1 : 0.55,
              child: ClipOval(
                child: Image.asset(
                  language.imageUrl!,
                  width: flag,
                  height: flag,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            SizedBox(width: 32 * s),
            Expanded(
              child: Text(
                language.languageName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (selected ? loewBold : loewRegular).copyWith(
                  fontSize: _kLabelSize * s,
                  height: 1.1,
                  color: selected ? Colors.black : _kSheetMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final double s;
  final VoidCallback onTap;
  const _CircleBackButton({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final double size = _kBackButtonSize * s;
    return KioskTap(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _kSheetInk,
            width: (_kCardBorder * s).clamp(1.2, _kCardBorder),
          ),
        ),
        child: Icon(Icons.chevron_left_rounded,
            size: size * 0.6, color: _kSheetInk),
      ),
    );
  }
}
