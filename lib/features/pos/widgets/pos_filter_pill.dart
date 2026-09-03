import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Sub-category filter pill above the product grid.
///
/// Deliberately not `PosNavPill`: that one is the top-nav pill at 14px with
/// 20/12 padding and no border. These are 13px, 18/8, uppercase, and carry a
/// 1.5px outline when inactive rather than a white fill. Same family, different
/// component — forcing one widget to serve both would mean a pile of
/// mode-conditional styling.
class PosFilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const PosFilterPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? PosHomeSpec.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(PosHomeSpec.pillRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosHomeSpec.pillRadius),
        child: Container(
          height: PosHomeSpec.pillHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosHomeSpec.pillRadius),
            border: active
                ? null
                : Border.all(
                    color: PosHomeSpec.ink,
                    width: PosHomeSpec.pillBorder,
                  ),
          ),
          child: Text(
            label.toUpperCase(),
            style: (active ? loewBold : loewMedium).copyWith(
              fontSize: PosHomeSpec.pillLabelSize,
              color: active ? PosHomeSpec.pageBg : PosHomeSpec.ink,
              height: 16 / 13,
            ),
          ),
        ),
      ),
    );
  }
}
