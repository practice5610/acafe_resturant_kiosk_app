import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_sections.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_composition.dart';
import 'package:acafe_customer/features/pos/domain/pos_customize_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/product_helper.dart';
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

  const PosReceiptLineEdits({required this.flags, required this.addOnIds});
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

    // Index add-ons by ID for quick lookup (price delta, label).
    _addOnById = {};
    for (final group
        in widget.line.product?.effectiveAddOnGroups ?? const []) {
      for (final addon in group.addons) {
        if (addon.id != null) _addOnById[addon.id!] = addon;
      }
    }
  }

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

  void _toggleVariation(int groupIdx, int valueIdx, bool isMultiSelect) {
    setState(() {
      if (groupIdx >= _flags.length) return;
      final row = _flags[groupIdx];
      if (!isMultiSelect) {
        for (int i = 0; i < row.length; i++) {
          row[i] = i == valueIdx ? true : false;
        }
      } else {
        if (valueIdx < row.length) row[valueIdx] = !(row[valueIdx] ?? false);
      }
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

  void _confirm() {
    final edits = PosReceiptLineEdits(
      flags: _flags,
      addOnIds: [
        for (final id in _selectedAddonIds) AddOn(id: id, quantity: 1),
      ],
    );
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
                    onToggleVariation: _toggleVariation,
                    onToggleAddon: _toggleAddon,
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
                _RightSidebar(
                  receiptNumber: widget.receiptNumber,
                  line: widget.line,
                  flags: _flags,
                  selectedAddonIds: _selectedAddonIds,
                  addOnById: _addOnById,
                ),
              ],
            ),
          ),
          _Footer(
            addonDelta: _addonDelta,
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
  final void Function(int groupIdx, int valueIdx, bool isMultiSelect)
      onToggleVariation;
  final void Function(int id) onToggleAddon;
  final VoidCallback onBack;

  const _LeftPanel({
    required this.line,
    required this.flags,
    required this.selectedAddonIds,
    required this.onToggleVariation,
    required this.onToggleAddon,
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
            _LeftHeader(name: name, onBack: onBack),
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
                    isMultiSelect:
                        entry.value.isMultiSelect ?? false,
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
  final VoidCallback onBack;

  const _LeftHeader({required this.name, required this.onBack});

  @override
  Widget build(BuildContext context) {
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'ADD NOTE',
            style: loewExtraBold.copyWith(
              fontSize: 14,
              color: PosHomeSpec.ink,
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
  final bool isMultiSelect;
  final void Function(int groupIdx, int valueIdx, bool isMultiSelect) onToggle;

  const _VariationSection({
    required this.variation,
    required this.groupIdx,
    required this.flags,
    required this.isMultiSelect,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final values = variation.variationValues ?? const [];
    if (values.isEmpty) return const SizedBox.shrink();
    final rowFlags = groupIdx < flags.length ? flags[groupIdx] : const <bool?>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(variation.name ?? ''),
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
                onTap: () => onToggle(groupIdx, i, isMultiSelect),
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
                    color: PosHomeSpec.inkAlpha(0.6),
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
  final CartModel line;
  final List<List<bool?>> flags;
  final Set<int> selectedAddonIds;
  final Map<int, AddOns> addOnById;

  const _RightSidebar({
    required this.receiptNumber,
    required this.line,
    required this.flags,
    required this.selectedAddonIds,
    required this.addOnById,
  });

  /// Cup/Can label derived from the LOCAL flags, not from the (immutable) line.
  String? _unit() {
    final variations = line.product?.variations ?? const <Variation>[];
    for (int i = 0; i < variations.length; i++) {
      if (!kioskCupCanPattern.hasMatch(variations[i].name ?? '')) continue;
      final values = variations[i].variationValues ?? const [];
      final row = i < flags.length ? flags[i] : const <bool?>[];
      for (int j = 0; j < values.length && j < row.length; j++) {
        if (row[j] == true) {
          final label = values[j].level ?? '';
          if (label.isNotEmpty) return label;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final String productName = line.product?.name ?? '';
    final double basePrice = line.discountedPrice ?? line.price ?? 0;
    final String? unit = _unit();
    final String priceLine =
        unit == null ? PosHomeSpec.formatPrice(basePrice) : '${PosHomeSpec.formatPrice(basePrice)} · $unit';

    // Collect selected non-default add-on labels.
    final List<String> addOnLabels = [
      for (final id in selectedAddonIds)
        if (addOnById.containsKey(id) && !addOnById[id]!.isDefault)
          addOnById[id]!.name ?? '',
    ].where((s) => s.isNotEmpty).toList();

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _kFooterBorder),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                          color: PosHomeSpec.inkAlpha(0.6),
                        ),
                      ),
                      if (addOnLabels.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '+ ${addOnLabels.join(', ')}',
                          style: swiss721Light.copyWith(
                            fontSize: 11,
                            color: PosHomeSpec.inkAlpha(0.53),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final double addonDelta;
  final VoidCallback onConfirm;

  const _Footer({required this.addonDelta, required this.onConfirm});

  String _ctaLabel() {
    if (addonDelta == 0) return 'UPDATE ITEM';
    final String formatted = PriceConverterHelper.convertPrice(addonDelta.abs());
    final String sign = addonDelta > 0 ? '+' : '-';
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
