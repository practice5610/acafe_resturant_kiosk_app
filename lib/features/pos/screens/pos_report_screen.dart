import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_placeholder.dart';
import 'package:flutter/material.dart';

/// Restyled copy of the existing manager Sales Overview. Same provider calls, POS presentation.
class PosReportScreen extends StatelessWidget {
  const PosReportScreen({super.key});

  @override
  Widget build(BuildContext context) => const PosPlaceholder(
        title: 'Report',
        route: PosRoutes.report,
        note: 'Restyled copy of the existing manager Sales Overview. Same provider calls, POS presentation.',
      );
}
