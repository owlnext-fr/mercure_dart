/// Options for publishing an update to a Mercure hub.
///
/// Maps to the form-urlencoded body of the POST request.
/// See https://mercure.rocks/spec#publication
final class PublishOptions {
  /// The topic IRIs for this update.
  ///
  /// At least one topic is required. Multiple topics are sent as
  /// repeated `topic` form fields.
  final List<String> topics;

  /// The event payload.
  final String? data;

  /// Whether this update is private.
  ///
  /// When `true`, the hub only dispatches the update to subscribers
  /// whose JWT contains matching `mercure.subscribe` claims.
  final bool private;

  /// An explicit event ID. If `null`, the hub generates one.
  final String? id;

  /// The event type (SSE `event:` field).
  final String? type;

  /// Reconnection delay hint in milliseconds (SSE `retry:` field).
  final int? retry;

  const PublishOptions({
    required this.topics,
    this.data,
    this.private = false,
    this.id,
    this.type,
    this.retry,
  });

  /// Encodes these options as form-urlencoded fields.
  ///
  /// Returns a list of entries because `topic` can appear multiple times.
  /// The transport layer is responsible for encoding this into a request body.
  List<MapEntry<String, String>> toFormFields() {
    final fields = <MapEntry<String, String>>[];

    for (final topic in topics) {
      fields.add(MapEntry('topic', topic));
    }

    if (data != null) {
      fields.add(MapEntry('data', data!));
    }

    if (private) {
      fields.add(const MapEntry('private', 'on'));
    }

    if (id != null) {
      fields.add(MapEntry('id', id!));
    }

    if (type != null) {
      fields.add(MapEntry('type', type!));
    }

    if (retry != null) {
      fields.add(MapEntry('retry', retry.toString()));
    }

    return fields;
  }
}
