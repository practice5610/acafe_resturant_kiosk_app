import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Device name and branch (read-only), language, and logout.
class PosSettingsScreen extends StatelessWidget {
  const PosSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Settings',
        route: PosRoutes.settings,
        note: 'Device name and branch (read-only), language, and logout.',
      );
}
