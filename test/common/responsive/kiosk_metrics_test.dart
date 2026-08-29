import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/common/responsive/kiosk_shell.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KioskMetrics.resolve', () {
    test('the production 1080×1920 kiosk is standard portrait at s≈0.42', () {
      final m = KioskMetrics.resolve(const Size(1080, 1920));
      expect(m.band, KioskBand.standard);
      expect(m.isPortrait, isTrue);
      expect(m.contentWidth, 1080);
      expect(m.scale, closeTo(1080 / 2572, 0.0001));
      expect(m.viewport, const Size(1080, 1920));
    });

    test('content is capped at the 2572 artboard, not 1440', () {
      final m = KioskMetrics.resolve(const Size(3840, 2160));
      expect(m.contentWidth, KioskResponsive.designWidth);
      expect(m.scale, 1.0);
      expect(m.band, KioskBand.large);
      expect(m.isLandscape, isTrue);
      // Surplus is margins, not a frozen 1440 island.
      expect(3840 - m.contentWidth, 1268);
    });

    test('below the artboard the cap never binds', () {
      for (final width in [768.0, 1024.0, 1080.0, 1440.0, 1920.0, 2560.0]) {
        final m = KioskMetrics.resolve(Size(width, 1920));
        expect(m.contentWidth, width,
            reason: '$width should pass through the 2572 cap');
      }
    });

    test('900 sits clear of the 1080 hardware so there is no seam', () {
      expect(KioskResponsive.compactMax, lessThan(1080));
      expect(
        KioskMetrics.resolve(const Size(1080, 1920)).band,
        KioskBand.standard,
      );
      expect(
        KioskMetrics.resolve(const Size(899, 1600)).band,
        KioskBand.compact,
      );
    });

    test('1800 keeps 1440/1600 laptops in the same band as the kiosk', () {
      expect(
        KioskMetrics.resolve(const Size(1440, 900)).band,
        KioskBand.standard,
      );
      expect(
        KioskMetrics.resolve(const Size(1600, 900)).band,
        KioskBand.standard,
      );
      expect(
        KioskMetrics.resolve(const Size(1800, 1000)).band,
        KioskBand.large,
      );
    });

    test('fullBleed uses the window width (welcome video)', () {
      final m = KioskMetrics.resolve(const Size(3840, 2160), fullBleed: true);
      expect(m.contentWidth, 3840);
      expect(m.fullBleed, isTrue);
    });

    test('a landscape laptop is height-limited so chrome is not zoomed', () {
      // 14" MacBook-class window: wide enough that width-only scale (1440/2572)
      // inflates the header and cart bar until the product grid is clipped.
      final m = KioskMetrics.resolve(const Size(1440, 900));
      expect(m.isLandscape, isTrue);
      expect(m.scale, closeTo(900 / KioskResponsive.landscapeDesignHeight, 0.0001));
      expect(m.scale, lessThan(1440 / KioskResponsive.designWidth));
    });
  });

  group('scale at 1080 is unchanged', () {
    test('KioskResponsive.scale(1080) matches the previous menu clamp', () {
      expect(KioskResponsive.scale(1080), closeTo(1080 / 2572, 0.0001));
      expect(KioskResponsive.scale(1080),
          inInclusiveRange(KioskResponsive.minScale, KioskResponsive.maxScale));
    });

    test('formScale at 1080 stays 1.0 so login does not shrink', () {
      expect(KioskResponsive.formContentWidth(1080), 1000);
      expect(KioskResponsive.formScale(1080), 1.0);
    });

    test('form column grows only past 1400', () {
      expect(KioskResponsive.formContentWidth(1400), 1000);
      expect(KioskResponsive.formContentWidth(1800), 1800);
      expect(KioskResponsive.formContentWidth(3840), 1800);
    });
  });

  group('kioskBounded', () {
    test('returns the value when it sits between min and max', () {
      expect(kioskBounded(50, min: 10, max: 100), 50);
    });

    test('prefers the ceiling when min would exceed max', () {
      // Medium landscape login: formWidth 1000, usable ~962.
      expect(kioskBounded(1850, min: 1000, max: 962.56), 962.56);
      expect(kioskBounded(634, min: 720, max: 1024), 720);
    });

    test('collapses to max when the range is empty', () {
      expect(kioskBounded(500, min: 800, max: 600), 600);
    });
  });

  group('product grid', () {
    KioskProductGridGeometry menuGrid(double screenWidth) {
      final double s = KioskResponsive.scale(screenWidth);
      final double inner = screenWidth - 2 * 85 * s;
      final rail = kioskCategoryRailLayout(scale: s, innerWidth: inner);
      final double area = inner - rail.width - rail.gap;
      return KioskProductGridGeometry.resolve(areaWidth: area, gap: 41 * s);
    }

    test('the production kiosk stays on 3 Figma columns', () {
      final geo = menuGrid(1080);
      expect(geo.columns, 3);
      expect(geo.tileWidth, closeTo(262, 2));
    });

    test('column count moves with measured product-area width', () {
      expect(menuGrid(1080).columns, 3);
      expect(menuGrid(1440).columns, greaterThanOrEqualTo(3));
      expect(menuGrid(1920).columns, greaterThanOrEqualTo(menuGrid(1440).columns));
      expect(menuGrid(2560).columns, lessThanOrEqualTo(6));
      expect(menuGrid(2572).columns, lessThanOrEqualTo(6));
    });

    test('cards always fill the row', () {
      for (final screen in [768.0, 1080.0, 1440.0, 1920.0, 2560.0, 2572.0]) {
        final double s = KioskResponsive.scale(screen);
        final double inner = screen - 2 * 85 * s;
        final rail = kioskCategoryRailLayout(scale: s, innerWidth: inner);
        final double area = inner - rail.width - rail.gap;
        final geo =
            KioskProductGridGeometry.resolve(areaWidth: area, gap: 41 * s);
        final double used =
            geo.tileWidth * geo.columns + geo.gap * (geo.columns - 1);
        expect(used, closeTo(area, 0.5), reason: 'row does not fill at $screen');
      }
    });

    test('landscape cards use a square image so a 16:9 row still fits', () {
      const area = 900.0;
      const gap = 16.0;
      final portrait =
          KioskProductGridGeometry.resolve(areaWidth: area, gap: gap);
      final landscape = KioskProductGridGeometry.resolve(
        areaWidth: area,
        gap: gap,
        landscape: true,
      );
      expect(landscape.tileHeight, lessThan(portrait.tileHeight));
      expect(landscape.imageHeight, closeTo(landscape.tileWidth, 0.01));
      expect(portrait.imageHeight, closeTo(portrait.tileWidth / 0.72, 0.01));
    });
  });

  group('orientation, not a 1100px seam', () {
    testWidgets('1080×1920 is not wide', (tester) async {
      late bool wide;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1080, 1920)),
          child: KioskShell(
            child: Builder(builder: (context) {
              wide = Responsive.isWide(context);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(wide, isFalse);
    });

    testWidgets('1920×1080 is landscape / wide', (tester) async {
      late bool wide;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: KioskShell(
            child: Builder(builder: (context) {
              wide = Responsive.isWide(context);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(wide, isTrue);
    });
  });

  group('KioskLayout reads metrics from the shell', () {
    testWidgets('portrait 1080 matches the artboard scale', (tester) async {
      late double scale;
      late bool landscape;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1080, 1920)),
          child: KioskShell(
            child: Builder(builder: (context) {
              scale = KioskLayout.scaleOf(context);
              landscape = KioskLayout.isLandscape(context);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(scale, closeTo(1080 / 2572, 0.0001));
      expect(landscape, isFalse);
    });

    testWidgets('landscape 1920×1080 is height-limited', (tester) async {
      late double scale;
      late bool landscape;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1920, 1080)),
          child: KioskShell(
            child: Builder(builder: (context) {
              scale = KioskLayout.scaleOf(context);
              landscape = KioskLayout.isLandscape(context);
              return const SizedBox();
            }),
          ),
        ),
      );
      expect(landscape, isTrue);
      expect(scale, closeTo(1080 / KioskResponsive.landscapeDesignHeight, 0.0001));
    });
  });

  group('KioskShell overrides MediaQuery to the capped box', () {
    testWidgets('at 1080 the reported width is 1080', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      late Size reported;
      late KioskMetrics metrics;
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(1080, 1920)),
          child: KioskShell(
            child: _Probe(),
          ),
        ),
      );
      final probe = tester.widget<_Probe>(find.byType(_Probe));
      reported = probe.size;
      metrics = probe.metrics;
      expect(reported.width, 1080);
      expect(metrics.contentWidth, 1080);
    });

    testWidgets('at 3840 the reported width is 2572, not 1440', (tester) async {
      tester.view.physicalSize = const Size(3840, 2160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(3840, 2160)),
          child: KioskShell(
            child: _Probe(),
          ),
        ),
      );
      final probe = tester.widget<_Probe>(find.byType(_Probe));
      expect(probe.size.width, KioskResponsive.designWidth);
      expect(probe.metrics.contentWidth, KioskResponsive.designWidth);
      expect(probe.size.width, isNot(1440));
    });
  });
}

class _Probe extends StatelessWidget {
  const _Probe();

  Size get size => _size;
  KioskMetrics get metrics => _metrics;

  static late Size _size;
  static late KioskMetrics _metrics;

  @override
  Widget build(BuildContext context) {
    _size = MediaQuery.sizeOf(context);
    _metrics = KioskMetrics.of(context);
    return const SizedBox.expand();
  }
}
