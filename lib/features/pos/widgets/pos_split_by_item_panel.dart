import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_builder.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

const _labelInk = Color(0xFF78706E);
const _mutedInk = Color(0xFFA7A19A);

/// Right pane for split-by-item: shows items to select, payment method, and summary.
///
/// Layout: header (fixed) → scrollable item list (flexible) → bottom actions (fixed).
/// The Start Payment button and Pay With toggle are always visible regardless of
/// how many items are in the order.
class PosSplitByItemPanel extends StatelessWidget {
  final int groupSeq;
  final double grandTotal;
  final double remaining;
  final List<PosSplitByItemLineItem> lineItems;
  final PosSplitByItemGroupsBuilder groupBuilder;
  final PosPaymentMethod paymentMethod;
  final ValueChanged<int> onToggleItem;
  final ValueChanged<PosPaymentMethod> onPaymentMethodChanged;
  final VoidCallback onStartPayment;
  final VoidCallback onAddTip;

  const PosSplitByItemPanel({
    super.key,
    required this.groupSeq,
    required this.grandTotal,
    required this.remaining,
    required this.lineItems,
    required this.groupBuilder,
    required this.paymentMethod,
    required this.onToggleItem,
    required this.onPaymentMethodChanged,
    required this.onStartPayment,
    required this.onAddTip,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PosSplitByItemGroupBuilder>(
      valueListenable: groupBuilder,
      builder: (context, builder, _) {
        final double selectedAmount = builder.calculateAmount(lineItems);
        final bool disabled = selectedAmount <= 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Fixed header ─────────────────────────────────────────────
            _SplitHeader(grandTotal: grandTotal),
            _SectionLabel(
              'SELECT ITEMS FOR PAYMENT $groupSeq'
              ' · ${builder.selectedItemIds.length} OF ${lineItems.length}',
            ),

            // ── Scrollable item list ──────────────────────────────────────
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemCount: lineItems.length,
                itemBuilder: (context, i) {
                  final item = lineItems[i];
                  final bool selected = builder.isSelected(item.id);
                  return _ItemTile(
                    item: item,
                    selected: selected,
                    onTap: () => onToggleItem(item.id),
                  );
                },
              ),
            ),

            // ── Fixed bottom actions ──────────────────────────────────────
            const _SectionDivider(),
            _SectionLabel('PAY WITH'),
            _PayWithRow(
              method: paymentMethod,
              onChanged: onPaymentMethodChanged,
            ),
            _SelectedSummary(
              selectedAmount: selectedAmount,
              remaining: remaining,
            ),
            _TipRow(onTap: onAddTip),
            _StartPaymentButton(
              seq: groupSeq,
              amount: selectedAmount,
              disabled: disabled,
              onTap: onStartPayment,
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _SplitHeader extends StatelessWidget {
  final double grandTotal;

  const _SplitHeader({required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SPLIT PAYMENT',
            style: loewBold.copyWith(
              fontSize: 11,
              letterSpacing: 0.8,
              color: _labelInk,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Select items for payment',
            style: swiss721Light.copyWith(fontSize: 10, color: _mutedInk),
          ),
          const SizedBox(height: 6),
          Text(
            PosHomeSpec.formatPrice(grandTotal, padZero: false),
            style: loewExtraBold.copyWith(
              fontSize: 30,
              color: PosHomeSpec.ink,
              height: 1,
            ),
          ),
          Text(
            'Total to pay',
            style: swiss721Light.copyWith(fontSize: 10, color: _labelInk),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(
        text,
        style: loewBold.copyWith(fontSize: 10, letterSpacing: 0.4, color: _labelInk),
      ),
    );
  }
}

// ── Item tile ─────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final PosSplitByItemLineItem item;
  final bool selected;
  final VoidCallback onTap;

  const _ItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFBF7ED) : Colors.white,
          border: Border.all(
            color: selected ? PosHomeSpec.ink : const Color(0xFFE8E3D6),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? PosHomeSpec.ink : Colors.white,
                border: Border.all(
                  color: selected ? PosHomeSpec.ink : const Color(0xFFB9B5A6),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: loewBold.copyWith(fontSize: 13, color: PosHomeSpec.ink),
                  ),
                  if (item.variant.isNotEmpty)
                    Text(
                      item.variant,
                      style: swiss721Light.copyWith(fontSize: 10, color: _labelInk),
                    ),
                ],
              ),
            ),
            Text(
              PosHomeSpec.formatPrice(item.price, padZero: false),
              style: loewExtraBold.copyWith(fontSize: 13, color: PosHomeSpec.ink),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pay with row ──────────────────────────────────────────────────────────────

class _PayWithRow extends StatelessWidget {
  final PosPaymentMethod method;
  final ValueChanged<PosPaymentMethod> onChanged;

  const _PayWithRow({required this.method, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _MethodButton(
            label: 'Card',
            icon: Icons.credit_card,
            active: method == PosPaymentMethod.card,
            onTap: () => onChanged(PosPaymentMethod.card),
          ),
          const SizedBox(width: 8),
          _MethodButton(
            label: 'Cash',
            icon: Icons.account_balance_wallet,
            active: method == PosPaymentMethod.cash,
            onTap: () => onChanged(PosPaymentMethod.cash),
          ),
        ],
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MethodButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: active ? PosHomeSpec.ink : Colors.white,
            border: Border.all(
              color: active ? PosHomeSpec.ink : const Color(0xFFE8E3D6),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16,
                  color: active ? Colors.white : PosHomeSpec.ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: loewBold.copyWith(
                  fontSize: 14,
                  color: active ? Colors.white : PosHomeSpec.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Selected summary ──────────────────────────────────────────────────────────

class _SelectedSummary extends StatelessWidget {
  final double selectedAmount;
  final double remaining;

  const _SelectedSummary({
    required this.selectedAmount,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBD9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected total',
                  style: loewBold.copyWith(fontSize: 11, color: _labelInk),
                ),
                Text(
                  PosHomeSpec.formatPrice(selectedAmount, padZero: false),
                  style: loewExtraBold.copyWith(
                      fontSize: 13, color: PosHomeSpec.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${PosHomeSpec.formatPrice(remaining - selectedAmount, padZero: false)} remaining after this payment',
                style: swiss721Light.copyWith(fontSize: 10, color: _labelInk),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tip row ───────────────────────────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  final VoidCallback onTap;

  const _TipRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EAD6),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Icon(
                Icons.add_circle_outline,
                size: 12,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add tip',
                    style: loewBold.copyWith(
                        fontSize: 12, color: const Color(0xFF1A1A2E)),
                  ),
                  Text(
                    'Add the tip you received here',
                    style: swiss721Light.copyWith(
                        fontSize: 10, color: const Color(0xFF8A94A6)),
                  ),
                ],
              ),
            ),
            Text(
              '0.00',
              style: loewBold.copyWith(
                  fontSize: 13, color: const Color(0xFF1A1A2E)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 14, color: Color(0xFF1A1A2E)),
          ],
        ),
      ),
    );
  }
}

// ── Section divider ───────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      color: const Color(0xFFEEE9D8),
    );
  }
}

// ── Start Payment button ──────────────────────────────────────────────────────

class _StartPaymentButton extends StatelessWidget {
  final int seq;
  final double amount;
  final bool disabled;
  final VoidCallback onTap;

  const _StartPaymentButton({
    required this.seq,
    required this.amount,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: disabled ? const Color(0xFFD4CDBA) : PosHomeSpec.ink,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: Text(
              'Start Payment $seq'
              ' · ${PosHomeSpec.formatPrice(amount, padZero: false)}',
              style: loewBold.copyWith(fontSize: 14, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
