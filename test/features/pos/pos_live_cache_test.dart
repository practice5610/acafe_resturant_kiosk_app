import 'dart:convert';

import 'package:acafe_customer/features/pos/domain/pos_live_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The cache is what makes Orders and Receipts paint on their first frame after
/// a reload. What it must never do is paint the WRONG thing: another branch's
/// orders, yesterday's receipts, or a half-written blob.

/// Counts writes and can be told to fail them, the way a full localStorage
/// quota does on web.
class _Prefs implements SharedPreferences {
  _Prefs(this._inner);

  final SharedPreferences _inner;
  int setStringCalls = 0;
  bool failWrites = false;

  @override
  Future<bool> setString(String key, String value) async {
    setStringCalls++;
    if (failWrites) throw Exception('QuotaExceededError');
    return _inner.setString(key, value);
  }

  @override
  String? getString(String key) => _inner.getString(key);

  @override
  Set<String> getKeys() => _inner.getKeys();

  @override
  Future<bool> remove(String key) => _inner.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late SharedPreferences raw;
  late _Prefs prefs;
  late DateTime now;
  late PosLiveCache cache;

  const String scope = 'b1.d7';
  const Map<String, dynamic> board = {
    'orders': [
      {'id': 100014, 'order_status': 'new'},
    ],
    'counts': {'new': 1},
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    raw = await SharedPreferences.getInstance();
    prefs = _Prefs(raw);
    now = DateTime(2026, 10, 19, 12, 0);
    cache = PosLiveCache(prefs, clock: () => now);
  });

  test('a snapshot reads back for the scope it was written under', () async {
    await cache.write('orders', scope: scope, data: board);

    final PosLiveSnapshot? snapshot =
        cache.read('orders', scope: scope, maxAge: const Duration(hours: 12));

    expect(snapshot, isNotNull);
    expect(snapshot!.data, board);
    expect(snapshot.savedAt, now);
  });

  test("another branch or device never sees this one's snapshot", () async {
    await cache.write('orders', scope: scope, data: board);

    expect(
      cache.read('orders', scope: 'b2.d7', maxAge: const Duration(hours: 12)),
      isNull,
    );
    expect(
      cache.read('orders', scope: 'b1.d8', maxAge: const Duration(hours: 12)),
      isNull,
    );
  });

  test('a snapshot older than maxAge is not served', () async {
    await cache.write('orders', scope: scope, data: board);
    now = now.add(const Duration(hours: 12, minutes: 1));

    expect(
      cache.read('orders', scope: scope, maxAge: const Duration(hours: 12)),
      isNull,
    );
  });

  test('sameDayOnly drops a snapshot from before midnight', () async {
    now = DateTime(2026, 10, 18, 23, 59);
    await cache.write('receipts', scope: scope, data: board);
    now = DateTime(2026, 10, 19, 0, 1);

    expect(
      cache.read('receipts',
          scope: scope, maxAge: const Duration(hours: 12), sameDayOnly: true),
      isNull,
    );
    // Same blob, no day rule: still within maxAge, so it is served.
    expect(
      cache.read('receipts', scope: scope, maxAge: const Duration(hours: 12)),
      isNotNull,
    );
  });

  test('a corrupt or foreign-format blob reads as no snapshot', () async {
    await raw.setString('${PosLiveCache.keyPrefix}orders', '{not json');
    expect(
      cache.read('orders', scope: scope, maxAge: const Duration(hours: 12)),
      isNull,
    );

    await raw.setString(
      '${PosLiveCache.keyPrefix}orders',
      jsonEncode({
        'v': PosLiveCache.formatVersion + 1,
        'scope': scope,
        'savedAt': now.millisecondsSinceEpoch,
        'data': board,
      }),
    );
    expect(
      cache.read('orders', scope: scope, maxAge: const Duration(hours: 12)),
      isNull,
    );
  });

  test('a failed write (storage quota) is swallowed', () async {
    prefs.failWrites = true;

    await expectLater(
      cache.write('orders', scope: scope, data: board),
      completes,
    );
    expect(
      cache.read('orders', scope: scope, maxAge: const Duration(hours: 12)),
      isNull,
    );
  });

  test('an unchanged payload is not written again', () async {
    await cache.write('orders', scope: scope, data: board);
    now = now.add(const Duration(seconds: 5));
    await cache.write('orders', scope: scope, data: board);

    expect(prefs.setStringCalls, 1);
  });

  test('clearAll removes every snapshot and nothing else', () async {
    await raw.setString('token', 'device-token');
    await cache.write('orders', scope: scope, data: board);
    await cache.write('receipts', scope: scope, data: board);

    await PosLiveCache.clearAll(prefs);

    expect(raw.getString('token'), 'device-token');
    expect(
      raw.getKeys().where((k) => k.startsWith(PosLiveCache.keyPrefix)),
      isEmpty,
    );
  });

  test('scopeFor needs a bound branch', () {
    expect(PosLiveCache.scopeFor(branchId: null, deviceId: 7), isNull);
    expect(PosLiveCache.scopeFor(branchId: 0, deviceId: 7), isNull);
    expect(PosLiveCache.scopeFor(branchId: 1, deviceId: 7), 'b1.d7');
    expect(PosLiveCache.scopeFor(branchId: 1, deviceId: null), 'b1.d0');
  });
}
