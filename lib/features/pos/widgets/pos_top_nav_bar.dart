import 'dart:async';

import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_nav_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/features/pos/widgets/pos_wordmark.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Design constants for the nav bar, measured from Figma `MAIN_NAV_BAR`
/// (node 1642:1088).
class PosNavBarSpec {
  PosNavBarSpec._();

  static const double height = 80;
  static const double horizontalPadding = 32;
  static const double borderWidth = 2;

  static const double wordmarkHeight = 18; // -> 68.652 wide

  /// Gap between the wordmark and the date.
  ///
  /// The brief originally called this 5px; that figure is the `date-block`'s
  /// *internal* gap to a calendar icon which is `hidden="true"` in the file and
  /// never renders. Measured against the frame, the date sits at x=191 while
  /// the wordmark ends at 100.65.
  ///
  /// TODO(pos-home): this currently approximates the width of the category
  /// sidebar, which the date is aligned to in the full-screen design. Once the
  /// POS home screen (sidebar + product grid + receipt panel) exists, derive
  /// this from the real sidebar width instead of holding a measured constant.
  static const double kNavDateOffset = 90.35;

  static const double dateSize = 16;

  static const double pillGap = 12;
  static const double groupGap = 16;

  static const double scanSize = 36;
  static const double avatarSize = 40;
  static const Key scanButtonKey = Key('pos-scan-button');

  /// Report is 18/10 in the frame; every other pill is 20/12.
  static const EdgeInsets reportPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 10);
}

/// One tab in the POS top navigation.
class PosNavItem {
  final String label;
  final String path;

  const PosNavItem({required this.label, required this.path});
}

const List<PosNavItem> kPosNavItems = [
  PosNavItem(label: 'POS', path: PosRoutes.home),
  PosNavItem(label: 'Report', path: PosRoutes.report),
  PosNavItem(label: 'Orders', path: PosRoutes.orders),
  PosNavItem(label: 'Receipts', path: PosRoutes.receipts),
  PosNavItem(label: 'Settings', path: PosRoutes.settings),
];

/// Persistent POS chrome, mounted by the `ShellRoute` so it survives tab
/// switches instead of being rebuilt per screen.
///
/// [currentPath] drives selection rather than an index, so a deep link or a
/// browser Back lands on the right tab — this ships as Flutter web, where both
/// are reachable by the user at any time.
class PosTopNavBar extends StatefulWidget implements PreferredSizeWidget {
  final String currentPath;

  /// Clock seam. Because this widget is mounted inside the `ShellRoute` it can
  /// stay alive for days on a counter terminal, so the date is held in state
  /// and refreshed by a timer rather than read from `DateTime.now()` in build().
  /// Injecting the clock is also what lets a test cross midnight without
  /// waiting for one.
  final DateTime Function() now;

  const PosTopNavBar({
    super.key,
    required this.currentPath,
    this.now = _systemNow,
  });

  static DateTime _systemNow() => DateTime.now();

  /// Browse is reached from the POS tab, so it keeps that tab lit.
  static bool isSelected(PosNavItem item, String path) {
    if (item.path == PosRoutes.home) {
      return path == PosRoutes.home || path == PosRoutes.browse;
    }
    return path == item.path;
  }

  @override
  Size get preferredSize => const Size.fromHeight(PosNavBarSpec.height);

  @override
  State<PosTopNavBar> createState() => _PosTopNavBarState();
}

class _PosTopNavBarState extends State<PosTopNavBar> {
  late DateTime _today;
  Timer? _rollover;

  @override
  void initState() {
    super.initState();
    _today = widget.now();
    _scheduleRollover();
  }

  @override
  void dispose() {
    _rollover?.cancel();
    super.dispose();
  }

  /// Fires just after the next local midnight, then re-arms. A periodic timer
  /// would drift across DST; recomputing the next boundary each time does not.
  void _scheduleRollover() {
    _rollover?.cancel();
    final DateTime now = widget.now();
    final DateTime nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _rollover = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (!mounted) return;
        setState(() => _today = widget.now());
        _scheduleRollover();
      },
    );
  }

  /// Default `intl` locale on purpose: `initializeDateFormatting()` is never
  /// called in this app, so any other locale would throw `LocaleDataException`.
  String get _formattedDate => DateFormat('EEEE, d MMMM').format(_today);

  Future<void> _openAvatarMenu() async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Offset origin =
        box == null ? Offset.zero : box.localToGlobal(Offset.zero);

    final String? action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx + (box?.size.width ?? 0),
        origin.dy + PosNavBarSpec.height,
        0,
        0,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'lock',
          child: Text('Lock terminal'),
        ),
      ],
    );

    if (action != 'lock' || !mounted) return;
    // Clears the shift PIN. The route guard then refuses every /pos- path, but
    // it only re-evaluates on navigation, so send the terminal to the lock
    // screen explicitly rather than waiting for the next tap.
    context.read<KioskManagerProvider>().lockManagerAccess();
    if (!mounted) return;
    context.go(PosRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<KioskAuthProvider>();

    return Container(
      height: PosNavBarSpec.height,
      padding: const EdgeInsets.symmetric(
          horizontal: PosNavBarSpec.horizontalPadding),
      decoration: const BoxDecoration(
        color: PosUI.pageBg,
        border: Border(
          bottom: BorderSide(
            color: PosUI.ink,
            width: PosNavBarSpec.borderWidth,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left cluster. Flexible so a window narrower than the design does
          // not overflow: the date is the only element here with slack, so it
          // ellipsises rather than the bar throwing.
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PosWordmark(height: PosNavBarSpec.wordmarkHeight),
                const SizedBox(width: PosNavBarSpec.kNavDateOffset),
                Flexible(
                  child: Text(
                    _formattedDate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewMedium.copyWith(
                      fontSize: PosNavBarSpec.dateSize,
                      color: PosUI.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: PosNavBarSpec.groupGap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in kPosNavItems) ...[
                if (item != kPosNavItems.first)
                  const SizedBox(width: PosNavBarSpec.pillGap),
                PosNavPill(
                  label: item.label,
                  active: PosTopNavBar.isSelected(item, widget.currentPath),
                  bold: item.path == PosRoutes.report,
                  padding: item.path == PosRoutes.report
                      ? PosNavBarSpec.reportPadding
                      : PosNavPill.defaultPadding,
                  onTap: () => context.go(item.path),
                ),
              ],
              const SizedBox(width: PosNavBarSpec.groupGap),
              const _ScanButton(),
              const SizedBox(width: PosNavBarSpec.groupGap),
              PosAvatar(
                // No staff identity exists: the terminal authenticates as a
                // device and the shift PIN is that device's configuration_code,
                // so there is no user record and no photo to show. The initial
                // names the till instead of inventing a person.
                initial: _initialFor(auth),
                onTap: _openAvatarMenu,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _initialFor(KioskAuthProvider auth) {
    final String source =
        auth.deviceName.isNotEmpty ? auth.deviceName : auth.branchName;
    return source.isEmpty ? 'A' : source.trim().characters.first.toUpperCase();
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: PosNavBarSpec.scanButtonKey,
      width: PosNavBarSpec.scanSize,
      height: PosNavBarSpec.scanSize,
      // Visual only — there is no scanner package in this app (qr_flutter
      // generates codes, it does not read them).
      child: SvgPicture.asset(
        Images.posScanSvg,
        width: PosNavBarSpec.scanSize,
        height: PosNavBarSpec.scanSize,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const Icon(
          Icons.crop_free,
          size: PosNavBarSpec.scanSize,
          color: PosUI.ink,
        ),
      ),
    );
  }
}

/// 40x40 circular identity badge.
///
/// [imageUrl] is the seam for a real photo: when POS grows a staff identity,
/// pass it here and the initial becomes the fallback, with no other change.
class PosAvatar extends StatelessWidget {
  final String initial;
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;

  const PosAvatar({
    super.key,
    required this.initial,
    this.imageUrl,
    this.size = PosNavBarSpec.avatarSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget face = (imageUrl != null && imageUrl!.isNotEmpty)
        ? ClipOval(
            child: CustomImageWidget(
              image: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          )
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: PosUI.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: loewBold.copyWith(
                fontSize: size * 0.4,
                color: PosUI.ink,
                height: 1.0,
              ),
            ),
          );

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: face),
      ),
    );
  }
}
