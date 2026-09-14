import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Compact allergen disclosure for the POS product-customize pane — same
/// data and tap-through dialog as the kiosk's [KioskAllergenNotice], but
/// sized for a staff-facing pane read at arm's length rather than the
/// kiosk's own artboard-scaled touch chrome (see `PosResponsive`'s note on
/// why POS does not share the kiosk's sizing model).
class PosAllergenNotice extends StatelessWidget {
  final Set<KioskAllergen> allergens;

  const PosAllergenNotice({super.key, required this.allergens});

  /// Builds the strip for [product], or null when [enabled] is false (the
  /// branch admin toggle is off) or the product declares no allergens.
  static Widget? maybe({required Product product, required bool enabled}) {
    if (!enabled) return null;
    final Set<KioskAllergen> found = kioskProductAllergens(product);
    if (found.isEmpty) return null;
    return PosAllergenNotice(allergens: found);
  }

  List<KioskAllergen> get _ordered =>
      KioskAllergen.values.where(allergens.contains).toList();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => showPosAllergenInfo(context, allergens),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF8EF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDED9C7), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (getTranslated('allergen_contains', context) ?? 'CONTAINS')
                    .toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.1,
                  height: 1.0,
                  color: Color(0xFF6B6459),
                ),
              ),
              const SizedBox(width: 8),
              for (int i = 0; i < _ordered.length; i++)
                Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                  child: _Disc(allergen: _ordered[i]),
                ),
              const SizedBox(width: 8),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6B6459), width: 1),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'i',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    height: 1.0,
                    color: Color(0xFF6B6459),
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

class _Disc extends StatelessWidget {
  final KioskAllergen allergen;
  final double size;
  final double glyph;

  const _Disc({required this.allergen, this.size = 22, this.glyph = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: allergen.swatch, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: SvgPicture.asset(allergen.icon, width: glyph, height: glyph),
    );
  }
}

/// Shared card shell tokens for the POS allergen dialogs ([PosAllergenInfoDialog]
/// here and `PosAllergenFilterDialog`) — a compact desktop-admin popover sized
/// against [PosSettingsSpec], not the kiosk's large touch-artboard dialogs
/// scaled down, which read as oversized and off-brand on a staff window.
class PosAllergenDialogSpec {
  PosAllergenDialogSpec._();

  static const double cardWidth = 400;
  static const double radius = 16;
  static const double pad = 24;
  static const double titleSize = 18;
  static const double subtitleSize = 13;
  static const double sectionGap = 16;
  static const double rowGap = 10;
  static const double buttonHeight = 44;
  static const double buttonRadius = 10;
  static const double closeSize = 28;
}

/// The card shell every POS allergen dialog sits in: cream card, hairline
/// border, soft shadow to lift it off the (blurred) screen behind it —
/// matches the compact language the rest of POS Settings uses.
class _PosAllergenCard extends StatelessWidget {
  final Widget child;

  const _PosAllergenCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final double maxWidth =
        MediaQuery.sizeOf(context).width - PosAllergenDialogSpec.pad * 2;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PosAllergenDialogSpec.pad),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth < PosAllergenDialogSpec.cardWidth
                  ? maxWidth
                  : PosAllergenDialogSpec.cardWidth,
            ),
            child: Container(
              padding: const EdgeInsets.all(PosAllergenDialogSpec.pad),
              decoration: BoxDecoration(
                color: PosSettingsSpec.panelBg,
                borderRadius: BorderRadius.circular(PosAllergenDialogSpec.radius),
                border: Border.all(color: PosSettingsSpec.fieldBorder, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular "x" close affordance shared by both POS allergen dialogs.
class PosAllergenCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const PosAllergenCloseButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: PosAllergenDialogSpec.closeSize,
      height: PosAllergenDialogSpec.closeSize,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(
            Icons.close,
            size: PosAllergenDialogSpec.closeSize * 0.6,
            color: PosSettingsSpec.inkMuted(),
          ),
        ),
      ),
    );
  }
}

/// Primary full-width action button shared by both POS allergen dialogs.
class PosAllergenPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const PosAllergenPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosAllergenDialogSpec.buttonHeight,
      child: Material(
        color: PosSettingsSpec.ink,
        borderRadius: BorderRadius.circular(PosAllergenDialogSpec.buttonRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(PosAllergenDialogSpec.buttonRadius),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: loewBold.copyWith(
                fontSize: 13,
                letterSpacing: 0.6,
                color: PosSettingsSpec.panelBg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "contains allergens" info card — same data as the kiosk's
/// [KioskAllergenNotice] tap-through, sized to [PosAllergenDialogSpec]
/// instead of the kiosk's own touch-artboard dialog.
class PosAllergenInfoDialog extends StatelessWidget {
  final Set<KioskAllergen> allergens;

  const PosAllergenInfoDialog({super.key, required this.allergens});

  List<KioskAllergen> get _ordered =>
      KioskAllergen.values.where(allergens.contains).toList();

  @override
  Widget build(BuildContext context) {
    return _PosAllergenCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  getTranslated('allergen_info_title', context) ??
                      'Contains allergens',
                  style: loewBold.copyWith(
                    fontSize: PosAllergenDialogSpec.titleSize,
                    color: PosSettingsSpec.ink,
                  ),
                ),
              ),
              PosAllergenCloseButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            getTranslated('allergen_info_body', context) ??
                'This item contains the following. Please let us know if you have any allergies.',
            style: loewRegular.copyWith(
              fontSize: PosAllergenDialogSpec.subtitleSize,
              color: PosSettingsSpec.inkMuted(),
              height: 1.35,
            ),
          ),
          const SizedBox(height: PosAllergenDialogSpec.sectionGap),
          for (int i = 0; i < _ordered.length; i++) ...[
            if (i > 0) const SizedBox(height: PosAllergenDialogSpec.rowGap),
            Row(
              children: [
                _Disc(allergen: _ordered[i], size: 28, glyph: 16),
                const SizedBox(width: 12),
                Text(
                  getTranslated(_ordered[i].translationKey, context) ??
                      _ordered[i].label,
                  style: loewMedium.copyWith(
                    fontSize: 14,
                    color: PosSettingsSpec.ink,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: PosAllergenDialogSpec.sectionGap),
          PosAllergenPrimaryButton(
            label: (getTranslated('allergen_info_dismiss', context) ?? 'Got it')
                .toUpperCase(),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Opens the compact POS "contains allergens" info card.
Future<void> showPosAllergenInfo(
  BuildContext context,
  Set<KioskAllergen> allergens,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => PosAllergenInfoDialog(allergens: allergens),
  );
}

/// Compact "what should we avoid?" filter card — same [KioskAllergenPreferences]
/// state and [KioskAllergen] domain data as the kiosk's own filter popup
/// (`KioskAllergenFilterScreen`), sized to [PosAllergenDialogSpec] instead of
/// the kiosk's large touch-artboard dialog. Selecting an allergen here hides
/// matching products from the POS grid the same way it does on the kiosk —
/// see `filterKioskProductsByAllergens` in `pos_home_cart_screen.dart`.
class PosAllergenFilterDialog extends StatefulWidget {
  const PosAllergenFilterDialog({super.key});

  @override
  State<PosAllergenFilterDialog> createState() =>
      _PosAllergenFilterDialogState();
}

class _PosAllergenFilterDialogState extends State<PosAllergenFilterDialog> {
  late final Set<KioskAllergen> _selected = {
    ...KioskAllergenPreferences.instance.avoided,
  };

  bool get _allSelected => _selected.length == KioskAllergen.values.length;

  void _toggle(KioskAllergen allergen) {
    setState(() {
      if (!_selected.remove(allergen)) _selected.add(allergen);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(KioskAllergen.values);
      }
    });
  }

  void _apply() {
    KioskAllergenPreferences.instance.applySelection(_selected);
    Navigator.of(context).pop(true);
  }

  /// Backing out is an answer too — "nothing to declare". Marking it asked is
  /// what keeps the customize-screen gate a once-per-order prompt rather than
  /// something that reopens on every product tap. Mirrors the kiosk's own
  /// `KioskAllergenFilterScreen._dismiss`.
  void _dismiss() {
    KioskAllergenPreferences.instance.markAsked();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null) {
          KioskAllergenPreferences.instance.markAsked();
        }
      },
      child: _PosAllergenCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    getTranslated('allergen_popup_title', context) ??
                        'Anything we should know?',
                    style: loewBold.copyWith(
                      fontSize: PosAllergenDialogSpec.titleSize,
                      color: PosSettingsSpec.ink,
                    ),
                  ),
                ),
                PosAllergenCloseButton(onTap: _dismiss),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              getTranslated('allergen_popup_subtitle', context) ??
                  'Select everything that applies, and we\'ll hide matching items from the menu.',
              style: loewRegular.copyWith(
                fontSize: PosAllergenDialogSpec.subtitleSize,
                color: PosSettingsSpec.inkMuted(),
                height: 1.35,
              ),
            ),
            const SizedBox(height: PosAllergenDialogSpec.sectionGap),
            InkWell(
              onTap: _toggleAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        getTranslated('allergen_select_all', context) ??
                            'Select all',
                        style: loewMedium.copyWith(
                          fontSize: 13,
                          color: PosSettingsSpec.inkMuted(),
                        ),
                      ),
                    ),
                    _Checkbox(selected: _allSelected),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: PosSettingsSpec.divider),
            const SizedBox(height: 8),
            for (final allergen in KioskAllergen.values)
              InkWell(
                onTap: () => _toggle(allergen),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _Disc(allergen: allergen, size: 28, glyph: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          getTranslated(allergen.translationKey, context) ??
                              allergen.label,
                          style: loewMedium.copyWith(
                            fontSize: 14,
                            color: PosSettingsSpec.ink,
                          ),
                        ),
                      ),
                      _Checkbox(selected: _selected.contains(allergen)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: PosAllergenDialogSpec.sectionGap),
            PosAllergenPrimaryButton(
              label: (getTranslated('allergen_apply_filters', context) ??
                      'Apply filters')
                  .toUpperCase(),
              onTap: _apply,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small square selection indicator shared by every filter row.
class _Checkbox extends StatelessWidget {
  final bool selected;

  const _Checkbox({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? PosSettingsSpec.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected ? PosSettingsSpec.ink : PosSettingsSpec.fieldBorder,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? const Icon(Icons.check, size: 14, color: PosSettingsSpec.panelBg)
          : null,
    );
  }
}

/// Opens the compact POS allergen filter card. Returns true when the staff
/// member tapped Apply, false when they backed out. Either way the selection
/// is marked as asked for this order, mirroring `showKioskAllergenFilter`.
Future<bool> showPosAllergenFilter(BuildContext context) async {
  final bool? applied = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const PosAllergenFilterDialog(),
  );
  return applied ?? false;
}
