import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Renders from the same device-auth transactions feed as the Orders tab.
class PosReceiptsScreen extends StatelessWidget {
  const PosReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Receipts',
        route: PosRoutes.receipts,
        note: 'Renders from the same device-auth transactions feed as the Orders tab.',
      );
}
