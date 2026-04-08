# mercure_dart

Pure Dart implementation of the [Mercure protocol](https://mercure.rocks) — zero dependencies, fully spec-compliant, multi-platform.

[![CI](https://github.com/owlnext/mercure_dart/actions/workflows/ci.yml/badge.svg)](https://github.com/owlnext/mercure_dart/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Dart 3.0+](https://img.shields.io/badge/Dart-3.0+-0175C2.svg)](https://dart.dev)

[Mercure](https://mercure.rocks) is a protocol for pushing data updates to web browsers and other HTTP clients using Server-Sent Events (SSE). This package implements the full Mercure client specification from scratch, with no external dependencies.

## Features

- **Subscribe** to real-time updates via Server-Sent Events
- **Publish** updates to a Mercure hub
- **Discovery** of hub URLs from HTTP `Link` headers
- **Subscriptions API** to query active subscriptions on the hub
- **Multi-platform** — mobile (iOS/Android), desktop, server (dart:io) and web (dart:html)
- **Zero runtime dependencies** — only uses the Dart SDK
- **Automatic reconnection** with exponential backoff and `Last-Event-ID`
- **Three auth methods** — Bearer token, cookie, query parameter
- **Spec-compliant** SSE parser handling all edge cases

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  mercure_dart: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Quick Start

```dart
import 'package:mercure_dart/mercure_dart.dart';

void main() async {
  final hubUrl = Uri.parse('https://hub.example.com/.well-known/mercure');

  // Subscribe to updates
  final subscriber = MercureSubscriber(
    hubUrl: hubUrl,
    topics: ['https://example.com/books/{id}'],
    auth: Bearer('your-subscriber-jwt'),
  );

  subscriber.subscribe().listen((event) {
    print('${event.type}: ${event.data}');
  });

  // Publish an update
  final publisher = MercurePublisher(
    hubUrl: hubUrl,
    auth: Bearer('your-publisher-jwt'),
  );

  final id = await publisher.publish(PublishOptions(
    topics: ['https://example.com/books/1'],
    data: '{"title": "Updated Title"}',
  ));
  print('Published: $id'); // urn:uuid:...
}
```

## Usage

### Subscribe

```dart
final subscriber = MercureSubscriber(
  hubUrl: Uri.parse('https://hub.example.com/.well-known/mercure'),
  topics: [
    'https://example.com/books/{id}',   // URI template
    'https://example.com/users/dunglas', // Exact topic
  ],
  auth: Bearer(subscriberToken),
  lastEventId: 'earliest', // Get full history
);

final subscription = subscriber.subscribe().listen(
  (event) {
    print('ID: ${event.id}');
    print('Type: ${event.type}');
    print('Data: ${event.data}');
    print('Retry: ${event.retry}');
  },
  onError: (error) => print('Error: $error'),
);

// Later: stop listening
await subscription.cancel();
subscriber.close();
```

### Publish

```dart
final publisher = MercurePublisher(
  hubUrl: hubUrl,
  auth: Bearer(publisherToken),
);

// Simple update
final id = await publisher.publish(PublishOptions(
  topics: ['https://example.com/books/1'],
  data: '{"title": "The Great Gatsby"}',
));

// Private update (only authorized subscribers receive it)
await publisher.publish(PublishOptions(
  topics: ['https://example.com/users/42'],
  data: '{"email": "user@example.com"}',
  private: true,
));

// With event type and retry hint
await publisher.publish(PublishOptions(
  topics: ['https://example.com/books/1'],
  data: '{"stock": 0}',
  type: 'out-of-stock',
  retry: 5000,
));

publisher.close();
```

### Discovery

Discover the Mercure hub URL from a resource that advertises it via a `Link` header:

```dart
final result = await discoverMercureHub(
  'https://example.com/books/1',
  auth: Bearer(token),
);

print(result.hubUrls);  // [https://example.com/.well-known/mercure]
print(result.topicUrl);  // https://example.com/books/1
```

### Subscriptions API

Query active subscriptions on the hub (requires authorization):

```dart
final api = MercureSubscriptionsApi(
  hubUrl: hubUrl,
  auth: Bearer(adminToken),
);

// All subscriptions
final response = await api.getSubscriptions();
for (final sub in response.subscriptions) {
  print('${sub.topic} — active: ${sub.active}');
}

// Filtered by topic
final filtered = await api.getSubscriptionsForTopic(
  'https://example.com/books/{id}',
);

// Specific subscription
final sub = await api.getSubscription(
  topic: 'https://example.com/books/{id}',
  subscriber: 'urn:uuid:bb3de268-05b0-4c65-b44e-8f9acefc29d6',
);

api.close();
```

### Authentication

Three authentication strategies are available, matching the [Mercure spec](https://mercure.rocks/spec#authorization):

```dart
// Bearer token — sent via Authorization header
// Best option for server-side and mobile
const auth = Bearer('your-jwt-token');

// Cookie — sent via Cookie header (web: automatic with withCredentials)
const auth = Cookie('cookie-value');
const auth = Cookie('value', name: 'customCookieName'); // default: mercureAuthorization

// Query parameter — token appended to URL as ?authorization=<token>
// Fallback for web subscribers (EventSource doesn't support custom headers)
const auth = QueryParam('your-jwt-token');
```

> **Web subscribers**: The browser's `EventSource` API does not support custom headers. When using `Bearer` auth for subscriptions on web, the transport automatically falls back to the `authorization` query parameter (as specified by the protocol). Cookie auth works natively with `withCredentials: true`. For publishing on web, `Bearer` works normally since `HttpRequest` supports custom headers.

## Reconnection

The dart:io transport handles reconnection automatically:

- **Exponential backoff** — delay doubles on each failed attempt (base 3s, max 60s) with random jitter to avoid thundering herd
- **`Last-Event-ID`** — sent on reconnection so the hub replays missed events
- **`retry:` hint** — when the hub sends a `retry:` field, it updates the base reconnection delay
- **Reset on success** — the backoff counter resets after a successful connection
- **Auth errors** — 401/403 responses stop reconnection (no point retrying with bad credentials)

To request the full event history on first connection:

```dart
final subscriber = MercureSubscriber(
  hubUrl: hubUrl,
  topics: ['https://example.com/books/{id}'],
  lastEventId: 'earliest',
);
```

On web, the browser's native `EventSource` handles reconnection internally.

## Supported Platforms

| Platform | Transport | SSE Parsing | Reconnection | Bearer Auth | Cookie Auth |
|----------|-----------|-------------|--------------|-------------|-------------|
| Mobile (iOS/Android) | dart:io `HttpClient` | Custom (`SseLineDecoder` + `SseParser`) | Exponential backoff | `Authorization` header | `Cookie` header |
| Desktop (macOS/Linux/Windows) | dart:io `HttpClient` | Custom | Exponential backoff | `Authorization` header | `Cookie` header |
| Server (Dart CLI) | dart:io `HttpClient` | Custom | Exponential backoff | `Authorization` header | `Cookie` header |
| Web (Flutter web) | dart:html `EventSource` | Native browser | Native `EventSource` | Query param fallback | `withCredentials: true` |

## Architecture

```
┌─────────────────────────────────────────┐
│  Public API: MercureSubscriber,         │
│  MercurePublisher, discoverMercureHub,  │
│  MercureSubscriptionsApi                │  ← Façades
├─────────────────────────────────────────┤
│  MercureTransport (abstract interface)  │  ← Platform boundary
├──────────────┬──────────────────────────┤
│  IO transport│  Web transport           │  ← Platform-specific
│  (HttpClient)│  (EventSource + XHR)     │
├──────────────┴──────────────────────────┤
│  SSE parser, models, auth               │  ← Pure Dart, shared
└─────────────────────────────────────────┘
```

A single [conditional import](lib/src/transport/mercure_transport_factory.dart) selects the correct transport at compile time. Everything outside the `transport/` directory is pure Dart — no `dart:io` or `dart:html` imports.

## Tests

```bash
# Unit tests (pure Dart, no network)
dart test test/unit/

# Integration tests (requires Docker)
dart test test/integration/

# All tests
dart test

# Single test file
dart test test/unit/sse/sse_parser_test.dart

# Single test by name
dart test --name "parses multi-data"
```

Integration tests start a [Mercure hub](https://mercure.rocks) Docker container automatically. Make sure Docker is running.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, coding conventions, and the PR process.

## Security

See [SECURITY.md](SECURITY.md) for our vulnerability disclosure policy.

## Protocol Reference

- [Mercure protocol specification](https://mercure.rocks/spec)
- [Mercure hub documentation](https://mercure.rocks/docs)
- [SSE specification (WHATWG)](https://html.spec.whatwg.org/multipage/server-sent-events.html)

## License

MIT — see [LICENSE](LICENSE).
