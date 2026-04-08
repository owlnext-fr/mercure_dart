@TestOn('vm')
library;

import 'dart:async';

import 'package:mercure_dart/mercure.dart';
import 'package:mercure_dart/src/transport/mercure_transport_io.dart';
import 'package:test/test.dart';

import '../helpers/hub.dart';

void main() {
  late MercureTestHub hub;

  setUpAll(() async {
    hub = await MercureTestHub.start();
  });

  tearDownAll(() => hub.stop());

  group('Reconnection', () {
    test('subscriber catches up via Last-Event-ID after reconnect', () async {
      final topic =
          'https://example.com/reconnect/${DateTime.now().millisecondsSinceEpoch}';

      // Step 1: Publish some events and record the first event's ID
      final transport1 = MercureTransportIo();
      final firstId = await transport1.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(topics: [topic], data: 'event-1'),
      );

      await transport1.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(topics: [topic], data: 'event-2'),
      );

      await transport1.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(topics: [topic], data: 'event-3'),
      );
      transport1.close();

      // Step 2: Subscribe with Last-Event-ID pointing to the first event
      // This should replay event-2 and event-3
      final transport2 = MercureTransportIo();
      final received = <String>[];
      final completer = Completer<void>();

      final subscription = transport2
          .subscribe(
        hubUrl: hub.hubUrl,
        topics: [topic],
        auth: Bearer(hub.subscriberToken),
        lastEventId: firstId,
      )
          .listen((event) {
        received.add(event.data);
        if (received.length >= 2) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      await completer.future.timeout(const Duration(seconds: 10));
      await subscription.cancel();
      transport2.close();

      expect(received, contains('event-2'));
      expect(received, contains('event-3'));
      expect(received, isNot(contains('event-1')));
    });

    test('lastEventID=earliest retrieves full history', () async {
      final topic =
          'https://example.com/earliest/${DateTime.now().millisecondsSinceEpoch}';

      // Publish events
      final transport1 = MercureTransportIo();
      await transport1.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(topics: [topic], data: 'history-1'),
      );
      await transport1.publish(
        hubUrl: hub.hubUrl,
        auth: Bearer(hub.publisherToken),
        options: PublishOptions(topics: [topic], data: 'history-2'),
      );
      transport1.close();

      // Subscribe with earliest — should get all events
      final transport2 = MercureTransportIo();
      final received = <String>[];
      final completer = Completer<void>();

      final subscription = transport2
          .subscribe(
        hubUrl: hub.hubUrl,
        topics: [topic],
        auth: Bearer(hub.subscriberToken),
        lastEventId: 'earliest',
      )
          .listen((event) {
        received.add(event.data);
        if (received.length >= 2) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      await completer.future.timeout(const Duration(seconds: 10));
      await subscription.cancel();
      transport2.close();

      expect(received, contains('history-1'));
      expect(received, contains('history-2'));
    });
  });
}
