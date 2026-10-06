import 'package:acafe_customer/features/pos/domain/pos_staff_session.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_session_provider.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The permission each till action needs.
///
/// These are the action -> key bindings, the same contract the server's route
/// middleware enforces. They are not the permission catalogue: which
/// permissions exist, what they are called and what order they come in is still
/// served by the branch. They live here once so no screen spells a key itself.
class PosPermission {
  PosPermission._();

  static const String closeDay = 'close_day';
  static const String voidOrders = 'void_orders';
  static const String manageOrders = 'manage_orders';
  static const String manageItemStatus = 'manage_item_status';
  static const String manageInventory = 'manage_inventory';
  static const String manageSettings = 'manage_settings';
  static const String manageStaff = 'manage_staff';
  static const String accessReports = 'access_reports';
  static const String applyDiscounts = 'apply_discounts';
  static const String processRefunds = 'process_refunds';
  static const String accessCashDrawer = 'access_cash_drawer';
  static const String viewOrders = 'view_orders';

  /// Widens the Attendance tab's scope rather than gating the tab: every
  /// signed-in staff member can open Attendance, but only a holder of this key
  /// (Branch Manager / Owner) sees the whole branch; everyone else sees only
  /// their own punches. The server enforces this; the key mirrors its name.
  static const String viewAttendance = 'view_attendance';
}

/// The till's current [PosAccess], read from both session providers.
///
/// Null-safe on purpose: a screen rendered in a harness without the staff
/// provider behaves as a branch with staff sign-in off -- everything allowed,
/// manager tabs by step-up -- which is exactly today's behaviour.
class PosAccessScope {
  PosAccessScope._();

  static PosAccess of(BuildContext context, {bool listen = true}) {
    final PosSessionProvider? stepUp =
        Provider.of<PosSessionProvider?>(context, listen: listen);
    final PosStaffSessionProvider? staff =
        Provider.of<PosStaffSessionProvider?>(context, listen: listen);
    final bool managerStepUp = stepUp?.canAccessManagerTabs ?? false;
    return staff?.access(managerStepUp: managerStepUp) ??
        PosAccess(loginRequired: false, managerStepUp: managerStepUp);
  }

  /// True when the signed-in person may do [permission]. When they may not,
  /// says so plainly and returns false, so a call site is one line:
  ///
  ///     if (!PosAccessScope.guard(context, PosPermission.closeDay)) return;
  ///
  /// The server refuses the same thing with a 403 regardless; this is only
  /// the courtesy of not letting someone start what they cannot finish.
  static bool guard(BuildContext context, String permission) {
    if (of(context, listen: false).can(permission)) return true;
    showDenied(context);
    return false;
  }

  static void showDenied(BuildContext context) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        key: deniedKey,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF241F20),
        content: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You don't have permission to do that.",
                style: loewBold.copyWith(fontSize: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const Key deniedKey = Key('pos-permission-denied');
}
