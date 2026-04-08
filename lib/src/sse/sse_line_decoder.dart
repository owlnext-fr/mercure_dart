import 'dart:async';

const _lf = 0x0A; // \n
const _cr = 0x0D; // \r

/// Transforms a stream of byte chunks into a stream of lines.
///
/// Handles all three SSE line delimiters: `\r\n`, `\r`, and `\n`,
/// including delimiters split across chunk boundaries.
///
/// Used only by the dart:io transport — the web transport relies on
/// the browser's native EventSource which handles line splitting.
final class SseLineDecoder implements StreamTransformer<List<int>, String> {
  const SseLineDecoder();

  @override
  Stream<String> bind(Stream<List<int>> stream) {
    final buffer = <int>[];
    var lastCharWasCr = false;

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
            sink.add(String.fromCharCodes(buffer));
            buffer.clear();
            lastCharWasCr = false;
          } else if (byte == _cr) {
            // \r delimiter — emit line immediately
            sink.add(String.fromCharCodes(buffer));
            buffer.clear();
            lastCharWasCr = true;
          } else {
            lastCharWasCr = false;
            buffer.add(byte);
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
