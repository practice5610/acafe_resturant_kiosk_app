import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'text_legibility_audit.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: child),
      ),
    ),
  );
}

Widget _onPanel(Widget child) =>
    ColoredBox(color: PosHomeSpec.panelBg, child: child);

void main() {
  testWidgets('flags faint ink on the receipt panel and passes the tones',
      (tester) async {
    await _pump(
      tester,
      _onPanel(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('faint',
                style:
                    TextStyle(fontSize: 11, color: PosHomeSpec.inkAlpha(0.53))),
            const Text('secondary',
                style: TextStyle(fontSize: 11, color: TextTones.secondary)),
            const Text('hint',
                style: TextStyle(fontSize: 14, color: TextTones.hint)),
          ],
        ),
      ),
    );

    final List<LegibilityIssue> issues = auditTextLegibility(tester);
    expect(issues.map((i) => i.text), ['faint']);
    expect(issues.single.problem, contains('3.45:1 < 4.5:1'));
    expect(issues.single.problem, contains('#FFFBF8EF'));
  });

  testWidgets('large text is held to the 3:1 floor', (tester) async {
    // ink @ 50 % on the panel is ~3.1:1: fails as body copy, passes as large.
    await _pump(
      tester,
      _onPanel(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('body',
                style:
                    TextStyle(fontSize: 14, color: PosHomeSpec.inkAlpha(0.5))),
            Text('display',
                style:
                    TextStyle(fontSize: 28, color: PosHomeSpec.inkAlpha(0.5))),
          ],
        ),
      ),
    );

    expect(auditTextLegibility(tester).map((i) => i.text), ['body']);
    expect(auditTextLegibility(tester, minRatio: 4.5).map((i) => i.text),
        ['body', 'display']);
  });

  testWidgets('an Opacity ancestor dims the text it wraps', (tester) async {
    await _pump(
      tester,
      _onPanel(
        const Opacity(
          opacity: 0.6,
          child: Text('dimmed',
              style: TextStyle(fontSize: 15, color: TextTones.secondary)),
        ),
      ),
    );

    final List<LegibilityIssue> issues = auditTextLegibility(tester);
    expect(issues.map((i) => i.text), ['dimmed']);
  });

  testWidgets('finds the surface through Container, Material and Ink',
      (tester) async {
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // White text is only legible because of the dark fill behind it.
          Container(
            decoration: const BoxDecoration(color: PosHomeSpec.ink),
            child: const Text('on decoration',
                style: TextStyle(color: Colors.white)),
          ),
          const Material(
            color: PosHomeSpec.ink,
            child: Text('on material', style: TextStyle(color: Colors.white)),
          ),
          Material(
            child: Ink(
              decoration: const BoxDecoration(color: PosHomeSpec.ink),
              child:
                  const Text('on ink', style: TextStyle(color: Colors.white)),
            ),
          ),
          // Transparent Material paints nothing: the white Scaffold shows.
          const Material(
            type: MaterialType.transparency,
            child: Text('on scaffold', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    expect(auditTextLegibility(tester).map((i) => i.text), ['on scaffold']);
  });

  testWidgets('composites a translucent fill over the surface below it',
      (tester) async {
    await _pump(
      tester,
      ColoredBox(
        color: Colors.black,
        child: ColoredBox(
          // 90 % white over black is light grey, so black text still passes,
          // which it would not if the fill were read as transparent.
          color: Colors.white.withValues(alpha: 0.9),
          child:
              const Text('over a scrim', style: TextStyle(color: Colors.black)),
        ),
      ),
    );

    expect(auditTextLegibility(tester), isEmpty);
  });

  testWidgets('flags an unregistered font family', (tester) async {
    await _pump(
      tester,
      Text('reopen copy',
          style: loewRegular.copyWith(
              fontFamily: 'Swiss721Light', color: TextTones.primary)),
    );

    expect(auditTextLegibility(tester).single.problem,
        contains('"Swiss721Light" is not registered'));
  });

  testWidgets('flags a bold the family cannot draw without synthesising',
      (tester) async {
    await _pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('fake bold',
              style: swiss721Light.copyWith(
                  fontWeight: FontWeight.w700, color: TextTones.primary)),
          Text('real medium',
              style: swiss721Medium.copyWith(color: TextTones.primary)),
          Text('real bold', style: loewBold.copyWith(color: TextTones.primary)),
        ],
      ),
    );

    final List<LegibilityIssue> issues = auditTextLegibility(tester);
    expect(issues.map((i) => i.text), ['fake bold']);
    expect(issues.single.problem, contains('bold would be synthesised'));
  });

  testWidgets('skips icon glyphs and runs the caller ignores', (tester) async {
    await _pump(
      tester,
      _onPanel(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, color: PosHomeSpec.inkAlpha(0.2)),
            const Text('Unavailable',
                style: TextStyle(color: TextTones.disabled)),
          ],
        ),
      ),
    );

    expect(auditTextLegibility(tester, ignore: (t) => t == 'Unavailable'),
        isEmpty);
  });

  test('reads every registered family and weight from pubspec.yaml', () {
    final Map<String, Set<int>> families = registeredFontFamilies;
    expect(families['Loew'], {400, 500, 700, 800});
    expect(families['Swiss721'], {400, 500});
    expect(families['Inter'], {400, 600, 700, 800});
    expect(families['Roboto'], {400});
  });
}
