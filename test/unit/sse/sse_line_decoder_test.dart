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

  group('SseLineDecoder maxLineLength', () {
    /// Helper with a custom maxLineLength.
    Future<({List<String> lines, List<Object> errors})> decodeWithLimit(
      List<List<int>> chunks, {
      required int maxLineLength,
    }) async {
      final controller = StreamController<List<int>>();
      final lines = <String>[];
      final errors = <Object>[];
      final completer = Completer<void>();
      SseLineDecoder(maxLineLength: maxLineLength)
          .bind(controller.stream)
          .listen(
            lines.add,
            onError: errors.add,
            onDone: completer.complete,
          );
      for (final chunk in chunks) {
        controller.add(chunk);
      }
      await controller.close();
      await completer.future;
      return (lines: lines, errors: errors);
    }

    test('line within limit is emitted normally', () async {
      final r = await decodeWithLimit([bytes('hello\n')], maxLineLength: 10);
      expect(r.lines, ['hello']);
      expect(r.errors, isEmpty);
    });

    test('line exceeding limit emits error and is discarded', () async {
      final r = await decodeWithLimit(
        [bytes('this-is-too-long\nok\n')],
        maxLineLength: 5,
      );
      expect(r.lines, ['ok']);
      expect(r.errors, hasLength(1));
      expect(r.errors[0], isA<StateError>());
    });

    test('line exactly at limit is emitted normally', () async {
      final r = await decodeWithLimit([bytes('abcde\n')], maxLineLength: 5);
      expect(r.lines, ['abcde']);
      expect(r.errors, isEmpty);
    });

    test('overflow line split across chunks is discarded', () async {
      final r = await decodeWithLimit(
        [bytes('abc'), bytes('defgh\nnext\n')],
        maxLineLength: 5,
      );
      expect(r.lines, ['next']);
      expect(r.errors, hasLength(1));
    });

    test('multiple overflow lines emit multiple errors', () async {
      final r = await decodeWithLimit(
        [bytes('toolong1\ntoolong2\nok\n')],
        maxLineLength: 3,
      );
      expect(r.lines, ['ok']);
      expect(r.errors, hasLength(2));
    });

    test('overflow does not corrupt subsequent lines', () async {
      final r = await decodeWithLimit(
        [bytes('overflow-data\na\nb\n')],
        maxLineLength: 5,
      );
      expect(r.lines, ['a', 'b']);
      expect(r.errors, hasLength(1));
    });
  });
}
