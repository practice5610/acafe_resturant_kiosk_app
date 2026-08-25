import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the values read off Figma `02a – Menu Browse (Full Page)`
/// (node 1385:13510, 2572×5400 artboard) into the customize screen's source.
///
/// These are design tokens with no runtime behaviour to assert against, so the
/// guard is a source check: if someone edits a constant away from the design,
/// this fails and names the value. It is deliberately narrow — only the
/// numbers the design actually specifies.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/kiosk/screens/kiosk_product_customize_sheet.dart',
    ).readAsStringSync();
  });

  group('Figma colours', () {
    const tokens = {
      '_kPanelBg': '0xFFFFFFFF', // section card fill
      '_kPanelBorder': '0xFFB9B5A6', // scroll track
      '_kScrollThumb': '0xFF000000', // Rectangle 100
    };

    tokens.forEach((name, hex) {
      test('$name is $hex', () {
        expect(source, contains('$name = Color($hex)'),
            reason: '$name must stay the Figma token $hex');
      });
    });

    test('the scroll track reuses the border token', () {
      expect(source, contains('_kScrollTrack = _kPanelBorder'));
    });
  });

  group('Figma metrics', () {
    const metrics = {
      '_kScrollbarWidth': '20', // Rectangle 100/101 width
      '_kScrollbarRadius': '15', // Rectangle 100/101 radius
    };

    metrics.forEach((name, value) {
      test('$name is $value', () {
        expect(source, contains('$name = $value'),
            reason: '$name must stay the Figma value $value');
      });
    });

    test('hero image is the design\'s 453x731 portrait box, centred', () {
      expect(source, contains('width: 453 * s'));
      expect(source, contains('height: 731 * s'));
    });

    test('product title is Loew ExtraBold 72 at line-height 100%', () {
      expect(
        source,
        contains(
            'loewExtraBold.copyWith(\n              fontSize: 72 * s, height: 1.0'),
        reason: 'Inspect: Loew / ExtraBold / 72px / line-height 100%',
      );
    });
  });

  group('responsive', () {
    test('panels share the option-card corner radius', () {
      expect(source, contains('_kOptionRadius'));
      expect(source, contains('BorderRadius.circular('));
      expect(source.contains('BorderRadius.circular(70 * s)'), isFalse,
          reason: 'the panel had its own radius; it now follows the cards');
    });

    test('cards are sized from available width, not a fixed artboard value',
        () {
      expect(source, contains('_optionCardWidth('));
      expect(source, contains('width: cardWidth'),
          reason: 'both card types must take the computed width');
      // The rule itself lives in a testable helper.
      expect(source, contains('kioskOptionCardWidth('));
    });

    test('the header compacts when the viewport is too short for the hero', () {
      expect(source, contains('_kFullHeroMinViewport'));
      expect(source, contains('constraints.maxHeight < _kFullHeroMinViewport'));
    });

    test('cup/can cards are capped against the viewport height', () {
      final int start = source.indexOf('class _CupCanSection');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);

      expect(body, contains('MediaQuery.sizeOf(context).height'));
      expect(body, contains('viewportHeight * 0.22'),
          reason:
              'vessel cards must not eat the add-on list on a short screen');
    });

    test('the vessel card sizes its contents from its own height', () {
      final int start = source.indexOf('class _CupCanCard');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);

      // A short card with artboard-sized artwork inside it was the bug: the
      // vessel, its label and the tick all have to shrink with the card.
      expect(body, contains('final double height;'));
      expect(body, contains('height: height,'));
      expect(body.contains('fontSize: 34 * s'), isFalse,
          reason: 'the label must scale with the card, not the artboard');
    });

    test('card interiors come from the card width, not the raw scale', () {
      // `s` bottoms out at KioskResponsive.minScale, so anything multiplied
      // straight by it stops shrinking while the panel keeps getting narrower
      // — which is what left oversized boxes around 7px labels.
      expect(source, contains('class _OptionCardMetrics'));
      expect('_OptionCardMetrics.of(cardWidth'.allMatches(source).length, 2,
          reason: 'both the add-on and the dietary card must use it');
      for (final String frozen in [
        'height: _kOptionImage * s',
        'padding: EdgeInsets.all(_kOptionCardPad * s)',
        'fontSize: _kOptionNameSize * s',
        'fontSize: _kOptionPriceSize * s',
      ]) {
        expect(source.contains(frozen), isFalse,
            reason: '$frozen freezes at the minimum scale');
      }
    });

    test('a row with no artwork drops the image slot rather than reserving it',
        () {
      expect(source, contains('bool _hasOptionArt('));
      expect(source, contains('if (m.image > 0)'),
          reason: 'the slot is conditional, not a fixed band of white');
      // Decided per row/group so every card in a row keeps ONE height: a Wrap
      // does not stretch siblings, so a per-card decision would go ragged.
      expect(source, contains('group.addons.any((addon) => addon.hasImage)'));
      expect(source, contains('images.any(_hasOptionArt)'));
    });

    test('the compact header stacks photo over name, centred', () {
      final int start = source.indexOf('class _CompactHeader');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);

      expect(body.contains('Row('), isFalse,
          reason: 'the photo sits above the name now, not beside it');
      expect(body, contains('CrossAxisAlignment.center'));
      expect(body, contains('textAlign: TextAlign.center'));
      // The back button no longer pushes the block off-centre.
      expect(body, contains('Positioned('));
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

    test('cancel is outlined, add to cart is filled', () {
      final String body = source.substring(source.indexOf('class _ActionBar'));
      expect(body, contains('filled: false'));
      expect(body, contains('filled: true'));
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
      final int scrollArea = source.indexOf('child: _AddOnScrollBox(');
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

    test('add-ons are the only vertical scroller', () {
      expect(source, contains('_AddOnScrollBox'));
      expect(source.contains('_kAddOnViewport'), isFalse,
          reason: 'the fixed viewport cap is gone with the pinned layout');

      // Exactly one instance: several stacked scrollers is what made the page
      // and the group both scroll at once.
      expect('_AddOnScrollBox('.allMatches(source).length, 2,
          reason: 'one constructor declaration + one usage');
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
      expect(body, contains('fill: true'),
          reason: 'the panel has to give the scroller its remaining height');
    });

    test('cup/can is pinned outside the scroll area, above the action bar', () {
      final int start =
          source.indexOf('class _KioskProductCustomizeScreenState');
      final int end = source.indexOf('\nclass _Header');
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

    test('add-on cards put the price in the selected top-right corner', () {
      final int start = source.indexOf('class _AddOnCard');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);
      expect(body, contains('_addonPriceLabel('));
      expect(body, contains('priceOnTop'));
      expect(body, contains('Positioned('));
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
  });
}
