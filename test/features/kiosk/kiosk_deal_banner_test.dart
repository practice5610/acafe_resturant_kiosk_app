import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/widgets/network_image_aspect.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_deal_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/single_child_widget.dart';

import '../../helpers/kiosk_layout_harness.dart';

/// The two banners actually on the live branch, plus the shapes an admin could
/// plausibly upload by mistake.
const double kWide = 2400 / 1000; // 2.40
const double kNarrow = 1672 / 941; // 1.78
const double kSquare = 1.0;

/// KioskStubSplashProvider serves product images from here and the banner falls
/// back to it when no deal base URL is configured.
const String kBase = 'http://localhost/product';

KioskDeal _deal(int id, String image) => KioskDeal(
      id: id,
      title: 'Deal $id',
      image: image,
      bundlePrice: 5,
      originalPrice: 6,
      savings: 1,
      savingsPercent: 16,
      available: true,
      items: const [],
    );

/// Renders the banner inside the real kiosk shell, in a column the width of a
/// product area, and returns the slot's size. The artwork cards inside it are
/// read with [_cards].
Future<Size> _pumpBanner(
  WidgetTester tester,
  Size window,
  List<KioskDeal> deals, {
  required List<SingleChildWidget> providers,
  double areaFraction = 0.72,
}) async {
  final double area = window.width * areaFraction;
  await pumpKioskScreen(
    tester,
    window,
    Scaffold(
      body: Center(
        child: SizedBox(
          width: area,
          child: KioskDealPromoBanner(
            s: KioskResponsive.scale(window.width, window.height),
            deals: deals,
          ),
        ),
      ),
    ),
    providers: providers,
  );
  await settleKiosk(tester);
  return tester.getSize(find.byType(KioskDealPromoBanner));
}

/// The artwork boxes inside the slot, in page order.
List<Size> _cards(WidgetTester tester) => tester
    .widgetList<SizedBox>(find.byKey(kKioskDealBannerCardKey))
    .map((box) => Size(box.width!, box.height!))
    .toList();

/// Where the artwork card actually sits on screen.
Rect _cardRect(WidgetTester tester) {
  final finder = find.byKey(kKioskDealBannerCardKey).first;
  return tester.getTopLeft(finder) & tester.getSize(finder);
}

/// Where the slot sits on screen. Defaults to the menu carousel; the deal
/// detail hero passes its own widget type.
Rect _slotRect(WidgetTester tester, [Finder? finder]) {
  final f = finder ?? find.byType(KioskDealPromoBanner);
  return tester.getTopLeft(f) & tester.getSize(f);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SingleChildWidget> providers;

  setUpAll(() async {
    await loadKioskTestFonts();
    providers = await kioskBaseProviders();
  });

  setUp(() {
    NetworkImageAspect.clearCache();
    // Seed the ratios so the widget lays out against real artwork shapes
    // without a network round-trip.
    NetworkImageAspect.seed('$kBase/wide.png', kWide);
    NetworkImageAspect.seed('$kBase/narrow.png', kNarrow);
    NetworkImageAspect.seed('$kBase/square.png', kSquare);
  });

  tearDown(NetworkImageAspect.clearCache);

  group('KioskDealPromoBanner', () {
    testWidgets('nothing renders when there are no deals', (tester) async {
      await pumpKioskScreen(
        tester,
        const Size(1080, 1920),
        const Scaffold(
          body: KioskDealPromoBanner(s: 0.42, deals: <KioskDeal>[]),
        ),
        providers: providers,
      );
      await settleKiosk(tester);
      expect(tester.getSize(find.byType(KioskDealPromoBanner)), Size.zero);
    });

    for (final size in kioskTargetSizes) {
      final label = '${size.width.toInt()}×${size.height.toInt()}';

      testWidgets('$label: a single banner keeps the artwork\'s shape',
          (tester) async {
        final Size box = await _pumpBanner(
          tester,
          size,
          [_deal(1, 'wide.png')],
          providers: providers,
        );

        expectNoOverflow(tester, size);
        final List<Size> cards = _cards(tester);
        expect(cards, hasLength(1), reason: label);

        // The card IS the artwork's own ratio, so BoxFit.cover crops nothing.
        expect(cards.single.width / cards.single.height, closeTo(kWide, 0.01),
            reason: '$label card drifted from the artwork');

        // It fits the room it was given, and never eats the screen.
        expect(cards.single.width, lessThanOrEqualTo(box.width + 0.5),
            reason: label);
        expect(box.height, closeTo(cards.single.height, 0.5), reason: label);
        expect(
          box.height,
          lessThanOrEqualTo(
            size.height * KioskResponsive.dealBannerMaxHeightFraction + 0.5,
          ),
          reason: '$label banner takes more than its share of the viewport',
        );
      });

      testWidgets('$label: a carousel sizes one slot for every banner',
          (tester) async {
        final Size box = await _pumpBanner(
          tester,
          size,
          [_deal(1, 'wide.png'), _deal(2, 'narrow.png')],
          providers: providers,
        );

        expectNoOverflow(tester, size);

        // A PageView only mounts the visible page, so each card is measured on
        // the page it lives on.
        final Size first = _cards(tester).single;
        expect(first.width / first.height, closeTo(kWide, 0.01), reason: label);

        // The slot is taller than the wide banner — it was sized for the
        // narrow one — so paging never resizes the products underneath.
        expect(box.height, closeTo(first.width / kNarrow, 0.5), reason: label);
        expect(first.height, lessThan(box.height), reason: label);

        await tester.fling(
          find.byType(PageView),
          Offset(-size.width / 2, 0),
          1000,
        );
        await settleKiosk(tester);

        final Size second = _cards(tester).single;
        expect(second.width / second.height, closeTo(kNarrow, 0.01),
            reason: label);
        // Same width, and it fills the slot it was sized for.
        expect(second.width, closeTo(first.width, 0.5), reason: label);
        expect(second.height, closeTo(box.height, 0.5), reason: label);
      });
    }

    testWidgets('a capped banner starts at the leading edge, not the middle',
        (tester) async {
      // Regression: the card used to be centred, so on a large panel it began
      // half a gap in from the first column of products above it.
      const Size big = Size(2560, 1440);
      await _pumpBanner(
        tester,
        big,
        [_deal(1, 'wide.png')],
        providers: providers,
        areaFraction: 0.9,
      );

      expectNoOverflow(tester, big);
      final Rect card = _cardRect(tester);
      final Rect slot = _slotRect(tester);

      expect(card.width, lessThan(slot.width),
          reason: 'this case is only meaningful when the cap binds');
      // Flush with the slot's leading edge …
      expect(card.left, closeTo(slot.left, 0.5));
      // … and all the spare room is on the trailing side.
      expect(slot.right - card.right, closeTo(slot.width - card.width, 0.5));
      // Vertically it still sits in the middle of its slot.
      expect(card.center.dy, closeTo(slot.center.dy, 0.5));
    });

    testWidgets('an uncapped banner fills its slot edge to edge',
        (tester) async {
      const Size window = Size(1080, 1920);
      await _pumpBanner(
        tester,
        window,
        [_deal(1, 'wide.png')],
        providers: providers,
      );

      expectNoOverflow(tester, window);
      final Rect card = _cardRect(tester);
      final Rect slot = _slotRect(tester);
      expect(card.left, closeTo(slot.left, 0.5));
      expect(card.right, closeTo(slot.right, 0.5));
    });

    testWidgets('the half-window cap makes the banner narrower than its area',
        (tester) async {
      const Size big = Size(2560, 1440);
      final Size box = await _pumpBanner(
        tester,
        big,
        [_deal(1, 'wide.png')],
        providers: providers,
        areaFraction: 0.9,
      );

      expectNoOverflow(tester, big);
      // The slot fills the area it was handed …
      final double area = big.width * 0.9;
      expect(box.width, closeTo(area, 0.5));

      // … but the artwork card stops at half the window.
      final Size card = _cards(tester).single;
      expect(card.width, closeTo(big.width * 0.5, 0.5),
          reason: 'a large panel should not get a full-width billboard');
      expect(card.width, lessThan(area));
      expect(card.width / card.height, closeTo(kWide, 0.01));
    });

    testWidgets('a near-square upload cannot take over the page',
        (tester) async {
      const Size window = Size(1080, 1920);
      final Size box = await _pumpBanner(
        tester,
        window,
        [_deal(1, 'square.png')],
        providers: providers,
      );

      expectNoOverflow(tester, window);
      // Clamped to the minimum aspect rather than laid out 1:1.
      final Size card = _cards(tester).single;
      expect(card.width / card.height,
          closeTo(KioskResponsive.dealBannerMinAspect, 0.01));
      expect(box.height, closeTo(card.height, 0.5));
    });

    testWidgets('an unresolved ratio still reserves the design slot',
        (tester) async {
      NetworkImageAspect.clearCache();
      const Size window = Size(1080, 1920);
      final Size box = await _pumpBanner(
        tester,
        window,
        [_deal(1, 'unknown.png')],
        providers: providers,
      );

      expectNoOverflow(tester, window);
      final Size card = _cards(tester).single;
      expect(card.width / card.height,
          closeTo(KioskResponsive.dealBannerDefaultAspect, 0.01));
      expect(box.height, closeTo(card.height, 0.5));
    });
  });

  group('KioskDealBannerImage — the deal detail hero', () {
    /// Renders the hero the way the detail screen does: inside the shell, in a
    /// ListView column with the screen's 32px side padding.
    Future<void> pumpHero(WidgetTester tester, Size window, String image) async {
      await pumpKioskScreen(
        tester,
        window,
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
            children: [
              KioskDealBannerImage(
                imageUrl: image.isEmpty ? '' : '$kBase/$image',
                fallback: const ColoredBox(color: Color(0xFF6B4A2F)),
              ),
            ],
          ),
        ),
        providers: providers,
      );
      await settleKiosk(tester);
    }

    for (final size in kioskTargetSizes) {
      final label = '${size.width.toInt()}×${size.height.toInt()}';

      testWidgets('$label: the hero keeps the artwork\'s shape', (tester) async {
        await pumpHero(tester, size, 'wide.png');
        expectNoOverflow(tester, size);

        final Size card = _cards(tester).single;
        expect(card.width / card.height, closeTo(kWide, 0.01),
            reason: '$label hero drifted from the artwork');
        expect(
          card.height,
          lessThanOrEqualTo(
            size.height * KioskResponsive.dealBannerMaxHeightFraction + 0.5,
          ),
          reason: '$label hero takes over the viewport',
        );
      });
    }

    testWidgets('the hero starts at the leading edge when capped',
        (tester) async {
      const Size big = Size(2560, 1440);
      await pumpHero(tester, big, 'wide.png');
      expectNoOverflow(tester, big);

      final Rect card = _cardRect(tester);
      final Rect slot = _slotRect(tester, find.byType(KioskDealBannerImage));
      expect(card.width, lessThan(slot.width));
      expect(card.left, closeTo(slot.left, 0.5));
      expect(card.width, closeTo(big.width * 0.5, 0.5));
    });

    testWidgets('a deal with no artwork still gets a sized fallback',
        (tester) async {
      const Size window = Size(1080, 1920);
      await pumpHero(tester, window, '');
      expectNoOverflow(tester, window);

      final Size card = _cards(tester).single;
      expect(card.width, greaterThan(0));
      expect(card.width / card.height,
          closeTo(KioskResponsive.dealBannerDefaultAspect, 0.01));
      expect(find.byType(ColoredBox), findsWidgets);
    });

    testWidgets('the old fixed 220px hero was the bug', (tester) async {
      // The detail screen used to render `SizedBox(height: 220, width:
      // infinity)`. On a wide window that is an ~8:1 box for a 2.4:1 image, so
      // cover threw away most of the artwork. Stated here so the fixed height
      // cannot quietly come back.
      const Size window = Size(2000, 1300);
      await pumpHero(tester, window, 'wide.png');

      final Size card = _cards(tester).single;
      expect(card.height, isNot(closeTo(220, 1)));
      expect(card.width / card.height, closeTo(kWide, 0.01));
    });
  });
}
