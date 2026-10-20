/// Which terminal a device-login page is serving, read from the address the
/// app was opened at.
///
/// One web build is served on both `kiosk.acafepos.com` and
/// `pos.acafepos.com`, so the host's first label is the only thing that tells
/// the login page which device it is binding. Anything else (localhost, an IP,
/// a native build) is [device]: the login page cannot know yet, and the
/// device's category from the backend decides after sign-in.
///
/// This is copy only. Whether the app opens as kiosk or POS stays decided by
/// the device category, never by the host.
enum KioskLoginSurface {
  kiosk,
  pos,
  device;

  /// `pos.*` and `pos-*.*` are POS; `kiosk.*` and `kiosk-*.*` are kiosk.
  static KioskLoginSurface fromUri(Uri uri) {
    final String label = uri.host.toLowerCase().split('.').first;
    if (label == 'pos' || label.startsWith('pos-')) return pos;
    if (label == 'kiosk' || label.startsWith('kiosk-')) return kiosk;
    return device;
  }

  /// The address this app was opened at.
  static KioskLoginSurface get current => fromUri(Uri.base);

  /// The login card's subtitle.
  String get hint => switch (this) {
        kiosk => 'Sign in once to bind this kiosk to its branch.',
        pos => 'Sign in once to bind this POS to its branch.',
        device => 'Sign in once to bind this device to its branch.',
      };
}
