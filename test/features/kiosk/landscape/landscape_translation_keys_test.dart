import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Scans lib/features/kiosk/landscape/** for every translation key used via
/// getTranslated/kioskTranslate/translate and fails if that key is missing
/// from any of the 8 language files. Unlike kiosk_languages_test.dart's own
/// scanner (which only counts a key if it ALREADY exists in en.json — so a
/// brand-new key silently passes with no coverage at all), this one treats
/// en.json as the source of truth to add to, not a filter on what counts.
void main() {
  test('every landscape translation key exists in all 8 language files', () {
    final RegExp call = RegExp(
        r"""(?:getTranslated|kioskTranslate|translate)\(\s*(?:[\w.]+\s*,\s*)?['"]([^'"]+)['"]""");
    final Set<String> keys = {};
    for (final f in Directory('lib/features/kiosk/landscape')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      for (final m in call.allMatches(f.readAsStringSync())) {
        keys.add(m.group(1)!);
      }
    }
    expect(keys, isNotEmpty);

    const codes = ['en', 'de', 'es', 'fr', 'it', 'ja', 'nl', 'zh'];
    for (final code in codes) {
      final Map<String, dynamic> table = jsonDecode(
          File('assets/language/$code.json').readAsStringSync());
      final List<String> missing =
          keys.where((k) => !table.containsKey(k)).toList()..sort();
      expect(missing, isEmpty, reason: '$code.json is missing: $missing');
    }
  });
}
