import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Drives KioskPaymentService.pay(). Simulated, exactly as the kiosk is today.
class PosWaitingForPaymentScreen extends StatelessWidget {
  const PosWaitingForPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Waiting for Payment',
        route: PosRoutes.paymentWait,
        note: 'Drives KioskPaymentService.pay(). Simulated, exactly as the kiosk is today.',
      );
}
