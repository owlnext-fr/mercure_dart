import 'dart:async';
import 'dart:io';

import 'jwt.dart';

/// Manages a Mercure hub Docker container for integration tests.
///
/// Usage:
/// ```dart
/// late MercureTestHub hub;
/// setUpAll(() async => hub = await MercureTestHub.start());
/// tearDownAll(() => hub.stop());
/// ```
final class MercureTestHub {
  /// The URL of the running Mercure hub.
  final Uri hubUrl;

  /// JWT for publishing (mercure.publish: ["*"]).
  final String publisherToken;

  /// JWT for subscribing (mercure.subscribe: ["*"]).
  final String subscriberToken;

  /// The Docker container ID.
  final String _containerId;

  MercureTestHub._({
    required this.hubUrl,
    required this.publisherToken,
    required this.subscriberToken,
    required String containerId,
  }) : _containerId = containerId;

  /// The shared JWT secret used for signing tokens.
  static const _jwtSecret = 'mercure-dart-test-secret-key-min-256-bits!!';

  /// Starts or connects to a Mercure hub for testing.
  ///
  /// If the `MERCURE_HUB_URL` environment variable is set, connects to
  /// that external hub (useful in CI with service containers).
  /// Otherwise, starts a new Docker container on a random port.
  static Future<MercureTestHub> start({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final publisherToken = generatePublisherJwt(secret: _jwtSecret);
    final subscriberToken = generateSubscriberJwt(secret: _jwtSecret);

    final externalUrl = Platform.environment['MERCURE_HUB_URL'];
    if (externalUrl != null) {
      // External hub (CI service container) — no Docker management needed
      final hubUrl = Uri.parse(externalUrl);
      final hub = MercureTestHub._(
        hubUrl: hubUrl,
        publisherToken: publisherToken,
        subscriberToken: subscriberToken,
        containerId: '',
      );
      await hub._waitForReady(timeout);
      return hub;
    }

    // Local: start a Docker container
    final port = await _findAvailablePort();

    final result = await Process.run('docker', [
      'run',
      '--detach',
      '--rm',
      '-p',
      '$port:80',
      '-e',
      'MERCURE_PUBLISHER_JWT_KEY=$_jwtSecret',
      '-e',
      'MERCURE_SUBSCRIBER_JWT_KEY=$_jwtSecret',
      '-e',
      'MERCURE_EXTRA_DIRECTIVES=anonymous\nsubscriptions',
      '-e',
      'SERVER_NAME=:80',
      'dunglas/mercure',
    ]);

    if (result.exitCode != 0) {
      throw StateError(
        'Failed to start Mercure hub: ${result.stderr}',
      );
    }

    final containerId = (result.stdout as String).trim();
    final hubUrl = Uri.parse('http://localhost:$port/.well-known/mercure');

    final hub = MercureTestHub._(
      hubUrl: hubUrl,
      publisherToken: publisherToken,
      subscriberToken: subscriberToken,
      containerId: containerId,
    );

    await hub._waitForReady(timeout);
    return hub;
  }

  /// Stops and removes the Docker container.
  ///
  /// No-op when using an external hub (CI service container).
  Future<void> stop() async {
    if (_containerId.isEmpty) return;
    await Process.run('docker', ['stop', _containerId]);
  }

  /// Waits for the hub to respond to HTTP requests.
  Future<void> _waitForReady(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    final client = HttpClient();

    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final request =
              await client.getUrl(hubUrl).timeout(const Duration(seconds: 2));
          final response = await request.close().timeout(
                const Duration(seconds: 2),
              );
          await response.drain<void>();
          // Any response means the hub is up (even 400)
          return;
        } catch (_) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      throw TimeoutException('Mercure hub did not start within $timeout');
    } finally {
      client.close(force: true);
    }
  }

  /// Finds an available TCP port.
  static Future<int> _findAvailablePort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }
}
