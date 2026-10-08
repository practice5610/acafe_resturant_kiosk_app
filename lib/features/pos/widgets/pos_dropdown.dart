import 'dart:math' as math;

import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One entry in a [PosDropdown] menu.
class PosDropdownOption<T> {
  final T value;
  final String label;

  const PosDropdownOption({required this.value, required this.label});
}

/// Builds the always-visible trigger. Wire [toggle] to the trigger's own tap
/// surface so its ink/radius match the trigger's shape.
typedef PosDropdownTriggerBuilder<T> = Widget Function(
  BuildContext context,
  PosDropdownOption<T>? selected,
  bool isOpen,
  VoidCallback toggle,
);

/// The one POS select menu — every POS dropdown (settings fields, Orders /
/// Receipts filter pills, Attendance staff filter) opens through this.
///
/// Why not Material's [DropdownButton] / [showMenu]:
/// * [DropdownButton] deliberately paints its menu *over* the button (the
///   selected row is aligned on top of the trigger), which hid the trigger.
/// * Route-based menus on the web HTML renderer can share a stacking context
///   with later form fields and get painted underneath them.
///
/// Instead the menu is rendered through an [OverlayPortal] into the **root**
/// [Overlay] — the top-most layer of the app, above every screen, field and
/// panel — glued to the trigger with a [CompositedTransformFollower] so it never covers the
/// trigger, follows it if the page scrolls, opens *below* it, flips *above*
/// only when there is not enough room below, and scrolls when the list is
/// longer than the space available.
class PosDropdown<T> extends StatefulWidget {
  final List<PosDropdownOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final PosDropdownTriggerBuilder<T> triggerBuilder;

  /// The menu is at least as wide as the trigger, and at least this wide.
  final double menuMinWidth;
  final double menuMaxHeight;
  final double itemHeight;

  /// Space between the trigger's edge and the menu.
  final double gap;
  final bool enabled;

  const PosDropdown({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.triggerBuilder,
    this.menuMinWidth = 0,
    this.menuMaxHeight = 320,
    this.itemHeight = 44,
    this.gap = 6,
    this.enabled = true,
  });

  /// Key of the open menu panel (for tests).
  static const Key menuKey = Key('pos-dropdown-menu');

  /// Key of the menu row at [index] (for tests).
  static Key itemKey(int index) => Key('pos-dropdown-item-$index');

  /// Keeps the menu off the very edge of the screen.
  static const double screenMargin = 8;

  /// Vertical padding inside the menu panel, above the first / below the last row.
  static const double menuPadding = 6;

  @override
  State<PosDropdown<T>> createState() => _PosDropdownState<T>();
}

class _PosDropdownState<T> extends State<PosDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final GlobalKey _targetKey = GlobalKey();
  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  /// Logical state (drives the chevron). The portal itself stays up a little
  /// longer than this while the close animation plays.
  bool _isOpen = false;
  _MenuGeometry? _geometry;

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

  PosDropdownOption<T>? get _selected {
    for (final PosDropdownOption<T> o in widget.options) {
      if (o.value == widget.value) return o;
    }
    return null;
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    if (!widget.enabled || widget.options.isEmpty) return;

    final RenderBox? overlayBox = Overlay.of(context, rootOverlay: true)
        .context
        .findRenderObject() as RenderBox?;
    final RenderBox? target =
        _targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || target == null || !target.hasSize) return;

    final Offset topLeft =
        target.localToGlobal(Offset.zero, ancestor: overlayBox);
    _geometry = _MenuGeometry.compute(
      trigger: topLeft & target.size,
      screen: overlayBox.size,
      optionCount: widget.options.length,
      itemHeight: widget.itemHeight,
      minWidth: widget.menuMinWidth,
      maxHeight: widget.menuMaxHeight,
      gap: widget.gap,
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

  void _select(T value) {
    _close();
    if (value != widget.value) widget.onChanged(value);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final _MenuGeometry g = _geometry!;
    final PosDropdownOption<T>? selected = _selected;

    return Stack(
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
          targetAnchor: g.targetAnchor,
          followerAnchor: g.followerAnchor,
          offset: Offset(0, g.openUp ? -widget.gap : widget.gap),
          child: Align(
            alignment: g.followerAnchor,
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
                  // it to the menu's own width; it grows down from the
                  // trigger (or up, when flipped).
                  child: SizedBox(
                    width: g.width,
                    child: SizeTransition(
                      sizeFactor: _curve,
                      alignment: Alignment(-1, g.openUp ? 1 : -1),
                      child: _MenuPanel<T>(
                        width: g.width,
                        maxHeight: g.maxHeight,
                        itemHeight: widget.itemHeight,
                        options: widget.options,
                        selected: selected,
                        onSelect: _select,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant PosDropdown<T> oldWidget) {
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
          child: widget.triggerBuilder(context, _selected, _isOpen, _toggle),
        ),
      ),
    );
  }
}

/// Where and how big the menu is, decided once when it opens.
@immutable
class _MenuGeometry {
  final double width;
  final double maxHeight;
  final bool openUp;
  final bool alignRight;

  const _MenuGeometry({
    required this.width,
    required this.maxHeight,
    required this.openUp,
    required this.alignRight,
  });

  Alignment get targetAnchor => openUp
      ? (alignRight ? Alignment.topRight : Alignment.topLeft)
      : (alignRight ? Alignment.bottomRight : Alignment.bottomLeft);

  Alignment get followerAnchor => openUp
      ? (alignRight ? Alignment.bottomRight : Alignment.bottomLeft)
      : (alignRight ? Alignment.topRight : Alignment.topLeft);

  static _MenuGeometry compute({
    required Rect trigger,
    required Size screen,
    required int optionCount,
    required double itemHeight,
    required double minWidth,
    required double maxHeight,
    required double gap,
  }) {
    const double margin = PosDropdown.screenMargin;

    final double available = math.max(0, screen.width - margin * 2);
    final double width = math.min(math.max(trigger.width, minWidth), available);

    final double natural =
        optionCount * itemHeight + PosDropdown.menuPadding * 2;
    final double wanted = math.min(natural, maxHeight);

    final double below = screen.height - trigger.bottom - gap - margin;
    final double above = trigger.top - gap - margin;
    // Below is the default; go up only if it does not fit below AND up has
    // more room.
    final bool openUp = wanted > below && above > below;
    final double room = openUp ? above : below;
    // Always leave space for at least ~2 rows so the list stays usable.
    final double height = math.max(
      math.min(wanted, room),
      math.min(wanted, itemHeight * 2 + PosDropdown.menuPadding * 2),
    );

    // Left-aligned with the trigger unless that would run off the right edge.
    final bool alignRight = trigger.left + width > screen.width - margin &&
        trigger.right - width >= margin;

    return _MenuGeometry(
      width: width,
      maxHeight: height,
      openUp: openUp,
      alignRight: alignRight,
    );
  }
}

class _MenuPanel<T> extends StatefulWidget {
  final double width;
  final double maxHeight;
  final double itemHeight;
  final List<PosDropdownOption<T>> options;
  final PosDropdownOption<T>? selected;
  final ValueChanged<T> onSelect;

  const _MenuPanel({
    required this.width,
    required this.maxHeight,
    required this.itemHeight,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_MenuPanel<T>> createState() => _MenuPanelState<T>();
}

class _MenuPanelState<T> extends State<_MenuPanel<T>> {
  late final ScrollController _scroll;

  int get _selectedIndex =>
      widget.selected == null ? -1 : widget.options.indexOf(widget.selected!);

  @override
  void initState() {
    super.initState();
    // Open scrolled to the current pick when the list is long.
    final int i = _selectedIndex;
    _scroll = ScrollController(
      initialScrollOffset:
          i <= 0 ? 0 : math.max(0, (i - 1) * widget.itemHeight),
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _selectedIndex;
    final List<PosDropdownOption<T>> options = widget.options;
    final double itemHeight = widget.itemHeight;

    return Material(
      key: PosDropdown.menuKey,
      color: PosSettingsSpec.fieldFill,
      elevation: 12,
      shadowColor: const Color(0x33241F20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
        side: const BorderSide(color: PosSettingsSpec.fieldBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: widget.width)
            .copyWith(maxHeight: widget.maxHeight),
        child: ListView.builder(
          shrinkWrap: true,
          padding:
              const EdgeInsets.symmetric(vertical: PosDropdown.menuPadding),
          controller: _scroll,
          itemExtent: itemHeight,
          itemCount: options.length,
          itemBuilder: (context, i) {
            final PosDropdownOption<T> option = options[i];
            final bool isSelected = i == selectedIndex;
            return InkWell(
              key: PosDropdown.itemKey(i),
              onTap: () => widget.onSelect(option.value),
              child: Container(
                color: isSelected
                    ? PosSettingsSpec.ink.withValues(alpha: 0.05)
                    : null,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewBold.copyWith(
                          fontSize: PosSettingsSpec.fieldTextSize,
                          color: PosSettingsSpec.ink,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: PosSettingsSpec.ink,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
