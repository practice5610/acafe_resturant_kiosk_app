import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

const Color _kInk = Color(0xFF1E1E1E);
const Duration _kSwitch = Duration(milliseconds: 180);

/// Row of language buttons at the foot of the kiosk welcome screen.
///
/// Every proportion is a fraction of [pillHeight], so the bar scales with the
/// intro artwork like the logo and prompt above it. All labels share one
/// weight: choosing a language changes colour only, never a button's width,
/// so the row never shifts under the customer's finger.
class KioskWelcomeLanguageBar extends StatelessWidget {
  final List<LanguageModel> languages;
  final String current;
  final double pillHeight;

  /// False while the menu is being made ready after "touch to order".
  final bool enabled;
  final ValueChanged<LanguageModel> onSelect;

  const KioskWelcomeLanguageBar({
    super.key,
    required this.languages,
    required this.current,
    required this.pillHeight,
    required this.onSelect,
    this.enabled = true,
  });

  static Key pillKey(String languageCode) =>
      ValueKey<String>('kiosk-welcome-language-$languageCode');

  @override
  Widget build(BuildContext context) {
    // One language is not a choice.
    if (languages.length < 2) return const SizedBox.shrink();

    final double gap = pillHeight * 0.22;
    // The welcome screen orders on a tap anywhere; this strip is the one
    // place that must not, or a near-miss between two buttons would start an
    // order in the language the customer was trying to leave.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final LanguageModel language in languages)
            _LanguagePill(
              key: pillKey(language.languageCode!),
              language: language,
              height: pillHeight,
              selected: language.languageCode == current,
              enabled: enabled,
              onTap: () => onSelect(language),
            ),
        ],
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  final LanguageModel language;
  final double height;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _LanguagePill({
    super.key,
    required this.language,
    required this.height,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double flag = height * 0.72;
    final VoidCallback? tap = enabled ? onTap : null;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      label: language.languageName,
      onTap: tap,
      excludeSemantics: true,
      child: KioskTap(
        onTap: tap,
        child: AnimatedContainer(
          duration: _kSwitch,
          curve: Curves.easeOut,
          height: height,
          padding: EdgeInsets.only(left: height * 0.14, right: height * 0.38),
          decoration: BoxDecoration(
            color: selected ? _kInk : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: selected ? _kInk : _kInk.withValues(alpha: 0.12),
              width: (height * 0.02).clamp(1.0, 3.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.18 : 0.08),
                blurRadius: height * 0.35,
                offset: Offset(0, height * 0.08),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
              SizedBox(width: height * 0.2),
              AnimatedDefaultTextStyle(
                duration: _kSwitch,
                curve: Curves.easeOut,
                style: loewBold.copyWith(
                  fontSize: height * 0.3,
                  height: 1.1,
                  letterSpacing: 0,
                  color: selected ? Colors.white : _kInk,
                ),
                child: Text(
                  language.languageName ?? '',
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
