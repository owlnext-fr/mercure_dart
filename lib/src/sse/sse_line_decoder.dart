import 'dart:async';

const _lf = 0x0A; // \n
const _cr = 0x0D; // \r

/// Transforms a stream of byte chunks into a stream of lines.
///
/// Handles all three SSE line delimiters: `\r\n`, `\r`, and `\n`,
/// including delimiters split across chunk boundaries.
///
/// Lines exceeding [maxLineLength] bytes are discarded and a
/// [StateError] is added to the output stream.
///
/// Used only by the dart:io transport — the web transport relies on
/// the browser's native EventSource which handles line splitting.
final class SseLineDecoder implements StreamTransformer<List<int>, String> {
  /// Maximum allowed line length in bytes. Lines exceeding this limit
  /// are discarded and an error is emitted. Defaults to 1 MB.
  final int maxLineLength;

  const SseLineDecoder({this.maxLineLength = 1024 * 1024});

  @override
  Stream<String> bind(Stream<List<int>> stream) {
    final buffer = <int>[];
    var lastCharWasCr = false;
    var overflow = false;

    return stream.transform(StreamTransformer<List<int>, String>.fromHandlers(
      handleData: (chunk, sink) {
        for (var i = 0; i < chunk.length; i++) {
          final byte = chunk[i];

          if (byte == _lf) {
            if (lastCharWasCr) {
              // \r\n pair — the \r already emitted the line, skip the \n
              lastCharWasCr = false;
              continue;
            }
            // Pure \n delimiter
            if (overflow) {
              overflow = false;
            } else {
              sink.add(String.fromCharCodes(buffer));
            }
            buffer.clear();
            lastCharWasCr = false;
          } else if (byte == _cr) {
            // \r delimiter — emit line immediately
            if (overflow) {
              overflow = false;
            } else {
              sink.add(String.fromCharCodes(buffer));
            }
            buffer.clear();
            lastCharWasCr = true;
          } else {
            lastCharWasCr = false;
            if (!overflow) {
              buffer.add(byte);
              if (buffer.length > maxLineLength) {
                sink.addError(
                  StateError('SSE line exceeded $maxLineLength bytes'),
                );
                buffer.clear();
                overflow = true;
              }
            }
          }
        }
      },
      handleDone: (sink) {
        // Emit any remaining buffered data as a final line
        if (buffer.isNotEmpty) {
          sink.add(String.fromCharCodes(buffer));
          buffer.clear();
        }
        sink.close();
      },
    ));
  }

  @override
  StreamTransformer<RS, RT> cast<RS, RT>() =>
      StreamTransformer.castFrom<List<int>, String, RS, RT>(this);
}
