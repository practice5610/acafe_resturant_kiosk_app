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
      '_kAddOnViewport': '1205', // Rectangle 101 height (track)
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
    test('dietary options are one horizontally-scrolling row, not a Wrap', () {
      expect(source, contains('_HorizontalOptionRow'));
      expect(source, contains('scrollDirection: Axis.horizontal'));
    });

    test('add-ons scroll inside their own capped viewport', () {
      expect(source, contains('_AddOnScrollBox'));
      expect(source, contains('maxHeight: _kAddOnViewport * s'));
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
