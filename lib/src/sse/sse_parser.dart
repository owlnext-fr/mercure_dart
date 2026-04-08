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
/// Used only by the dart:io transport — the web transport receives
/// already-parsed events from the browser's native EventSource.
final class SseParser implements StreamTransformer<String, MercureEvent> {
  const SseParser();

  @override
  Stream<MercureEvent> bind(Stream<String> stream) {
    String? id;
    String? type;
    final dataBuffer = StringBuffer();
    var hasData = false;
    int? retry;

    void reset() {
      id = null;
      type = null;
      dataBuffer.clear();
      hasData = false;
      retry = null;
    }

    return stream
        .transform(StreamTransformer<String, MercureEvent>.fromHandlers(
      handleData: (line, sink) {
        // Empty line → dispatch event if we have data
        if (line.isEmpty) {
          if (hasData) {
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
        if (hasData) {
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
