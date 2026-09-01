import 'dart:io';

import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_manager_repo.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_pin_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// The manager PIN modal is one vertical card on every viewport the kiosk ships
/// on. These checks pin the two things that were wrong before: the card used a
/// side-by-side landscape variant on wide windows, and on small windows nothing
/// kept it inside the viewport at a sane size.
class _StubManagerRepo implements KioskManagerRepo {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Real type, so the card's measured height matches what the kiosk renders.
    final loader = FontLoader('Loew');
    for (final path in const [
      'assets/fonts/Loew-Regular.ttf',
      'assets/fonts/Loew-Medium.ttf',
      'assets/fonts/Loew-Bold.ttf',
    ]) {
      loader.addFont(
        File(path).readAsBytes().then((b) => b.buffer.asByteData()),
      );
    }
    await loader.load();
  });

  Widget harness() => ChangeNotifierProvider(
        create: (_) =>
            KioskManagerProvider(kioskManagerRepo: _StubManagerRepo()),
        child: const MaterialApp(home: Scaffold(body: KioskPinEntrySheet())),
      );

  Future<void> render(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 300));
  }

  const viewports = <String, Size>{
    'portrait kiosk': Size(1080, 1920),
    'narrow browser window': Size(660, 1130),
    'phone-sized window': Size(390, 780),
    'desktop landscape window': Size(1500, 820),
    'short landscape display': Size(1600, 620),
    'large landscape display': Size(2560, 1440),
  };

  for (final entry in viewports.entries) {
    testWidgets('fits inside a ${entry.key} as one column', (tester) async {
      await render(tester, entry.value);

      expect(tester.takeException(), isNull);
      expect(find.text('Manager access'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
      for (final digit in ['0', '1', '5', '9']) {
        expect(find.text(digit), findsOneWidget);
      }

      final Rect card = tester.getRect(find.byType(FittedBox).first);
      final Size screen = entry.value;

      // Never bleeds past an edge.
      expect(card.left, greaterThanOrEqualTo(-0.5));
      expect(card.top, greaterThanOrEqualTo(-0.5));
      expect(card.right, lessThanOrEqualTo(screen.width + 0.5));
      expect(card.bottom, lessThanOrEqualTo(screen.height + 0.5));

      // Always taller than it is wide -- proof the keypad stayed under the
      // header instead of moving beside it.
      final Rect title = tester.getRect(find.text('Manager access'));
      final Rect keypad = tester.getRect(find.text('5'));
      expect(keypad.top, greaterThan(title.bottom));
      expect(keypad.center.dx, closeTo(title.center.dx, 1.0));
    });
  }

  testWidgets('keypad is comfortably sized on the production kiosk',
      (tester) async {
    await render(tester, const Size(1080, 1920));

    final Rect key = tester.getRect(find.ancestor(
      of: find.text('5'),
      matching: find.byType(AnimatedContainer),
    ));
    expect(key.height, greaterThan(70));
    expect(key.width, greaterThan(90));
  });

  testWidgets('tapping digits fills the dots and clear empties them',
      (tester) async {
    await render(tester, const Size(1080, 1920));

    Iterable<AnimatedContainer> dots() => tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((c) => c.constraints?.maxHeight == 22);

    expect(dots().length, 0);
    await tester.tap(find.text('7'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(dots().length, 1);

    await tester.tap(find.text('C'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(dots().length, 0);
  });

  testWidgets('close button sits in the top-right corner of the card',
      (tester) async {
    await render(tester, const Size(1080, 1920));

    final Rect card = tester.getRect(find.byType(FittedBox).first);
    final Rect close = tester.getRect(find.byIcon(Icons.close_rounded));
    final Rect title = tester.getRect(find.text('Manager access'));

    // Right half, above the title -- i.e. the card corner, not hanging off
    // the lock badge in the middle.
    expect(close.center.dx, greaterThan(card.center.dx));
    expect(close.center.dy, lessThan(title.top));
    expect(close.center.dx, greaterThan(title.right));
  });

  testWidgets('card is not a narrow vertical strip', (tester) async {
    for (final size in const [Size(1080, 1920), Size(660, 1130)]) {
      await render(tester, size);
      final Rect badge = tester.getRect(find.byType(CustomAssetImageWidget));
      final Rect unlock = tester.getRect(find.text('Unlock'));
      final Rect keyRow = tester.getRect(find.ancestor(
        of: find.text('1'),
        matching: find.byType(AnimatedContainer),
      ));
      final Rect lastKey = tester.getRect(find.ancestor(
        of: find.text('3'),
        matching: find.byType(AnimatedContainer),
      ));
      final double cardHeight = unlock.bottom - badge.top;
      final double cardWidth = lastKey.right - keyRow.left;
      // Content is wider than 0.7x its height: a designed panel, not a strip.
      expect(cardWidth / cardHeight, greaterThan(0.7));
    }
  });

  testWidgets('tapping the scrim outside the card closes it', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => KioskManagerProvider(kioskManagerRepo: _StubManagerRepo()),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openKioskManagerAccess(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Manager access'), findsOneWidget);

    await tester.tapAt(const Offset(20, 20)); // scrim, well clear of the card
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Manager access'), findsNothing);
  });
}
