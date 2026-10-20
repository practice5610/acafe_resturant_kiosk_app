import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_sections.dart';
import 'package:acafe_customer/features/pos/domain/pos_customize_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_line_copy.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_add_note_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/product_helper.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

// ── palette ───────────────────────────────────────────────────────────────────
// All tokens already live in PosHomeSpec / PosCustomizeSpec; only the
// footer-border colour (shared with kiosk) is local.
const _kFooterBorder = Color(0xFFB9B5A6); // = PosHomeSpec.itemDivider
const _kSidebarBg = Color(0xFFFBF8EF);
const _kSidebarBorder = Color(0xFFF0EBD8);
const _kFooterCta = Color(0xFFF7F1DE);   // cream label on ink pill

// ── public API ─────────────────────────────────────────────────────────────

/// The edited selections the caller receives when the user taps UPDATE ITEM.
class PosReceiptLineEdits {
  final List<List<bool?>> flags;
  final List<AddOn> addOnIds;

  /// The line's kitchen note; null when there is none (or it was cleared).
  final String? instruction;

  const PosReceiptLineEdits({
    required this.flags,
    required this.addOnIds,
    this.instruction,
  });
}

/// [line] with [edits] applied.
///
/// A stored line's price already includes its option surcharges, so the unit
/// price moves by the surcharge difference: the row and the to-charge
/// estimate follow a Small → Large edit. The server re-prices for real on
/// save; this is the till's estimate of it.
CartModel posApplyLineEdits(CartModel line, PosReceiptLineEdits edits) {
  final CartModel picked = CartModel(
    line.price,
    line.discountedPrice,
    line.variation ?? const [],
    line.discountAmount,
    line.quantity,
    line.taxAmount,
    edits.addOnIds,
    line.product,
    edits.flags,
  );
  final double move =
      posLineVariationSurcharge(picked) - posLineVariationSurcharge(line);
  return CartModel(
    (line.price ?? 0) + move,
    (line.discountedPrice ?? line.price ?? 0) + move,
    line.variation ?? const [],
    line.discountAmount,
    line.quantity,
    line.taxAmount,
    edits.addOnIds,
    line.product,
    edits.flags,
    instruction: edits.instruction,
  );
}

/// Opens the full-screen line-item editor — Figma **1915:21366** —
/// as a [showGeneralDialog] overlay.
///
/// [onConfirm] is called with the updated [PosReceiptLineEdits] once the user
/// taps UPDATE ITEM.  The dialog dismisses itself first.
Future<void> showPosReceiptEditLineDialog({
  required BuildContext context,
  required String receiptNumber,
  required CartModel line,
  required void Function(PosReceiptLineEdits edits) onConfirm,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'EditLine',
    barrierColor: Colors.black87,
    pageBuilder: (dialogContext, _, __) => Material(
      type: MaterialType.transparency,
      child: _EditLineScreen(
        receiptNumber: receiptNumber,
        line: line,
        onConfirm: onConfirm,
      ),
    ),
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class _EditLineScreen extends StatefulWidget {
  final String receiptNumber;
  final CartModel line;
  final void Function(PosReceiptLineEdits edits) onConfirm;

  const _EditLineScreen({
    required this.receiptNumber,
    required this.line,
    required this.onConfirm,
  });

  @override
  State<_EditLineScreen> createState() => _EditLineScreenState();
}

class _EditLineScreenState extends State<_EditLineScreen> {
  late List<List<bool?>> _flags;
  late Set<int> _selectedAddonIds;
  late Set<int> _origAddonIds;
  late Map<int, AddOns> _addOnById;
  String? _note;

  @override
  void initState() {
    super.initState();
    // Deep-copy the flags so the original line is never mutated.
    final src = widget.line.variations ?? const [];
    _flags = [for (final row in src) List<bool?>.from(row)];

    _origAddonIds = {
      for (final a in widget.line.addOnIds ?? const <AddOn>[])
        if (a.id != null) a.id!,
    };
    _selectedAddonIds = Set<int>.from(_origAddonIds);
    _note = widget.line.instruction;

    // Index add-ons by ID for quick lookup (price delta, label).
    _addOnById = {};
    for (final group
        in widget.line.product?.effectiveAddOnGroups ?? const []) {
      for (final addon in group.addons) {
        if (addon.id != null) _addOnById[addon.id!] = addon;
      }
    }
  }

  PosReceiptLineEdits get _edits => PosReceiptLineEdits(
        flags: _flags,
        addOnIds: [
          for (final id in _selectedAddonIds) AddOn(id: id, quantity: 1),
        ],
        instruction: _note,
      );

  /// The line as it will read after UPDATE ITEM — what the sidebar shows.
  CartModel get _preview => posApplyLineEdits(widget.line, _edits);

  double get _addonDelta {
    double origTotal = 0;
    double newTotal = 0;
    for (final entry in _addOnById.entries) {
      final price = entry.value.effectivePrice;
      if (_origAddonIds.contains(entry.key)) origTotal += price;
      if (_selectedAddonIds.contains(entry.key)) newTotal += price;
    }
    return newTotal - origTotal;
  }

  /// Add-ons plus option surcharges, per unit.
  double get _priceDelta =>
      _addonDelta +
      posLineVariationSurcharge(_preview) -
      posLineVariationSurcharge(widget.line);

  /// Same rules as the customize screen (ProductProvider.setCartVariationIndex):
  /// a required single choice always holds exactly one pick, an optional one
  /// clears when its pick is tapped again, and a multi choice stops at its max.
  void _toggleVariation(int groupIdx, int valueIdx, Variation variation) {
    setState(() {
      if (groupIdx >= _flags.length) return;
      final row = _flags[groupIdx];
      if (valueIdx >= row.length) return;
      if (!(variation.isMultiSelect ?? false)) {
        final bool clear =
            !(variation.isRequired ?? false) && row[valueIdx] == true;
        for (int i = 0; i < row.length; i++) {
          row[i] = !clear && i == valueIdx;
        }
        return;
      }
      final bool picking = row[valueIdx] != true;
      final int max = variation.max ?? 0;
      if (picking && max > 0 && row.where((f) => f == true).length >= max) {
        return;
      }
      row[valueIdx] = picking;
    });
  }

  void _toggleAddon(int id) {
    setState(() {
      if (_selectedAddonIds.contains(id)) {
        _selectedAddonIds.remove(id);
      } else {
        _selectedAddonIds.add(id);
      }
    });
  }

  /// The same "Add Note" modal the customize screen opens (Figma 1915:14827),
  /// seeded with the line's note and its product's quick-add phrases.
  Future<void> _editNote() async {
    final String? result = await showPosAddNoteDialog(
      context: context,
      initialNote: _note,
      quickAdd: widget.line.product?.noteSuggestions ?? const [],
    );
    if (result == null || !mounted) return;
    setState(() => _note = result.isEmpty ? null : result);
  }

  void _confirm() {
    final edits = _edits;
    Navigator.of(context).pop();
    widget.onConfirm(edits);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PosHomeSpec.pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _LeftPanel(
                    line: widget.line,
                    flags: _flags,
                    selectedAddonIds: _selectedAddonIds,
                    hasNote: _note != null,
                    onToggleVariation: _toggleVariation,
                    onToggleAddon: _toggleAddon,
                    onEditNote: _editNote,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
                _RightSidebar(
                  receiptNumber: widget.receiptNumber,
                  preview: _preview,
                ),
              ],
            ),
          ),
          _Footer(
            delta: _priceDelta,
            onConfirm: _confirm,
          ),
        ],
      ),
    );
  }
}

// ── Left panel ────────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final CartModel line;
  final List<List<bool?>> flags;
  final Set<int> selectedAddonIds;
  final bool hasNote;
  final void Function(int groupIdx, int valueIdx, Variation variation)
      onToggleVariation;
  final void Function(int id) onToggleAddon;
  final VoidCallback onEditNote;
  final VoidCallback onBack;

  const _LeftPanel({
    required this.line,
    required this.flags,
    required this.selectedAddonIds,
    required this.hasNote,
    required this.onToggleVariation,
    required this.onToggleAddon,
    required this.onEditNote,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final product = line.product;
    final name = product?.name ?? '';
    final sections = product != null ? KioskCustomizeSections.of(product) : null;
    final variations = ProductHelper.effectiveVariations(product) ?? [];
    final addOnGroups = product?.effectiveAddOnGroups ?? const [];

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: back + title + ADD NOTE
            _LeftHeader(
              name: name,
              hasNote: hasNote,
              onEditNote: onEditNote,
              onBack: onBack,
            ),
            const SizedBox(height: 24),

            // Variation sections (dietary → size → cup/can)
            if (sections != null) ...[
              for (final entry in [
                ...sections.dietary,
                ...sections.size,
                ...sections.cupCan,
              ])
                if (entry.key < variations.length) ...[
                  _VariationSection(
                    variation: entry.value,
                    groupIdx: entry.key,
                    flags: flags,
                    onToggle: onToggleVariation,
                  ),
                  const SizedBox(height: 24),
                ],
            ],

            // Add-on groups
            for (final group in addOnGroups) ...[
              _AddonSection(
                group: group,
                selectedAddonIds: selectedAddonIds,
                onToggle: onToggleAddon,
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeftHeader extends StatelessWidget {
  final String name;
  final bool hasNote;
  final VoidCallback onEditNote;
  final VoidCallback onBack;

  const _LeftHeader({
    required this.name,
    required this.hasNote,
    required this.onEditNote,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius noteRadius = BorderRadius.circular(14);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kSidebarBg,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0D0D0D), width: 1.5),
            ),
            child: const Icon(
              Icons.chevron_left,
              size: 20,
              color: Color(0xFF0D0D0D),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            name,
            style: loewExtraBold.copyWith(
              fontSize: 24,
              color: const Color(0xFF0D0D0D),
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // "EDIT NOTE" once the line has a note, else "ADD NOTE" — the same
        // switch the customize header makes (Figma 1915:15205).
        Material(
          color: Colors.transparent,
          borderRadius: noteRadius,
          child: InkWell(
            key: const Key('pos-edit-line-note'),
            onTap: onEditNote,
            borderRadius: noteRadius,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 1),
                borderRadius: noteRadius,
              ),
              child: Text(
                hasNote ? 'EDIT NOTE' : 'ADD NOTE',
                style: loewExtraBold.copyWith(
                  fontSize: 14,
                  color: PosHomeSpec.ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VariationSection extends StatelessWidget {
  final Variation variation;
  final int groupIdx;
  final List<List<bool?>> flags;
  final void Function(int groupIdx, int valueIdx, Variation variation) onToggle;

  const _VariationSection({
    required this.variation,
    required this.groupIdx,
    required this.flags,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final values = variation.variationValues ?? const [];
    if (values.isEmpty) return const SizedBox.shrink();
    final rowFlags = groupIdx < flags.length ? flags[groupIdx] : const <bool?>[];
    final int max = variation.max ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(variation.name ?? ''),
        if ((variation.isMultiSelect ?? false) && max > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Choose up to $max',
            style: swiss721Light.copyWith(
              fontSize: 13,
              color: TextTones.secondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: PosCustomizeSpec.optionGridGap,
          runSpacing: PosCustomizeSpec.optionGridGap,
          children: [
            for (int i = 0; i < values.length; i++)
              _OptionTile(
                name: values[i].level?.trim() ?? '',
                price: values[i].optionPrice ?? 0,
                selected: i < rowFlags.length && rowFlags[i] == true,
                onTap: () => onToggle(groupIdx, i, variation),
              ),
          ],
        ),
      ],
    );
  }
}

class _AddonSection extends StatelessWidget {
  final AddOnGroup group;
  final Set<int> selectedAddonIds;
  final void Function(int id) onToggle;

  const _AddonSection({
    required this.group,
    required this.selectedAddonIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (group.addons.isEmpty) return const SizedBox.shrink();
    final title =
        (group.name != null && group.name!.isNotEmpty) ? group.name! : 'Add add-ons';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        const SizedBox(height: 12),
        Wrap(
          spacing: PosCustomizeSpec.optionGridGap,
          runSpacing: PosCustomizeSpec.optionGridGap,
          children: [
            for (final addon in group.addons)
              if (addon.id != null)
                _OptionTile(
                  name: addon.name?.trim() ?? '',
                  price: addon.effectivePrice,
                  selected: selectedAddonIds.contains(addon.id),
                  onTap: () => onToggle(addon.id!),
                  priceSigned: true,
                ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: loewExtraBold.copyWith(
        fontSize: 18,
        color: const Color(0xFF0D0D0D),
      ),
    );
  }
}

/// Option tile — matches the Figma 90px white card with ink outline when selected.
class _OptionTile extends StatelessWidget {
  final String name;
  final double price;
  final bool selected;
  final VoidCallback onTap;
  final bool priceSigned;

  const _OptionTile({
    required this.name,
    required this.price,
    required this.selected,
    required this.onTap,
    this.priceSigned = false,
  });

  String _priceLabel() {
    if (price <= 0) return PosHomeSpec.formatPrice(0);
    final formatted = PriceConverterHelper.convertPrice(price);
    if (!priceSigned) return formatted;
    // "€ +1.50" format
    final m = RegExp(r'^([^\d\s]+)\s*(.*)').firstMatch(formatted);
    if (m != null) return '${m.group(1)} +${m.group(2)}';
    return '+ $formatted';
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosCustomizeSpec.optionCardRadius);
    return Material(
      color: PosCustomizeSpec.optionCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: selected
            ? const BorderSide(
                color: PosHomeSpec.ink,
                width: PosCustomizeSpec.optionCardBorder,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          width: 274,
          height: PosCustomizeSpec.optionCardHeight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: loewExtraBold.copyWith(
                    fontSize: PosCustomizeSpec.optionNameSize,
                    color: PosHomeSpec.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _priceLabel(),
                  textAlign: TextAlign.center,
                  style: swiss721Light.copyWith(
                    fontSize: PosCustomizeSpec.optionPriceSize,
                    color: TextTones.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Right sidebar ─────────────────────────────────────────────────────────────

class _RightSidebar extends StatelessWidget {
  final String receiptNumber;

  /// The line with the editor's current picks applied, read through the same
  /// copy helpers as the receipt row so the two always describe it alike.
  final CartModel preview;

  const _RightSidebar({
    required this.receiptNumber,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final String productName = preview.product?.name ?? '';
    final String price = PosHomeSpec.formatPrice(kioskLineUnitPrice(preview));
    final String? unit = posReceiptUnit(preview);
    final String priceLine = unit == null ? price : '$price · $unit';
    final List<PosReceiptNote> picks = posReceiptNotes(preview);
    final String? note = preview.instruction;

    return Container(
      width: PosReceiptsSpec.sidebarWidth - 42, // 358px (Figma) ≈ 400 - 42
      decoration: const BoxDecoration(
        color: _kSidebarBg,
        border: Border(left: BorderSide(color: PosHomeSpec.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _kSidebarBorder),
              ),
            ),
            child: Text(
              'Editing item on #$receiptNumber',
              style: loewExtraBold.copyWith(
                fontSize: 16,
                color: PosHomeSpec.ink,
              ),
            ),
          ),
          // Item row
          Container(
            key: const Key('pos-edit-line-summary'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _kFooterBorder),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: loewExtraBold.copyWith(
                    fontSize: 14,
                    color: PosHomeSpec.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  priceLine,
                  style: swiss721Light.copyWith(
                    fontSize: 12,
                    color: TextTones.secondary,
                  ),
                ),
                for (final PosReceiptNote pick in picks) ...[
                  const SizedBox(height: 4),
                  _PickRow(pick: pick),
                ],
                if (note != null) ...[
                  const SizedBox(height: 6),
                  PosLineInstruction(text: note),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `+ Large` / `+ Blueberry` / `− Whipped cream` under the item, as on the
/// receipt row.
class _PickRow extends StatelessWidget {
  final PosReceiptNote pick;

  const _PickRow({required this.pick});

  @override
  Widget build(BuildContext context) {
    final TextStyle style = swiss721Light.copyWith(
      fontSize: 12,
      color: TextTones.secondary,
    );
    return Row(
      children: [
        SizedBox(width: 12, child: Text(pick.included ? '+' : '−', style: style)),
        Expanded(
          child: Text(
            pick.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  /// Per-unit price change: add-ons plus option surcharges.
  final double delta;
  final VoidCallback onConfirm;

  const _Footer({required this.delta, required this.onConfirm});

  String _ctaLabel() {
    if (delta.abs() < 0.005) return 'UPDATE ITEM';
    final String formatted = PriceConverterHelper.convertPrice(delta.abs());
    final String sign = delta > 0 ? '+' : '-';
    return 'UPDATE ITEM  •  $sign $formatted';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: PosHomeSpec.pageBg,
        border: Border(
          top: BorderSide(color: _kFooterBorder, width: 1.5),
        ),
      ),
      child: Material(
        color: PosHomeSpec.ink,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onConfirm,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: Text(
              _ctaLabel(),
              style: loewExtraBold.copyWith(
                fontSize: 18,
                color: _kFooterCta,
                letterSpacing: 0.72,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
