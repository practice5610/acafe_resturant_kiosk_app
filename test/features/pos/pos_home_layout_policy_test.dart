import 'package:acafe_customer/features/pos/domain/pos_home_layout.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The grid viewport width the home screen hands [PosProductGrid] in [window]:
/// the product pane, less the rail and the pinned receipt, less its insets.
double _gridViewport(Size window) {
  final PosHomeLayout layout = PosHomeLayout.resolve(window);
  final double pane = window.width -
      (layout.compact ? 0 : layout.sidebarWidth) -
      (layout.sideReceipt ? layout.receiptWidth : 0);
  return pane - layout.contentInsetLeft - layout.contentInsetRight;
}

int _columns(Size window) =>
    PosHomeLayout.resolve(window).gridColumns(_gridViewport(window));

void main() {
  group('composition', () {
    test('phones and narrow windows get the compact strip', () {
      for (final width in [320.0, 375.0, 430.0, 507.0, 768.0, 899.0]) {
        final layout = PosHomeLayout.resolve(Size(width, 800));
        expect(layout.compact, isTrue, reason: 'rail at $width');
        expect(layout.sideReceipt, isFalse, reason: 'pinned receipt at $width');
      }
    });

    test('the rail returns at the compact breakpoint', () {
      for (final width in [PosResponsive.compactMax, 1024.0, 1366.0, 1920.0]) {
        expect(PosHomeLayout.resolve(Size(width, 800)).compact, isFalse,
            reason: 'strip at $width');
      }
    });

    test('compact tightens the gutters and the grid fade', () {
      final compact = PosHomeLayout.resolve(const Size(375, 812));
      final desktop = PosHomeLayout.resolve(const Size(1366, 1024));
      expect(compact.contentInsetLeft, lessThan(desktop.contentInsetLeft));
      expect(compact.fadeHeight, lessThan(desktop.fadeHeight));
      // The toolbar and the tiles end on the same line in both.
      expect(compact.contentInsetRight + compact.toolbarInsetRight,
          compact.contentInsetRight + compact.gridInsetRight);
    });

    test('is exactly the Figma frame at 1366', () {
      final layout = PosHomeLayout.resolve(const Size(1366, 1024));
      expect(layout.scale, closeTo(1, 0.0001));
      expect(layout.sidebarWidth, closeTo(PosHomeSpec.sidebarWidth, 0.001));
      expect(layout.contentInsetLeft,
          closeTo(PosHomeSpec.contentPaddingLeft, 0.001));
      expect(layout.fadeHeight, PosHomeSpec.contentFadeHeight);
    });
  });

  group('grid columns follow the width, not a constant', () {
    test('three across at every desktop size the design covers', () {
      for (final window in const [
        Size(1024, 768),
        Size(1180, 820),
        Size(1280, 800),
        Size(1366, 768),
        Size(1366, 1024),
        Size(1440, 900),
        Size(1920, 1080),
      ]) {
        expect(_columns(window), PosHomeSpec.gridColumns,
            reason: 'columns at $window');
      }
    });

    test('two on a phone, so a tile is never a sliver', () {
      for (final window in const [
        Size(320, 640),
        Size(360, 780),
        Size(375, 812),
        Size(414, 896),
        Size(507, 800),
      ]) {
        expect(_columns(window), 2, reason: 'columns at $window');
      }
    });

    test('a portrait tablet fits a third column', () {
      expect(_columns(const Size(768, 1024)), 3);
      expect(_columns(const Size(820, 1180)), 3);
    });

    test('very large displays add columns instead of growing tiles', () {
      expect(_columns(const Size(2560, 1440)), greaterThan(3));
      expect(_columns(const Size(3840, 2160)),
          greaterThan(_columns(const Size(2560, 1440))));
    });

    test('a tile never grows past its stretch limit', () {
      for (final width in [
        320.0, 507.0, 768.0, 899.0, 950.0, 1024.0, 1366.0, 1920.0, 2560.0 //
      ]) {
        final Size window = Size(width, 900);
        final layout = PosHomeLayout.resolve(window);
        final double usable = _gridViewport(window) - layout.gridInsetRight;
        final int columns = _columns(window);
        final double tile =
            (usable - (columns - 1) * PosHomeSpec.gridColumnGap) / columns;
        expect(
            tile,
            lessThanOrEqualTo(PosHomeSpec.tileWidth *
                    layout.scale *
                    PosHomeLayout.maxTileStretch +
                0.001),
            reason: 'tile at $width');
      }
    });
  });
}
