import 'dart:math' as math;

import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_line_copy.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// POS "Apply discount" dialog — Figma `Apply discount – Modal` (1915:14411).
///
/// A manual percentage/amount discount applied against the selected cart lines.
/// On apply it writes the computed amount through [CouponProvider.setManualDiscount],
/// which reuses the existing `discount` field (and therefore the existing
/// `coupon_discount_amount` order field) — no new order-writing or API fields.
Future<void> showPosApplyDiscountDialog({
  required BuildContext context,
  required List<CartModel?> cartList,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x66000000), // rgba(0,0,0,0.4)
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _ApplyDiscountModal(cartList: cartList),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}

/// Immutable draft of the discount being composed.
class _DiscountDraft {
  final bool percentMode;
  final double value;
  final Set<int> selected;

  const _DiscountDraft({
    required this.percentMode,
    required this.value,
    required this.selected,
  });

  _DiscountDraft copyWith({
    bool? percentMode,
    double? value,
    Set<int>? selected,
  }) =>
      _DiscountDraft(
        percentMode: percentMode ?? this.percentMode,
        value: value ?? this.value,
        selected: selected ?? this.selected,
      );
}

class _ApplyDiscountModal extends StatefulWidget {
  final List<CartModel?> cartList;

  const _ApplyDiscountModal({required this.cartList});

  @override
  State<_ApplyDiscountModal> createState() => _ApplyDiscountModalState();
}

class _ApplyDiscountModalState extends State<_ApplyDiscountModal> {
  // Muted label colour #6F6A67 maps to the existing PosUI.inkMuted (#6E6A63).
  static const Color _muted = PosUI.inkMuted;
  static const Color _hairline = PosHomeSpec.contextMenuBorder; // #EAE5D5
  static const List<double> _presets = [10, 15, 20];

  late final List<int> _lineIndices;
  late final ValueNotifier<_DiscountDraft> _draft;
  final TextEditingController _valueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _lineIndices = [
      for (int i = 0; i < widget.cartList.length; i++)
        if (widget.cartList[i] != null) i,
    ];
    _draft = ValueNotifier(
      _DiscountDraft(
        percentMode: true,
        value: 10,
        selected: {..._lineIndices},
      ),
    );
    _valueController.text = _formatInput(10);
  }

  @override
  void dispose() {
    _draft.dispose();
    _valueController.dispose();
    super.dispose();
  }

  String _formatInput(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  double _lineTotal(int index) => kioskLineTotal(widget.cartList[index]!);

  double _selectedTotal(_DiscountDraft d) {
    double total = 0;
    for (final i in d.selected) {
      total += _lineTotal(i);
    }
    return total;
  }

  double _discountAmount(_DiscountDraft d) {
    final double base = _selectedTotal(d);
    final double raw =
        d.percentMode ? base * (d.value / 100.0) : d.value;
    return math.max(0, math.min(raw, base));
  }

  void _selectPreset(double preset) {
    _valueController.text = _formatInput(preset);
    _draft.value = _draft.value.copyWith(percentMode: true, value: preset);
  }

  void _setMode(bool percent) {
    _draft.value = _draft.value.copyWith(percentMode: percent);
  }

  void _onValueTyped(String text) {
    final double parsed = double.tryParse(text.replaceAll(',', '.')) ?? 0;
    _draft.value = _draft.value.copyWith(value: parsed);
  }

  void _toggleItem(int index) {
    final Set<int> next = {..._draft.value.selected};
    if (!next.remove(index)) next.add(index);
    _draft.value = _draft.value.copyWith(selected: next);
  }

  void _deselectAll() {
    _draft.value = _draft.value.copyWith(selected: <int>{});
  }

  void _apply() {
    final _DiscountDraft d = _draft.value;
    final double amount = _discountAmount(d);
    if (amount <= 0) {
      showCustomSnackBarHelper('Enter a discount above zero', isError: false);
      return;
    }
    context.read<CouponProvider>().setManualDiscount(amount);
    Navigator.of(context).pop();
    showCustomSnackBarHelper('Discount applied', isError: false);
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double width = math.min(1080, screen.width - 48);
    final double maxHeight = screen.height - 48;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PosHomeSpec.panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hairline, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000), // rgba(0,0,0,0.2)
              offset: Offset(0, 18),
              blurRadius: 48,
              spreadRadius: -12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _valueColumn()),
                      const SizedBox(width: 32),
                      SizedBox(width: 420, child: _itemsAndPreviewColumn()),
                    ],
                  ),
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Apply discount',
                  style: loewExtraBold.copyWith(
                    fontSize: 22,
                    color: PosHomeSpec.ink,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'By default, everything is selected.',
                  style: swiss721Light.copyWith(
                    fontSize: 13,
                    color: _muted,
                    height: 18 / 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, size: 20, color: PosHomeSpec.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: loewBold.copyWith(
          fontSize: 11,
          color: _muted,
          letterSpacing: 1,
          height: 1.0,
        ),
      );

  Widget _valueColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionLabel('PRESET PERCENTAGE'),
        const SizedBox(height: 10),
        ValueListenableBuilder<_DiscountDraft>(
          valueListenable: _draft,
          builder: (context, d, _) {
            return Row(
              children: [
                for (int i = 0; i < _presets.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _PresetButton(
                      label: '${_presets[i].toInt()}%',
                      active: d.percentMode && d.value == _presets[i],
                      onTap: () => _selectPreset(_presets[i]),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _customCard(),
      ],
    );
  }

  Widget _customCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosHomeSpec.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Custom',
                      style: loewExtraBold.copyWith(
                        fontSize: 14,
                        color: PosHomeSpec.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter another discount value',
                      style: swiss721Light.copyWith(
                        fontSize: 12,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<_DiscountDraft>(
                valueListenable: _draft,
                builder: (context, d, _) => _ModeToggle(
                  percentMode: d.percentMode,
                  onChanged: _setMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _customInput(),
        ],
      ),
    );
  }

  Widget _customInput() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: PosHomeSpec.ink, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              cursorColor: PosHomeSpec.ink,
              onChanged: _onValueTyped,
              style: loewBold.copyWith(fontSize: 24, color: PosHomeSpec.ink),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
          ValueListenableBuilder<_DiscountDraft>(
            valueListenable: _draft,
            builder: (context, d, _) => Text(
              d.percentMode ? '%' : '€',
              style: loewBold.copyWith(fontSize: 14, color: _muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemsAndPreviewColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel('APPLY TO ITEMS')),
            Material(
              color: PosHomeSpec.panelBg,
              child: InkWell(
                onTap: _deselectAll,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: _DeselectLabel(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ValueListenableBuilder<_DiscountDraft>(
          valueListenable: _draft,
          builder: (context, d, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final index in _lineIndices)
                  _DiscountItemRow(
                    line: widget.cartList[index]!,
                    selected: d.selected.contains(index),
                    onTap: () => _toggleItem(index),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _previewCard(),
      ],
    );
  }

  Widget _previewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline),
      ),
      child: ValueListenableBuilder<_DiscountDraft>(
        valueListenable: _draft,
        builder: (context, d, _) {
          final double itemsTotal = _selectedTotal(d);
          final double discount = _discountAmount(d);
          final double total = itemsTotal - discount;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionLabel('PREVIEW'),
              const SizedBox(height: 12),
              _previewRow(
                'Items total',
                PosHomeSpec.formatPrice(itemsTotal),
                color: PosHomeSpec.ink,
                bold: false,
              ),
              const SizedBox(height: 10),
              _previewRow(
                'Discount',
                '− ${PosHomeSpec.formatPrice(discount)}',
                color: PosHomeSpec.discountGreen,
                bold: false,
              ),
              const SizedBox(height: 10),
              const ColoredBox(
                color: _hairline,
                child: SizedBox(height: 1, width: double.infinity),
              ),
              const SizedBox(height: 10),
              _previewRow(
                'Total',
                PosHomeSpec.formatPrice(total),
                color: PosHomeSpec.ink,
                bold: true,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _previewRow(String label, String value,
      {required Color color, required bool bold}) {
    final TextStyle style = (bold ? loewExtraBold : loewBold).copyWith(
      fontSize: 13,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }

  Widget _bottomBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: PosHomeSpec.pageBg,
        border: Border(top: BorderSide(color: PosHomeSpec.ink, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14241F20), // rgba(36,31,32,0.08)
            offset: Offset(0, -6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Material(
        color: PosHomeSpec.ink,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          onTap: _apply,
          borderRadius: BorderRadius.circular(32),
          child: SizedBox(
            height: 64,
            width: double.infinity,
            child: Center(
              child: Text(
                'Apply discount',
                style: loewBold.copyWith(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.black : Colors.transparent,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: active
                ? null
                : Border.all(color: Colors.black, width: 2),
          ),
          child: Text(
            label,
            style: loewMedium.copyWith(
              fontSize: 13,
              color: active ? Colors.white : Colors.black,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool percentMode;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.percentMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosHomeSpec.contextMenuBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('%', percentMode, () => onChanged(true)),
          _segment('€', !percentMode, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return Material(
      color: active ? PosHomeSpec.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
          child: Text(
            label,
            style: loewBold.copyWith(
              fontSize: 11,
              color: active ? Colors.white : PosUI.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeselectLabel extends StatelessWidget {
  const _DeselectLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Deselect all',
      style: swiss721Light.copyWith(
        fontSize: 12,
        color: Colors.black,
        decoration: TextDecoration.underline,
      ),
    );
  }
}

class _DiscountItemRow extends StatelessWidget {
  final CartModel line;
  final bool selected;
  final VoidCallback onTap;

  const _DiscountItemRow({
    required this.line,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String? unit = posReceiptUnit(line);
    final String price = PosHomeSpec.formatPrice(kioskLineUnitPrice(line));
    final String priceLine = unit == null ? price : '$price · $unit';

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: PosHomeSpec.itemDivider)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Row(
          children: [
            _Checkbox(checked: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    posReceiptLineName(line),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewExtraBold.copyWith(
                      fontSize: 14,
                      color: PosHomeSpec.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    priceLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: swiss721Light.copyWith(
                      fontSize: 12,
                      color: PosUI.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 22px selection checkbox (Figma `Selected checkbox` 1915:14447).
class _Checkbox extends StatelessWidget {
  final bool checked;

  const _Checkbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? PosHomeSpec.ink : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: checked ? PosHomeSpec.ink : PosHomeSpec.itemDivider,
          width: 1.5,
        ),
      ),
      child: checked
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null,
    );
  }
}
