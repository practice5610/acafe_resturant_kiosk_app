import 'package:flutter/material.dart';

import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_allergen_filter_screen.dart';
import 'package:acafe_customer/features/search/widget/kiosk_search_theme.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/styles.dart';

/// The allergen entry point inside the menu's Filter sheet.
///
/// The allergen popup opens once per order, on the customer's first reach for a
/// product, and dismissing it counts as "nothing to declare" — which is right,
/// but it also meant a customer who waved it away had no way back. The only
/// other affordance was the empty-state link, and that only appears once a
/// filter is already active, so it could never be the way IN.
///
/// This row is that way back. It is deliberately not a set of checkboxes: the
/// popup is the one place allergens are chosen, so there is a single screen to
/// keep correct and a single place the "asked" flag is set.
///
/// Selection is NOT part of [SearchProvider]'s filter state, so it applies the
/// moment the popup's own APPLY is pressed and is unaffected by this sheet's
/// Apply / Reset. Reset clearing someone's allergens would be dangerous in a
/// way none of the other filters are.
class KioskAllergenFilterRow extends StatelessWidget {
  /// Called before the popup opens — the menu uses it to close the filter
  /// sheet, so the popup is not stacked on top of it.
  final VoidCallback? onBeforeOpen;

  const KioskAllergenFilterRow({super.key, this.onBeforeOpen});

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the popup commits, so re-opening the sheet shows what is
    // actually being avoided rather than a stale summary.
    return ListenableBuilder(
      listenable: KioskAllergenPreferences.instance,
      builder: (context, _) {
        final Set<KioskAllergen> avoided =
            KioskAllergenPreferences.instance.avoided;
        final bool active = avoided.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kioskTranslate(context, 'allergens', 'Allergens'),
              style: loewBold.copyWith(
                fontSize: Dimensions.fontSizeLarge,
                color: KioskSearchTheme.primary,
              ),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            Material(
              color: KioskSearchTheme.surface,
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () async {
                  onBeforeOpen?.call();
                  await showKioskAllergenFilter(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Dimensions.paddingSizeDefault,
                    vertical: Dimensions.paddingSizeDefault,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: active
                          ? KioskSearchTheme.primary
                          : KioskSearchTheme.border,
                    ),
                    borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
                  ),
                  child: Row(
                    children: [
                      _AllergenBadge(avoided: avoided),
                      const SizedBox(width: Dimensions.paddingSizeDefault),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              kioskTranslate(context, 'allergen_filter_title',
                                  'Anything to avoid?'),
                              style: loewBold.copyWith(
                                fontSize: Dimensions.fontSizeDefault,
                                color: KioskSearchTheme.primary,
                              ),
                            ),
                            const SizedBox(
                                height: Dimensions.paddingSizeExtraSmall),
                            Text(
                              _summary(context, avoided),
                              style: rubikRegular.copyWith(
                                fontSize: Dimensions.fontSizeSmall,
                                color: active
                                    ? KioskSearchTheme.primary
                                    : KioskSearchTheme.muted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Dimensions.paddingSizeSmall),
                      const Icon(
                        Icons.chevron_right,
                        color: KioskSearchTheme.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// What is currently being avoided, named rather than counted — "Dairy,
  /// Nuts" tells the customer whether the list is still right; "2 selected"
  /// makes them open the popup to find out.
  String _summary(BuildContext context, Set<KioskAllergen> avoided) {
    if (avoided.isEmpty) {
      return kioskTranslate(context, 'allergen_filter_none',
          'Tap to choose allergens to hide from the menu');
    }
    // Enum order, not selection order, so the summary is stable between visits.
    final List<String> names = KioskAllergen.values
        .where(avoided.contains)
        .map((a) => kioskTranslate(context, a.translationKey, a.label))
        .toList();
    return '${kioskTranslate(context, 'allergen_filter_hiding', 'Hiding')}: '
        '${names.join(', ')}';
  }
}

/// Circular badge: the avoided allergens' own swatches when there is a
/// selection, a neutral glyph when there is not.
class _AllergenBadge extends StatelessWidget {
  final Set<KioskAllergen> avoided;
  const _AllergenBadge({required this.avoided});

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    if (avoided.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: const BoxDecoration(
          color: Color(0xFFF3EFE6),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.no_food_outlined,
          size: 22,
          color: KioskSearchTheme.muted,
        ),
      );
    }

    // Up to three swatches, overlapped like a stack of chips, with the rest
    // implied by the summary text beside it. More than three at this size
    // stops reading as anything at all.
    final List<KioskAllergen> shown =
        KioskAllergen.values.where(avoided.contains).take(3).toList();

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < shown.length; i++)
            Positioned(
              left: i * 12.0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: shown[i].swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: KioskSearchTheme.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
