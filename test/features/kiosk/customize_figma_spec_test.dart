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
      '_kPanelBg': '0xFFFBF8EF', // panel background
      '_kPanelBorder': '0xFFB9B5A6', // panel + card border, scroll track
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
        contains('loewExtraBold.copyWith(\n              fontSize: 72 * s, height: 1.0'),
        reason: 'Inspect: Loew / ExtraBold / 72px / line-height 100%',
      );
    });
  });

  group('responsive', () {
    test('panels share the option-card corner radius', () {
      expect(source, contains('BorderRadius.circular(_kOptionRadius * s)'));
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

    test('the header compacts when the viewport is too short for the hero',
        () {
      expect(source, contains('_kFullHeroMinViewport'));
      expect(source, contains('constraints.maxHeight < _kFullHeroMinViewport'));
    });

    test('cup/can cards are capped against the viewport height', () {
      expect(source, contains('MediaQuery.sizeOf(context).height * 0.22'),
          reason: 'vessel cards must not eat the add-on list on a short screen');
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
      final String body =
          source.substring(source.indexOf('class _ActionBar'));
      expect(body, contains('KioskCheckoutButton('));
      expect(source.contains('class _AddToCartBar'), isFalse,
          reason: 'the one-off bar should be gone');
    });

    test('cancel is outlined, add to cart is filled', () {
      final String body =
          source.substring(source.indexOf('class _ActionBar'));
      expect(body, contains('filled: false'));
      expect(body, contains('filled: true'));
    });

    test('add to cart shows the running line total', () {
      final String body =
          source.substring(source.indexOf('class _ActionBar'));
      expect(body, contains('kioskLineTotal(buildKioskCartModel('),
          reason: 'price must track quantity, variations and add-ons');
      expect(body, contains('PriceConverterHelper.convertPrice('));
    });

    test('cancel returns to the menu', () {
      final String body =
          source.substring(source.indexOf('class _ActionBar'));
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

    test('the outer options list has no scrollbar of its own', () {
      // build() lives on the State class, so slice from there.
      final int start = source.indexOf('class _OptionsScrollAreaState');
      final int end = source.indexOf('\nclass ', start + 10);
      final String body = source.substring(start, end);

      expect(body.contains('RawScrollbar'), isFalse,
          reason: 'the page-length tan bar was removed; only the add-on '
              'panels carry an indicator, where scrolling actually happens');
      expect(body, contains('scrollbars: false'));
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
      // The pinned block sits between the Expanded scroll area and the bar.
      final int scrollArea = source.indexOf('_OptionsScrollArea(');
      final int cupCan = source.indexOf('_CupCanSection(', scrollArea);
      final int bar = source.indexOf('_ActionBar(', scrollArea);

      expect(scrollArea, greaterThan(-1));
      expect(cupCan, greaterThan(-1));
      expect(bar, greaterThan(cupCan),
          reason: 'cup/can must come before the action bar');

      // And it must no longer be a child of the scrolling column.
      final String scrollChildren = source.substring(scrollArea, cupCan);
      expect(scrollChildren.contains('_CupCanSection('), isFalse,
          reason: 'cup/can should not scroll away with the options');
    });
  });
}
