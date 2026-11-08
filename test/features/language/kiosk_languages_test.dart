import 'dart:convert';
import 'dart:io';

import 'package:acafe_customer/utill/app_constants.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter_test/flutter_test.dart';

/// The kiosk ships exactly eight locales. These guard the pairing between
/// [AppConstants.languages], the bundled `assets/language/*.json` files and the
/// flag artwork — the three things that must be added (or removed) together.
void main() {
  const List<String> expected = ['nl', 'en', 'de', 'fr', 'it', 'ja', 'zh', 'es'];

  test('offers exactly the eight kiosk languages, in picker order', () {
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
      expect(language.imageUrl, Images.roundFlagFor(language.languageCode),
          reason: '${language.languageCode} must use the round flag set');
      final String? round = Images.roundFlagFor(language.languageCode);
      expect(round, isNotNull,
          reason: '${language.languageCode} has no round welcome flag');
      expect(File(round!).existsSync(), isTrue,
          reason: 'missing round flag asset $round');
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

  test('the welcome prompt is translated into every kiosk language', () {
    Map<String, dynamic> read(String code) => json.decode(
        File('assets/language/$code.json').readAsStringSync());

    final String english = read('en')['touch_to_order'] as String;
    expect(english.trim(), isNotEmpty);

    for (final code in expected.where((c) => c != 'en')) {
      final Object? value = read(code)['touch_to_order'];
      expect(value, isA<String>(), reason: '$code.json lacks "touch_to_order"');
      expect((value as String).trim(), isNotEmpty);
      expect(value, isNot(english),
          reason: '$code.json still carries the English prompt');
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

  test('no kiosk screen draws the old ringed flags', () {
    final RegExp old = RegExp(
        r'Images\.(netherlands|unitedKingdom|germany|france|spain)\b|'
        r'(netherlands|united_kindom|germany|france|spain)\.png');
    for (final dir in ['lib/features/kiosk', 'lib/features/language']) {
      for (final f in Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        expect(old.hasMatch(f.readAsStringSync()), isFalse,
            reason: '${f.path} references an old flag PNG');
      }
    }
  });

  group('translations', () {
    Map<String, String> read(String code) =>
        (json.decode(File('assets/language/$code.json').readAsStringSync())
                as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString()));

    final english = read('en');
    List<String> placeholders(String v) => RegExp(r'\{[^}]*\}|%[sd]')
        .allMatches(v)
        .map((m) => m.group(0)!)
        .toList()
      ..sort();

    /// Keys the kiosk and POS screens look up (`getTranslated` /
    /// `kioskTranslate` / `translate` with a literal key).
    Set<String> screenKeys(String dir) {
      final RegExp call = RegExp(
          r"""(?:getTranslated|kioskTranslate|translate)\(\s*(?:[\w.]+\s*,\s*)?['"]([^'"]+)['"]""");
      final Set<String> keys = {};
      for (final f in Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        for (final m in call.allMatches(f.readAsStringSync())) {
          if (english.containsKey(m.group(1))) keys.add(m.group(1)!);
        }
      }
      return keys;
    }

    final kioskKeys = screenKeys('lib/features/kiosk');
    final posKeys = screenKeys('lib/features/pos');

    test('every language has every key of en.json, none empty', () {
      for (final code in expected) {
        final other = read(code);
        expect(other.keys.toSet(), english.keys.toSet(),
            reason: '$code.json key set differs from en.json');
        for (final e in other.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$code "${e.key}" is empty');
        }
      }
    });

    test('every placeholder matches en.json', () {
      for (final code in expected) {
        final other = read(code);
        for (final k in english.keys) {
          expect(placeholders(other[k]!), placeholders(english[k]!),
              reason: '$code "$k" changed a placeholder');
        }
      }
    });

    test('every key a kiosk or POS screen renders exists in all 8 files', () {
      expect(kioskKeys, isNotEmpty);
      for (final code in expected) {
        final other = read(code);
        for (final k in {...kioskKeys, ...posKeys}) {
          expect(other[k], isNotNull, reason: '$code is missing "$k"');
        }
      }
    });

    test('rendered kiosk keys are translated, not English, in every language',
        () {
      // Words that are legitimately the same in a language (loanwords, "OK").
      const Set<String> sameWord = {'ok', 'email', 'password', 'coupon', 'stop',
          'subtotal', 'total', 'name', 'description', 'message', 'variation',
          'offline', 'on', 'off', 'v', 'continue', 'popular', 'tip', 'cart'};
      for (final code in expected.where((c) => c != 'en')) {
        final other = read(code);
        final stillEnglish = kioskKeys
            .where((k) => other[k] == english[k] && !sameWord.contains(k))
            .toList();
        expect(stillEnglish, isEmpty,
            reason: '$code still has English for: $stillEnglish');
      }
    });

    test('Japanese and Chinese ship their own script', () {
      final cjk = RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]');
      for (final code in ['ja', 'zh']) {
        final other = read(code);
        for (final k in kioskKeys.where((k) => english[k]!.length > 6)) {
          expect(cjk.hasMatch(other[k]!), isTrue,
              reason: '$code "$k" has no Japanese/Chinese text: ${other[k]}');
        }
      }
    });
  });
}
