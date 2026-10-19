import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Builds a [PosMenuAnchor]'s always-visible trigger. Wire [toggle] to the
/// trigger's own tap surface so its ink/radius match the trigger's shape.
typedef PosMenuTriggerBuilder = Widget Function(
  BuildContext context,
  bool isOpen,
  VoidCallback toggle,
);

/// Builds the open menu's panel at [layout]'s width, no taller than its
/// `maxHeight`. Call [close] to dismiss the menu.
typedef PosMenuPanelBuilder = Widget Function(
  BuildContext context,
  PosMenuLayout layout,
  VoidCallback close,
);

/// The side of the trigger a menu prefers. It takes the other side only when
/// it does not fit on this one and the other side has more room.
enum PosMenuSide { below, above }

/// Which trigger edge a menu lines up with. It takes the other edge only when
/// it would run off the screen on this one and fits on the other.
enum PosMenuAlign { start, end }

/// Where and how big an open menu is, decided once when it opens.
@immutable
class PosMenuLayout {
  final double width;
  final double maxHeight;
  final bool opensUp;
  final bool alignsEnd;

  /// Sideways nudge that keeps the menu on screen when neither edge fits.
  final double shiftX;

  const PosMenuLayout({
    required this.width,
    required this.maxHeight,
    required this.opensUp,
    required this.alignsEnd,
    this.shiftX = 0,
  });

  Alignment get targetAnchor => opensUp
      ? (alignsEnd ? Alignment.topRight : Alignment.topLeft)
      : (alignsEnd ? Alignment.bottomRight : Alignment.bottomLeft);

  Alignment get followerAnchor => opensUp
      ? (alignsEnd ? Alignment.bottomRight : Alignment.bottomLeft)
      : (alignsEnd ? Alignment.topRight : Alignment.topLeft);

  static PosMenuLayout compute({
    required Rect trigger,
    required Size screen,
    required double menuHeight,
    double minWidth = 0,
    double maxHeight = double.infinity,
    double minHeight = 0,
    double gap = 6,
    PosMenuSide side = PosMenuSide.below,
    PosMenuAlign align = PosMenuAlign.start,
  }) {
    const double margin = PosMenuAnchor.screenMargin;

    final double available = math.max(0, screen.width - margin * 2);
    final double width = math.min(math.max(trigger.width, minWidth), available);

    final double wanted = math.min(menuHeight, maxHeight);
    final double below = screen.height - trigger.bottom - gap - margin;
    final double above = trigger.top - gap - margin;
    final bool opensUp = side == PosMenuSide.below
        ? wanted > below && above > below
        : !(wanted > above && below > above);
    final double room = opensUp ? above : below;
    final double height =
        math.max(math.min(wanted, room), math.min(wanted, minHeight));

    final bool fitsStart = trigger.left + width <= screen.width - margin;
    final bool fitsEnd = trigger.right - width >= margin;
    final bool alignsEnd = align == PosMenuAlign.start
        ? !fitsStart && fitsEnd
        : fitsEnd || !fitsStart;

    final double left = alignsEnd ? trigger.right - width : trigger.left;
    final double shiftX =
        left.clamp(margin, screen.width - margin - width) - left;

    return PosMenuLayout(
      width: width,
      maxHeight: height,
      opensUp: opensUp,
      alignsEnd: alignsEnd,
      shiftX: shiftX,
    );
  }
}

/// The one way a POS menu opens — every dropdown ([PosDropdown]) and every
/// action menu (the order ⋮ / ⋯) goes through this.
///
/// Why not Material's [DropdownButton] / [showMenu], or a route placed at the
/// trigger's screen position:
/// * [DropdownButton] deliberately paints its menu *over* the button (the
///   selected row is aligned on top of the trigger), which hid the trigger.
/// * Route-based menus on the web HTML renderer can share a stacking context
///   with later form fields and get painted underneath them.
/// * A route lands in the *nearest* navigator. Inside the POS shell that is
///   the tab's nested navigator, which starts below the nav bar, so a menu
///   positioned with screen coordinates opened a nav-bar height too low.
///
/// Instead the menu is rendered through an [OverlayPortal] into the **root**
/// [Overlay] — the top-most layer of the app, above every screen, field and
/// panel — glued to the trigger with a [CompositedTransformFollower], so it
/// sits against the trigger wherever the trigger is, never covers it, follows
/// it if the page scrolls, takes the other side only when there is not
/// enough room on the preferred one, and closes on Escape or an outside tap.
class PosMenuAnchor extends StatefulWidget {
  final PosMenuTriggerBuilder triggerBuilder;
  final PosMenuPanelBuilder menuBuilder;

  /// The menu's natural height — what it takes with every row showing.
  final double menuHeight;

  /// The menu is at least as wide as the trigger, and at least this wide.
  final double menuMinWidth;
  final double menuMaxHeight;

  /// Never squeezed below this, even when neither side has that much room.
  final double menuMinHeight;

  /// Space between the trigger's edge and the menu.
  final double gap;
  final PosMenuSide side;
  final PosMenuAlign align;
  final bool enabled;

  const PosMenuAnchor({
    super.key,
    required this.triggerBuilder,
    required this.menuBuilder,
    required this.menuHeight,
    this.menuMinWidth = 0,
    this.menuMaxHeight = double.infinity,
    this.menuMinHeight = 0,
    this.gap = 6,
    this.side = PosMenuSide.below,
    this.align = PosMenuAlign.start,
    this.enabled = true,
  });

  /// Keeps the menu off the very edge of the screen.
  static const double screenMargin = 8;

  @override
  State<PosMenuAnchor> createState() => _PosMenuAnchorState();
}

class _PosMenuAnchorState extends State<PosMenuAnchor>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  /// Logical state (drives the trigger's open look). The portal itself stays
  /// up a little longer than this while the close animation plays.
  bool _isOpen = false;
  PosMenuLayout? _layout;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    if (!widget.enabled) return;

    final RenderBox? overlayBox = Overlay.of(context, rootOverlay: true)
        .context
        .findRenderObject() as RenderBox?;
    final RenderBox? target =
        _targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || target == null || !target.hasSize) return;

    final Offset topLeft =
        target.localToGlobal(Offset.zero, ancestor: overlayBox);
    _layout = PosMenuLayout.compute(
      trigger: topLeft & target.size,
      screen: overlayBox.size,
      menuHeight: widget.menuHeight,
      minWidth: widget.menuMinWidth,
      maxHeight: widget.menuMaxHeight,
      minHeight: widget.menuMinHeight,
      gap: widget.gap,
      side: widget.side,
      align: widget.align,
    );

    // A focused TextField's HTML <input> can sit above the menu on the web
    // HTML renderer — drop focus before the menu appears.
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _isOpen = true);
    _portal.show();
    _controller.forward(from: 0);
  }

  /// Animates the menu out, then hides it.
  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse().whenComplete(() {
      // Re-opened mid-animation: leave it up.
      if (mounted && !_isOpen && _portal.isShowing) _portal.hide();
    });
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final PosMenuLayout layout = _layout!;

    // Inert while it fades out, so a tap right after picking (the confirm
    // dialog an action opens) reaches what is underneath.
    return IgnorePointer(
      ignoring: !_isOpen,
      child: Stack(
        children: [
          // Full-screen catcher: any tap outside the menu (including on the
          // trigger itself) closes it, and nothing beneath reacts to that tap.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const ColoredBox(color: Color(0x00000000)),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: layout.targetAnchor,
            followerAnchor: layout.followerAnchor,
            offset: Offset(
              layout.shiftX,
              layout.opensUp ? -widget.gap : widget.gap,
            ),
            child: Align(
              alignment: layout.followerAnchor,
              widthFactor: 1,
              heightFactor: 1,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): _close,
                },
                child: Focus(
                  autofocus: true,
                  child: FadeTransition(
                    opacity: _curve,
                    // SizeTransition stretches to the available width, so pin
                    // it to the menu's own width; it grows away from the
                    // trigger (down, or up when flipped).
                    child: SizedBox(
                      width: layout.width,
                      child: SizeTransition(
                        sizeFactor: _curve,
                        alignment: Alignment(-1, layout.opensUp ? 1 : -1),
                        child: widget.menuBuilder(
                          overlayContext,
                          layout,
                          _close,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(covariant PosMenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No manual overlay rebuild needed: the OverlayPortal child is rebuilt
    // with this widget, so a parent that rebuilds while the menu is open (the
    // Orders board ticks every second) just refreshes it.
    if (!widget.enabled && _isOpen) {
      _isOpen = false;
      _controller.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isOpen && _portal.isShowing) _portal.hide();
      });
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: _buildOverlay,
      child: CompositedTransformTarget(
        link: _link,
        child: KeyedSubtree(
          key: _targetKey,
          child: widget.triggerBuilder(context, _isOpen, _toggle),
        ),
      ),
    );
  }
}
