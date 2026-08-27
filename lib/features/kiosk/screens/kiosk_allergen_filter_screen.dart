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
/// ## Sizing
/// Authored against the 2078 x 2098 popup frame on the 2572px kiosk artboard,
/// and rendered by multiplying every Figma pixel by one scale — the same
/// [KioskResponsive.scale] the rest of the kiosk uses, so this modal is the
/// same physical size as the screen it covers. There are no per-element
/// clamps: one scale in, proportional layout out.
///
/// Height is the awkward axis. The frame is 2098 tall against a 4530 portrait
/// artboard, which fits comfortably — but on a landscape panel the scale comes
/// off the *height* and the five rows can still outgrow the viewport. Hence
/// `content-scroll-container` in the design: the header, subtitle and APPLY
/// button are pinned and only the rows scroll, so the button is always
/// reachable without the customer discovering they had to scroll.
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
          final double s = KioskLayout.scaleOf(context, constraints);

          // The popup is 2078 wide on a 2572 artboard. Cap at the available
          // width minus a margin so the black border is never flush against
          // the screen edge.
          final double cardWidth = math.min(
            _KioskAllergenSpec.cardWidth * s,
            constraints.maxWidth - 48 * s,
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
                child: SizedBox(
                  width: cardWidth,
                  child: _card(context, s),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, double s) {
    return Container(
      decoration: BoxDecoration(
        color: _KioskAllergenSpec.cardBg,
        borderRadius: BorderRadius.circular(_KioskAllergenSpec.cardRadius * s),
        border: Border.all(
          color: _KioskAllergenSpec.ink,
          width: _KioskAllergenSpec.cardBorder * s,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(_KioskAllergenSpec.cardPadding * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(context, s),
          SizedBox(height: _KioskAllergenSpec.sectionGap * s),
          _subtitle(context, s),
          SizedBox(height: _KioskAllergenSpec.sectionGap * s),
          // Only the rows scroll — the header and APPLY stay put. [Flexible]
          // rather than [Expanded] so a tall viewport lets the card shrink to
          // its natural height instead of stretching the rows apart.
          Flexible(child: _rows(context, s)),
          SizedBox(height: _KioskAllergenSpec.sectionGap * s),
          _applyButton(context, s),
        ],
      ),
    );
  }

  /// Back chevron overlaid on the centred title, matching the Figma grid where
  /// both share one row and the title is centred on the CARD, not on the space
  /// left over beside the button.
  Widget _header(BuildContext context, double s) {
    final double button = _KioskAllergenSpec.backButton * s;
    return SizedBox(
      height: button,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            // Keep the title clear of the back button on both sides so it stays
            // optically centred rather than drifting into the chevron.
            padding: EdgeInsets.symmetric(horizontal: button + 24 * s),
            child: Text(
              kioskTranslate(
                context,
                'allergen_popup_title',
                'ANYTHING WE SHOULD KNOW?',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Loew',
                fontWeight: FontWeight.w800,
                fontSize: _KioskAllergenSpec.titleSize * s,
                color: _KioskAllergenSpec.ink,
                height: 1.0,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
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
        ],
      ),
    );
  }

  Widget _subtitle(BuildContext context, double s) {
    return SizedBox(
      width: _KioskAllergenSpec.subtitleWidth * s,
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
          fontSize: _KioskAllergenSpec.subtitleSize * s,
          color: _KioskAllergenSpec.ink,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _rows(BuildContext context, double s) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _selectAllRow(context, s),
          SizedBox(height: _KioskAllergenSpec.rowGap * s),
          Container(
            height: _KioskAllergenSpec.dividerHeight * s,
            color: _KioskAllergenSpec.divider,
          ),
          SizedBox(height: _KioskAllergenSpec.rowGap * s),
          for (final KioskAllergen allergen in KioskAllergen.values) ...[
            _AllergenRow(
              s: s,
              allergen: allergen,
              selected: _selected.contains(allergen),
              onTap: () => _toggle(allergen),
            ),
            if (allergen != KioskAllergen.values.last)
              SizedBox(height: _KioskAllergenSpec.rowGap * s),
          ],
        ],
      ),
    );
  }

  Widget _selectAllRow(BuildContext context, double s) {
    return KioskTap(
      onTap: _toggleAll,
      child: SizedBox(
        height: _KioskAllergenSpec.selectAllHeight * s,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: _KioskAllergenSpec.rowPaddingX * s,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  kioskTranslate(context, 'allergen_select_all', 'Select all'),
                  style: TextStyle(
                    fontFamily: 'Loew',
                    fontWeight: FontWeight.w700,
                    fontSize: _KioskAllergenSpec.rowLabelSize * s,
                    color: _KioskAllergenSpec.rowLabel,
                    height: 1.0,
                  ),
                ),
              ),
              _AllergenCheckbox(s: s, checked: _allSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _applyButton(BuildContext context, double s) {
    return KioskTap(
      onTap: _apply,
      child: Container(
        width: double.infinity,
        height: _KioskAllergenSpec.applyHeight * s,
        decoration: BoxDecoration(
          color: _KioskAllergenSpec.ink,
          borderRadius:
              BorderRadius.circular(_KioskAllergenSpec.cardRadius * s),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              offset: Offset(0, 14 * s),
              blurRadius: 14 * s,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          kioskTranslate(context, 'allergen_apply_filters', 'APPLY FILTERS')
              .toUpperCase(),
          style: TextStyle(
            fontFamily: 'Loew',
            fontWeight: FontWeight.w800,
            fontSize: _KioskAllergenSpec.applyLabelSize * s,
            color: _KioskAllergenSpec.applyLabel,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

/// One allergen row: colour circle + white glyph, name, checkbox.
class _AllergenRow extends StatelessWidget {
  final double s;
  final KioskAllergen allergen;
  final bool selected;
  final VoidCallback onTap;

  const _AllergenRow({
    required this.s,
    required this.allergen,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double circle = _KioskAllergenSpec.iconCircle * s;
    final double glyph = _KioskAllergenSpec.iconGlyph * s;

    return KioskTap(
      onTap: onTap,
      child: Container(
        height: _KioskAllergenSpec.rowHeight * s,
        decoration: BoxDecoration(
          color: _KioskAllergenSpec.rowBg,
          borderRadius: BorderRadius.circular(_KioskAllergenSpec.rowRadius * s),
          border: Border.all(
            color: _KioskAllergenSpec.rowBorder,
            width: _KioskAllergenSpec.rowBorderWidth * s,
          ),
          // Figma lifts the selected row off the page. It is the only feedback
          // that survives a glance from arm's length on a kiosk.
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: Offset(0, 6 * s),
                    blurRadius: 8 * s,
                  ),
                ]
              : null,
        ),
        padding:
            EdgeInsets.symmetric(horizontal: _KioskAllergenSpec.rowPaddingX * s),
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
            SizedBox(width: _KioskAllergenSpec.iconGap * s),
            Expanded(
              child: Text(
                kioskTranslate(
                  context,
                  allergen.translationKey,
                  allergen.label,
                ),
                style: TextStyle(
                  fontFamily: 'Loew',
                  // Figma sets the selected row's label to ExtraBold.
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  fontSize: _KioskAllergenSpec.rowLabelSize * s,
                  color: _KioskAllergenSpec.rowLabel,
                  height: 1.0,
                ),
              ),
            ),
            _AllergenCheckbox(s: s, checked: selected),
          ],
        ),
      ),
    );
  }
}

/// Square checkbox: white with an ink outline, or solid ink with a white tick.
class _AllergenCheckbox extends StatelessWidget {
  final double s;
  final bool checked;

  const _AllergenCheckbox({required this.s, required this.checked});

  @override
  Widget build(BuildContext context) {
    final double box = _KioskAllergenSpec.checkbox * s;
    final double tick = _KioskAllergenSpec.checkGlyph * s;

    return Container(
      width: box,
      height: box,
      decoration: BoxDecoration(
        color: checked ? _KioskAllergenSpec.ink : Colors.white,
        borderRadius:
            BorderRadius.circular(_KioskAllergenSpec.checkboxRadius * s),
        border: checked
            ? null
            : Border.all(
                color: _KioskAllergenSpec.ink,
                width: _KioskAllergenSpec.checkboxBorder * s,
              ),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: checked
          ? SvgPicture.asset(
              Images.allergenCheckSvg,
              width: tick,
              height: tick,
            )
          : null,
    );
  }
}

/// Every measurement in this file, in Figma artboard pixels.
///
/// Kept in one place so the popup can be re-scaled from the design without
/// hunting through the widget tree, and so a reviewer can diff these against
/// the Figma inspector directly.
class _KioskAllergenSpec {
  _KioskAllergenSpec._();

  // Card
  static const double cardWidth = 2078;
  static const double cardPadding = 96;
  static const double cardRadius = 30;
  static const double cardBorder = 6;
  static const double sectionGap = 64;

  // Type
  static const double titleSize = 72;
  static const double subtitleSize = 48;
  static const double subtitleWidth = 1394;
  static const double rowLabelSize = 40;
  static const double applyLabelSize = 64;

  // Rows
  static const double rowGap = 24;
  static const double rowHeight = 191;
  static const double rowRadius = 24;
  static const double rowBorderWidth = 3;
  static const double rowPaddingX = 48;
  static const double selectAllHeight = 137;
  static const double dividerHeight = 4;
  static const double iconCircle = 84;
  static const double iconGlyph = 48;
  static const double iconGap = 24;

  // Checkbox
  static const double checkbox = 65;
  static const double checkboxRadius = 12.5;
  static const double checkboxBorder = 2.5;
  static const double checkGlyph = 46.875;

  // Apply button
  static const double backButton = 141;
  static const double applyHeight = 252;

  // Colours (Figma)
  static const Color cardBg = Color(0xFFFBF8EF);
  static const Color ink = Color(0xFF0D0D0D);
  static const Color rowBg = Color(0xFFFAF9F7);
  static const Color rowBorder = Color(0xFFDED9C7);
  static const Color rowLabel = Color(0xFF1F1F1F);
  static const Color divider = Color(0xFFDED9C7);
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
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(eased),
            child: child,
          ),
        );
      },
    ),
  );
  return applied ?? false;
}
