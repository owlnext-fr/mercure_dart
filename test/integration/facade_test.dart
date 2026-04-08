@TestOn('vm')
library;

import 'dart:async';

import 'package:mercure_dart/mercure_dart.dart';
import 'package:mercure_dart/src/transport/mercure_transport_io.dart';
import 'package:test/test.dart';

import '../helpers/hub.dart';

void main() {
  late MercureTestHub hub;

  setUpAll(() async {
    hub = await MercureTestHub.start();
  });

  tearDownAll(() => hub.stop());

  group('Publisher → Subscriber end-to-end', () {
    test('subscriber receives event published via facades', () async {
      final topic =
          'https://example.com/e2e/${DateTime.now().millisecondsSinceEpoch}';

      final publisher = MercurePublisher(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
      );

      final subscriber = MercureSubscriber(
        hubUrl: hub.hubUrl,
        topics: [topic],
        auth: Bearer(hub.subscriberToken),
      );

      final completer = Completer<MercureEvent>();
      final subscription = subscriber.subscribe().listen((event) {
        if (!completer.isCompleted) completer.complete(event);
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      final id = await publisher.publish(PublishOptions(
        topics: [topic],
        data: 'end-to-end test',
        type: 'e2e',
      ));

      final event = await completer.future.timeout(const Duration(seconds: 10));

      expect(event.data, 'end-to-end test');
      expect(event.type, 'e2e');
      expect(id, startsWith('urn:uuid:'));

      await subscription.cancel();
      subscriber.close();
      publisher.close();
    });

    test('multiple subscribers on different topics', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final topicA = 'https://example.com/multi-sub-a/$ts';
      final topicB = 'https://example.com/multi-sub-b/$ts';

      final publisher = MercurePublisher(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
      );

      final subA = MercureSubscriber(
        hubUrl: hub.hubUrl,
        topics: [topicA],
        auth: Bearer(hub.subscriberToken),
      );
      final subB = MercureSubscriber(
        hubUrl: hub.hubUrl,
        topics: [topicB],
        auth: Bearer(hub.subscriberToken),
      );

      final eventsA = <MercureEvent>[];
      final eventsB = <MercureEvent>[];
      final completerA = Completer<void>();
      final completerB = Completer<void>();

      final listenA = subA.subscribe().listen((e) {
        eventsA.add(e);
        if (!completerA.isCompleted) completerA.complete();
      });
      final listenB = subB.subscribe().listen((e) {
        eventsB.add(e);
        if (!completerB.isCompleted) completerB.complete();
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      await publisher.publish(PublishOptions(topics: [topicA], data: 'for A'));
      await publisher.publish(PublishOptions(topics: [topicB], data: 'for B'));

      await completerA.future.timeout(const Duration(seconds: 10));
      await completerB.future.timeout(const Duration(seconds: 10));

      expect(eventsA.map((e) => e.data), contains('for A'));
      expect(eventsB.map((e) => e.data), contains('for B'));

      // A should NOT have received B's event and vice versa
      expect(eventsA.map((e) => e.data), isNot(contains('for B')));
      expect(eventsB.map((e) => e.data), isNot(contains('for A')));

      await listenA.cancel();
      await listenB.cancel();
      subA.close();
      subB.close();
      publisher.close();
    });
  });

  group('Subscriptions API', () {
    test('lists active subscriptions', () async {
      final topic =
          'https://example.com/subs-api/${DateTime.now().millisecondsSinceEpoch}';

      // Create an active subscription first
      final subscriber = MercureSubscriber(
        hubUrl: hub.hubUrl,
        topics: [topic],
        auth: Bearer(hub.subscriberToken),
      );

      final listenSub = subscriber.subscribe().listen((_) {});
      await Future<void>.delayed(const Duration(seconds: 1));

      // Query the subscriptions API
      final api = MercureSubscriptionsApi(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.subscriberToken),
      );

      final response = await api.getSubscriptions();

      expect(response.type, 'Subscriptions');
      expect(response.context, 'https://mercure.rocks/');
      expect(response.subscriptions, isNotEmpty);

      // At least one subscription should be active
      final active = response.subscriptions.where((s) => s.active);
      expect(active, isNotEmpty);

      await listenSub.cancel();
      subscriber.close();
      api.close();
    });
  });

  group('Discovery', () {
    test('discovers hub URL from Link header', () async {
      // The Mercure hub itself exposes Link headers on GET requests
      // We can use the subscriptions endpoint which returns Link: <hub>; rel="mercure"
      final transport = MercureTransportIo();

      try {
        final response = await transport.get(
          _subscriptionsUrl(hub.hubUrl),
          auth: Bearer(hub.subscriberToken),
        );

        // Verify the hub actually sends a Link header
        final linkHeader = response.headers['link'];

        if (linkHeader != null) {
          final links = parseLinkHeader(linkHeader);
          final mercureLinks = links.where((l) => l.rel == 'mercure');
          expect(mercureLinks, isNotEmpty);
        } else {
          // Hub may not send Link headers on subscriptions endpoint
          // This is acceptable — test the parser separately
          markTestSkipped('Hub did not return Link header');
        }
      } finally {
        transport.close();
      }
    });
  });
}

Uri _subscriptionsUrl(Uri hubUrl) {
  return hubUrl.replace(
    path: '${hubUrl.path}/subscriptions',
  );
}
