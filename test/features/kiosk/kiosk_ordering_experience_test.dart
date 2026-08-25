import 'package:flutter_test/flutter_test.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_ordering_experience.dart';

void main() {
  group('KioskOrderingExperience.fromApi', () {
    test('maps the two wire values the backend can send', () {
      expect(KioskOrderingExperience.fromApi('version_a'),
          KioskOrderingExperience.versionA);
      expect(KioskOrderingExperience.fromApi('version_b'),
          KioskOrderingExperience.versionB);
    });

    test('falls back to Version A for anything unrecognised', () {
      // A device whose session predates the setting, a null column, a value
      // written by a newer backend than this build knows about, or junk. None
      // of these may leave the kiosk without a flow to render.
      for (final input in <String?>[
        null,
        '',
        'version_c',
        'VERSION_A',
        ' version_a ',
      ]) {
        expect(
          KioskOrderingExperience.fromApi(input),
          KioskOrderingExperience.versionA,
          reason: 'input: ${input ?? "null"}',
        );
      }
    });

    test('wire values match the Laravel Device::ORDERING_EXPERIENCES list', () {
      expect(
        KioskOrderingExperience.values.map((e) => e.apiValue).toList(),
        ['version_a', 'version_b'],
      );
    });

    test('variantTag is what analytics groups on', () {
      expect(KioskOrderingExperience.versionA.variantTag, 'A');
      expect(KioskOrderingExperience.versionB.variantTag, 'B');
    });

    test('isVersionA / isVersionB are mutually exclusive', () {
      expect(KioskOrderingExperience.versionA.isVersionA, isTrue);
      expect(KioskOrderingExperience.versionA.isVersionB, isFalse);
      expect(KioskOrderingExperience.versionB.isVersionB, isTrue);
      expect(KioskOrderingExperience.versionB.isVersionA, isFalse);
    });
  });
}
