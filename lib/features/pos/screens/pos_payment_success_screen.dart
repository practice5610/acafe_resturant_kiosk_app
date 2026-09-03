import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Result of placeKioskOrder(), which already tags the order order_type: pos.
class PosPaymentSuccessScreen extends StatelessWidget {
  const PosPaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Payment Complete',
        route: PosRoutes.paymentSuccess,
        note: 'Result of placeKioskOrder(), which already tags the order order_type: pos.',
      );
}
