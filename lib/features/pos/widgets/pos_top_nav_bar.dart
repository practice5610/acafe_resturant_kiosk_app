import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// One tab in the POS top navigation.
class PosNavItem {
  final String label;
  final IconData icon;
  final String path;

  const PosNavItem({
    required this.label,
    required this.icon,
    required this.path,
  });
}

const List<PosNavItem> kPosNavItems = [
  PosNavItem(label: 'POS', icon: Icons.point_of_sale_outlined, path: PosRoutes.home),
  PosNavItem(label: 'Report', icon: Icons.insights_outlined, path: PosRoutes.report),
  PosNavItem(label: 'Orders', icon: Icons.receipt_long_outlined, path: PosRoutes.orders),
  PosNavItem(label: 'Receipts', icon: Icons.description_outlined, path: PosRoutes.receipts),
  PosNavItem(label: 'Settings', icon: Icons.settings_outlined, path: PosRoutes.settings),
];

/// Persistent POS chrome, mounted by the `ShellRoute` so it survives tab
/// switches instead of being rebuilt per screen.
///
/// [currentPath] drives selection rather than an index, so a deep link or a
/// browser Back lands on the right tab — this ships as Flutter web, where both
/// are reachable by the user at any time.
class PosTopNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String currentPath;

  const PosTopNavBar({super.key, required this.currentPath});

  /// Browse is reached from the POS tab, so it keeps that tab lit.
  static bool _isSelected(PosNavItem item, String path) {
    if (item.path == PosRoutes.home) {
      return path == PosRoutes.home || path == PosRoutes.browse;
    }
    return path == item.path;
  }

  @override
  Size get preferredSize => const Size.fromHeight(PosUI.navBarHeight);

  @override
  Widget build(BuildContext context) {
    final PosMetrics? metrics = PosMetrics.maybeOf(context);
    final double s = metrics?.scale ?? 1.0;
    final bool compact = metrics?.isCompact ?? false;
    final auth = context.watch<KioskAuthProvider>();

    return Container(
      height: PosUI.navBarHeight * s,
      padding: EdgeInsets.symmetric(horizontal: PosUI.gutter * s),
      decoration: const BoxDecoration(
        color: PosUI.surface,
        border: Border(bottom: BorderSide(color: PosUI.border)),
      ),
      child: Row(
        children: [
          // Branch / device identity. Staff run several terminals against
          // several branches; knowing which one this is prevents ringing a
          // sale up on the wrong till.
          if (!compact) ...[
            Text(
              auth.branchName.isEmpty ? 'A/CAFÉ' : auth.branchName,
              style: PosUI.text(context,
                  size: PosUI.headingSize, weight: FontWeight.w700),
            ),
            SizedBox(width: PosUI.gutter * s),
          ],
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final item in kPosNavItems)
                  _PosNavTab(
                    item: item,
                    selected: _isSelected(item, currentPath),
                    compact: compact,
                    onTap: () => context.go(item.path),
                  ),
              ],
            ),
          ),
          if (!compact)
            Text(
              auth.deviceName,
              style: PosUI.text(context,
                  size: PosUI.captionSize, color: PosUI.inkMuted),
            ),
        ],
      ),
    );
  }
}

class _PosNavTab extends StatelessWidget {
  final PosNavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _PosNavTab({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double s = PosMetrics.maybeOf(context)?.scale ?? 1.0;
    final Color fg = selected ? PosUI.onAccent : PosUI.inkMuted;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4 * s),
      child: Material(
        color: selected ? PosUI.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(PosUI.radius * s),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PosUI.radius * s),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (compact ? 12 : 20) * s,
              vertical: 10 * s,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 20 * s, color: fg),
                if (!compact) ...[
                  SizedBox(width: 8 * s),
                  Text(
                    item.label,
                    style: PosUI.text(
                      context,
                      size: PosUI.bodySize,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
