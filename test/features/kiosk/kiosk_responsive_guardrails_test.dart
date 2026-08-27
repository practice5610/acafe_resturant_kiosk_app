import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level rails so the frozen 1100px "wide" layouts cannot creep back
/// in, and so layout width is not read from the window instead of the shell.
void main() {
  final Directory kioskLib = Directory('lib/features/kiosk');

  List<File> dartFiles() => kioskLib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('cart / confirm / checkout no longer ship a frozen wide twin', () {
    final cart = File('lib/features/kiosk/screens/kiosk_cart_screen.dart')
        .readAsStringSync();
    final confirm = File('lib/features/kiosk/screens/kiosk_confirm_screen.dart')
        .readAsStringSync();
    final checkout =
        File('lib/features/kiosk/screens/kiosk_checkout_widgets.dart')
            .readAsStringSync();

    expect(cart, isNot(contains('_WideKioskCartScreen')));
    expect(cart, isNot(contains('Responsive.isWide')));
    expect(confirm, isNot(contains('_WideConfirmScreen')));
    expect(confirm, isNot(contains('Responsive.isWide')));
    expect(checkout, isNot(contains('_WideCheckoutBody')));
    expect(checkout, isNot(contains('_WideCheckoutField')));
  });

  test('no kiosk screen keys layout off Responsive.isWide', () {
    for (final file in dartFiles()) {
      final body = file.readAsStringSync();
      expect(
        body.contains('Responsive.isWide'),
        isFalse,
        reason: '${file.path} still branches on isWide — use orientation + s',
      );
    }
  });

  test('MediaQuery size reads in kiosk UI are an allowlisted fallback', () {
    const allowed = <String>{
      'lib/features/kiosk/widgets/kiosk_scrim.dart',
      'lib/features/kiosk/widgets/kiosk_bottom_sheet.dart',
      'lib/features/kiosk/widgets/kiosk_pin_entry_sheet.dart',
      'lib/features/kiosk/screens/kiosk_welcome_screen.dart',
    };

    final offenders = <String>[];
    for (final file in dartFiles()) {
      final body = file.readAsStringSync();
      final usesWindow = body.contains('MediaQuery.sizeOf') ||
          body.contains('MediaQuery.of(context).size');
      if (!usesWindow) continue;
      if (allowed.contains(file.path)) continue;
      offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'layout width must come from KioskMetrics / LayoutBuilder, not the window. Offenders: $offenders',
    );
  });

  test('content cap is the artboard, not 1440', () {
    final shell =
        File('lib/common/responsive/kiosk_shell.dart').readAsStringSync();
    final metrics =
        File('lib/common/responsive/kiosk_responsive.dart').readAsStringSync();
    expect(metrics, contains('designWidth = 2572'));
    expect(
      metrics,
      contains('kKioskContentMaxWidth = KioskResponsive.designWidth'),
    );
    expect(shell, contains('maxWidth: metrics.contentWidth'));
  });
}
