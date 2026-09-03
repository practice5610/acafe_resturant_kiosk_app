import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Landing screen after the shift PIN. Hosts the current sale and the purchase-receipt panel, backed by CartProvider and the shared kiosk_cart_totals functions.
class PosHomeCartScreen extends StatelessWidget {
  const PosHomeCartScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Home / Cart',
        route: PosRoutes.home,
        note: 'Landing screen after the shift PIN. Hosts the current sale and the purchase-receipt panel, backed by CartProvider and the shared kiosk_cart_totals functions.',
      );
}
