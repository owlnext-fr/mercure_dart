import '../auth/mercure_auth.dart';
import '../models/mercure_event.dart';
import '../models/publish_options.dart';

/// Platform-agnostic transport interface for Mercure hub communication.
///
/// Implementations handle the actual HTTP/SSE communication using
/// platform-specific APIs (dart:io HttpClient or dart:html EventSource).
///
/// Use [createMercureTransport] from `mercure_transport_factory.dart`
/// to get the correct implementation for the current platform.
abstract class MercureTransport {
  /// Opens an SSE connection to the hub and returns a stream of events.
  ///
  /// The transport handles:
  /// - Topic query parameters
  /// - Authentication headers/cookies/query params
  /// - `Last-Event-ID` header for reconnection
  /// - Automatic reconnection with configurable retry delay
  Stream<MercureEvent> subscribe({
    required Uri hubUrl,
    required List<String> topics,
    MercureAuth? auth,
    String? lastEventId,
  });

  /// Publishes an update to the hub.
  ///
  /// Returns the update ID assigned by the hub (from the response body).
  Future<String> publish({
    required Uri hubUrl,
    required MercureAuth auth,
    required PublishOptions options,
  });

  /// Performs a GET request and returns the raw response.
  ///
  /// Used by discovery and the subscriptions API.
  Future<TransportResponse> get(Uri url, {MercureAuth? auth});

  /// Releases resources (HTTP clients, open connections).
  void close();
}

/// Raw HTTP response from a [MercureTransport.get] call.
final class TransportResponse {
  final int statusCode;
  final Map<String, String> headers;
  final String body;

  const TransportResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });
}
