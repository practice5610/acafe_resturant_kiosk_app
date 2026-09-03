import 'package:acafe_customer/features/pos/screens/pos_home_cart_screen.dart';
import 'package:flutter/material.dart';

/// Same layout as home — Figma's browse and cart-active frames share one
/// three-pane screen, distinguished only by whether the cart has lines.
class PosBrowseProductsScreen extends StatelessWidget {
  const PosBrowseProductsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosHomeCartScreen();
}
