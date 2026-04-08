# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.2] - 2026-04-08

### Security

- **SSE pipeline hardening** — configurable size limits to prevent memory exhaustion from malicious SSE streams:
  - `SseLineDecoder`: `maxLineLength` parameter (default 1 MB). Lines exceeding the limit are discarded with a `StateError`.
  - `SseParser`: `maxEventSize` parameter (default 10 MB). Events exceeding the limit are discarded with a `StateError`.
- **Error message sanitization** — HTTP response bodies are truncated to 200 characters in exception messages to prevent information leakage (IO transport, web transport, subscriptions API).
- **`MercureEvent.toString()` truncation** — event data is truncated to 100 characters in debug output to prevent sensitive payloads from leaking into logs.

### Added

- Input validation on `MercureSubscriber` and `PublishOptions` constructors: `topics` must be non-empty and contain no empty strings.
- Defensive JSON deserialization in `SubscriptionInfo.fromJson` and `SubscriptionsResponse.fromJson`: `TypeError` is caught and rethrown as `FormatException` with context.

### Changed

- `PublishOptions` constructor is no longer `const` (body validation requires runtime checks).

## [1.0.1] - 2026-04-08

### Fixed

- Repository URL corrected to `owlnext-fr` across all files (pubspec, README, CONTRIBUTING, SECURITY, CHANGELOG).
- CI badge now targets `main` branch explicitly for accurate status display.
- Architecture diagram alignment fixed (consistent column widths with box-drawing characters).

### Added

- Table of contents in README.
- Emoji icons on features list.

## [1.0.0] - 2026-04-08

### Added

- **Models**: `MercureEvent`, `PublishOptions`, `SubscriptionInfo`, `SubscriptionsResponse` — immutable data classes for the Mercure protocol.
- **Authentication**: `MercureAuth` sealed class with `Bearer`, `Cookie`, and `QueryParam` variants.
- **SSE parser**: `SseLineDecoder` (bytes to lines) and `SseParser` (lines to events) — spec-compliant `StreamTransformer` implementations handling all SSE edge cases.
- **Transport layer**: `MercureTransport` abstract interface with platform-specific implementations:
  - `MercureTransportIo` (dart:io) — `HttpClient` with custom SSE parsing pipeline and automatic reconnection with exponential backoff.
  - `MercureTransportWeb` (dart:html) — native `EventSource` for subscribe, `HttpRequest` for publish.
  - Conditional import factory for automatic platform selection.
- **MercureSubscriber** — facade for subscribing to hub updates via `Stream<MercureEvent>`.
- **MercurePublisher** — facade for publishing updates to the hub.
- **Discovery** — `discoverMercureHub()` function with `Link` header parser (RFC 8288).
- **Subscriptions API** — `MercureSubscriptionsApi` for querying active subscriptions (JSON-LD).
- **Reconnection**: exponential backoff with jitter, `Last-Event-ID` reconciliation, `retry:` hint support, `earliest` history retrieval.
- **Zero runtime dependencies** — pure Dart SDK only.
- **CI**: GitHub Actions workflow (analyze, unit tests on SDK 3.0.0 + stable, integration tests with Mercure Docker).
- Integration test infrastructure with Docker (`dunglas/mercure`) and minimal JWT HS256 generator.
- Library entry point: `import 'package:mercure_dart/mercure_dart.dart';`

[1.0.2]: https://github.com/owlnext-fr/mercure_dart/releases/tag/v1.0.2
[1.0.1]: https://github.com/owlnext-fr/mercure_dart/releases/tag/v1.0.1
[1.0.0]: https://github.com/owlnext-fr/mercure_dart/releases/tag/v1.0.0
