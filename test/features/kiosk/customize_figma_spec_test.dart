import 'dart:io';

import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_spec.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the values read off Figma `02a – Menu Browse (Full Page)`
/// (node 1385:13510, 2572x5400 artboard) into the customize screen.
///
/// Two kinds of guard live here. The measurements are real code now — they sit
/// in [KioskCustomizeSpec] — so those are asserted as values. The colours and
/// the layout RULES have no runtime handle, so they stay source checks: if
/// someone edits a token away from the design, this fails and names it.
void main() {
  late String source;
  late String stepSource;

  setUpAll(() {
    source = File(
      'lib/features/kiosk/screens/kiosk_product_customize_sheet.dart',
    ).readAsStringSync();
    stepSource = File(
      'lib/features/kiosk/screens/kiosk_product_customize_step_flow.dart',
    ).readAsStringSync();
  });

  group('Figma colours', () {
    const tokens = {
      // `Rectangle 62` — the section panels AND the option cards share one fill.
      '_kPanelBg': '0xFFFBF8EF',
      // `Rectangle 62` stroke, the idle card outline and the scroll track.
      '_kPanelBorder': '0xFFB9B5A6',
      // `can` (unselected vessel) carries a lighter outline than the cards.
      '_kVesselIdleBorder': '0xFFE2D9C8',
      '_kCardBorderSelected': '0xFF000000',
      '_kInkText': '0xFF0D0D0D',
      '_kCreamText': '0xFFF3F3DD',
      '_kScrollThumb': '0xFF000000', // Rectangle 100
    };

    tokens.forEach((name, hex) {
      test('$name is $hex', () {
        expect(source, contains('$name = Color($hex)'),
            reason: '$name must stay the Figma token $hex');
      });
    });

    test('the idle card outline and scroll track reuse the border token', () {
      expect(source, contains('_kCardIdleBorder = _kPanelBorder'));
      expect(source, contains('_kScrollTrack = _kPanelBorder'));
    });

    test('the panel is a flat cream card, not a white one with a shadow', () {
      final int start = source.indexOf('class _SectionPanel');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);

      expect(body, contains('color: _kPanelBg'));
      expect(body.contains('boxShadow'), isFalse,
          reason: 'Figma draws a 1px border, no drop shadow');
    });
  });

  group('Figma metrics', () {
    test('the artboard is the 2572x5400 portrait frame', () {
      expect(KioskCustomizeSpec.artboardWidth, 2572);
      expect(KioskCustomizeSpec.artboardHeight, 5400);
    });

    test('hero image is the design\'s 453x731 portrait box', () {
      expect(KioskCustomizeSpec.heroWidth, 453);
      expect(KioskCustomizeSpec.heroHeight, 731);
      expect(source, contains('fit: BoxFit.contain'),
          reason: 'a landscape photo letterboxes, it never stretches');
    });

    test('type follows the inspected Figma styles', () {
      // Loew ExtraBold 72 / Swiss 721 Light 48 / Loew ExtraBold 96.
      expect(KioskCustomizeSpec.titleSize, 72);
      expect(KioskCustomizeSpec.descriptionSize, 48);
      expect(KioskCustomizeSpec.stepperGlyphSize, 96);
      expect(KioskCustomizeSpec.panelTitleSize, 72);
      // Loew Medium 45.36 / 45 on the cards, Swiss 721 Light 36 for prices.
      expect(KioskCustomizeSpec.optionLabelSize, closeTo(45.36, 0.001));
      expect(KioskCustomizeSpec.addOnNameSize, 45);
      expect(KioskCustomizeSpec.addOnPriceSize, 36);
      // `cup-text` / `can-text`: Loew Bold 28 with 3.36 tracking.
      expect(KioskCustomizeSpec.vesselLabelSize, 28);
      expect(KioskCustomizeSpec.vesselLabelTracking, closeTo(3.36, 0.001));
      expect(KioskCustomizeSpec.actionLabelSize, 72);
    });

    test('card labels use Loew Medium, as inspected', () {
      expect(source, contains('loewMedium.copyWith('),
          reason: 'Figma card labels are Loew Medium, not Bold');
    });

    test('the description is Swiss 721 Light', () {
      final int start = source.indexOf('class _Header');
      final int end = source.indexOf('\nclass ', start + 10);
      expect(source.substring(start, end), contains('swiss721Light.copyWith('));
    });

    test('boxes match the artboard', () {
      // `Group 97` back button, `Group 95` stepper, `Group 167` action bar.
      expect(KioskCustomizeSpec.backButton, 141);
      expect(KioskCustomizeSpec.stepperButtonWidth, 150);
      expect(KioskCustomizeSpec.stepperButtonHeight, 114);
      expect(KioskCustomizeSpec.actionHeight, 252);
      // `Group 98` dietary card and `card-shot-espresso` add-on card.
      expect(KioskCustomizeSpec.optionCardWidth, closeTo(407.823, 0.001));
      expect(KioskCustomizeSpec.optionCardHeight, closeTo(449.4, 0.001));
      expect(KioskCustomizeSpec.addOnCardWidth, 539);
      expect(KioskCustomizeSpec.addOnCardHeight, 535);
      // `cup` / `can`.
      expect(KioskCustomizeSpec.vesselCardWidth, 1099);
      expect(KioskCustomizeSpec.vesselCardHeight, 790);
      // `Rectangle 100`/`101`.
      expect(KioskCustomizeSpec.scrollbarWidth, 20);
      expect(KioskCustomizeSpec.scrollbarRadius, 15);
    });

    test('radii and gaps match the artboard', () {
      expect(KioskCustomizeSpec.panelRadius, 30);
      expect(KioskCustomizeSpec.optionCardRadius, 31.5);
      expect(KioskCustomizeSpec.addOnCardRadius, 31.5);
      expect(KioskCustomizeSpec.vesselCardRadius, 28);
      expect(KioskCustomizeSpec.actionRadius, 30);
      expect(KioskCustomizeSpec.optionCardGap, 45);
      expect(KioskCustomizeSpec.addOnCardGap, 20);
      expect(KioskCustomizeSpec.vesselCardGap, 35);
      expect(KioskCustomizeSpec.actionGap, 22);
    });
  });

  group('one scale, no per-element floors', () {
    test('the screen carries no clamp of its own', () {
      // Per-element floors are what pulled the old screen out of proportion: a
      // 16px minimum heading inside a panel that kept shrinking. Every bound
      // now lives on the scale, so the screen itself must have none.
      expect(source.contains('.clamp('), isFalse,
          reason: 'bound the scale, not individual elements');
      expect(stepSource.contains('* s).clamp('), isFalse,
          reason: 'Version B\'s chrome follows the same rule');
    });

    test('borders are the one exception, and only ever a floor', () {
      expect(
          source, contains('double _border(double artboardWidth, double s)'));
      expect(source, contains('math.max(KioskCustomizeSpec.borderFloor'));
      expect(KioskCustomizeSpec.borderFloor, 1.0);
    });

    test('the compact second header is gone', () {
      // It existed only because the old scale ignored height and left no room
      // for the real header. It carried its own photo size, type sizes and
      // spacing — a second design competing with Figma's.
      expect(source.contains('class _CompactHeader'), isFalse);
      expect(source.contains('_kFullHeroMinViewport'), isFalse);
      expect(stepSource.contains('_CompactHeader'), isFalse);
    });

    test('card interiors come from the card width, not the raw scale', () {
      // A card sizes its own interior from the width it was given, so it is the
      // same SHAPE on a phone-width window and a 4K kiosk.
      for (final String card in ['_DietaryCard', '_AddOnCard']) {
        final int start = source.indexOf('class $card');
        final int end = source.indexOf('\nclass ', start + 10);
        final String body = source.substring(start, end);
        expect(body, contains('final double k = width /'),
            reason: '$card must derive its interior from its own width');
      }
    });

    test('cards are sized from available width, not a fixed artboard value',
        () {
      expect(source, contains('_cardWidthFor('));
      expect(source, contains('width: cardWidth'),
          reason: 'both card types must take the computed width');
      // The rule itself lives in a testable helper.
      expect(source, contains('kioskOptionCardWidth('));
    });

    test('a row keeps ONE height, so cards never go ragged', () {
      // A Row/Wrap lets each child size itself, which is how the old grid ended
      // up with a short card beside a tall empty one.
      expect(source, contains('double _choiceCardHeight('));
      expect(source, contains('double _optionCardHeight('));
      expect(source, contains('double _addOnCardHeight('));
      expect(source, contains('height: cardHeight'));
    });

    test('variation and add-on cards share one compact image/name/price box',
        () {
      expect(source, contains('_choiceTileWidth('));
      expect(source, contains('KioskResponsive.compactMax'));
      expect(KioskCustomizeSpec.choiceCardWidth, 320);
      expect(KioskCustomizeSpec.choiceCardHeight, 340);
      expect(KioskCustomizeSpec.choiceCardMaxEdgeCompact, 96);
      expect(KioskCustomizeSpec.choiceCardMaxEdgeCompact,
          lessThan(KioskCustomizeSpec.choiceCardWidth));
      expect(KioskCustomizeSpec.choiceCardWidth,
          lessThan(KioskCustomizeSpec.optionCardWidth));
      expect(KioskCustomizeSpec.choiceCardWidth,
          lessThan(KioskCustomizeSpec.addOnCardWidth));
      expect(KioskCustomizeSpec.choiceCardHeight,
          lessThan(KioskCustomizeSpec.optionCardHeight));
      expect(KioskCustomizeSpec.choiceCardHeight,
          lessThan(KioskCustomizeSpec.addOnCardHeight));
    });

    test('cup/can cards are shorter than the Figma 1099x790 ratio', () {
      expect(KioskCustomizeSpec.vesselHeightFactor, lessThan(1));
      expect(source, contains('KioskCustomizeSpec.vesselHeightFactor'));
      expect(source, contains('compact: true'),
          reason: 'the vessel panel tightens its chrome as well as its cards');
    });
  });

  group('bottom action pair', () {
    test('is CANCEL ITEM beside ADD TO CART, in that order', () {
      final int bar = source.indexOf('class _ActionBar');
      expect(bar, greaterThan(-1), reason: '_ActionBar should exist');

      // Row order is what the design fixes, so compare the two buttons'
      // fill flags rather than the translation keys — the add-to-cart label is
      // built above the Row, so key order says nothing about layout.
      final String body = source.substring(bar);
      final int outlined = body.indexOf('filled: false');
      final int filled = body.indexOf('filled: true');
      expect(outlined, greaterThan(-1));
      expect(filled, greaterThan(outlined),
          reason: 'cancel (outlined) sits left of add to cart (filled)');
    });

    test('reuses the shared KioskCheckoutButton rather than a local button',
        () {
      final String body = source.substring(source.indexOf('class _ActionBar'));
      expect(body, contains('KioskCheckoutButton('));
      expect(source.contains('class _AddToCartBar'), isFalse,
          reason: 'the one-off bar should be gone');
    });

    test('the bar scales with the page instead of snapping at the 1100px seam',
        () {
      final String body = source.substring(source.indexOf('class _ActionBar'));
      expect(body, contains('forceScaled: true'),
          reason: 'a fixed 60px button would break the artboard it sits in');
    });

    test('add to cart shows the running line total', () {
      final String body = source.substring(source.indexOf('class _ActionBar'));
      expect(body, contains('kioskLineTotal(buildKioskCartModel('),
          reason: 'price must track quantity, variations and add-ons');
      expect(body, contains('PriceConverterHelper.convertPrice('));
    });

    test('cancel returns to the menu', () {
      final String body = source.substring(source.indexOf('class _ActionBar'));
      expect(body, contains('KioskNavigationHelper.popOrNavigate'));
      expect(body, contains('RouterHelper.getKioskMenuRoute'));
    });
  });

  group('Figma layout rules', () {
    test('every variation row scrolls sideways and never wraps', () {
      expect(source, contains('scrollDirection: Axis.horizontal'));

      // Both dietary AND size are variations, so both must use the single-line
      // row. Size used to be a Wrap, which spilled onto a second line.
      for (final String panel in ['_VariationSection', '_SizeOptionsPanel']) {
        final int start = source.indexOf('class $panel');
        expect(start, greaterThan(-1), reason: '$panel should exist');
        final int end = source.indexOf('\nclass ', start + 10);
        final String body = source.substring(start, end);

        expect(body, contains('_HorizontalOptionRow('),
            reason: '$panel must lay its cards out in one scrolling row');
        expect(body.contains('child: Wrap('), isFalse,
            reason: '$panel must not wrap onto a second line');
      }
    });

    test('variations are NOT inside any vertical scroller', () {
      // The rule, stated three times by the user and got wrong twice: a
      // variation row moves horizontally and never vertically. Making the row
      // horizontal was not enough — the panels also have to sit OUTSIDE the
      // vertical scroll area, or the whole row scrolls up and down with the
      // page.
      final int scrollArea = source.indexOf('_AddOnScrollBox(s: s');
      final int sizePanel = source.indexOf('_SizeOptionsPanel(');
      final int dietary = source.indexOf('_VariationSection(');

      expect(sizePanel, greaterThan(-1));
      expect(dietary, greaterThan(-1));
      expect(scrollArea, greaterThan(-1));
      expect(sizePanel, lessThan(scrollArea),
          reason: 'size must be pinned above the scroller');
      expect(dietary, lessThan(scrollArea),
          reason: 'dietary must be pinned above the scroller');
    });

    test('the add-on scroller carries no horizontal axis', () {
      final int start = source.indexOf('class _AddOnScrollBoxState');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);

      expect(body.contains('Axis.horizontal'), isFalse,
          reason: 'add-ons scroll vertically only');
    });

    test('the horizontal row carries no vertical axis', () {
      final int start = source.indexOf('class _HorizontalOptionRow');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);

      expect(body, contains('scrollDirection: Axis.horizontal'));
      expect(body.contains('Axis.vertical'), isFalse);
    });

    test('the page itself has no outer options scrollbar', () {
      expect(source.contains('class _OptionsScrollArea'), isFalse,
          reason: 'the page-length scroller is gone; only the add-on '
              'panel carries an indicator');
      expect(source.contains('class _WideCustomizeLayout'), isFalse,
          reason: 'wide two-column layout diverged from Figma; one layout now');
    });

    test('the add-on panel keeps its own indicator', () {
      final int start = source.indexOf('class _AddOnScrollBoxState');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);

      expect(body, contains('RawScrollbar'));
      expect(body, contains('thumbColor: _kScrollThumb'));
      expect(body, contains('trackColor: _kScrollTrack'));
    });

    test('there is exactly one add-on scroller', () {
      // Several stacked scrollers is what made the page and the group both
      // scroll at once. One declaration + one usage.
      expect('_AddOnScrollBox('.allMatches(source).length, 2);
    });

    test('the scroll indicator lives INSIDE the add-ons panel', () {
      final int section = source.indexOf('class _AddOnsSection');
      final int end = source.indexOf('\nclass ', section + 10);
      final String body = source.substring(section, end);

      // The section builds the panel and the scroller together, so the bar is
      // drawn within the panel's padding rather than beside the whole region.
      final int panel = body.indexOf('_SectionPanel(');
      final int scroller = body.indexOf('_AddOnScrollBox(');
      expect(panel, greaterThan(-1));
      expect(scroller, greaterThan(panel),
          reason: 'the scroller must be a child of the panel, not its sibling');
      expect(body, contains('fill: scrollable'),
          reason: 'the panel has to give the scroller its remaining height');
    });

    test('cup/can is pinned outside the scroll area, above the action bar', () {
      final int start =
          source.indexOf('class _KioskProductCustomizeScreenState');
      final int end = source.indexOf('\nString kioskProductDescription');
      final String body = source.substring(start, end);

      final int addOns = body.indexOf('_AddOnsSection(');
      final int cupCan = body.indexOf('_CupCanSection(');
      final int bar = body.indexOf('_ActionBar(');

      expect(addOns, greaterThan(-1));
      expect(cupCan, greaterThan(addOns),
          reason: 'cup/can sits below the add-on scroller');
      expect(bar, greaterThan(cupCan),
          reason: 'cup/can must come before the action bar');
    });

    test('the action bar is a sibling of the scroll area, never over it', () {
      // Requirement: the bottom buttons must not overlap the customization
      // content. A pinned Column child cannot, a Stack/Positioned bar could.
      final int start =
          source.indexOf('class _KioskProductCustomizeScreenState');
      final int end = source.indexOf('\nString kioskProductDescription');
      final String body = source.substring(start, end);
      expect(body.contains('Positioned('), isFalse);
      expect(body, contains('Expanded('),
          reason: 'the scrolling region takes the height the bar leaves');
    });
  });

  group('Figma card anatomy', () {
    test('variation radios are filled dots, not checkmarks', () {
      final int start = source.indexOf('class _RadioDot');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);
      expect(body.contains('Icons.check'), isFalse);
      expect(body, contains('BoxShape.circle'));
      expect(body, contains('color: Colors.black'));
    });

    test('a chosen add-on with no stepper moves its price to the top-right',
        () {
      // `card-whipped-cream/Selected` puts the price above the artwork;
      // `card-vanilla-syrup/Selected`, which has a stepper, keeps it inline.
      final int start = source.indexOf('class _AddOnCard');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);
      expect(body, contains('_addonPriceLabel('));
      expect(
          body, contains('selected && !showQuantity && priceLabel.isNotEmpty'));
      expect(body, contains('textAlign: TextAlign.right'));
    });

    test('selected multi add-ons show an in-card quantity stepper', () {
      expect(source, contains('class _CardQtyStepper'));
      expect(source, contains('showQuantity: selected && !group.isSingle'));
      expect(source, contains('setAddOnQuantity('));
    });

    test('size variations use the dietary card with a radio', () {
      final int start = source.indexOf('class _SizeOptionsPanel');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);
      expect(body, contains('_DietaryCard('));
      expect(body.contains('_AddOnCard('), isFalse);
    });

    test('the vessel card sizes its contents from its own box', () {
      final int start = source.indexOf('class _CupCanCard');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);

      expect(body, contains('final double kW = width /'));
      expect(body, contains('final double kH = height /'));
      expect(body, contains('height: height,'),
          reason: 'both vessels are given the same height by the section');
    });
  });
}
