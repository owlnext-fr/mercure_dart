/// Conditional import that selects the correct transport for the platform.
///
/// This is the **only** file in the package that uses conditional imports.
/// - dart:io available → [MercureTransportIo] (mobile, desktop, server)
/// - dart:html available → [MercureTransportWeb] (browser)
/// - neither → [MercureTransportPlatform] stub (throws UnsupportedError)
library;

export 'mercure_transport_stub.dart'
    if (dart.library.io) 'mercure_transport_io.dart'
    if (dart.library.html) 'mercure_transport_web.dart';
