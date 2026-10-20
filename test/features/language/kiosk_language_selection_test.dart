import 'dart:convert';

import 'package:acafe_customer/common/models/language_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_language_offering.dart';
import 'package:acafe_customer/utill/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which language the welcome screen shows as chosen, given what Settings →
/// Hardware offers and what the kiosk is currently in. English is the default
/// whenever the current language is not on offer.
void main() {
  Future<List<LanguageModel>> offering(List<String>? codes) async {
    SharedPreferences.setMockInitialValues({
      if (codes != null)
        AppConstants.posHardwareSettingsKey:
            jsonEncode({'kiosk_languages': codes}),
    });
    return KioskLanguageOffering.forDevice(
        await SharedPreferences.getInstance());
  }

  const cases = <({String name, List<String>? offered, String current, String want})>[
    (name: 'fresh kiosk', offered: null, current: 'en', want: 'en'),
    (name: 'a guest chose French', offered: null, current: 'fr', want: 'fr'),
    (name: 'current language was removed', offered: ['nl', 'en', 'fr'], current: 'de', want: 'en'),
    (name: 'English is not offered', offered: ['nl', 'fr'], current: 'en', want: 'nl'),
    (name: 'neither current nor English offered', offered: ['fr', 'de'], current: 'nl', want: 'fr'),
    (name: 'unknown saved code', offered: null, current: 'xx', want: 'en'),
  ];

  for (final c in cases) {
    test('${c.name}: ${c.current} -> ${c.want}', () async {
      final List<LanguageModel> offered = await offering(c.offered);

      expect(
        KioskLanguageOffering.selectionFor(offered, c.current).languageCode,
        c.want,
      );
    });
  }
}
