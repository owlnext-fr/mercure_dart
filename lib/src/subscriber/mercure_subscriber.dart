import '../auth/mercure_auth.dart';
import '../models/mercure_event.dart';
import '../transport/mercure_transport.dart';
import '../transport/mercure_transport_factory.dart';

/// Public API for subscribing to Mercure hub updates.
///
/// Wraps [MercureTransport.subscribe] with a convenient interface.
///
/// ```dart
/// final subscriber = MercureSubscriber(
///   hubUrl: Uri.parse('https://hub.example.com/.well-known/mercure'),
///   topics: ['https://example.com/books/{id}'],
///   auth: Bearer(subscriberToken),
/// );
///
/// subscriber.subscribe().listen((event) {
///   print('Received: ${event.data}');
/// });
/// ```
final class MercureSubscriber {
  final Uri hubUrl;
  final List<String> topics;
  final MercureAuth? auth;
  final String? lastEventId;
  final MercureTransport _transport;
  final bool _ownsTransport;

  /// Creates a subscriber.
  ///
  /// If [transport] is not provided, a platform-appropriate transport
  /// is created automatically via conditional import.
  MercureSubscriber({
    required this.hubUrl,
    required this.topics,
    this.auth,
    this.lastEventId,
    MercureTransport? transport,
  })  : _transport = transport ?? createMercureTransport(),
        _ownsTransport = transport == null {
    if (topics.isEmpty) {
      throw ArgumentError.value(topics, 'topics', 'must not be empty');
    }
    for (final topic in topics) {
      if (topic.isEmpty) {
        throw ArgumentError.value(
            topic, 'topics', 'must not contain empty strings');
      }
    }
  }

  /// Opens an SSE connection and returns a stream of events.
  ///
  /// The stream handles reconnection automatically. Cancel the
  /// subscription or call [close] to stop receiving events.
  Stream<MercureEvent> subscribe() {
    return _transport.subscribe(
      hubUrl: hubUrl,
      topics: topics,
      auth: auth,
      lastEventId: lastEventId,
    );
  }

  /// Releases resources.
  ///
  /// Only closes the transport if it was created internally
  /// (not injected via constructor).
  void close() {
    if (_ownsTransport) {
      _transport.close();
    }
  }
}
