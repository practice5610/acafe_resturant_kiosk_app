import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _kInk = Color(0xFF1E1E1E);

/// Frosted surfaces: translucent white over a blur of the artwork behind.
const Color _kGlass = Color(0xC7FFFFFF); // white @ 78 %
const Color _kGlassOpen = Color(0xF2FFFFFF); // white @ 95 %
const Color _kPanelGlass = Color(0xE0FFFFFF); // white @ 88 %
const Color _kGlassEdge = Color(0xE6FFFFFF); // white @ 90 %
const double _kBlur = 22;

/// Leaves the menu for the next guest closed if this one walks away from it.
const Duration _kAutoClose = Duration(seconds: 15);

/// Language dropdown at the foot of the kiosk welcome screen.
///
/// Closed, it is one frosted pill — the chosen language's flag and name and a
/// chevron. A tap opens a frosted card *above* it (the pill sits at the foot
/// of the screen) listing every offered language, the chosen one ticked.
/// Picking one applies it at once and closes the card.
///
/// Every proportion is a fraction of [pillHeight], so the picker scales with
/// the intro artwork like the logo and prompt above it.
///
/// The welcome screen orders on a tap anywhere. The open card therefore sits
/// in the root overlay over a full-screen catcher: a tap beside it only closes
/// it, never starts an order in a language the guest was still choosing.
class KioskWelcomeLanguagePicker extends StatefulWidget {
  final List<LanguageModel> languages;
  final String current;
  final double pillHeight;

  /// False while the menu is being made ready after "touch to order".
  final bool enabled;
  final ValueChanged<LanguageModel> onSelect;

  const KioskWelcomeLanguagePicker({
    super.key,
    required this.languages,
    required this.current,
    required this.pillHeight,
    required this.onSelect,
    this.enabled = true,
  });

  static const Key triggerKey =
      ValueKey<String>('kiosk-welcome-language-trigger');
  static const Key menuKey = ValueKey<String>('kiosk-welcome-language-menu');

  static Key optionKey(String languageCode) =>
      ValueKey<String>('kiosk-welcome-language-$languageCode');

  @override
  State<KioskWelcomeLanguagePicker> createState() =>
      _KioskWelcomeLanguagePickerState();
}

class _KioskWelcomeLanguagePickerState extends State<KioskWelcomeLanguagePicker>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _controller;
  Timer? _autoClose;

  /// Logical state (drives the trigger's open look). The portal stays up a
  /// little longer than this while the close animation plays.
  bool _isOpen = false;

  LanguageModel get _selected {
    for (final LanguageModel l in widget.languages) {
      if (l.languageCode == widget.current) return l;
    }
    return widget.languages.first;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 180),
    );
  }

  /// One width for the pill and the card it opens, so the two line up as
  /// one object. Narrow windows leave room for the screen's side gutters.
  double _width(BuildContext context) => math.min(
        widget.pillHeight * 5.2,
        MediaQuery.sizeOf(context).width - 72,
      );

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    if (!widget.enabled || _isOpen) return;
    setState(() => _isOpen = true);
    _portal.show();
    _controller.forward();
    _autoClose?.cancel();
    _autoClose = Timer(_kAutoClose, _close);
  }

  void _close() {
    _autoClose?.cancel();
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse().whenComplete(() {
      // Re-opened mid-animation: leave it up.
      if (mounted && !_isOpen && _portal.isShowing) _portal.hide();
    });
  }

  void _pick(LanguageModel language) {
    // Apply first, so the tick and the pill change while the card closes.
    if (language.languageCode != widget.current) widget.onSelect(language);
    _close();
  }

  @override
  void didUpdateWidget(covariant KioskWelcomeLanguagePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ordering started: the card goes at once, there is no choice left.
    if (!widget.enabled && _isOpen) {
      _autoClose?.cancel();
      _isOpen = false;
      _controller.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isOpen && _portal.isShowing) _portal.hide();
      });
    }
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One language is not a choice.
    if (widget.languages.length < 2) return const SizedBox.shrink();

    final double h = widget.pillHeight;
    // A near-miss just beside the pill must not start an order either.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        padding: EdgeInsets.all(h * 0.12),
        child: OverlayPortal(
          controller: _portal,
          overlayLocation: OverlayChildLocation.rootOverlay,
          overlayChildBuilder: _buildOverlay,
          child: CompositedTransformTarget(
            link: _link,
            child: _Trigger(
              key: KioskWelcomeLanguagePicker.triggerKey,
              language: _selected,
              height: h,
              width: _width(context),
              open: _isOpen,
              enabled: widget.enabled,
              openProgress: _controller,
              onTap: _toggle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final double h = widget.pillHeight;
    final double width = _width(overlayContext);
    // `drive` rather than CurvedAnimation: nothing to dispose on each build.
    final Animation<double> curve =
        _controller.drive(CurveTween(curve: Curves.easeOutCubic));

    // Inert while it fades out, so the tap after a pick reaches the screen.
    return IgnorePointer(
      ignoring: !_isOpen,
      child: Stack(
        children: [
          // Full-screen catcher with a light veil that puts the card in front.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: FadeTransition(
                opacity: curve,
                child: const ColoredBox(color: Color(0x24000000)),
              ),
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            offset: Offset(0, -h * 0.22),
            child: Align(
              alignment: Alignment.bottomCenter,
              widthFactor: 1,
              heightFactor: 1,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): _close,
                },
                child: Focus(
                  autofocus: true,
                  child: FadeTransition(
                    opacity: curve,
                    child: ScaleTransition(
                      alignment: Alignment.bottomCenter,
                      scale: Tween<double>(begin: 0.94, end: 1).animate(curve),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.03),
                          end: Offset.zero,
                        ).animate(curve),
                        child: _Menu(
                          key: KioskWelcomeLanguagePicker.menuKey,
                          width: width,
                          height: h,
                          languages: widget.languages,
                          current: widget.current,
                          progress: _controller,
                          onPick: _pick,
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
}

/// A frosted rounded surface: blur of what is behind, translucent white,
/// a bright hairline edge and a soft two-layer shadow.
class _Glass extends StatelessWidget {
  final double radius;
  final Color tint;
  final List<BoxShadow> shadows;
  final Widget child;

  const _Glass({
    required this.radius,
    required this.tint,
    required this.shadows,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius corners = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: corners, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: corners,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: _kBlur, sigmaY: _kBlur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: corners,
              border: Border.all(color: _kGlassEdge, width: 1.2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A round flag with a white rim, so every flag reads as the same object
/// whatever its colours.
class _Flag extends StatelessWidget {
  final String asset;
  final double size;

  const _Flag({required this.asset, required this.size});

  @override
  Widget build(BuildContext context) {
    final double rim = (size * 0.05).clamp(1.5, 5.0);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(rim),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _Trigger extends StatefulWidget {
  final LanguageModel language;
  final double height;
  final double width;
  final bool open;
  final bool enabled;
  final Animation<double> openProgress;
  final VoidCallback onTap;

  const _Trigger({
    super.key,
    required this.language,
    required this.height,
    required this.width,
    required this.open,
    required this.enabled,
    required this.openProgress,
    required this.onTap,
  });

  @override
  State<_Trigger> createState() => _TriggerState();
}

class _TriggerState extends State<_Trigger> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final double h = widget.height;
    final VoidCallback? tap = widget.enabled ? widget.onTap : null;
    final double disc = h * 0.54;

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      label: widget.language.languageName,
      hint: kioskTranslate(context, 'select_language', 'Select language'),
      onTap: tap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: tap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          onTapDown: tap == null ? null : (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            // Width outside the glass, as on the card: the glass's hairline
            // border would otherwise make the pill wider than the card.
            child: SizedBox(
              width: widget.width,
              child: _Glass(
                radius: h / 2,
                tint: widget.open ? _kGlassOpen : _kGlass,
                shadows: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: h * 0.6,
                    offset: Offset(0, h * 0.16),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: h * 0.08,
                    offset: Offset(0, h * 0.02),
                  ),
                ],
                child: SizedBox(
                  height: h,
                  child: Padding(
                    // Insets concentric with the pill's round ends.
                    padding: EdgeInsets.only(left: h * 0.14, right: h * 0.23),
                    child: Row(
                      children: [
                        // Flag + name cross-fade on a switch; the chevron stays
                        // put at the far end.
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                ...previous,
                                if (current != null) current
                              ],
                            ),
                            child: Row(
                              key: ValueKey<String?>(
                                  widget.language.languageCode),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _Flag(
                                  asset: widget.language.imageUrl!,
                                  size: h * 0.72,
                                ),
                                SizedBox(width: h * 0.22),
                                Flexible(
                                  child: Text(
                                    widget.language.languageName ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: loewBold.copyWith(
                                      fontSize: h * 0.3,
                                      height: 1.1,
                                      letterSpacing: 0,
                                      color: _kInk,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: h * 0.16),
                        // Ink disc with a chevron that turns over as the card
                        // opens: up = "more above", down = "put it away".
                        Container(
                          width: disc,
                          height: disc,
                          decoration: const BoxDecoration(
                            color: _kInk,
                            shape: BoxShape.circle,
                          ),
                          child: RotationTransition(
                            turns: widget.openProgress.drive(
                              Tween<double>(begin: 0, end: 0.5).chain(
                                  CurveTween(curve: Curves.easeOutCubic)),
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: disc * 0.72,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  final double width;
  final double height;
  final List<LanguageModel> languages;
  final String current;
  final Animation<double> progress;
  final ValueChanged<LanguageModel> onPick;

  const _Menu({
    super.key,
    required this.width,
    required this.height,
    required this.languages,
    required this.current,
    required this.progress,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final double h = height;
    final String caption =
        kioskTranslate(context, 'select_language', 'Select language')
            .toUpperCase();
    final int n = languages.length;

    return SizedBox(
      width: width,
      child: _Glass(
        radius: h * 0.42,
        tint: _kPanelGlass,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: h * 1.1,
            offset: Offset(0, h * 0.36),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: h * 0.12,
            offset: Offset(0, h * 0.03),
          ),
        ],
        child: Padding(
          padding: EdgeInsets.fromLTRB(h * 0.12, h * 0.3, h * 0.12, h * 0.12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(h * 0.2, 0, h * 0.2, h * 0.18),
                child: Row(
                  children: [
                    Icon(
                      Icons.language_rounded,
                      size: h * 0.26,
                      color: TextTones.secondary,
                    ),
                    SizedBox(width: h * 0.12),
                    Expanded(
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewBold.copyWith(
                          fontSize: h * 0.2,
                          height: 1.2,
                          letterSpacing: h * 0.025,
                          color: TextTones.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < n; i++) ...[
                if (i > 0) SizedBox(height: h * 0.04),
                _Staggered(
                  progress: progress,
                  index: i,
                  count: n,
                  child: _Option(
                    key: KioskWelcomeLanguagePicker.optionKey(
                        languages[i].languageCode!),
                    language: languages[i],
                    height: h,
                    selected: languages[i].languageCode == current,
                    onTap: () => onPick(languages[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows rise in one after another as the card opens; all leave together.
class _Staggered extends StatelessWidget {
  final Animation<double> progress;
  final int index;
  final int count;
  final Widget child;

  const _Staggered({
    required this.progress,
    required this.index,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final double step = count <= 1 ? 0 : 0.35 / (count - 1);
    final double start = 0.15 + index * step;
    final Animation<double> curve = progress.drive(CurveTween(
      curve: Interval(start, math.min(1, start + 0.5), curve: Curves.easeOut),
    ));
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

class _Option extends StatefulWidget {
  final LanguageModel language;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  const _Option({
    super.key,
    required this.language,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_Option> createState() => _OptionState();
}

class _OptionState extends State<_Option> {
  bool _pressed = false;

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final double h = widget.height;
    final bool selected = widget.selected;
    final double mark = h * 0.42;
    final Color fill = selected
        ? _kInk.withValues(alpha: 0.07)
        : _pressed
            ? _kInk.withValues(alpha: 0.05)
            : Colors.transparent;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: widget.language.languageName,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: (_) => _press(true),
          onTapUp: (_) => _press(false),
          onTapCancel: () => _press(false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            // A little over the pill, so a row never dips under the 48px
            // touch target the pill is clamped to.
            height: h * 1.04,
            padding: EdgeInsets.symmetric(horizontal: h * 0.16),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(h * 0.28),
            ),
            child: Row(
              children: [
                _Flag(asset: widget.language.imageUrl!, size: h * 0.62),
                SizedBox(width: h * 0.24),
                Expanded(
                  child: Text(
                    widget.language.languageName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                      fontSize: h * 0.3,
                      height: 1.1,
                      letterSpacing: 0,
                      color: _kInk,
                    ),
                  ),
                ),
                SizedBox(width: h * 0.16),
                // Ink tick for the chosen language, an empty ring for the rest.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: mark,
                  height: mark,
                  decoration: BoxDecoration(
                    color: selected ? _kInk : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _kInk : _kInk.withValues(alpha: 0.22),
                      width: (h * 0.025).clamp(1.2, 3.0),
                    ),
                  ),
                  child: AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.check_rounded,
                      size: mark * 0.68,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
