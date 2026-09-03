import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Cash or card fork for the current sale.
class PosPaymentSelectionScreen extends StatelessWidget {
  const PosPaymentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Payment',
        route: PosRoutes.payment,
        note: 'Cash or card fork for the current sale.',
      );
}
