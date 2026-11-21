import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acafe_customer/features/kiosk/landscape/kiosk_orientation.dart';

/// classifyKioskLayout is the whole decision: read fresh from the current
/// window every time, no memory across calls, so a resize always lands on
/// the right layout.
void main() {
  group('classifyKioskLayout (width >= height rule)', () {
    test('a window wider than it is tall is landscape', () {
      expect(classifyKioskLayout(const Size(1366, 1024)),
          KioskLayoutMode.landscape);
    });

    test('a window taller than it is wide is portrait', () {
      expect(classifyKioskLayout(const Size(1080, 1920)),
          KioskLayoutMode.portrait);
    });

    test('a square window counts as landscape (>= not >)', () {
      expect(classifyKioskLayout(const Size(1000, 1000)),
          KioskLayoutMode.landscape);
    });

    test('every call reads the window fresh — no lock across calls', () {
      expect(classifyKioskLayout(const Size(1366, 1024)),
          KioskLayoutMode.landscape);
      expect(classifyKioskLayout(const Size(1024, 1366)),
          KioskLayoutMode.portrait);
      expect(classifyKioskLayout(const Size(1920, 1080)),
          KioskLayoutMode.landscape);
    });
  });
}
