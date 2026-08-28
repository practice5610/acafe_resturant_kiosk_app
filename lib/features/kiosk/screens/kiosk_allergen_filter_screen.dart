import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_scrim.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/utill/images.dart';

/// Allergen filter popup — Figma POS node 1385:15054
/// ("allergen-filter-popup-highlight").
///
/// Opens once per order, on the customer's first reach for a product, and asks
/// what they need to avoid. Whatever they tick is removed from the menu for the
/// rest of that order (see [KioskAllergenPreferences]).
///
/// ## Sizing — why this is not the raw 2078px Figma frame
/// The Figma frame is 2078 wide on the 2572 artboard: 81% of the screen. Drawn
/// at the kiosk scale that stops reading as a dialog and starts reading as a
/// second page — a slab of 191px rows and a 252px button pinned edge to edge.
/// It looked oversized on every panel we ship on.
///
/// So the popup is authored against its own [_Spec.cardWidth] card (60% of the
/// artboard) with proportionally tighter internals, and everything inside is
/// multiplied by [_CardMetrics.scale] — the *card's* scale, not the screen's:
///
/// ```text
/// cardWidth = clamp(1560 * s, floor, viewport - margins)
/// cs        = cardWidth / 1560          // == s until the viewport clamps
/// ```
///
/// That one substitution is what makes it pixel-perfect everywhere. On any
/// kiosk the card is exactly 1560 artboard px and `cs == s`, so it matches the
/// rest of the flow; on a window too narrow for that, the card takes the width
/// it can get and every glyph, gap and radius inside shrinks by the same
/// factor, so the composition never breaks and nothing can overflow sideways.
///
/// Height is the other axis. The card is capped at the viewport minus its
/// margin and only the rows scroll — header, subtitle and APPLY are pinned, so
/// the button is reachable on a 768px-tall landscape panel without the
/// customer having to discover that the list moves. [_ScrollFade] puts a soft
/// edge under the fixed chrome when there is more list, which is the only
/// honest way to say "keep going" at arm's length.
/// The card's outer box. Exposed so the responsive test can measure the card
/// itself rather than guessing at it from the text inside.
@visibleForTesting
const Key kKioskAllergenCardKey = ValueKey<String>('kiosk-allergen-card');

class KioskAllergenFilterScreen extends StatefulWidget {
  /// Selection to open with. Re-opening the popup later in an order (from the
  /// menu's filter affordance) should show what is already active.
  final Set<KioskAllergen> initialSelection;

  const KioskAllergenFilterScreen({
    super.key,
    this.initialSelection = const <KioskAllergen>{},
  });

  @override
  State<KioskAllergenFilterScreen> createState() =>
      _KioskAllergenFilterScreenState();
}

class _KioskAllergenFilterScreenState extends State<KioskAllergenFilterScreen> {
  late final Set<KioskAllergen> _selected =
      <KioskAllergen>{...widget.initialSelection};

  bool get _allSelected => _selected.length == KioskAllergen.values.length;

  void _toggle(KioskAllergen allergen) {
    setState(() {
      if (!_selected.remove(allergen)) _selected.add(allergen);
    });
  }

  /// "Select all" is a toggle: ticking it selects every allergen, un-ticking it
  /// clears the lot. Anything else makes the row a dead end once it is ticked.
  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(KioskAllergen.values);
      }
    });
  }

  void _apply() {
    KioskAllergenPreferences.instance.applySelection(_selected);
    Navigator.of(context).pop(true);
  }

  /// Backing out is an answer too — "nothing to declare". Marking it asked is
  /// what keeps this a once-per-order popup rather than something that reopens
  /// on every product tap.
  void _dismiss() {
    KioskAllergenPreferences.instance.markAsked();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // Width comes from the shell / the incoming constraints, never from the
      // window — see the kiosk responsive guardrail test.
      body: LayoutBuilder(
        builder: (context, constraints) {
          final _CardMetrics card = _CardMetrics.resolve(
            KioskLayout.scaleOf(context, constraints),
            constraints,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: KioskScrim(
                  animation: ModalRoute.of(context)?.animation ??
                      kAlwaysCompleteAnimation,
                  onDismiss: _dismiss,
                ),
              ),
              Center(
                // Width is fixed (the button inside must fill it); height is
                // only capped, so a card that needs less takes less.
                child: SizedBox(
                  key: kKioskAllergenCardKey,
                  width: card.width,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: card.maxHeight),
                    child: _card(context, card.scale),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, double cs) {
    return Container(
      decoration: BoxDecoration(
        color: _Spec.cardBg,
        borderRadius: BorderRadius.circular(_Spec.cardRadius * cs),
        border: Border.all(
          color: _Spec.ink,
          width: _Spec.cardBorder * cs,
        ),
        // The card has to sit *above* the blurred menu, not on it. A wide, low
        // shadow does that without any visible edge of its own.
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.22),
            offset: Offset(0, 28 * cs),
            blurRadius: 72 * cs,
            spreadRadius: -12 * cs,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.fromLTRB(
        _Spec.cardPadX * cs,
        _Spec.cardPadTop * cs,
        _Spec.cardPadX * cs,
        _Spec.cardPadBottom * cs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context, cs),
          SizedBox(height: _Spec.headerGap * cs),
          _subtitle(context, cs),
          SizedBox(height: _Spec.subtitleGap * cs),
          // Only the rows scroll — the header and APPLY stay put. [Flexible]
          // rather than [Expanded] so a tall viewport lets the card shrink to
          // its natural height instead of stretching the rows apart.
          Flexible(child: _rows(context, cs)),
          SizedBox(height: _Spec.applyGap * cs),
          _applyButton(context, cs),
        ],
      ),
    );
  }

  /// Back chevron overlaid on the centred title, matching the Figma grid where
  /// both share one row and the title is centred on the CARD, not on the space
  /// left over beside the button.
  Widget _header(BuildContext context, double cs) {
    final double button = _Spec.backButton * cs;
    final double title = _Spec.titleSize * cs;

    return SizedBox(
      // Full card width, or the Stack shrink-wraps the title and the chevron
      // lands beside the first word instead of on the card's left edge.
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ConstrainedBox(
            // The row is never shorter than the chevron, even for a one-line
            // title.
            constraints: BoxConstraints(minHeight: button),
            child: Padding(
              // Keep the title clear of the back button on both sides so it
              // stays optically centred rather than drifting into the chevron.
              padding: EdgeInsets.symmetric(horizontal: button + 20 * cs),
              child: Center(
                widthFactor: 1,
                child: Text(
                  kioskTranslate(
                    context,
                    'allergen_popup_title',
                    'ANYTHING WE SHOULD KNOW?',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Loew',
                    // Bold, not ExtraBold. At this size ExtraBold shouted over
                    // everything else on the card and read as a warning banner
                    // rather than a question. Tracking opens the caps back up.
                    fontWeight: FontWeight.w700,
                    fontSize: title,
                    letterSpacing: title * 0.02,
                    color: _Spec.ink,
                    height: 1.14,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: KioskTap(
                onTap: _dismiss,
                child: SizedBox(
                  width: button,
                  height: button,
                  child: SvgPicture.asset(
                    Images.allergenBackSvg,
                    width: button,
                    height: button,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtitle(BuildContext context, double cs) {
    return SizedBox(
      width: _Spec.subtitleWidth * cs,
      child: Text(
        kioskTranslate(
          context,
          'allergen_popup_subtitle',
          'Select everything that applies to you so we can personalize your experience',
        ),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Loew',
          fontWeight: FontWeight.w400,
          fontSize: _Spec.subtitleSize * cs,
          // Muted, so the question above it is the only thing shouting.
          color: _Spec.muted,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _rows(BuildContext context, double cs) {
    return _ScrollFade(
      fade: _Spec.scrollFade * cs,
      color: _Spec.cardBg,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _selectAllRow(context, cs),
            SizedBox(height: _Spec.selectAllGap * cs),
            Container(
              height: _Spec.dividerHeight * cs,
              color: _Spec.divider,
            ),
            SizedBox(height: _Spec.selectAllGap * cs),
            for (final KioskAllergen allergen in KioskAllergen.values) ...[
              _AllergenRow(
                cs: cs,
                allergen: allergen,
                selected: _selected.contains(allergen),
                onTap: () => _toggle(allergen),
              ),
              if (allergen != KioskAllergen.values.last)
                SizedBox(height: _Spec.rowGap * cs),
            ],
          ],
        ),
      ),
    );
  }

  /// Sits outside the row cards, in the card's own padding, so it reads as a
  /// control over the list rather than a sixth allergen. Its checkbox lines up
  /// with the row checkboxes because both are inset by [_Spec.rowPaddingX].
  Widget _selectAllRow(BuildContext context, double cs) {
    return KioskTap(
      onTap: _toggleAll,
      child: SizedBox(
        height: _Spec.selectAllHeight * cs,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _Spec.rowPaddingX * cs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  kioskTranslate(context, 'allergen_select_all', 'Select all'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Loew',
                    fontWeight: FontWeight.w500,
                    fontSize: _Spec.rowLabelSize * cs,
                    letterSpacing: _Spec.rowLabelSize * cs * 0.01,
                    color: _Spec.muted,
                    height: 1.0,
                  ),
                ),
              ),
              _AllergenCheckbox(cs: cs, checked: _allSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _applyButton(BuildContext context, double cs) {
    return KioskTap(
      onTap: _apply,
      child: Container(
        width: double.infinity,
        height: _Spec.applyHeight * cs,
        decoration: BoxDecoration(
          color: _Spec.ink,
          borderRadius: BorderRadius.circular(_Spec.applyRadius * cs),
          boxShadow: [
            BoxShadow(
              color: _Spec.ink.withValues(alpha: 0.22),
              offset: Offset(0, 10 * cs),
              blurRadius: 24 * cs,
              spreadRadius: -6 * cs,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          kioskTranslate(context, 'allergen_apply_filters', 'APPLY FILTERS')
              .toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Loew',
            fontWeight: FontWeight.w700,
            fontSize: _Spec.applyLabelSize * cs,
            letterSpacing: _Spec.applyLabelSize * cs * 0.06,
            color: _Spec.applyLabel,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// One allergen row: colour circle + white glyph, name, checkbox.
class _AllergenRow extends StatelessWidget {
  final double cs;
  final KioskAllergen allergen;
  final bool selected;
  final VoidCallback onTap;

  const _AllergenRow({
    required this.cs,
    required this.allergen,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double circle = _Spec.iconCircle * cs;
    final double glyph = _Spec.iconGlyph * cs;

    return KioskTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _Spec.stateChange,
        curve: Curves.easeOutCubic,
        height: _Spec.rowHeight * cs,
        decoration: BoxDecoration(
          color: _Spec.rowBg,
          borderRadius: BorderRadius.circular(_Spec.rowRadius * cs),
          // Selection is carried by the border colour, not its width — a
          // thicker border on select would shift the label a pixel and make
          // the whole list twitch as the customer works down it.
          border: Border.all(
            color: selected ? _Spec.ink : _Spec.rowBorder,
            width: _Spec.rowBorderWidth * cs,
          ),
          // Figma lifts the selected row off the page. It is the only feedback
          // that survives a glance from arm's length on a kiosk.
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E1E1E)
                  .withValues(alpha: selected ? 0.10 : 0.03),
              offset: Offset(0, (selected ? 8 : 2) * cs),
              blurRadius: (selected ? 18 : 6) * cs,
              spreadRadius: -2 * cs,
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: _Spec.rowPaddingX * cs),
        child: Row(
          children: [
            Container(
              width: circle,
              height: circle,
              decoration: BoxDecoration(
                color: allergen.swatch,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                allergen.icon,
                width: glyph,
                height: glyph,
              ),
            ),
            SizedBox(width: _Spec.iconGap * cs),
            Expanded(
              child: Text(
                kioskTranslate(
                  context,
                  allergen.translationKey,
                  allergen.label,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Loew',
                  // Medium at rest, Bold once ticked — enough of a step to
                  // scan the ticked rows without the list looking heavy.
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: _Spec.rowLabelSize * cs,
                  letterSpacing: _Spec.rowLabelSize * cs * 0.01,
                  color: _Spec.rowLabel,
                  height: 1.0,
                ),
              ),
            ),
            _AllergenCheckbox(cs: cs, checked: selected),
          ],
        ),
      ),
    );
  }
}

/// Square checkbox: white with an ink outline, or solid ink with a white tick.
class _AllergenCheckbox extends StatelessWidget {
  final double cs;
  final bool checked;

  const _AllergenCheckbox({required this.cs, required this.checked});

  @override
  Widget build(BuildContext context) {
    final double box = _Spec.checkbox * cs;
    final double tick = _Spec.checkGlyph * cs;

    return AnimatedContainer(
      duration: _Spec.stateChange,
      curve: Curves.easeOutCubic,
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: checked ? _Spec.ink : Colors.white,
        borderRadius: BorderRadius.circular(_Spec.checkboxRadius * cs),
        border: Border.all(
          color: checked ? _Spec.ink : _Spec.checkboxBorder,
          width: _Spec.checkboxBorderWidth * cs,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      // The tick grows in rather than appearing — at kiosk distance an
      // instantaneous swap is easy to miss when you tapped the row, not the box.
      child: AnimatedScale(
        duration: _Spec.stateChange,
        curve: Curves.easeOutBack,
        scale: checked ? 1.0 : 0.4,
        child: AnimatedOpacity(
          duration: _Spec.stateChange,
          opacity: checked ? 1.0 : 0.0,
          child: SvgPicture.asset(
            Images.allergenCheckSvg,
            width: tick,
            height: tick,
          ),
        ),
      ),
    );
  }
}

/// Soft edges on a scrollable, drawn in the surface colour, shown only on the
/// side that actually has more content.
///
/// The alternative — a scrollbar — is wrong for a kiosk: it is thin, it is
/// aimed at a cursor, and it tells the customer nothing until they are already
/// dragging. This tells them before they touch anything.
class _ScrollFade extends StatefulWidget {
  final Widget child;
  final double fade;
  final Color color;

  const _ScrollFade({
    required this.child,
    required this.fade,
    required this.color,
  });

  @override
  State<_ScrollFade> createState() => _ScrollFadeState();
}

class _ScrollFadeState extends State<_ScrollFade> {
  bool _above = false;
  bool _below = false;

  /// [ScrollMetricsNotification] arrives during layout, so committing straight
  /// to [setState] would rebuild mid-frame. Defer to the next frame instead.
  bool _sync(ScrollMetrics metrics) {
    final bool above = metrics.extentBefore > 1;
    final bool below = metrics.extentAfter > 1;
    if (above == _above && below == _below) return false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _above = above;
        _below = below;
      });
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _sync(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _sync(n.metrics),
        child: Stack(
          children: [
            widget.child,
            _edge(top: true, visible: _above),
            _edge(top: false, visible: _below),
          ],
        ),
      ),
    );
  }

  Widget _edge({required bool top, required bool visible}) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: widget.fade,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: visible ? 1.0 : 0.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  widget.color,
                  widget.color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card geometry for one viewport.
class _CardMetrics {
  /// Logical width of the card.
  final double width;

  /// Logical height the card may not exceed.
  final double maxHeight;

  /// Artboard px → logical px *inside* the card. Equal to the kiosk scale on
  /// every panel wide enough for the full card; smaller when the viewport
  /// clamps the width, which shrinks the contents by the same factor instead
  /// of letting them overflow.
  final double scale;

  const _CardMetrics({
    required this.width,
    required this.maxHeight,
    required this.scale,
  });

  static _CardMetrics resolve(double s, BoxConstraints constraints) {
    final double margin = _Spec.viewportMargin * s;
    // A viewport can be unbounded in a test harness or inside a scrollable
    // parent; fall back to the design card rather than producing infinity.
    final double availableW = constraints.hasBoundedWidth
        ? math.max(constraints.maxWidth - margin * 2, 1)
        : _Spec.cardWidth * s;
    final double availableH = constraints.hasBoundedHeight
        ? math.max(constraints.maxHeight - margin * 2, 1)
        : double.infinity;

    final double width = math.min(_Spec.cardWidth * s, availableW);
    return _CardMetrics(
      width: width,
      maxHeight: availableH,
      scale: width / _Spec.cardWidth,
    );
  }
}

/// Every measurement in this file, in Figma artboard pixels — the same unit the
/// rest of the kiosk is authored in, so `value * scale` is always the logical
/// size. Kept in one place so the popup can be re-proportioned without hunting
/// through the widget tree.
///
/// Note these are authored against the [cardWidth] card, not the 2572 screen:
/// a 132px row here is 132px of a 1560px card.
class _Spec {
  _Spec._();

  // Card
  static const double cardWidth = 1560;
  static const double viewportMargin = 72;
  static const double cardPadX = 64;
  static const double cardPadTop = 56;
  static const double cardPadBottom = 56;
  static const double cardRadius = 40;
  static const double cardBorder = 4;

  // Vertical rhythm
  static const double headerGap = 28;
  static const double subtitleGap = 44;
  static const double applyGap = 44;
  static const double selectAllGap = 20;
  static const double rowGap = 16;
  static const double scrollFade = 40;

  // Type
  static const double titleSize = 56;
  static const double subtitleSize = 34;
  static const double subtitleWidth = 1040;
  static const double rowLabelSize = 34;
  static const double applyLabelSize = 42;

  // Rows
  static const double rowHeight = 132;
  static const double rowRadius = 22;
  static const double rowBorderWidth = 2.5;
  static const double rowPaddingX = 36;
  static const double selectAllHeight = 84;
  static const double dividerHeight = 2;
  static const double iconCircle = 66;
  static const double iconGlyph = 36;
  static const double iconGap = 24;

  // Checkbox
  static const double checkbox = 48;
  static const double checkboxRadius = 12;
  static const double checkboxBorderWidth = 2.5;
  static const double checkGlyph = 30;

  // Controls
  static const double backButton = 88;
  static const double applyHeight = 148;
  static const double applyRadius = 24;

  /// Selection feedback. Long enough to read as motion, short enough that a
  /// customer tapping down the list never waits on it.
  static const Duration stateChange = Duration(milliseconds: 180);

  // Colours (Figma)
  static const Color cardBg = Color(0xFFFBF8EF);
  static const Color ink = Color(0xFF0D0D0D);
  static const Color rowBg = Color(0xFFFFFFFF);
  static const Color rowBorder = Color(0xFFE7E1CF);
  static const Color rowLabel = Color(0xFF1F1F1F);
  static const Color muted = Color(0xFF6F6A5E);
  static const Color checkboxBorder = Color(0xFFB9B3A2);
  static const Color divider = Color(0xFFE7E1CF);
  static const Color applyLabel = Color(0xFFFAF9F5);
}

/// Shows the allergen popup over the current screen.
///
/// Returns true when the customer tapped APPLY, false when they backed out.
/// Either way the popup is marked as asked for this order.
Future<bool> showKioskAllergenFilter(BuildContext context) async {
  final bool? applied = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => KioskAllergenFilterScreen(
        initialSelection: KioskAllergenPreferences.instance.avoided,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final Animation<double> eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(eased),
            child: child,
          ),
        );
      },
    ),
  );
  return applied ?? false;
}
