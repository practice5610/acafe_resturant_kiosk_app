import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// A fully-rounded POS nav pill.
///
/// Width is driven by content plus padding rather than the snapped per-pill
/// widths in the design file, so a longer label — or a localised one — grows
/// the pill instead of clipping. The Figma widths fall out of this exactly:
/// 20 + 33 + 20 = 73 for POS, 18 + 50 + 18 = 86 for Report, and so on.
///
/// Standalone rather than private to the nav bar: the POS design uses the same
/// pill for the product-grid category filters, so the next screen that needs
/// one should not have to re-derive it.
class PosNavPill extends StatelessWidget {
  /// Design default. Report is the one exception in the frame, at 18/10.
  static const EdgeInsets defaultPadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 12);

  static const double labelSize = 14;

  /// 17px line box at 14px type, measured off the design.
  static const double labelHeight = 17 / 14;

  /// "Fully rounded" — any radius past half the pill's height reads the same.
  static const double radius = 100;

  final String label;
  final bool active;

  /// Report is Loew Bold in the source file while its neighbours are Medium.
  /// That is deliberate in the design, not an inconsistency to normalise.
  final bool bold;

  final EdgeInsets padding;
  final VoidCallback? onTap;

  const PosNavPill({
    super.key,
    required this.label,
    required this.active,
    this.bold = false,
    this.padding = defaultPadding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color background = active ? PosUI.ink : Colors.white;
    final Color foreground = active ? PosUI.pageBg : PosUI.ink;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: padding,
          child: Text(
            label,
            style: (bold ? loewBold : loewMedium).copyWith(
              fontSize: labelSize,
              color: foreground,
              height: labelHeight,
            ),
          ),
        ),
      ),
    );
  }
}
