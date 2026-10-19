import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One snapshot as it came back off disk.
class PosLiveSnapshot {
  final Map<String, dynamic> data;
  final DateTime savedAt;

  const PosLiveSnapshot({required this.data, required this.savedAt});
}

/// The last good answer of a POS live screen (the Orders board, Receipts),
/// kept on disk so the screen can paint it on its very first frame — after a
/// tab switch, a reload, or a terminal waking up — while the network refresh
/// runs behind it.
///
/// SharedPreferences, not Drift: it is `localStorage` on the web build the POS
/// ships as (Drift has no web worker set up in this app), and it is the same
/// store the kiosk menu cache already uses.
///
/// A snapshot is only ever a head start. The provider that wrote it re-pulls
/// on open and on every socket push, so what this guards against is painting
/// the WRONG data, never stale-by-seconds data:
///
///  * **scope** — every snapshot carries the branch + device it was written
///    under, and a read for any other scope misses. One slot per screen, not one
///    key per branch, so a terminal moved between branches leaves no trail.
///  * **age** — [read] takes a max age, and receipts additionally refuse a
///    snapshot from before midnight ("Today" would otherwise open on
///    yesterday's sales until the refresh lands).
///  * **format** — a blob that does not parse, or carries another
///    [formatVersion], reads as no snapshot rather than as a crash.
///
/// Writes never throw: a full storage quota (web) costs the head start, not
/// the screen.
class PosLiveCache {
  PosLiveCache(this._prefs, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  static const String keyPrefix = 'pos_live_cache.';

  /// Bump when the shape of `data` written by a provider changes, so an old
  /// blob is dropped instead of half-parsed.
  static const int formatVersion = 1;

  /// The last encoded payload written per slot, so an unchanged refresh — the
  /// common case for a socket ping about an order already on screen — costs
  /// a string compare instead of a storage write.
  final Map<String, String> _lastWritten = <String, String>{};

  /// The cache scope for a device session, or null while no branch is bound
  /// (nothing is cached for a signed-out terminal).
  static String? scopeFor({required int? branchId, required int? deviceId}) {
    if (branchId == null || branchId <= 0) return null;
    return 'b$branchId.d${deviceId ?? 0}';
  }

  PosLiveSnapshot? read(
    String slot, {
    required String scope,
    required Duration maxAge,
    bool sameDayOnly = false,
  }) {
    final String? raw = _prefs.getString('$keyPrefix$slot');
    if (raw == null) return null;

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final Map<String, dynamic> blob = Map<String, dynamic>.from(decoded);

      if (blob['v'] != formatVersion || blob['scope'] != scope) return null;

      final int? savedAtMs = blob['savedAt'] as int?;
      final Object? data = blob['data'];
      if (savedAtMs == null || data is! Map) return null;

      final DateTime savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
      final DateTime now = _clock();
      if (now.difference(savedAt) > maxAge) return null;
      if (sameDayOnly && !_sameDay(savedAt, now)) return null;

      return PosLiveSnapshot(
        data: Map<String, dynamic>.from(data),
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String slot, {
    required String scope,
    required Map<String, dynamic> data,
  }) async {
    try {
      final String payload = jsonEncode(data);
      final String fingerprint = '$scope|$payload';
      if (_lastWritten[slot] == fingerprint) return;

      await _prefs.setString(
        '$keyPrefix$slot',
        jsonEncode(<String, dynamic>{
          'v': formatVersion,
          'scope': scope,
          'savedAt': _clock().millisecondsSinceEpoch,
          'data': data,
        }),
      );
      _lastWritten[slot] = fingerprint;
    } catch (e) {
      // Quota, or a value jsonEncode cannot take. The screen keeps working
      // from memory; only the next cold start loses its head start.
      if (kDebugMode) debugPrint('PosLiveCache write $slot failed: $e');
    }
  }

  /// Every snapshot, for a device sign-out or a branch rebind. Static so the
  /// session code can call it without holding a cache instance.
  static Future<void> clearAll(SharedPreferences prefs) async {
    final List<String> keys = prefs
        .getKeys()
        .where((key) => key.startsWith(keyPrefix))
        .toList(growable: false);
    for (final String key in keys) {
      await prefs.remove(key);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
