/// Pure Dart implementation of the Mercure protocol.
///
/// See https://mercure.rocks/spec for the protocol specification.
library mercure;

// Auth
export 'src/auth/mercure_auth.dart';

// Models
export 'src/models/mercure_event.dart';
export 'src/models/publish_options.dart';
export 'src/models/subscription_info.dart';

// SSE (typically internal, but useful for custom transports)
export 'src/sse/sse_line_decoder.dart';
export 'src/sse/sse_parser.dart';

// Transport
export 'src/transport/mercure_transport.dart';
export 'src/transport/mercure_transport_factory.dart';

// Public API — Façades
export 'src/subscriber/mercure_subscriber.dart';
export 'src/publisher/mercure_publisher.dart';
export 'src/discovery/mercure_discovery.dart';
export 'src/subscriptions_api/mercure_subscriptions_api.dart';
