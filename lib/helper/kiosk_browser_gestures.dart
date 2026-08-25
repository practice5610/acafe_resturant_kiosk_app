import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

/// Stops Chrome/Safari on macOS from treating a two-finger trackpad swipe as
/// browser Back / Forward.
///
/// The kiosk is a single-page Flutter web app. A horizontal swipe would
/// otherwise fire `history.back()` and jump to the previous route (menu →
/// login, customize → menu, etc.). In-app Back buttons still work — they
/// go through [GoRouter], not the browser gesture.
///
/// Wheel listeners MUST be `{passive: false}` or Chrome ignores
/// `preventDefault`. Dart's `addEventListener` cannot set that flag, so this
/// injects a small JS listener. Safe to call more than once.
void disableKioskBrowserHistorySwipe() {
  if (!kIsWeb) return;

  _applyOverscrollNone();
  _installWheelGuard();
}

const String _kGuardScriptId = 'kiosk-swipe-nav-guard';

void _applyOverscrollNone() {
  const String none = 'none';
  for (final String selector in [
    'html',
    'body',
    'flt-glass-pane',
    'flt-scene-host',
    'flutter-view',
    'canvas',
  ]) {
    html.document.querySelectorAll(selector).forEach((html.Element el) {
      el.style.setProperty('overscroll-behavior', none);
      el.style.setProperty('overscroll-behavior-x', none);
    });
  }
  html.document.documentElement?.style.setProperty('overflow', 'hidden');
  html.document.body?.style.setProperty('overflow', 'hidden');
}

void _installWheelGuard() {
  if (html.document.getElementById(_kGuardScriptId) != null) return;

  final html.ScriptElement script = html.ScriptElement()
    ..id = _kGuardScriptId
    ..text = r'''
(function () {
  if (window.__kioskSwipeNavGuard) return;
  window.__kioskSwipeNavGuard = true;

  function blockHistorySwipe(e) {
    if (Math.abs(e.deltaX) > Math.abs(e.deltaY)) {
      e.preventDefault();
    }
  }

  var opts = { passive: false, capture: true };
  window.addEventListener('wheel', blockHistorySwipe, opts);
  window.addEventListener('mousewheel', blockHistorySwipe, opts);
})();
''';

  (html.document.head ?? html.document.body)?.append(script);
}
