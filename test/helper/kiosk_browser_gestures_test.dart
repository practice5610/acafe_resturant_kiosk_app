import 'dart:io';

import 'package:acafe_customer/helper/kiosk_browser_gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two-finger swipe on a Mac trackpad must not drive browser Back/Forward
/// inside the kiosk. The guard lives in two places: `web/index.html` (runs
/// before Flutter) and [disableKioskBrowserHistorySwipe] (re-applies after
/// Flutter mounts its glass pane).
void main() {
  late String html;
  late String helper;
  late String mainSource;

  setUpAll(() {
    html = File('web/index.html').readAsStringSync();
    helper = File('lib/helper/kiosk_browser_gestures.dart').readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
  });

  group('index.html', () {
    test('the document itself cannot overscroll into history', () {
      expect(html, contains('overscroll-behavior-x: none'));
      expect(html, contains('overflow: hidden'));
    });

    test('Flutter html-renderer hosts also opt out of swipe-to-navigate', () {
      expect(html, contains('flt-glass-pane'));
      expect(html, contains('overscroll-behavior-x: none'));
    });

    test('the wheel guard is non-passive so preventDefault is honoured', () {
      expect(html, contains("addEventListener('wheel'"));
      expect(html, contains('passive: false'));
      expect(html, contains('preventDefault()'));
      expect(html.contains('stopPropagation('), isFalse,
          reason: 'Flutter still needs the wheel event for in-app lists');
    });

    test('only horizontal-dominant swipes are blocked', () {
      expect(
        html,
        contains('Math.abs(e.deltaX) > Math.abs(e.deltaY)'),
      );
    });
  });

  group('Dart helper', () {
    test('is wired from main() so a regenerated index.html is not enough to lose it',
        () {
      expect(mainSource, contains('disableKioskBrowserHistorySwipe()'));
    });

    test('injects a non-passive capture listener', () {
      expect(helper, contains('passive: false'));
      expect(helper, contains('capture: true'));
      expect(helper, contains('preventDefault()'));
    });

    test('is a no-op off web so widget tests do not touch the DOM', () {
      expect(() => disableKioskBrowserHistorySwipe(), returnsNormally);
    });
  });
}
