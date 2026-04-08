@TestOn('vm')
library;

import 'dart:async';

import 'package:mercure_dart/src/auth/mercure_auth.dart';
import 'package:mercure_dart/src/models/mercure_event.dart';
import 'package:mercure_dart/src/models/publish_options.dart';
import 'package:mercure_dart/src/transport/mercure_transport_io.dart';
import 'package:test/test.dart';

import '../helpers/hub.dart';

void main() {
  late MercureTestHub hub;
  late MercureTransportIo transport;

  setUpAll(() async {
    hub = await MercureTestHub.start();
  });

  tearDownAll(() => hub.stop());

  setUp(() {
    transport = MercureTransportIo();
  });

  tearDown(() {
    transport.close();
  });

  group('Subscribe + Publish', () {
    test('subscriber receives a published event', () async {
      final topic =
          'https://example.com/test/${DateTime.now().millisecondsSinceEpoch}';
      final receivedEvents = <MercureEvent>[];
      final completer = Completer<void>();

      // Start subscribing
      final subscription = transport
          .subscribe(
        hubUrl: hub.hubUrl,
        topics: [topic],
        auth: Bearer(hub.subscriberToken),
      )
          .listen((event) {
        receivedEvents.add(event);
        if (receivedEvents.length == 1) completer.complete();
      });

      // Give the subscription time to establish
      await Future<void>.delayed(const Duration(seconds: 1));

      // Publish an event
      final publishedId = await transport.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(
          topics: [topic],
          data: 'hello mercure',
        ),
      );

      // Wait for the event to arrive
      await completer.future.timeout(const Duration(seconds: 10));
      await subscription.cancel();

      expect(receivedEvents, hasLength(1));
      expect(receivedEvents[0].data, 'hello mercure');
      expect(publishedId, isNotEmpty);
    });

    test('subscriber receives events on multiple topics', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final topic1 = 'https://example.com/multi-a/$ts';
      final topic2 = 'https://example.com/multi-b/$ts';
      final receivedEvents = <MercureEvent>[];
      final completer = Completer<void>();

      final subscription = transport
          .subscribe(
        hubUrl: hub.hubUrl,
        topics: [topic1, topic2],
        auth: Bearer(hub.subscriberToken),
      )
          .listen((event) {
        receivedEvents.add(event);
        if (receivedEvents.length == 2) completer.complete();
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      await transport.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(topics: [topic1], data: 'from topic1'),
      );
      await transport.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(topics: [topic2], data: 'from topic2'),
      );

      await completer.future.timeout(const Duration(seconds: 10));
      await subscription.cancel();

      expect(receivedEvents, hasLength(2));
      final dataSet = receivedEvents.map((e) => e.data).toSet();
      expect(dataSet, containsAll(['from topic1', 'from topic2']));
    });

    test('publish returns the update ID', () async {
      final topic =
          'https://example.com/id-test/${DateTime.now().millisecondsSinceEpoch}';

      final id = await transport.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(
          topics: [topic],
          data: 'test',
        ),
      );

      expect(id, startsWith('urn:uuid:'));
    });

    test('published event type is received by subscriber', () async {
      final topic =
          'https://example.com/type-test/${DateTime.now().millisecondsSinceEpoch}';
      final completer = Completer<MercureEvent>();

      final subscription = transport
          .subscribe(
        hubUrl: hub.hubUrl,
        topics: [topic],
        auth: Bearer(hub.subscriberToken),
      )
          .listen((event) {
        if (!completer.isCompleted) completer.complete(event);
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      await transport.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(
          topics: [topic],
          data: '{"updated": true}',
          type: 'book-update',
        ),
      );

      final event = await completer.future.timeout(const Duration(seconds: 10));
      await subscription.cancel();

      expect(event.data, '{"updated": true}');
      expect(event.type, 'book-update');
    });
  });

  group('Private updates', () {
    test('private update is received by authorized subscriber', () async {
      final topic =
          'https://example.com/private-test/${DateTime.now().millisecondsSinceEpoch}';
      final completer = Completer<MercureEvent>();

      final subscription = transport
          .subscribe(
        hubUrl: hub.hubUrl,
        topics: [topic],
        auth: Bearer(hub.subscriberToken),
      )
          .listen((event) {
        if (!completer.isCompleted) completer.complete(event);
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      await transport.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(
          topics: [topic],
          data: 'secret data',
          private: true,
        ),
      );

      final event = await completer.future.timeout(const Duration(seconds: 10));
      await subscription.cancel();

      expect(event.data, 'secret data');
    });

    test('private update is NOT received by anonymous subscriber', () async {
      final topic =
          'https://example.com/anon-test/${DateTime.now().millisecondsSinceEpoch}';
      final received = <MercureEvent>[];

      // Subscribe without auth (anonymous)
      final subscription = transport.subscribe(
        hubUrl: hub.hubUrl,
        topics: [topic],
      ).listen((event) {
        received.add(event);
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      // Publish a private update
      await transport.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(
          topics: [topic],
          data: 'secret',
          private: true,
        ),
      );

      // Wait a bit to confirm no event arrives
      await Future<void>.delayed(const Duration(seconds: 2));
      await subscription.cancel();

      expect(received, isEmpty);
    });
  });

  group('Auth errors', () {
    test('publish without token fails', () async {
      final topic =
          'https://example.com/noauth/${DateTime.now().millisecondsSinceEpoch}';

      expect(
        () => transport.publish(
          hubUrl: hub.hubUrl,
          auth: const Bearer('invalid-token'),
          options: PublishOptions(topics: [topic], data: 'test'),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
