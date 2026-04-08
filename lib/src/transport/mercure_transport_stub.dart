import '../auth/mercure_auth.dart';
import '../models/mercure_event.dart';
import '../models/publish_options.dart';
import 'mercure_transport.dart';

/// Stub transport that throws on every call.
///
/// This is the default export from `mercure_transport_factory.dart`
/// when neither dart:io nor dart:html is available.
final class MercureTransportPlatform extends MercureTransport {
  MercureTransportPlatform();

  @override
  Stream<MercureEvent> subscribe({
    required Uri hubUrl,
    required List<String> topics,
    MercureAuth? auth,
    String? lastEventId,
  }) {
    throw UnsupportedError(
      'Mercure transport is not supported on this platform.',
    );
  }

  @override
  Future<String> publish({
    required Uri hubUrl,
    required MercureAuth auth,
    required PublishOptions options,
  }) {
    throw UnsupportedError(
      'Mercure transport is not supported on this platform.',
    );
  }

  @override
  Future<TransportResponse> get(Uri url, {MercureAuth? auth}) {
    throw UnsupportedError(
      'Mercure transport is not supported on this platform.',
    );
  }

  @override
  void close() {}
}

/// Factory function to create the platform transport.
MercureTransport createMercureTransport() => MercureTransportPlatform();
