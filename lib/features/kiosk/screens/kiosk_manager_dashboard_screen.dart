import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

/// Landing screen after a correct manager PIN: three tiles into the POS
/// manager tools. Reachable only via [openKioskManagerAccess] (the PIN
/// sheet) -- see kiosk_pin_entry_sheet.dart.
class KioskManagerDashboardScreen extends StatelessWidget {
  const KioskManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskResponsive.scale(constraints.maxWidth);
            return KioskCenteredContent(
              child: Column(
                children: [
                  KioskHeaderBar(
                    s: s,
                    title: 'MANAGER',
                    onBack: () {
                      context.read<KioskManagerProvider>().lockManagerAccess();
                      RouterHelper.getKioskMenuRoute(action: RouteAction.pushReplacement);
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 132 * s, vertical: 40 * s),
                      child: Wrap(
                        spacing: 40 * s,
                        runSpacing: 40 * s,
                        children: [
                          _ManagerTile(
                            s: s,
                            title: 'SALES OVERVIEW',
                            subtitle: 'Daily totals, End-of-day report, Do Z Report',
                            onTap: () => RouterHelper.getKioskManagerSalesOverviewRoute(),
                          ),
                          _ManagerTile(
                            s: s,
                            title: 'TRANSACTION HISTORY',
                            subtitle: "Today's branch-wide order list",
                            onTap: () => RouterHelper.getKioskManagerTransactionsRoute(),
                          ),
                          _ManagerTile(
                            s: s,
                            title: 'MARK OUT OF STOCK',
                            subtitle: 'Toggle product availability',
                            onTap: () => RouterHelper.getKioskManagerStockRoute(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ManagerTile extends StatelessWidget {
  final double s;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ManagerTile({
    required this.s,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double tileWidth = 620 * s;
    return SizedBox(
      width: tileWidth,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24 * s),
        child: KioskTap(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(48 * s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24 * s),
              border: Border.all(color: Colors.black, width: 2 * s),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: loewExtraBold.copyWith(fontSize: 56 * s, color: Colors.black)),
                SizedBox(height: 16 * s),
                Text(subtitle,
                    style: loewRegular.copyWith(fontSize: 36 * s, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
