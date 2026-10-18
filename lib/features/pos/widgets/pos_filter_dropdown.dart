import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_filters.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_dropdown.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// How a [PosFilterDropdown] trigger is drawn. Only the trigger varies; the
/// menu is always the shared [PosDropdown].
///
/// [receipts] is the original look and stays the default, so the Receipts
/// screen is unchanged. [orders] is the Orders board's filter-row pill.
@immutable
class PosFilterDropdownStyle {
  final double radius;
  final Color idleFill;
  final Color idleBorder;
  final double borderWidth;
  final EdgeInsets padding;
  final TextStyle labelFont;
  final double labelSize;
  final bool uppercase;
  final String chevronAsset;
  final double chevronSize;
  final double gap;

  const PosFilterDropdownStyle({
    required this.radius,
    required this.idleFill,
    required this.idleBorder,
    required this.borderWidth,
    required this.padding,
    required this.labelFont,
    required this.labelSize,
    required this.uppercase,
    required this.chevronAsset,
    required this.chevronSize,
    required this.gap,
  });

  /// Receipts (Figma 1641:3239…1641:3251).
  static const PosFilterDropdownStyle receipts = PosFilterDropdownStyle(
    radius: PosReceiptsSpec.filterRadius,
    idleFill: PosReceiptsSpec.surface,
    idleBorder: PosReceiptsSpec.fieldBorder,
    borderWidth: 1,
    padding: EdgeInsets.symmetric(
      horizontal: PosReceiptsSpec.filterPaddingH,
      vertical: PosReceiptsSpec.filterPaddingV,
    ),
    labelFont: loewBold,
    labelSize: PosReceiptsSpec.filterLabelSize,
    uppercase: false,
    chevronAsset: Images.posChevronDownSvg,
    chevronSize: PosReceiptsSpec.filterChevronSize,
    gap: PosReceiptsSpec.filterGap,
  );

  /// Orders board `dropdown-row` (Figma 1915:15802…1915:15814): outlined ink
  /// pill on the page, Medium 13 uppercase.
  static const PosFilterDropdownStyle orders = PosFilterDropdownStyle(
    radius: PosOrdersSpec.filterPillRadius,
    idleFill: Colors.transparent,
    idleBorder: PosHomeSpec.ink,
    borderWidth: PosOrdersSpec.filterPillBorder,
    padding: EdgeInsets.fromLTRB(
      PosOrdersSpec.dropdownPaddingLeft,
      PosOrdersSpec.filterPillPaddingV,
      PosOrdersSpec.dropdownPaddingRight,
      PosOrdersSpec.filterPillPaddingV,
    ),
    labelFont: loewMedium,
    labelSize: PosOrdersSpec.dropdownLabelSize,
    uppercase: true,
    chevronAsset: Images.posOrdersChevronDownSvg,
    chevronSize: PosOrdersSpec.chevronSize,
    gap: PosOrdersSpec.filterIconGap,
  );
}

/// A filter pill that opens a menu — Figma `status-filter` / `category-filter`
/// / `amount-filter` / `date-filter` (1641:3239…1641:3251).
///
/// Deliberately not a new dropdown *variant*: the menu is the shared
/// [PosDropdown] (same fill, radius, border, shadow and checkmark row as
/// [PosSettingsDropdown]), and only the trigger differs — a 36px pill with a
/// chevron instead of a labelled settings field. Sharing the menu chrome is
/// what keeps every POS select looking like the same control.
class PosFilterDropdown<T> extends StatelessWidget {
  /// Shown when nothing is picked yet ("Status", "Category", "Amount").
  final String label;

  final List<PosReceiptFilterOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// True renders the picked option's label in place of [label]. The date pill
  /// always shows its selection ("Today"), the others fall back to their own
  /// name while they are on their "all" entry.
  final bool alwaysShowSelection;

  /// Trigger look. Defaults to [PosFilterDropdownStyle.receipts].
  final PosFilterDropdownStyle style;

  const PosFilterDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.alwaysShowSelection = false,
    this.style = PosFilterDropdownStyle.receipts,
  });

  PosReceiptFilterOption<T>? get _selected {
    for (final PosReceiptFilterOption<T> option in options) {
      if (option.value == value) return option;
    }
    return null;
  }

  /// Active means "narrowed": anything other than the set's first entry, which
  /// is always the un-filtered default. Not `value != null` — the date pill's
  /// default is `today`, not null, and Figma draws that one plain like the
  /// rest.
  bool get _isActive => options.isNotEmpty && value != options.first.value;

  String get _displayLabel {
    final String text = (!_isActive && !alwaysShowSelection)
        ? label
        : (_selected?.label ?? label);
    return style.uppercase ? text.toUpperCase() : text;
  }

  @override
  Widget build(BuildContext context) {
    final bool active = _isActive;

    return PosDropdown<T>(
      value: value,
      onChanged: onChanged,
      menuMinWidth: 180,
      itemHeight: PosReceiptsSpec.filterMenuItemHeight,
      options: [
        for (final PosReceiptFilterOption<T> o in options)
          PosDropdownOption<T>(value: o.value, label: o.label),
      ],
      triggerBuilder: (context, selected, isOpen, toggle) {
        final Color ink = active ? PosReceiptsSpec.selectedInk : PosHomeSpec.ink;

        return Material(
          color: active ? PosHomeSpec.ink : style.idleFill,
          borderRadius: BorderRadius.circular(style.radius),
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(style.radius),
            child: Container(
              padding: style.padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(style.radius),
                border: Border.all(
                  color: active ? PosHomeSpec.ink : style.idleBorder,
                  width: style.borderWidth,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style.labelFont.copyWith(
                        fontSize: style.labelSize,
                        color: ink,
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: style.gap),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 140),
                    child: SvgPicture.asset(
                      style.chevronAsset,
                      width: style.chevronSize,
                      height: style.chevronSize,
                      colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
                      placeholderBuilder: (_) => Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: style.chevronSize,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// `export-btn` (1641:3255) — ink-filled, same 8px radius as the pills.
class PosExportButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool busy;

  const PosExportButton({super.key, this.onTap, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? PosHomeSpec.inkAlpha(0.35) : PosHomeSpec.ink,
      borderRadius: BorderRadius.circular(PosReceiptsSpec.filterRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosReceiptsSpec.filterRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PosReceiptsSpec.filterPaddingH,
            vertical: PosReceiptsSpec.filterPaddingV,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                busy ? 'EXPORTING' : 'EXPORT',
                style: loewBold.copyWith(
                  fontSize: PosReceiptsSpec.filterLabelSize,
                  color: PosReceiptsSpec.selectedInk,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
