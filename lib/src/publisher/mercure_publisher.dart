import '../auth/mercure_auth.dart';
import '../models/publish_options.dart';
import '../transport/mercure_transport.dart';
import '../transport/mercure_transport_factory.dart';

/// Public API for publishing updates to a Mercure hub.
///
/// Wraps [MercureTransport.publish] with a convenient interface.
///
/// ```dart
/// final publisher = MercurePublisher(
///   hubUrl: Uri.parse('https://hub.example.com/.well-known/mercure'),
///   auth: Bearer(publisherToken),
/// );
///
/// final id = await publisher.publish(PublishOptions(
///   topics: ['https://example.com/books/1'],
///   data: '{"title": "Updated"}',
/// ));
/// ```
final class MercurePublisher {
  final Uri hubUrl;
  final MercureAuth auth;
  final MercureTransport _transport;
  final bool _ownsTransport;

  /// Creates a publisher.
  ///
  /// If [transport] is not provided, a platform-appropriate transport
  /// is created automatically via conditional import.
  MercurePublisher({
    required this.hubUrl,
    required this.auth,
    MercureTransport? transport,
  })  : _transport = transport ?? createMercureTransport(),
        _ownsTransport = transport == null;

  /// Publishes an update to the hub.
  ///
  /// Returns the update ID assigned by the hub (format: `urn:uuid:...`).
  Future<String> publish(PublishOptions options) {
    return _transport.publish(
      hubUrl: hubUrl,
      auth: auth,
      options: options,
    );
  }

  /// Releases resources.
  void close() {
    if (_ownsTransport) {
      _transport.close();
    }
  }
}
