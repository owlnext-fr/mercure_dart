import 'dart:convert';

/// A single subscription from the Mercure Subscriptions API.
///
/// See https://mercure.rocks/spec#subscription
final class SubscriptionInfo {
  /// The subscription IRI (URL path).
  final String id;

  /// Always `"Subscription"`.
  final String type;

  /// The topic this subscription is for.
  final String topic;

  /// The subscriber identifier (typically a URN).
  final String subscriber;

  /// Whether the subscription is currently active.
  final bool active;

  /// Optional payload associated with the subscription.
  final Map<String, dynamic>? payload;

  /// The last event ID for this specific subscription.
  ///
  /// Only present when fetching a single subscription.
  final String? lastEventId;

  const SubscriptionInfo({
    required this.id,
    required this.type,
    required this.topic,
    required this.subscriber,
    required this.active,
    this.payload,
    this.lastEventId,
  });

  /// Parses a [SubscriptionInfo] from a JSON string.
  factory SubscriptionInfo.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return SubscriptionInfo.fromJson(json);
  }

  /// Parses a [SubscriptionInfo] from a JSON-LD map.
  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    try {
      return SubscriptionInfo(
        id: json['id'] as String,
        type: json['type'] as String,
        topic: json['topic'] as String,
        subscriber: json['subscriber'] as String,
        active: json['active'] as bool,
        payload: json['payload'] as Map<String, dynamic>?,
        lastEventId: json['lastEventID'] as String?,
      );
    } on TypeError catch (e) {
      throw FormatException(
        'Invalid subscription JSON: $e',
        json.toString(),
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubscriptionInfo &&
          id == other.id &&
          type == other.type &&
          topic == other.topic &&
          subscriber == other.subscriber &&
          active == other.active;

  @override
  int get hashCode => Object.hash(id, type, topic, subscriber, active);

  @override
  String toString() =>
      'SubscriptionInfo(id: $id, topic: $topic, subscriber: $subscriber, '
      'active: $active)';
}

/// The response from the Mercure Subscriptions API.
///
/// Wraps a list of [SubscriptionInfo] in a JSON-LD envelope.
/// See https://mercure.rocks/spec#subscription
final class SubscriptionsResponse {
  /// The JSON-LD context (always `"https://mercure.rocks/"`).
  final String context;

  /// The collection IRI.
  final String id;

  /// Always `"Subscriptions"`.
  final String type;

  /// The last event ID for this collection.
  final String lastEventId;

  /// The list of subscriptions.
  final List<SubscriptionInfo> subscriptions;

  const SubscriptionsResponse({
    required this.context,
    required this.id,
    required this.type,
    required this.lastEventId,
    required this.subscriptions,
  });

  /// Parses a [SubscriptionsResponse] from a JSON string.
  factory SubscriptionsResponse.fromJsonString(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return SubscriptionsResponse.fromJson(json);
  }

  /// Parses a [SubscriptionsResponse] from a JSON-LD map.
  factory SubscriptionsResponse.fromJson(Map<String, dynamic> json) {
    try {
      final subs = (json['subscriptions'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(SubscriptionInfo.fromJson)
          .toList(growable: false);

      return SubscriptionsResponse(
        context: json['@context'] as String,
        id: json['id'] as String,
        type: json['type'] as String,
        lastEventId: json['lastEventID'] as String,
        subscriptions: subs,
      );
    } on TypeError catch (e) {
      throw FormatException(
        'Invalid subscriptions response JSON: $e',
        json.toString(),
      );
    }
  }
}
