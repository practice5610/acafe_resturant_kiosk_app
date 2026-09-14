import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_allergen_notice.dart'
    show showKioskAllergenInfo;
import 'package:acafe_customer/localization/language_constrants.dart';

/// Scale for the shared kiosk allergen dialogs ([showKioskAllergenInfo],
/// [showKioskAllergenFilter]) when opened from POS.
///
/// Those dialogs compute their own scale from the *height* of a tall kiosk
/// touchscreen artboard (2572×4530), which collapses to a sliver on POS's
/// short landscape window. POS instead scales off width only, against the
/// same 2572 artboard, clamped to a size that reads well on a staff-facing
/// desktop/tablet window rather than a customer kiosk at arm's length.
double posAllergenDialogScale(BuildContext context) {
  final double width = MediaQuery.sizeOf(context).width;
  return (width / 2572).clamp(0.28, 0.5);
}

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
        onTap: () => showKioskAllergenInfo(context, allergens,
            scale: posAllergenDialogScale(context)),
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

  const _Disc({required this.allergen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: allergen.swatch, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: SvgPicture.asset(allergen.icon, width: 12, height: 12),
    );
  }
}
