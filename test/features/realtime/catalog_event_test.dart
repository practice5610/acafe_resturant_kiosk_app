import 'package:acafe_customer/features/realtime/catalog_event.dart';
import 'package:acafe_customer/features/realtime/catalog_realtime_policy.dart';
import 'package:acafe_customer/features/realtime/catalog_socket_frame.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogEvent _event({
  String action = 'updated',
  int productId = 42,
  int revision = 2,
  String eventId = 'e1',
}) {
  return CatalogEvent(
    version: 1,
    eventId: eventId,
    action: action,
    productId: productId,
    branchId: 1,
    revision: revision,
  );
}

void main() {
  group('CatalogEvent', () {
    test('fromJson reads the v1 envelope', () {
      final event = CatalogEvent.fromJson({
        'v': 1,
        'event_id': 'abc',
        'action': 'updated',
        'product_id': 42,
        'branch_id': 1,
        'revision': 7,
        'occurred_at': '2026-08-17T14:52:01Z',
      });

      expect(event.eventId, 'abc');
      expect(event.action, 'updated');
      expect(event.productId, 42);
      expect(event.branchId, 1);
      expect(event.revision, 7);
      expect(event.isDelete, isFalse);
      expect(event.isRefresh, isFalse);
    });

    test('deleted and refresh flags', () {
      expect(_event(action: 'deleted').isDelete, isTrue);
      expect(_event(action: 'refresh').isRefresh, isTrue);
      expect(_event(action: 'availability').isAvailability, isTrue);
    });
  });

  group('CatalogRealtimePolicy.decide', () {
    test('ignores duplicate event ids', () {
      expect(
        CatalogRealtimePolicy.decide(
          event: _event(),
          menuRevision: 1,
          duplicateEventId: true,
        ),
        CatalogClientAction.ignore,
      );
    });

    test('reloads when the revision skips ahead', () {
      expect(
        CatalogRealtimePolicy.decide(
          event: _event(revision: 5),
          menuRevision: 2,
          duplicateEventId: false,
        ),
        CatalogClientAction.reload,
      );
    });

    test('reloads refresh events even with a sequential revision', () {
      expect(
        CatalogRealtimePolicy.decide(
          event: _event(action: 'refresh', productId: 0, revision: 3),
          menuRevision: 2,
          duplicateEventId: false,
        ),
        CatalogClientAction.reload,
      );
    });

    test('removes deleted products and empty product ids', () {
      expect(
        CatalogRealtimePolicy.decide(
          event: _event(action: 'deleted'),
          menuRevision: 1,
          duplicateEventId: false,
        ),
        CatalogClientAction.remove,
      );
      expect(
        CatalogRealtimePolicy.decide(
          event: _event(productId: 0),
          menuRevision: 1,
          duplicateEventId: false,
        ),
        CatalogClientAction.remove,
      );
    });

    test('fetches created, updated, and availability events', () {
      expect(
        CatalogRealtimePolicy.decide(
          event: _event(action: 'created', revision: 2),
          menuRevision: 1,
          duplicateEventId: false,
        ),
        CatalogClientAction.fetch,
      );
      expect(
        CatalogRealtimePolicy.decide(
          event: _event(action: 'availability', revision: 2),
          menuRevision: 1,
          duplicateEventId: false,
        ),
        CatalogClientAction.fetch,
      );
    });
  });

  group('CatalogRealtimePolicy fetch / sync', () {
    test('404 and Dio not-found remove the product', () {
      expect(
        CatalogRealtimePolicy.treatFetchedProductAsRemoved(
          event: _event(),
          statusCode: 404,
          notFound: false,
          productStatus: 1,
          isAvailable: true,
        ),
        isTrue,
      );
      expect(
        CatalogRealtimePolicy.treatFetchedProductAsRemoved(
          event: _event(),
          statusCode: null,
          notFound: true,
          productStatus: 1,
          isAvailable: true,
        ),
        isTrue,
      );
    });

    test('server errors do not remove the product', () {
      expect(
        CatalogRealtimePolicy.treatFetchedProductAsRemoved(
          event: _event(),
          statusCode: 500,
          notFound: false,
          productStatus: 1,
          isAvailable: true,
        ),
        isFalse,
      );
    });

    test('unavailable availability events remove after a successful fetch', () {
      expect(
        CatalogRealtimePolicy.treatFetchedProductAsRemoved(
          event: _event(action: 'availability'),
          statusCode: 200,
          notFound: false,
          productStatus: 1,
          isAvailable: false,
        ),
        isTrue,
      );
      expect(
        CatalogRealtimePolicy.treatFetchedProductAsRemoved(
          event: _event(action: 'updated'),
          statusCode: 200,
          notFound: false,
          productStatus: 1,
          isAvailable: true,
        ),
        isFalse,
      );
    });

    test('sync reload flag and revision cursor', () {
      expect(
        CatalogRealtimePolicy.syncNeedsReload(
          statusCode: 200,
          data: {'revision': 4, 'full_reload': true},
        ),
        isTrue,
      );
      expect(
        CatalogRealtimePolicy.syncNeedsReload(
          statusCode: 200,
          data: {'revision': 4, 'full_reload': false},
        ),
        isFalse,
      );
      expect(
        CatalogRealtimePolicy.syncNeedsReload(statusCode: 500, data: null),
        isTrue,
      );
      expect(
        CatalogRealtimePolicy.syncRevision({'revision': '9'}),
        9,
      );
    });
  });

  group('CatalogSocketFrame', () {
    test('parses nested product.changed JSON from Reverb', () {
      const frame =
          '{"event":"product.changed","channel":"branch.1.products","data":"{\\"v\\":1,\\"event_id\\":\\"abc\\",\\"action\\":\\"updated\\",\\"product_id\\":42,\\"branch_id\\":1,\\"revision\\":7}"}';
      final event = CatalogSocketFrame.productChanged(frame);
      expect(event, isNotNull);
      expect(event!.productId, 42);
      expect(event.action, 'updated');
      expect(event.revision, 7);
    });

    test('parses Echo-style .product.changed frames', () {
      const frame =
          '{"event":".product.changed","channel":"branch.1.products","data":"{\\"v\\":1,\\"event_id\\":\\"abc\\",\\"action\\":\\"updated\\",\\"product_id\\":42,\\"branch_id\\":1,\\"revision\\":7}"}';
      final event = CatalogSocketFrame.productChanged(frame);
      expect(event, isNotNull);
      expect(event!.productId, 42);
    });

    test('parses nested deal.changed JSON from Reverb', () {
      const frame =
          '{"event":"deal.changed","channel":"branch.1.products","data":"{\\"v\\":1,\\"event_id\\":\\"d1\\",\\"action\\":\\"updated\\",\\"deal_id\\":9,\\"branch_id\\":1}"}';
      final event = CatalogSocketFrame.dealChanged(frame);
      expect(event, isNotNull);
      expect(event!.dealId, 9);
      expect(event.action, 'updated');
      expect(event.isDeal, isTrue);
      expect(CatalogSocketFrame.productChanged(frame), isNull);
    });

    test('parses device.ordering_experience.changed frames', () {
      const frame =
          '{"event":"device.ordering_experience.changed","channel":"branch.1.products","data":"{\\"v\\":1,\\"event_id\\":\\"ox1\\",\\"device_id\\":1,\\"branch_id\\":1,\\"ordering_experience\\":\\"version_b\\"}"}';
      final event =
          CatalogSocketFrame.deviceOrderingExperienceChanged(frame);
      expect(event, isNotNull);
      expect(event!.deviceId, 1);
      expect(event.orderingExperience, 'version_b');
      expect(CatalogSocketFrame.productChanged(frame), isNull);
      expect(CatalogSocketFrame.dealChanged(frame), isNull);
    });

    test('parses Echo-style .device.ordering_experience.changed frames', () {
      const frame =
          '{"event":".device.ordering_experience.changed","channel":"branch.1.products","data":"{\\"v\\":1,\\"event_id\\":\\"ox2\\",\\"device_id\\":4,\\"branch_id\\":2,\\"ordering_experience\\":\\"version_a\\"}"}';
      final event =
          CatalogSocketFrame.deviceOrderingExperienceChanged(frame);
      expect(event, isNotNull);
      expect(event!.deviceId, 4);
      expect(event.orderingExperience, 'version_a');
    });

    test('ignores protocol frames', () {
      expect(
        CatalogSocketFrame.productChanged(
          '{"event":"pusher:pong","data":{}}',
        ),
        isNull,
      );
      expect(
        CatalogSocketFrame.isProtocolPing('{"event":"pusher:ping","data":{}}'),
        isTrue,
      );
      expect(
        CatalogSocketFrame.isConnectionEstablished(
          '{"event":"pusher:connection_established","data":"{\\"socket_id\\":\\"1.1\\",\\"activity_timeout\\":60}"}',
        ),
        isTrue,
      );
      expect(
        CatalogSocketFrame.activityTimeoutSeconds(
          '{"socket_id":"1.1","activity_timeout":60}',
        ),
        60,
      );
    });
  });
}
