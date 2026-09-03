import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Numeric pad and change-due calculation, entirely client-side.
class PosCashPaymentEntryScreen extends StatelessWidget {
  const PosCashPaymentEntryScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Cash Payment',
        route: PosRoutes.paymentCash,
        note: 'Numeric pad and change-due calculation, entirely client-side.',
      );
}
