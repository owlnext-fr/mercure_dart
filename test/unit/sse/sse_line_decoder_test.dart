import 'dart:async';

import 'package:mercure_dart/src/sse/sse_line_decoder.dart';
import 'package:test/test.dart';

/// Helper: feeds chunks through the decoder and collects output lines.
Future<List<String>> decode(List<List<int>> chunks) async {
  final controller = StreamController<List<int>>();
  final lines = const SseLineDecoder().bind(controller.stream).toList();
  for (final chunk in chunks) {
    controller.add(chunk);
  }
  await controller.close();
  return lines;
}

/// Shorthand to encode a string as bytes.
List<int> bytes(String s) => s.codeUnits;

void main() {
  group('SseLineDecoder', () {
    test('splits on LF', () async {
      final result = await decode([bytes('hello\nworld\n')]);
      expect(result, ['hello', 'world']);
    });

    test('splits on CR', () async {
      final result = await decode([bytes('hello\rworld\r')]);
      expect(result, ['hello', 'world']);
    });

    test('splits on CRLF', () async {
      final result = await decode([bytes('hello\r\nworld\r\n')]);
      expect(result, ['hello', 'world']);
    });

    test('handles mixed delimiters', () async {
      final result = await decode([bytes('a\nb\rc\r\nd')]);
      expect(result, ['a', 'b', 'c', 'd']);
    });

    test('emits empty lines for consecutive LFs', () async {
      final result = await decode([bytes('a\n\nb\n')]);
      expect(result, ['a', '', 'b']);
    });

    test('emits empty lines for consecutive CRs', () async {
      final result = await decode([bytes('a\r\rb\r')]);
      expect(result, ['a', '', 'b']);
    });

    test('emits empty lines for consecutive CRLFs', () async {
      final result = await decode([bytes('a\r\n\r\nb\r\n')]);
      expect(result, ['a', '', 'b']);
    });

    test('CRLF split across chunks', () async {
      // \r at end of chunk 1, \n at start of chunk 2
      final result = await decode([bytes('hello\r'), bytes('\nworld\n')]);
      expect(result, ['hello', 'world']);
    });

    test('CR at end of chunk followed by non-LF', () async {
      // \r at end of chunk 1 should emit line, next chunk starts fresh
      final result = await decode([bytes('hello\r'), bytes('world\n')]);
      expect(result, ['hello', 'world']);
    });

    test('multiple chunks without delimiters', () async {
      final result = await decode([bytes('hel'), bytes('lo'), bytes('\n')]);
      expect(result, ['hello']);
    });

    test('empty chunks are handled', () async {
      final result =
          await decode([<int>[], bytes('a\n'), <int>[], bytes('b\n')]);
      expect(result, ['a', 'b']);
    });

    test('trailing data without delimiter is emitted on close', () async {
      final result = await decode([bytes('hello')]);
      expect(result, ['hello']);
    });

    test('empty stream produces no lines', () async {
      final result = await decode([]);
      expect(result, isEmpty);
    });

    test('only delimiters produce empty lines', () async {
      final result = await decode([bytes('\n\n')]);
      expect(result, ['', '']);
    });

    test('CR at very end of stream with no following data', () async {
      final result = await decode([bytes('hello\r')]);
      expect(result, ['hello']);
    });

    test('CRLF at end of stream', () async {
      final result = await decode([bytes('hello\r\n')]);
      expect(result, ['hello']);
    });

    test('single byte chunks', () async {
      // h e l l o \r \n w \n
      final result = await decode(
        'hello\r\nw\n'.codeUnits.map((b) => [b]).toList(),
      );
      expect(result, ['hello', 'w']);
    });
  });
}
