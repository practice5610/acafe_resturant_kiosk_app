import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// The kiosk ships exactly four locales. These guard the pairing between
/// [AppConstants.languages], the bundled `assets/language/*.json` files and the
/// flag artwork — the three things that must be added (or removed) together.
void main() {
  const List<String> expected = ['nl', 'en', 'fr', 'de'];

  test('offers exactly the four kiosk languages, in picker order', () {
    expect(
      AppConstants.languages.map((l) => l.languageCode).toList(),
      expected,
    );
  });

  test('every language carries a name, country code and flag', () {
    for (final language in AppConstants.languages) {
      expect(language.languageName, isNotEmpty,
          reason: '${language.languageCode} has no display name');
      expect(language.countryCode, isNotEmpty,
          reason: '${language.languageCode} has no country code');
      expect(language.imageUrl, isNotEmpty,
          reason: '${language.languageCode} has no flag');
      expect(File(language.imageUrl!).existsSync(), isTrue,
          reason: 'missing flag asset ${language.imageUrl}');
    }
  });

  test('every language has a translation file, and no strays are bundled', () {
    final bundled = Directory('assets/language')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toList()
      ..sort();

    expect(bundled, (List<String>.from(expected)..sort()),
        reason: 'assets/language must contain one file per kiosk language');
  });

  test('translation files parse and share the same keys as English', () {
    Map<String, dynamic> read(String code) => json.decode(
        File('assets/language/$code.json').readAsStringSync());

    final english = read('en');
    expect(english, isNotEmpty);

    for (final code in expected.where((c) => c != 'en')) {
      final other = read(code);
      final missing = english.keys.where((k) => !other.containsKey(k)).toList();
      expect(missing, isEmpty, reason: '$code.json is missing: $missing');
    }
  });

  test('the strings the language sheet renders are translated everywhere', () {
    for (final code in expected) {
      final Map<String, dynamic> map = json
          .decode(File('assets/language/$code.json').readAsStringSync());
      for (final key in ['select_language', 'choose_your_preferred_language']) {
        expect(map[key], isA<String>(),
            reason: '$code.json is missing "$key"');
        expect((map[key] as String).trim(), isNotEmpty,
            reason: '$code.json has an empty "$key"');
      }
    }
  });

  test('the default locale is one the kiosk actually offers', () {
    expect(
      AppConstants.languages.map((l) => l.languageCode),
      contains(AppConstants.defaultLanguageCode),
    );
    final fallback = AppConstants.languages.firstWhere(
      (l) => l.languageCode == AppConstants.defaultLanguageCode,
    );
    expect(fallback.countryCode, AppConstants.defaultCountryCode);
  });
}
