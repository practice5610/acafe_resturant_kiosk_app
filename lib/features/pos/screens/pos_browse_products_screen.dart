import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Category rail plus product grid, served from the existing branch-menu cache on CategoryProvider.
class PosBrowseProductsScreen extends StatelessWidget {
  const PosBrowseProductsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Browse Products',
        route: PosRoutes.browse,
        note: 'Category rail plus product grid, served from the existing branch-menu cache on CategoryProvider.',
      );
}
