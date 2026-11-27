import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:acafe_customer/common/models/kiosk_theme.dart';

void main() {
  test('null / junk / {} all read as the built-in look', () {
    expect(KioskTheme.fromJson(null).isEmpty, isTrue);
    expect(KioskTheme.fromJson('not json').isEmpty, isTrue);
    expect(KioskTheme.fromJson(<String, dynamic>{}).isEmpty, isTrue);
    expect(KioskTheme.fromJson(<String, dynamic>{}), KioskTheme.none);
  });

  test('parses valid overrides and drops invalid ones', () {
    final t = KioskTheme.fromJson({
      'screen': {'bg': '#112233'},
      'sidebar': {'bg': 'red', 'text': '#FFFFFF', 'bold': true},
      'name': {'font': 'Inter', 'size': 18, 'color': '#FF0000', 'bg': '#000000'},
      'price': {'font': 'Rubik', 'size': 99}, // unknown font, out of range
      'description': {'font': 'Swiss721Light'},
    });
    expect(t.screenBg, const Color(0xFF112233));
    expect(t.sidebarBg, isNull);
    expect(t.sidebarText, const Color(0xFFFFFFFF));
    expect(t.sidebarBold, isTrue);
    expect(t.name!.font, 'Inter');
    expect(t.name!.size, 18);
    expect(t.price, isNull);
    expect(t.description!.font, 'Swiss721Light');
  });

  test('round-trips through JSON and compares by value', () {
    final a = KioskTheme.fromJson({'screen': {'bg': '#112233'}});
    final b = KioskTheme.fromJson(a.toJson());
    expect(a, b);
    expect(a == KioskTheme.none, isFalse);
  });

  test('apply scales size by the card factor and keeps caller colour', () {
    const t = KioskTextTheme(font: 'Swiss721Light', size: 20);
    final s = t.apply(const TextStyle(fontSize: 14), scale: 0.5, color: Colors.red);
    expect(s.fontFamily, 'Swiss721Light');
    expect(s.fontFamilyFallback, ['NunitoSans']);
    expect(s.fontSize, 10);
    expect(s.color, Colors.red);
  });
}
