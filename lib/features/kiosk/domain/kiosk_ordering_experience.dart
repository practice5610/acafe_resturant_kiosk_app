/// Which item-customization flow this kiosk renders.
///
/// Set per device in the back office (Device Update → Ordering Experience) and
/// delivered to the kiosk on `device/login` and `device/me` as
/// `device.ordering_experience`. The wire values mirror
/// `App\Model\Device::ORDERING_EXPERIENCES` on the Laravel side — keep the two
/// lists in step.
enum KioskOrderingExperience {
  /// Everything on one scrollable screen. The original kiosk behaviour, and the
  /// fallback for any device that has not been told otherwise.
  versionA('version_a'),

  /// Milks → Add-ons → Cup or Can, behind a segmented progress bar.
  versionB('version_b');

  const KioskOrderingExperience(this.apiValue);

  /// The value stored in `devices.ordering_experience` and sent over the API.
  final String apiValue;

  /// What a device runs when the server has not said otherwise — a session
  /// persisted before the column existed, a null, or a value this build of the
  /// app does not recognise. Never leaves the kiosk without a flow to render.
  static const KioskOrderingExperience fallback = KioskOrderingExperience.versionA;

  /// Parse an API/`SharedPreferences` value, falling back to [fallback].
  static KioskOrderingExperience fromApi(String? value) {
    for (final experience in KioskOrderingExperience.values) {
      if (experience.apiValue == value) return experience;
    }
    return fallback;
  }

  bool get isVersionA => this == KioskOrderingExperience.versionA;
  bool get isVersionB => this == KioskOrderingExperience.versionB;

  /// Short label used as the `variant` tag on analytics events.
  String get variantTag => isVersionB ? 'B' : 'A';
}
