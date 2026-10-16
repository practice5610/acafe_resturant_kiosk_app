import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_builder.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

const _errorSubtitle = Color(0xFF78706E);
const _mutedText = Color(0xFFA7A19A);

/// Right pane for split-by-item: shows items to select, payment method, and summary.
///
/// The operator checks items for Payment N, sees the selected total + remaining,
/// and toggles between Card/Cash before starting the payment.
class PosSplitByItemPanel extends StatelessWidget {
  /// Current payment group sequence (1-based).
  final int groupSeq;

  /// Total order amount.
  final double grandTotal;

  /// Amount remaining after all prior payments.
  final double remaining;

  /// All receipt line items (name, price, etc.).
  final List<PosSplitByItemLineItem> lineItems;

  /// The group builder holding selected items for THIS group.
  final PosSplitByItemGroupsBuilder groupBuilder;

  /// Current payment method (Card/Cash).
  final PosPaymentMethod paymentMethod;

  /// Called when operator toggles an item.
  final ValueChanged<int> onToggleItem;

  /// Called when operator changes payment method.
  final ValueChanged<PosPaymentMethod> onPaymentMethodChanged;

  /// Called when operator clicks "Start Payment N".
  final VoidCallback onStartPayment;

  /// Called when "Add tip" row is tapped.
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
        final selectedAmount = builder.calculateAmount(lineItems);
        final isPaymentDisabled = selectedAmount <= 0;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPLIT PAYMENT',
                      style: loewBold.copyWith(
                        fontSize: 13,
                        color: _errorSubtitle,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select items for payment $groupSeq',
                      style: swiss721Light.copyWith(
                        fontSize: 10,
                        color: _mutedText,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      PosHomeSpec.formatPrice(grandTotal, padZero: false),
                      style: loewExtraBold.copyWith(
                        fontSize: 36,
                        color: PosHomeSpec.ink,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Total to pay',
                      style: swiss721Light.copyWith(
                        fontSize: 10,
                        color: _errorSubtitle,
                      ),
                    ),
                  ],
                ),
              ),

              /// Item selection header
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
                child: Text(
                  'SELECT ITEMS FOR PAYMENT $groupSeq · ${builder.selectedItemIds.length} OF ${lineItems.length}',
                  style: loewBold.copyWith(
                    fontSize: 11,
                    color: _errorSubtitle,
                  ),
                ),
              ),

              /// Scrollable item list
              SizedBox(
                height: 276,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: lineItems.length,
                  itemBuilder: (context, i) {
                    final item = lineItems[i];
                    final isSelected = builder.isSelected(item.id);

                    return GestureDetector(
                      onTap: () => onToggleItem(item.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFBF7ED) : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? PosHomeSpec.ink
                                : const Color(0xFFE8E3D6),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            /// Checkbox
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? PosHomeSpec.ink
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? PosHomeSpec.ink
                                      : const Color(0xFFB9B5A6),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),

                            /// Item details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: loewBold.copyWith(
                                      fontSize: 14,
                                      color: PosHomeSpec.ink,
                                    ),
                                  ),
                                  if (item.variant.isNotEmpty)
                                    Text(
                                      item.variant,
                                      style: swiss721Light.copyWith(
                                        fontSize: 11,
                                        color: _errorSubtitle,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            /// Price
                            Text(
                              PosHomeSpec.formatPrice(item.price, padZero: false),
                              style: loewExtraBold.copyWith(
                                fontSize: 14,
                                color: PosHomeSpec.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              /// Payment method selector
              Padding(
                padding:
                    const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 12),
                child: Text(
                  'PAY WITH',
                  style: loewBold.copyWith(
                    fontSize: 11,
                    color: _errorSubtitle,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            onPaymentMethodChanged(PosPaymentMethod.card),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: paymentMethod == PosPaymentMethod.card
                                ? PosHomeSpec.ink
                                : Colors.white,
                            border: Border.all(
                              color: paymentMethod == PosPaymentMethod.card
                                  ? PosHomeSpec.ink
                                  : const Color(0xFFE8E3D6),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.credit_card,
                                size: 18,
                                color: paymentMethod == PosPaymentMethod.card
                                    ? Colors.white
                                    : PosHomeSpec.ink,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Card',
                                style: loewBold.copyWith(
                                  fontSize: 15,
                                  color: paymentMethod == PosPaymentMethod.card
                                      ? Colors.white
                                      : PosHomeSpec.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            onPaymentMethodChanged(PosPaymentMethod.cash),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: paymentMethod == PosPaymentMethod.cash
                                ? PosHomeSpec.ink
                                : Colors.white,
                            border: Border.all(
                              color: paymentMethod == PosPaymentMethod.cash
                                  ? PosHomeSpec.ink
                                  : const Color(0xFFE8E3D6),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                size: 18,
                                color: paymentMethod == PosPaymentMethod.cash
                                    ? Colors.white
                                    : PosHomeSpec.ink,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cash',
                                style: loewBold.copyWith(
                                  fontSize: 15,
                                  color: paymentMethod == PosPaymentMethod.cash
                                      ? Colors.white
                                      : PosHomeSpec.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              /// Selected total summary
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EBD9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Selected total',
                        style: loewBold.copyWith(
                          fontSize: 11,
                          color: _errorSubtitle,
                        ),
                      ),
                      Text(
                        PosHomeSpec.formatPrice(selectedAmount, padZero: false),
                        style: loewExtraBold.copyWith(
                          fontSize: 14,
                          color: PosHomeSpec.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              /// Remaining amount hint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  '${PosHomeSpec.formatPrice(remaining - selectedAmount, padZero: false)} remaining after this payment',
                  style: swiss721Light.copyWith(
                    fontSize: 11,
                    color: _errorSubtitle,
                  ),
                ),
              ),

              /// Add tip section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: GestureDetector(
                  onTap: onAddTip,
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add tip',
                              style: loewBold.copyWith(
                                fontSize: 12,
                                color: const Color(0xFF1A1A2E),
                              ),
                            ),
                            Text(
                              'Add the tip you received here',
                              style: swiss721Light.copyWith(
                                fontSize: 10,
                                color: const Color(0xFF8A94A6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '0.00',
                        style: loewBold.copyWith(
                          fontSize: 14,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xFF1A1A2E),
                      ),
                    ],
                  ),
                ),
              ),

              /// Start Payment button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: isPaymentDisabled ? null : onStartPayment,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: isPaymentDisabled
                          ? const Color(0xFFD4CDBA)
                          : PosHomeSpec.ink,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: Text(
                        'Start Payment $groupSeq'
                        ' · ${PosHomeSpec.formatPrice(selectedAmount, padZero: false)}',
                        style: loewBold.copyWith(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
