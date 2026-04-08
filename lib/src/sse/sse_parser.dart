import 'dart:async';

import '../models/mercure_event.dart';

/// Transforms a stream of SSE lines into a stream of [MercureEvent]s.
///
/// Follows the SSE specification parsing rules:
/// - Lines starting with `:` are comments (ignored)
/// - Multiple `data:` fields are concatenated with `\n`
/// - `id:` must not contain U+0000 NULL (ignored if it does)
/// - `retry:` must be all digits (ignored otherwise)
/// - Unknown fields are ignored
/// - An empty line dispatches the accumulated event
///
/// Events whose accumulated `data:` fields exceed [maxEventSize] bytes
/// are discarded and a [StateError] is added to the output stream.
///
/// Used only by the dart:io transport — the web transport receives
/// already-parsed events from the browser's native EventSource.
final class SseParser implements StreamTransformer<String, MercureEvent> {
  /// Maximum allowed event size in bytes (accumulated `data:` fields).
  /// Events exceeding this limit are discarded and an error is emitted.
  /// Defaults to 10 MB.
  final int maxEventSize;

  const SseParser({this.maxEventSize = 10 * 1024 * 1024});

  @override
  Stream<MercureEvent> bind(Stream<String> stream) {
    String? id;
    String? type;
    final dataBuffer = StringBuffer();
    var hasData = false;
    int? retry;
    var dataSize = 0;
    var overflow = false;

    void reset() {
      id = null;
      type = null;
      dataBuffer.clear();
      hasData = false;
      retry = null;
      dataSize = 0;
      overflow = false;
    }

    return stream
        .transform(StreamTransformer<String, MercureEvent>.fromHandlers(
      handleData: (line, sink) {
        // Empty line → dispatch event if we have data
        if (line.isEmpty) {
          if (hasData && !overflow) {
            sink.add(MercureEvent(
              id: id,
              type: type,
              data: dataBuffer.toString(),
              retry: retry,
            ));
          }
          reset();
          return;
        }

        // Skip all lines while in overflow state (until next empty line)
        if (overflow) return;

        // Comment line
        if (line.startsWith(':')) return;

        // Parse field name and value
        final String fieldName;
        final String fieldValue;

        final colonIndex = line.indexOf(':');
        if (colonIndex == -1) {
          // Line with no colon — field name is the whole line, value is empty
          fieldName = line;
          fieldValue = '';
        } else {
          fieldName = line.substring(0, colonIndex);
          // Skip optional single space after colon
          final valueStart =
              (colonIndex + 1 < line.length && line[colonIndex + 1] == ' ')
                  ? colonIndex + 2
                  : colonIndex + 1;
          fieldValue = line.substring(valueStart);
        }

        switch (fieldName) {
          case 'data':
            dataSize += fieldValue.length + (hasData ? 1 : 0);
            if (dataSize > maxEventSize) {
              overflow = true;
              dataBuffer.clear();
              sink.addError(
                StateError('SSE event exceeded $maxEventSize bytes'),
              );
              return;
            }
            if (hasData) dataBuffer.write('\n');
            dataBuffer.write(fieldValue);
            hasData = true;
          case 'id':
            // Ignore if the value contains NULL
            if (!fieldValue.contains('\x00')) {
              id = fieldValue;
            }
          case 'event':
            type = fieldValue;
          case 'retry':
            // Only accept if all characters are ASCII digits
            if (fieldValue.isNotEmpty &&
                fieldValue.codeUnits.every((c) => c >= 0x30 && c <= 0x39)) {
              retry = int.parse(fieldValue);
            }
          default:
            // Unknown field — ignore per spec
            break;
        }
      },
      handleDone: (sink) {
        // If there's buffered data without a trailing empty line, emit it
        if (hasData && !overflow) {
          sink.add(MercureEvent(
            id: id,
            type: type,
            data: dataBuffer.toString(),
            retry: retry,
          ));
          reset();
        }
        sink.close();
      },
    ));
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() =>
      StreamTransformer.castFrom<String, MercureEvent, RS, RT>(this);
}
