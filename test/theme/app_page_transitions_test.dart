import 'package:acafe_customer/theme/app_page_transitions.dart';
import 'package:acafe_customer/theme/dark_theme.dart';
import 'package:acafe_customer/theme/light_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both themes slide on every platform (Flutter would zoom-fade)', () {
    for (final ThemeData theme in [light, dark]) {
      for (final TargetPlatform platform in TargetPlatform.values) {
        expect(theme.pageTransitionsTheme.builders[platform],
            isA<AppSlidePageTransitionsBuilder>(),
            reason: '$platform');
      }
    }
  });

  testWidgets('a pushed screen slides in from the right, without a fade',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('second')),
            )),
            child: const Text('first'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('first'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Part-way across, purely sideways (a zoom would also shrink it off the
    // top), and the screen underneath has moved left with it.
    final Offset at = tester.getTopLeft(find.text('second'));
    expect(at.dx, greaterThan(0));
    expect(at.dx, lessThan(1000));
    expect(at.dy, 0);
    expect(tester.getTopLeft(find.text('first')).dx, lessThan(0));
    expect(
        find.ancestor(
            of: find.text('second'), matching: find.byType(FadeTransition)),
        findsNothing);

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('second')).dx, 0);
  });
}
