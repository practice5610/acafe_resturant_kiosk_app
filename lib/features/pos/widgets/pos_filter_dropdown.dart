import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_filters.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_dropdown.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  const PosFilterDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.alwaysShowSelection = false,
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
    if (!_isActive && !alwaysShowSelection) return label;
    return _selected?.label ?? label;
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
        return Material(
          color: active ? PosHomeSpec.ink : PosReceiptsSpec.surface,
          borderRadius: BorderRadius.circular(PosReceiptsSpec.filterRadius),
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(PosReceiptsSpec.filterRadius),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: PosReceiptsSpec.filterPaddingH,
                vertical: PosReceiptsSpec.filterPaddingV,
              ),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(PosReceiptsSpec.filterRadius),
                border: Border.all(
                  color: active ? PosHomeSpec.ink : PosReceiptsSpec.fieldBorder,
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
                      style: loewBold.copyWith(
                        fontSize: PosReceiptsSpec.filterLabelSize,
                        color: active
                            ? PosReceiptsSpec.selectedInk
                            : PosHomeSpec.ink,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: PosReceiptsSpec.filterGap),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 140),
                    child: SvgPicture.asset(
                      Images.posChevronDownSvg,
                      width: PosReceiptsSpec.filterChevronSize,
                      height: PosReceiptsSpec.filterChevronSize,
                      colorFilter: ColorFilter.mode(
                        active ? PosReceiptsSpec.selectedInk : PosHomeSpec.ink,
                        BlendMode.srcIn,
                      ),
                      placeholderBuilder: (_) => Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: PosReceiptsSpec.filterChevronSize,
                        color: active
                            ? PosReceiptsSpec.selectedInk
                            : PosHomeSpec.ink,
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
