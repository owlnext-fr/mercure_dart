import '../auth/mercure_auth.dart';
import '../models/subscription_info.dart';
import '../transport/mercure_transport.dart';
import '../transport/mercure_transport_factory.dart';

/// Client for the Mercure Subscriptions API.
///
/// Allows querying active subscriptions on the hub.
/// Requires authorization — the JWT must have matching topic selectors.
///
/// See https://mercure.rocks/spec#subscription
///
/// ```dart
/// final api = MercureSubscriptionsApi(
///   hubUrl: Uri.parse('https://hub.example.com/.well-known/mercure'),
///   auth: Bearer(adminToken),
/// );
///
/// final response = await api.getSubscriptions();
/// for (final sub in response.subscriptions) {
///   print('${sub.topic} — active: ${sub.active}');
/// }
/// ```
final class MercureSubscriptionsApi {
  final Uri hubUrl;
  final MercureAuth auth;
  final MercureTransport _transport;
  final bool _ownsTransport;

  MercureSubscriptionsApi({
    required this.hubUrl,
    required this.auth,
    MercureTransport? transport,
  })  : _transport = transport ?? createMercureTransport(),
        _ownsTransport = transport == null;

  /// Retrieves all active subscriptions.
  Future<SubscriptionsResponse> getSubscriptions() async {
    final url = _subscriptionsUrl();
    return _fetchSubscriptions(url);
  }

  /// Retrieves subscriptions filtered by topic.
  Future<SubscriptionsResponse> getSubscriptionsForTopic(String topic) async {
    final encodedTopic = Uri.encodeComponent(topic);
    final url = _subscriptionsUrl(segments: [encodedTopic]);
    return _fetchSubscriptions(url);
  }

  /// Retrieves a specific subscription by topic and subscriber.
  Future<SubscriptionInfo> getSubscription({
    required String topic,
    required String subscriber,
  }) async {
    final encodedTopic = Uri.encodeComponent(topic);
    final encodedSubscriber = Uri.encodeComponent(subscriber);
    final url = _subscriptionsUrl(
      segments: [encodedTopic, encodedSubscriber],
    );

    final response = await _transport.get(url, auth: auth);

    if (response.statusCode != 200) {
      throw StateError(
        'Subscriptions API failed: ${response.statusCode} ${response.body}',
      );
    }

    return SubscriptionInfo.fromJsonString(response.body);
  }

  /// Releases resources.
  void close() {
    if (_ownsTransport) {
      _transport.close();
    }
  }

  Uri _subscriptionsUrl({List<String> segments = const []}) {
    // Build path: <hubUrl-without-.well-known/mercure>/subscriptions[/topic[/subscriber]]
    final basePath = hubUrl.path.endsWith('/.well-known/mercure')
        ? hubUrl.path
        : hubUrl.path.endsWith('/')
            ? '${hubUrl.path}.well-known/mercure'
            : '${hubUrl.path}/.well-known/mercure';

    final subPath = ['$basePath/subscriptions', ...segments].join('/');
    return hubUrl.replace(path: subPath);
  }

  Future<SubscriptionsResponse> _fetchSubscriptions(Uri url) async {
    final response = await _transport.get(url, auth: auth);

    if (response.statusCode != 200) {
      throw StateError(
        'Subscriptions API failed: ${response.statusCode} ${response.body}',
      );
    }

    return SubscriptionsResponse.fromJsonString(response.body);
  }
}
