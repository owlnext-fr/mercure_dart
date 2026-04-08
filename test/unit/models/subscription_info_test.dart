import 'package:mercure_dart/src/models/subscription_info.dart';
import 'package:test/test.dart';

void main() {
  group('SubscriptionInfo', () {
    test('fromJson parses a subscription', () {
      final json = {
        'id': '/.well-known/mercure/subscriptions/topic/sub1',
        'type': 'Subscription',
        'topic': 'https://example.com/{selector}',
        'subscriber': 'urn:uuid:bb3de268-05b0-4c65-b44e-8f9acefc29d6',
        'active': true,
        'payload': {'foo': 'bar'},
      };
      final sub = SubscriptionInfo.fromJson(json);
      expect(sub.id, json['id']);
      expect(sub.type, 'Subscription');
      expect(sub.topic, json['topic']);
      expect(sub.subscriber, json['subscriber']);
      expect(sub.active, isTrue);
      expect(sub.payload, {'foo': 'bar'});
      expect(sub.lastEventId, isNull);
    });

    test('fromJson parses optional lastEventID', () {
      final json = {
        'id': '/sub/1',
        'type': 'Subscription',
        'topic': 'https://example.com/a',
        'subscriber': 'urn:uuid:123',
        'active': false,
        'lastEventID': 'urn:uuid:5e94c686',
      };
      final sub = SubscriptionInfo.fromJson(json);
      expect(sub.active, isFalse);
      expect(sub.lastEventId, 'urn:uuid:5e94c686');
      expect(sub.payload, isNull);
    });

    test('equality is based on identity fields', () {
      const a = SubscriptionInfo(
        id: '/sub/1',
        type: 'Subscription',
        topic: 'topic-a',
        subscriber: 'sub-1',
        active: true,
      );
      const b = SubscriptionInfo(
        id: '/sub/1',
        type: 'Subscription',
        topic: 'topic-a',
        subscriber: 'sub-1',
        active: true,
      );
      expect(a, equals(b));
    });
  });

  group('SubscriptionsResponse', () {
    test('fromJson parses a full JSON-LD response', () {
      final json = {
        '@context': 'https://mercure.rocks/',
        'id': '/.well-known/mercure/subscriptions',
        'type': 'Subscriptions',
        'lastEventID': 'urn:uuid:5e94c686-2c0b-4f9b-958c-92ccc3bbb4eb',
        'subscriptions': [
          {
            'id': '/sub/1',
            'type': 'Subscription',
            'topic': 'https://example.com/{selector}',
            'subscriber': 'urn:uuid:bb3de268',
            'active': true,
            'payload': {'foo': 'bar'},
          },
          {
            'id': '/sub/2',
            'type': 'Subscription',
            'topic': 'https://example.com/a-topic',
            'subscriber': 'urn:uuid:1e0cba4c',
            'active': true,
          },
        ],
      };

      final response = SubscriptionsResponse.fromJson(json);
      expect(response.context, 'https://mercure.rocks/');
      expect(response.id, '/.well-known/mercure/subscriptions');
      expect(response.type, 'Subscriptions');
      expect(
        response.lastEventId,
        'urn:uuid:5e94c686-2c0b-4f9b-958c-92ccc3bbb4eb',
      );
      expect(response.subscriptions, hasLength(2));
      expect(response.subscriptions[0].topic, 'https://example.com/{selector}');
      expect(response.subscriptions[1].payload, isNull);
    });

    test('fromJsonString parses a JSON string', () {
      const source = '{'
          '"@context":"https://mercure.rocks/",'
          '"id":"/subs",'
          '"type":"Subscriptions",'
          '"lastEventID":"urn:uuid:abc",'
          '"subscriptions":[]'
          '}';
      final response = SubscriptionsResponse.fromJsonString(source);
      expect(response.subscriptions, isEmpty);
      expect(response.lastEventId, 'urn:uuid:abc');
    });
  });
}
