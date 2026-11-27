import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_chrome_spec.dart';
import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_language_offering.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/utill/styles.dart';

// ===========================================================================
// B-00a "Select language" pop-up — Figma node `2305:3423` (`B-00a Language
// pop-up`), card `2305:3628` (`language-selector-screen`). Values below are
// read straight off that frame, authored against the same 1366x1024 landscape
// base every other `landscape/**` screen uses, so they are multiplied by `s`
// with no extra conversion.
//
// A new widget rather than a landscape mode of `KioskLanguageSheet`: that
// sheet is also opened from the portrait welcome/menu screens, and the Figma
// chrome here (centred card, whole-row 85% dimming on unselected rows) is
// different enough from the portrait card that branching it in place would
// mean threading a `landscape` flag through someone else's widget — the same
// reasoning `landscape_order_line_card.dart` documents for not reusing
// `KioskOrderLineCard`.
// ===========================================================================

const double _kCardWidth = 750;
const double _kCardPadding = 34.65;
const double _kCardGap = 23.1;
const double _kCardRadius = 10.83;
const double _kCardBorder = 2.17;

const double _kTitleSize = 26;
const double _kSubtitleSize = 17.3;

const double _kRowHeight = 68.9;
const double _kRowGap = 8.66;
const double _kRowRadius = 8.66;
const double _kRowPaddingH = 17.3;
const double _kFlagSize = 32.84;
const double _kLabelSize = 14.44;

const Color _kCardSurface = Color(0xFFFBF8EF);
const Color _kCardInk = Color(0xFF0D0D0D);
const Color _kRowSurface = Color(0xFFFAF9F7);
const Color _kRowBorderIdle = Color(0xFFDED9C7);
const Color _kRowLabel = Color(0xFF1F1F1F);

/// Opens the landscape "Select language" card centred over the current
/// screen, dimming it behind a 50%-black scrim (`rgba(0,0,0,0.5)` in Figma).
///
/// Writes the choice and closes itself, same contract as the portrait
/// `openKioskLanguageSheet` it mirrors.
Future<void> showLandscapeLanguageSheet(
  BuildContext context, {
  required double s,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => _LandscapeLanguageSheet(s: s),
  );
}

class _LandscapeLanguageSheet extends StatefulWidget {
  final double s;
  const _LandscapeLanguageSheet({required this.s});

  @override
  State<_LandscapeLanguageSheet> createState() =>
      _LandscapeLanguageSheetState();
}

class _LandscapeLanguageSheetState extends State<_LandscapeLanguageSheet> {
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

    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final String current =
        Provider.of<LocalizationProvider>(context).locale.languageCode;

    return Center(
      child: GestureDetector(
        onTap: () {}, // absorb taps inside the card
        child: LandscapeLanguageCard(
          s: widget.s,
          current: current,
          saving: _saving,
          onSelect: _select,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// The picker card itself. Public so widget tests can drive the part that
/// carries the design rules — which row is highlighted, which are dimmed —
/// without standing up the providers and network prefetch the full sheet
/// needs (mirrors `KioskLanguageCard` in the portrait sheet).
class LandscapeLanguageCard extends StatelessWidget {
  final double s;
  final String current;
  final bool saving;
  final ValueChanged<LanguageModel> onSelect;
  final VoidCallback? onClose;

  const LandscapeLanguageCard({
    super.key,
    this.s = 1,
    required this.current,
    this.saving = false,
    required this.onSelect,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final List<LanguageModel> languages = KioskLanguageOffering.forThisDevice();

    return Material(
      color: _kCardSurface,
      borderRadius: BorderRadius.circular(_kCardRadius * s),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: _kCardWidth * s,
        padding: EdgeInsets.all(_kCardPadding * s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kCardRadius * s),
          border: Border.all(
            color: _kCardInk,
            width: (_kCardBorder * s).clamp(1.0, _kCardBorder),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                KioskBackButton(
                  s: KioskChrome.scaleOf(context),
                  onTap: onClose ?? () {},
                ),
                Expanded(
                  child: Text(
                    kioskTranslate(
                            context, 'select_language', 'Select language')
                        .toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewExtraBold.copyWith(
                      fontSize: _kTitleSize * s,
                      height: 1.1,
                      color: _kCardInk,
                    ),
                  ),
                ),
                // Mirrors the back button so the title centres on the card.
                SizedBox(
                    width: KioskBackButton.diameterFor(
                        context, KioskChrome.scaleOf(context))),
              ],
            ),
            SizedBox(height: _kCardGap * s),
            Text(
              kioskTranslate(context, 'choose_your_preferred_language',
                  'Choose your preferred language'),
              textAlign: TextAlign.center,
              style: loewRegular.copyWith(
                fontSize: _kSubtitleSize * s,
                height: 1.3,
                color: _kCardInk,
              ),
            ),
            SizedBox(height: _kCardGap * s),
            Column(
              children: [
                for (int i = 0; i < languages.length; i++) ...[
                  if (i > 0) SizedBox(height: _kRowGap * s),
                  _LanguageRow(
                    s: s,
                    language: languages[i],
                    selected: languages[i].languageCode == current,
                    enabled: !saving,
                    onTap: () => onSelect(languages[i]),
                  ),
                ],
              ],
            ),
          ],
        ),
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

    // Figma dims the whole unselected row to 85% opacity (not just the flag),
    // and swaps the border/weight and label weight for the selected row.
    return Opacity(
      opacity: selected ? 1 : 0.85,
      child: KioskTap(
        onTap: enabled ? onTap : null,
        child: Container(
          height: _kRowHeight * s,
          padding: EdgeInsets.symmetric(horizontal: _kRowPaddingH * s),
          decoration: BoxDecoration(
            color: _kRowSurface,
            borderRadius: BorderRadius.circular(_kRowRadius * s),
            border: Border.all(
              color: selected ? Colors.black : _kRowBorderIdle,
              width: selected
                  ? (1.81 * s).clamp(1.0, 1.81)
                  : (1.08 * s).clamp(1.0, 1.08),
            ),
          ),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  language.imageUrl!,
                  width: flag,
                  height: flag,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              SizedBox(width: _kRowGap * s),
              Expanded(
                child: Text(
                  language.languageName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (selected ? loewExtraBold : loewBold).copyWith(
                    fontSize: _kLabelSize * s,
                    height: 1.1,
                    color: _kRowLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
