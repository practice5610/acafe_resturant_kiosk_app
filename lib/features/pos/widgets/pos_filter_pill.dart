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

  /// Multiplier on height, padding, radius and label size so the pill grows
  /// and shrinks with its pane; the outline stroke stays fixed. Defaults to 1
  /// (the flat Figma pill, as the Orders board draws it); the home screen
  /// passes [PosResponsive.homeScale].
  final double scale;

  const PosFilterPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosHomeSpec.pillRadius * scale);

    return Material(
      color: active ? PosHomeSpec.ink : Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: PosHomeSpec.pillHeight * scale,
          padding: EdgeInsets.symmetric(
              horizontal: PosHomeSpec.pillPadding.left * scale),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: active
                ? null
                : Border.all(
                    color: PosHomeSpec.ink,
                    width: PosHomeSpec.pillBorder,
                  ),
          ),
          // widthFactor 1 shrink-wraps the label while still centring it
          // vertically. Container.alignment would instead stretch the pill to
          // any bounded width it is handed — a Wrap's full row, say.
          child: Align(
            widthFactor: 1,
            child: Text(
              label.toUpperCase(),
              style: (active ? loewBold : loewMedium).copyWith(
                fontSize: PosHomeSpec.pillLabelSize * scale,
                color: active ? PosHomeSpec.pageBg : PosHomeSpec.ink,
                height: 16 / 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
