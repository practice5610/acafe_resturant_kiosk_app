import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Device-auth transaction list via KioskManagerProvider.loadTransactions. Summary rows only; the customer order-list endpoint is unusable here because POS orders are guest orders.
class PosOrdersListScreen extends StatelessWidget {
  const PosOrdersListScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Orders',
        route: PosRoutes.orders,
        note: 'Device-auth transaction list via KioskManagerProvider.loadTransactions. Summary rows only; the customer order-list endpoint is unusable here because POS orders are guest orders.',
      );
}
