import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:acafe_customer/data/datasource/remote/dio/dio_client.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_experiment_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_ordering_experience.dart';
import 'package:acafe_customer/utill/app_constants.dart';

/// The events the customization flow emits, for the back office A/B report.
///
/// Names are the wire contract — the Laravel side stores them verbatim and the
/// report groups on them — so renaming one here orphans existing rows.
class KioskCustomizeEvent {
  static const String customizationStarted = 'customization_started';

  /// Version B only: the customer arrived at a step.
  static const String stepViewed = 'step_viewed';

  /// Version B only: the customer left a step forwards, having answered it.
  static const String stepCompleted = 'step_completed';

  static const String addOnSelected = 'addon_selected';
  static const String addOnDeselected = 'addon_deselected';
  static const String cupOrCanSelected = 'cup_or_can_selected';
  static const String addToCartClicked = 'add_to_cart_clicked';

  /// The screen/step was left without an add-to-cart.
  static const String customizationAbandoned = 'customization_abandoned';

  const KioskCustomizeEvent._();
}

/// Emits customization telemetry for the A/B report.
///
/// Every event carries `variant`, which is the ordering experience an ADMIN
/// chose for this device (Device Update -> Ordering Experience) — not a
/// client-side coin flip — so the report always compares what was actually on
/// screen. Nothing here can affect the order: events are queued, flushed on a
/// timer, and every failure path is swallowed.
class KioskCustomizeAnalytics {
  KioskCustomizeAnalytics._();
  static final KioskCustomizeAnalytics instance = KioskCustomizeAnalytics._();

  /// Batched so a burst of add-on taps costs one request, not ten.
  static const Duration _flushInterval = Duration(seconds: 5);

  /// Hard ceiling on the buffer. A kiosk that has lost its network must not
  /// grow this list until the tab dies; oldest events are dropped first.
  static const int _maxBuffered = 200;

  DioClient? _dioClient;
  final List<Map<String, dynamic>> _pending = [];
  Timer? _flushTimer;
  bool _sending = false;

  void init(DioClient dioClient) {
    _dioClient = dioClient;
  }

  /// Record one event. Safe to call from a build method or a tap handler:
  /// it never throws, never awaits, and never touches the cart.
  void track(
    String event, {
    required KioskOrderingExperience experience,
    int? productId,
    int? branchId,
    int? deviceId,
    String? guestId,
    int? userId,
    String? step,
    int? addOnId,
    String? value,
  }) {
    try {
      _pending.add({
        'event': event,
        // 'A' | 'B' — the admin-selected experience for THIS device.
        'variant': experience.variantTag,
        'ordering_experience': experience.apiValue,
        'experiment_session_id': KioskExperimentSession.instance.id,
        if (productId != null) 'product_id': productId,
        if (branchId != null) 'branch_id': branchId,
        if (deviceId != null) 'device_id': deviceId,
        // Attached for the conversion join only — never used to pick a variant.
        if (guestId != null && guestId.isNotEmpty) 'guest_id': guestId,
        if (userId != null) 'user_id': userId,
        if (step != null) 'step': step,
        if (addOnId != null) 'addon_id': addOnId,
        if (value != null) 'value': value,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (_pending.length > _maxBuffered) {
        _pending.removeRange(0, _pending.length - _maxBuffered);
      }
      _scheduleFlush();
    } catch (e) {
      // Telemetry must never break ordering.
      debugPrint('KioskCustomizeAnalytics.track failed: $e');
    }
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(_flushInterval, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }

  /// Push whatever is buffered. Called on the timer and when the customer
  /// leaves the flow, so the last event of a session is not stranded.
  Future<void> flush() async {
    final DioClient? client = _dioClient;
    if (client == null || _sending || _pending.isEmpty) return;

    _sending = true;
    final List<Map<String, dynamic>> batch =
        List<Map<String, dynamic>>.from(_pending);
    _pending.clear();

    try {
      await client.post(
        AppConstants.kioskCustomizeEventsUri,
        data: {'events': batch},
      );
    } catch (e) {
      // Put them back (oldest-first) so a blip retries on the next flush,
      // still bounded by _maxBuffered.
      _pending.insertAll(0, batch);
      if (_pending.length > _maxBuffered) {
        _pending.removeRange(0, _pending.length - _maxBuffered);
      }
      debugPrint('KioskCustomizeAnalytics.flush failed: $e');
    } finally {
      _sending = false;
    }
  }
}
