/// Example usage of the mercure_dart package.
///
/// Requires a running Mercure hub. Start one with:
/// ```bash
/// docker run -e MERCURE_PUBLISHER_JWT_KEY='my-secret-key-min-256-bits!!!!!' \
///            -e MERCURE_SUBSCRIBER_JWT_KEY='my-secret-key-min-256-bits!!!!!' \
///            -e SERVER_NAME=:80 \
///            -p 8080:80 \
///            dunglas/mercure
/// ```
library;

import 'package:mercure_dart/mercure_dart.dart';

void main() async {
  final hubUrl = Uri.parse('http://localhost:8080/.well-known/mercure');

  // Replace with valid JWTs for your hub's key
  const publisherToken = 'your-publisher-jwt';
  const subscriberToken = 'your-subscriber-jwt';

  // --- Subscribe ---
  final subscriber = MercureSubscriber(
    hubUrl: hubUrl,
    topics: [
      'https://example.com/books/{id}',
      'https://example.com/users/dunglas',
    ],
    auth: const Bearer(subscriberToken),
  );

  final subscription = subscriber.subscribe().listen(
    (event) {
      print('Received event:');
      print('  ID:   ${event.id}');
      print('  Type: ${event.type}');
      print('  Data: ${event.data}');
    },
    onError: (Object error) {
      print('Subscription error: $error');
    },
  );

  // --- Publish ---
  final publisher = MercurePublisher(
    hubUrl: hubUrl,
    auth: const Bearer(publisherToken),
  );

  final updateId = await publisher.publish(PublishOptions(
    topics: ['https://example.com/books/1'],
    data: '{"title": "The Great Gatsby", "author": "F. Scott Fitzgerald"}',
    type: 'book-update',
  ));
  print('Published update: $updateId');

  // Publish a private update (only authorized subscribers receive it)
  await publisher.publish(PublishOptions(
    topics: ['https://example.com/users/dunglas'],
    data: '{"email": "kevin@example.com"}',
    private: true,
  ));

  // --- Discovery ---
  // Discover the hub URL from a resource that exposes Link headers
  // final result = await discoverMercureHub('https://example.com/books/1');
  // print('Hub URL: ${result.hubUrls.first}');
  // print('Topic: ${result.topicUrl}');

  // --- Subscriptions API ---
  final api = MercureSubscriptionsApi(
    hubUrl: hubUrl,
    auth: const Bearer(subscriberToken),
  );

  final subs = await api.getSubscriptions();
  print('Active subscriptions: ${subs.subscriptions.length}');
  for (final sub in subs.subscriptions) {
    print('  ${sub.topic} — active: ${sub.active}');
  }

  // Cleanup
  await subscription.cancel();
  subscriber.close();
  publisher.close();
  api.close();
}
