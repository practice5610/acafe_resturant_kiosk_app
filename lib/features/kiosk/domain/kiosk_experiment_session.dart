import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Identity for one customer's pass through the ordering flow, used to stitch
/// analytics events together (sessions, drop-offs, add-to-cart rate).
///
/// Deliberately NOT an assignment key: which ordering experience a kiosk runs
/// is chosen by admin per device (Device Update -> Ordering Experience) and read
/// from [KioskAuthProvider.orderingExperience]. This id only answers "which
/// visit was that?", so a `step_viewed` and the `add_to_cart_clicked` that
/// follows it can be recognised as the same customer.
///
/// It is independent of `guest_id` — which goes null the moment a customer or
/// staff member authenticates — so a login part-way through a session cannot
/// silently split one visit into two.
class KioskExperimentSession {
  KioskExperimentSession._();
  static final KioskExperimentSession instance = KioskExperimentSession._();

  static const String _storageKey = 'kiosk_experiment_session_id';

  static final Random _random = Random.secure();

  SharedPreferences? _prefs;
  String? _id;

  /// Wire up storage once at boot. Restores an id left by a previous run so a
  /// browser refresh mid-order does not look like a brand new session.
  void init(SharedPreferences prefs) {
    _prefs = prefs;
    _id = prefs.getString(_storageKey);
  }

  /// The current session id, minting one on first use.
  String get id {
    final String? existing = _id;
    if (existing != null && existing.isNotEmpty) return existing;
    return _start();
  }

  /// Begin a new session — call when a customer starts a fresh order, so one
  /// visit's events never merge into the next customer's.
  String start() => _start();

  String _start() {
    final String next = _uuidV4();
    _id = next;
    // Fire-and-forget: an unwritten id still works for this run, and telemetry
    // must never block or break the ordering flow.
    _prefs?.setString(_storageKey, next);
    return next;
  }

  /// Drop the current session (order placed / kiosk reset).
  void reset() {
    _id = null;
    _prefs?.remove(_storageKey);
  }

  /// RFC 4122 version 4 UUID. Hand-rolled rather than adding a dependency —
  /// `uuid` is only present transitively and is not a declared dependency of
  /// this app.
  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).toList();
    return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
        '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
        '${hex.sublist(10, 16).join()}';
  }
}
