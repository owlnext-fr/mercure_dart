/// A parsed Server-Sent Event received from a Mercure hub.
final class MercureEvent {
  /// The event ID set by the hub (SSE `id:` field).
  ///
  /// Used for reconnection via `Last-Event-ID`.
  final String? id;

  /// The event type (SSE `event:` field).
  ///
  /// When `null`, the event is dispatched as a generic `message` event.
  final String? type;

  /// The event payload (SSE `data:` field).
  ///
  /// Multiple `data:` lines are concatenated with `\n`.
  final String data;

  /// The reconnection delay hint in milliseconds (SSE `retry:` field).
  final int? retry;

  const MercureEvent({
    this.id,
    this.type,
    required this.data,
    this.retry,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MercureEvent &&
          id == other.id &&
          type == other.type &&
          data == other.data &&
          retry == other.retry;

  @override
  int get hashCode => Object.hash(id, type, data, retry);

  @override
  String toString() =>
      'MercureEvent(id: $id, type: $type, data: $data, retry: $retry)';
}
