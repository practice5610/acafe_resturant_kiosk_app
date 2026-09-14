import 'dart:async';

import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_allergen_filter_screen.dart';
import 'package:acafe_customer/features/pos/domain/pos_route_policy.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/providers/pos_session_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_allergen_notice.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_nav_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pin_modal.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/features/pos/widgets/pos_wordmark.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
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
  static const double lockSize = 36;
  static const Key scanButtonKey = Key('pos-scan-button');
  static const Key allergenButtonKey = Key('pos-allergen-button');
  static const Key lockButtonKey = Key('pos-lock-button');
  static const Key moreButtonKey = Key('pos-nav-more-button');
  static const Key avatarMenuButtonKey = Key('pos-avatar-menu-button');

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

/// Tabs every staff member can reach regardless of role.
const Set<String> _kAlwaysVisiblePaths = {
  PosRoutes.home,
  PosRoutes.orders,
  PosRoutes.receipts,
};

/// [kPosNavItems], filtered to what the signed-in staff member (or a
/// stepped-up Employee) may see. Manager-only tabs are hidden rather than
/// disabled — [PosRoutePolicy.managerOnlyPaths] is what stops a typed URL or
/// Back button from reaching them anyway.
List<PosNavItem> visiblePosNavItems(bool canAccessManagerTabs) {
  if (canAccessManagerTabs) return kPosNavItems;
  return kPosNavItems
      .where((item) => _kAlwaysVisiblePaths.contains(item.path))
      .toList();
}

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

  /// False freezes the bar: pills and the avatar menu stop responding while
  /// still painting normally.
  ///
  /// Figma draws the full nav on the payment frame (1641:2757), but a terminal
  /// that lets an operator jump tabs *while a card is being charged* is how you
  /// end up with a charged card and no order. Rather than hide the chrome the
  /// design asks for, the payment screen freezes it for the seconds the charge
  /// is in flight.
  final bool interactive;

  const PosTopNavBar({
    super.key,
    required this.currentPath,
    this.now = _systemNow,
    this.interactive = true,
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
  String get _formattedDate => intl.DateFormat('EEEE, d MMMM').format(_today);

  /// Locked (no step-up): opens the manager PIN modal. Unlocked (a manager
  /// step-up is active): drops the grant, re-hiding Report/Settings without
  /// leaving the current screen -- there's no shift to end, just a temporary
  /// grant to give up. This is a pure manager/employee toggle now; it does
  /// not sign the device out (see [_onAvatarLogout] for that).
  Future<void> _onLockTap() async {
    final session = context.read<PosSessionProvider>();
    if (session.canAccessManagerTabs) {
      session.lock();
      // The route guard only re-evaluates on navigation, so a lock while
      // sitting on Report/Settings would otherwise leave that screen showing
      // until the next tap. Send the terminal home explicitly instead.
      if (PosRoutePolicy.managerOnlyPaths.contains(widget.currentPath)) {
        context.go(PosRoutes.home);
      }
      return;
    }
    await PosPinModal.show(context);
  }

  /// The only way to sign this device out. Deliberately gated behind the
  /// avatar rather than the manager lock icon: elevating to manager access
  /// and then logging the whole terminal out from that same control read as
  /// one continuous "become manager, now log out" action, which is not what
  /// tapping the lock was ever meant to do -- it only ever toggled the
  /// manager step-up. A logout is its own, unrelated action, so it gets its
  /// own control.
  Future<void> _onAvatarLogout() async {
    final bool? confirmed = await PosCompleteConfirmationDialog.show(
      context,
      heading: 'Log out this terminal?',
      subtext: 'You will need to sign back in to use this device.',
      confirmLabel: 'Log Out',
    );
    if (confirmed != true || !mounted) return;

    context.read<PosSessionProvider>().lock();
    await context.read<KioskAuthProvider>().logout();
    if (!mounted) return;
    // The route guard only re-evaluates on navigation, so a signed-out
    // session sitting on any screen would otherwise keep showing it until
    // the next tap. Send the terminal to the login screen explicitly.
    context.go(RouterHelper.kioskLoginScreen);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<KioskAuthProvider>();
    final session = context.watch<PosSessionProvider>();

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
          // ellipsises rather than the bar throwing. flex: 1 against the
          // right cluster's flex: 3 (not an even split) -- this side only
          // ever needs ~300-400px (wordmark + date), so an even split capped
          // it at half the window and starved the pill row of width the
          // window actually had free, tipping tabs into "More" well before
          // the bar was actually full. See the right cluster's own comment.
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
          // Right cluster. Flexible, with the pill row giving way inside it:
          // five pills plus scan and avatar need roughly a 1000px window, so
          // below that the tabs have to give way somehow. Whatever doesn't fit
          // collapses into the "More" pill rather than scrolling off with no
          // indication it exists — that silently hid Settings on a narrow
          // staff tablet before this. At the design width nothing collapses.
          // flex: 2 -- see the left cluster's comment for why this is not an
          // even split with it.
          Flexible(
            flex: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: _PosNavPillRow(
                    items:
                        visiblePosNavItems(session.canAccessManagerTabs),
                    currentPath: widget.currentPath,
                    interactive: widget.interactive,
                    onSelect: (path) => context.go(path),
                  ),
                ),
                const SizedBox(width: PosNavBarSpec.groupGap),
                const _AllergenNavButton(),
                const SizedBox(width: PosNavBarSpec.groupGap),
                const _ScanButton(),
                const SizedBox(width: PosNavBarSpec.groupGap),
                _PosLockButton(
                  unlocked: session.canAccessManagerTabs,
                  onTap: widget.interactive ? _onLockTap : null,
                ),
                const SizedBox(width: PosNavBarSpec.groupGap),
                _PosAvatarMenuButton(
                  initial: _initialFor(auth),
                  interactive: widget.interactive,
                  onLogout: _onAvatarLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The till has no staff identity — anyone can operate the counter — so
  /// the avatar names the device/branch instead of a person.
  static String _initialFor(KioskAuthProvider auth) {
    final String source =
        auth.deviceName.isNotEmpty ? auth.deviceName : auth.branchName;
    return source.isEmpty ? 'A' : source.trim().characters.first.toUpperCase();
  }
}

/// Lays the visible nav pills out left to right, and -- whenever they don't
/// all fit -- tucks whichever ones don't into a trailing "More" pill instead
/// of letting them scroll silently out of view.
///
/// The currently active tab is always kept visible even if that means an
/// earlier, inactive tab is the one that gets tucked away: a manager sitting
/// on Settings should never see that tab vanish out from under them just
/// because the window narrowed.
///
/// Fit is decided from each pill's *real* rendered width, measured by laying
/// an [Offstage] copy of every pill out every build, rather than guessing
/// with a [TextPainter]: a guess landed a few px under what `Text` (default
/// `TextWidthBasis.parent`) actually renders at, which is exactly enough
/// drift to tip a hairline-tight fit (this bar has none to spare at the
/// design width) into a genuine `RenderFlex` overflow.
class _PosNavPillRow extends StatefulWidget {
  final List<PosNavItem> items;
  final String currentPath;
  final bool interactive;
  final ValueChanged<String> onSelect;

  const _PosNavPillRow({
    required this.items,
    required this.currentPath,
    required this.interactive,
    required this.onSelect,
  });

  static EdgeInsets _padding(PosNavItem item) =>
      item.path == PosRoutes.report
          ? PosNavBarSpec.reportPadding
          : PosNavPill.defaultPadding;

  static TextStyle _labelStyle(PosNavItem item) {
    final bool bold = item.path == PosRoutes.report;
    return (bold ? loewBold : loewMedium).copyWith(
      fontSize: PosNavPill.labelSize,
      color: PosUI.ink,
      height: PosNavPill.labelHeight,
    );
  }

  @override
  State<_PosNavPillRow> createState() => _PosNavPillRowState();
}

class _PosNavPillRowState extends State<_PosNavPillRow> {
  static const String _moreKey = '__more__';

  final Map<String, double> _widths = {};

  bool get _allMeasured =>
      _widths.containsKey(_moreKey) &&
      widget.items.every((item) => _widths.containsKey(item.path));

  void _report(String key, double width) {
    if (_widths[key] == width) return;
    setState(() => _widths[key] = width);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Offstage(
          // Offstage still hands its child whatever constraints it receives
          // -- "offstage" only suppresses painting, not layout-time overflow
          // checks. A bounded max width here (from this Stack) with content
          // that exceeds it still throws, offstage or not. OverflowBox breaks
          // that chain so the measuring row lays out at its true width
          // instead of asserting over the very thing it exists to measure.
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in widget.items)
                  _MeasureSize(
                    onChange: (size) => _report(item.path, size.width),
                    child: PosNavPill(
                      label: item.label,
                      active: false,
                      bold: item.path == PosRoutes.report,
                      padding: _PosNavPillRow._padding(item),
                    ),
                  ),
                _MeasureSize(
                  onChange: (size) => _report(_moreKey, size.width),
                  child: const _MorePillVisual(active: false),
                ),
              ],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // First frame before the offstage pass has reported real sizes:
            // nothing is known to be safe yet, so render nothing rather than
            // risk an overflow on a guess. Settles within the same frame.
            if (!_allMeasured) return const SizedBox.shrink();

            // The decision (not the render) gets a few px of headroom taken
            // off the budget: real glyph widths shift a little with device
            // pixel ratio, so the same layout can measure a couple of px
            // different across two host windows. Erring toward tucking a
            // pill away one tap too early is harmless; erring the other way
            // is a RenderFlex overflow. The widget actually rendered below
            // always shrink-wraps to whatever this picks, so it can never
            // overflow the real budget even though the check is stricter
            // than it.
            const double decisionMargin = 4;
            final double budget = constraints.maxWidth - decisionMargin;
            final double moreWidth = _widths[_moreKey]!;

            double widthOf(Iterable<PosNavItem> subset) {
              double total = 0;
              bool first = true;
              for (final item in subset) {
                if (!first) total += PosNavBarSpec.pillGap;
                total += _widths[item.path]!;
                first = false;
              }
              return total;
            }

            if (widthOf(widget.items) <= budget) {
              return _row(widget.items, const []);
            }

            final int activeIndex = widget.items.indexWhere(
              (item) => PosTopNavBar.isSelected(item, widget.currentPath),
            );

            // The More button renders AFTER the shown pills, separated by its
            // own gap -- not before them -- so that gap-plus-button overhead
            // has to be reserved up front and checked against every
            // candidate pill, not prepended as if it were the first pill.
            // Seeding `used` with moreWidth alone (an earlier version of this
            // did exactly that) undercounts by one pillGap and was exactly
            // what let a chosen combination render wider than the budget it
            // was just checked against.
            final double reserved = moreWidth + PosNavBarSpec.pillGap;
            final List<int> shown = [];
            double used = 0;

            void tryAdd(int index) {
              if (shown.contains(index)) return;
              final double gap = shown.isEmpty ? 0 : PosNavBarSpec.pillGap;
              final double next =
                  used + gap + _widths[widget.items[index].path]!;
              if (next + reserved <= budget) {
                used = next;
                shown.add(index);
              }
            }

            if (activeIndex >= 0) tryAdd(activeIndex);
            for (int i = 0; i < widget.items.length; i++) {
              tryAdd(i);
            }

            final Set<int> shownSet = shown.toSet();
            final List<PosNavItem> visible = [
              for (int i = 0; i < widget.items.length; i++)
                if (shownSet.contains(i)) widget.items[i],
            ];
            final List<PosNavItem> hidden = [
              for (int i = 0; i < widget.items.length; i++)
                if (!shownSet.contains(i)) widget.items[i],
            ];

            return _row(visible, hidden);
          },
        ),
      ],
    );
  }

  Widget _row(List<PosNavItem> visible, List<PosNavItem> hidden) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in visible) ...[
          if (item != visible.first)
            const SizedBox(width: PosNavBarSpec.pillGap),
          PosNavPill(
            label: item.label,
            active: PosTopNavBar.isSelected(item, widget.currentPath),
            bold: item.path == PosRoutes.report,
            padding: _PosNavPillRow._padding(item),
            onTap:
                widget.interactive ? () => widget.onSelect(item.path) : null,
          ),
        ],
        if (hidden.isNotEmpty) ...[
          if (visible.isNotEmpty) const SizedBox(width: PosNavBarSpec.pillGap),
          _PosNavMoreButton(
            items: hidden,
            currentPath: widget.currentPath,
            interactive: widget.interactive,
            onSelect: widget.onSelect,
          ),
        ],
      ],
    );
  }
}

/// Reports [child]'s laid-out size after every layout pass in which it
/// changes. The callback fires post-frame, never mid-layout, so it is safe
/// to call `setState` from it.
class _MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const _MeasureSize({required this.onChange, required Widget super.child});

  @override
  _RenderMeasureSize createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
      BuildContext context, _RenderMeasureSize renderObject) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  ValueChanged<Size> onChange;
  Size? _last;

  _RenderMeasureSize(this.onChange);

  @override
  void performLayout() {
    super.performLayout();
    final Size current = child?.size ?? Size.zero;
    if (_last == current) return;
    _last = current;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(current));
  }
}

/// The pill visual shared by the real "More" button and its offstage
/// measurement copy, so both are guaranteed to be the same size.
class _MorePillVisual extends StatelessWidget {
  final bool active;

  const _MorePillVisual({required this.active});

  @override
  Widget build(BuildContext context) {
    final Color background = active ? PosUI.ink : Colors.white;
    final Color foreground = active ? PosUI.pageBg : PosUI.ink;

    return Container(
      padding: PosNavPill.defaultPadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PosNavPill.radius),
      ),
      child: Text(
        'More',
        style: loewMedium.copyWith(
          fontSize: PosNavPill.labelSize,
          color: foreground,
          height: PosNavPill.labelHeight,
        ),
      ),
    );
  }
}

/// The pill any tabs that don't fit collapse into. Its own tap surface (not
/// [PosNavPill]'s) since [PopupMenuButton] already provides one.
class _PosNavMoreButton extends StatelessWidget {
  final List<PosNavItem> items;
  final String currentPath;
  final bool interactive;
  final ValueChanged<String> onSelect;

  const _PosNavMoreButton({
    required this.items,
    required this.currentPath,
    required this.interactive,
    required this.onSelect,
  });

  bool get _active =>
      items.any((item) => PosTopNavBar.isSelected(item, currentPath));

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: PosNavBarSpec.moreButtonKey,
      enabled: interactive,
      tooltip: 'More',
      // Without this, PopupMenuButton's default anchor is the button's own
      // top-left, which opens the menu overlapping the pill instead of below
      // it — same fix as the avatar menu.
      position: PopupMenuPosition.under,
      // Not PosNavPill.radius (100, the fully-rounded pill *trigger*'s own
      // corner radius) -- this `shape` controls the dropdown *panel*, and a
      // 100 radius on a menu that size rendered as a near-circle. A normal
      // small menu radius here, same family as any other dropdown card.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<String>(
            value: item.path,
            child: Text(item.label, style: _PosNavPillRow._labelStyle(item)),
          ),
      ],
      child: _MorePillVisual(active: _active),
    );
  }
}

/// Locked (an Employee): tapping opens the manager step-up PIN modal.
/// Unlocked (Manager/Owner, or a stepped-up Employee): tapping drops the
/// step-up grant. Never signs the device out -- that is the avatar menu's
/// job (see [_PosAvatarMenuButton]), not this icon's. Placeholder glyphs
/// pending real icon design, same status as the older kiosk manager lock
/// icon it replaces.
class _PosLockButton extends StatelessWidget {
  final bool unlocked;
  final VoidCallback? onTap;

  const _PosLockButton({required this.unlocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: PosNavBarSpec.lockButtonKey,
      width: PosNavBarSpec.lockSize,
      height: PosNavBarSpec.lockSize,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(
            unlocked ? Icons.lock_open : Icons.lock_outline,
            size: PosNavBarSpec.lockSize * 0.6,
            color: PosUI.ink,
          ),
        ),
      ),
    );
  }
}

/// Reopens the shared allergen filter ([KioskAllergenPreferences] /
/// [showKioskAllergenFilter], the exact same popup the kiosk uses and the
/// once-per-order gate in `openPosCustomize` opens automatically).
///
/// Lives in the persistent top nav rather than any one screen's toolbar so a
/// staff member who missed it (or dismissed it) on the first product of an
/// order — the popup only auto-opens once — always has somewhere to reopen
/// it and change or clear the selection, from any tab. Available to every
/// staff member and manager alike; hidden entirely only when the branch
/// admin's "Show Allergen Tag" toggle is off, same as the rest of this
/// feature in POS.
class _AllergenNavButton extends StatelessWidget {
  const _AllergenNavButton();

  @override
  Widget build(BuildContext context) {
    final bool enabled = context.watch<KioskAuthProvider>().allergenTagEnabled;
    if (!enabled) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: KioskAllergenPreferences.instance,
      builder: (context, _) {
        final bool active = KioskAllergenPreferences.instance.hasSelection;
        final int count = KioskAllergenPreferences.instance.avoided.length;

        return SizedBox(
          key: PosNavBarSpec.allergenButtonKey,
          width: PosNavBarSpec.lockSize,
          height: PosNavBarSpec.lockSize,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showKioskAllergenFilter(context,
                  scale: posAllergenDialogScale(context)),
              child: Tooltip(
                message: 'Allergens',
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.health_and_safety_outlined,
                      size: PosNavBarSpec.lockSize * 0.6,
                      color: active ? PosUI.accent : PosUI.ink,
                    ),
                    if (active)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: PosUI.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: loewBold.copyWith(
                              fontSize: 9,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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

/// The avatar's tap surface: the only way to log this device out. Opens a
/// one-item dropdown ("Logout") rather than acting on a single tap, so a
/// stray tap on the avatar can never fire a destructive action by accident.
class _PosAvatarMenuButton extends StatelessWidget {
  final String initial;
  final bool interactive;
  final Future<void> Function() onLogout;

  const _PosAvatarMenuButton({
    required this.initial,
    required this.interactive,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: PosNavBarSpec.avatarMenuButtonKey,
      enabled: interactive,
      tooltip: 'Account',
      // Without this, PopupMenuButton's default anchor is the button's own
      // top-left, which opens the menu overlapping the avatar and the icons
      // beside it instead of below them.
      position: PopupMenuPosition.under,
      onSelected: (_) => onLogout(),
      itemBuilder: (context) => const [
        PopupMenuItem<String>(value: 'logout', child: Text('Logout')),
      ],
      child: PosAvatar(initial: initial),
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
