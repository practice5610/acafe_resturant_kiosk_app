import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
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
                      final locale = context
                          .read<LocalizationProvider>()
                          .locale
                          .languageCode;
                      context.read<CategoryProvider>().prefetchKioskMenu(
                            localeCode: locale,
                            force: true,
                          );
                      RouterHelper.getKioskMenuRoute(
                          action: RouteAction.pushReplacement);
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 132 * s, vertical: 40 * s),
                    // IntrinsicHeight + stretch makes every tile match the
                    // tallest one's REAL rendered content height -- no
                    // guessed fixed height that can overflow if the copy
                    // (or a translation) ends up longer than expected.
                    // NOTE: this row must NOT be wrapped in an outer Expanded --
                    // that forces a tight height constraint equal to the whole
                    // remaining screen, which defeats IntrinsicHeight and
                    // stretches every tile to fill the page instead of just
                    // matching each other's content height.
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _ManagerTile(
                              s: s,
                              title: 'SALES OVERVIEW',
                              subtitle:
                                  'Daily totals, End-of-day report, Do Z Report',
                              onTap: () => RouterHelper
                                  .getKioskManagerSalesOverviewRoute(),
                            ),
                          ),
                          SizedBox(width: 40 * s),
                          Expanded(
                            child: _ManagerTile(
                              s: s,
                              title: 'TRANSACTION HISTORY',
                              subtitle: "Today's branch-wide order list",
                              onTap: () => RouterHelper
                                  .getKioskManagerTransactionsRoute(),
                            ),
                          ),
                          SizedBox(width: 40 * s),
                          Expanded(
                            child: _ManagerTile(
                              s: s,
                              title: 'MARK OUT OF STOCK',
                              subtitle: 'Toggle product availability',
                              onTap: () =>
                                  RouterHelper.getKioskManagerStockRoute(),
                            ),
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
    // Width comes from the parent's Expanded; height comes from the parent
    // Row's IntrinsicHeight + CrossAxisAlignment.stretch, which measures
    // every tile's natural (min-content) height and stretches all of them
    // to the tallest one -- no fixed number to guess or overflow.
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24 * s),
      child: KioskTap(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(48 * s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24 * s),
            border: Border.all(color: Colors.black, width: 2 * s),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: loewExtraBold.copyWith(
                      fontSize: 56 * s, color: Colors.black)),
              SizedBox(height: 16 * s),
              Text(subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: loewRegular.copyWith(
                      fontSize: 36 * s, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
