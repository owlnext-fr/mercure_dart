# Contributing to mercure_dart

Thanks for your interest in contributing! This document covers the setup, conventions, and process for submitting changes.

## Prerequisites

- **Dart SDK** >= 3.0.0 ([install](https://dart.dev/get-dart))
- **Docker** (for integration tests — [install](https://docs.docker.com/get-docker/))

## Setup

```bash
git clone https://github.com/owlnext/mercure_dart.git
cd mercure_dart
dart pub get
```

Verify everything works:

```bash
dart analyze
dart test test/unit/
dart test test/integration/   # requires Docker
```

## Code Conventions

### Zero runtime dependencies

The package has **no runtime dependencies** — only `dart:core`, `dart:async`, `dart:convert`, and platform libraries (`dart:io`, `dart:html`). Do not add packages to `dependencies` in `pubspec.yaml`. Dev dependencies (for tests and linting) are fine.

### Platform isolation

- Code in `lib/src/models/`, `lib/src/sse/`, `lib/src/auth/`, `lib/src/discovery/`, and `lib/src/subscriptions_api/` is **pure Dart** — it must never import `dart:io` or `dart:html`.
- Platform-specific code lives exclusively in `lib/src/transport/`.
- The **only** conditional import is in [`mercure_transport_factory.dart`](lib/src/transport/mercure_transport_factory.dart). Do not add new conditional imports elsewhere.

### Language features

- Dart 3.x: use `sealed class` for unions, `final class` everywhere else unless inheritance is needed.
- No code generation, no annotations.
- Sound null safety throughout.

### Style

- Follow `package:lints/recommended.yaml` (enforced by `dart analyze`).
- Run `dart format .` before committing.
- File names: `snake_case.dart`. Classes: `PascalCase`. Methods/variables: `camelCase`.
- Doc comments (`///`) on every public class and method.

## Tests

### Unit tests

Pure Dart, no network or Docker required. Run on all platforms.

```bash
dart test test/unit/
dart test test/unit/sse/sse_parser_test.dart   # single file
dart test --name "splits on CRLF"              # single test
```

### Integration tests

Run against a real [Mercure hub](https://mercure.rocks) in Docker. The test helper (`test/helpers/hub.dart`) manages the container lifecycle automatically.

```bash
dart test test/integration/
```

Docker must be running. The tests pull `dunglas/mercure:latest` if not already cached.

### Before submitting

Make sure all three pass:

```bash
dart analyze                          # Zero warnings
dart format --set-exit-if-changed .   # Formatting clean
dart test                             # All tests green
```

## Pull Request Process

1. **Fork** the repository and create a branch from `main`.
2. Make your changes, following the conventions above.
3. Add tests for any new functionality.
4. Ensure `dart analyze`, `dart format`, and `dart test` all pass.
5. Write a clear PR description explaining *what* changed and *why*.
6. Submit the PR. A maintainer will review it.

Keep PRs focused — one feature or fix per PR. Large refactors should be discussed in an issue first.

## Reporting Bugs

Open an [issue](https://github.com/owlnext/mercure_dart/issues) with:

- Dart SDK version (`dart --version`)
- Platform (io/web, OS)
- Minimal reproduction steps
- Expected vs. actual behavior

## Reporting Security Vulnerabilities

See [SECURITY.md](SECURITY.md).
