import 'dart:async';

import 'package:mercure_dart/src/models/mercure_event.dart';
import 'package:mercure_dart/src/sse/sse_parser.dart';
import 'package:test/test.dart';

/// Helper: feeds lines through the parser and collects output events.
Future<List<MercureEvent>> parse(List<String> lines) async {
  final controller = StreamController<String>();
  final events = const SseParser().bind(controller.stream).toList();
  for (final line in lines) {
    controller.add(line);
  }
  await controller.close();
  return events;
}

void main() {
  group('SseParser', () {
    test('parses a simple event', () async {
      final events = await parse(['data: hello', '']);
      expect(events, hasLength(1));
      expect(events[0].data, 'hello');
      expect(events[0].id, isNull);
      expect(events[0].type, isNull);
      expect(events[0].retry, isNull);
    });

    test('parses event with all fields', () async {
      final events = await parse([
        'id: 42',
        'event: update',
        'retry: 5000',
        'data: payload',
        '',
      ]);
      expect(events, hasLength(1));
      expect(
          events[0],
          const MercureEvent(
            id: '42',
            type: 'update',
            data: 'payload',
            retry: 5000,
          ));
    });

    test('concatenates multiple data fields with newline', () async {
      final events = await parse([
        'data: line1',
        'data: line2',
        'data: line3',
        '',
      ]);
      expect(events[0].data, 'line1\nline2\nline3');
    });

    test('ignores comment lines', () async {
      final events = await parse([
        ': this is a comment',
        'data: hello',
        ': another comment',
        '',
      ]);
      expect(events, hasLength(1));
      expect(events[0].data, 'hello');
    });

    test('ignores id field containing NULL', () async {
      final events = await parse([
        'id: bad\x00id',
        'data: hello',
        '',
      ]);
      expect(events[0].id, isNull);
    });

    test('accepts id field without NULL', () async {
      final events = await parse([
        'id: good-id',
        'data: hello',
        '',
      ]);
      expect(events[0].id, 'good-id');
    });

    test('retry: only digits are accepted', () async {
      final events = await parse([
        'retry: 3000',
        'data: a',
        '',
      ]);
      expect(events[0].retry, 3000);
    });

    test('retry: non-numeric is ignored', () async {
      final events = await parse([
        'retry: not-a-number',
        'data: a',
        '',
      ]);
      expect(events[0].retry, isNull);
    });

    test('retry: empty value is ignored', () async {
      final events = await parse([
        'retry: ',
        'data: a',
        '',
      ]);
      expect(events[0].retry, isNull);
    });

    test('retry: mixed digits and letters is ignored', () async {
      final events = await parse([
        'retry: 123abc',
        'data: a',
        '',
      ]);
      expect(events[0].retry, isNull);
    });

    test('ignores unknown fields', () async {
      final events = await parse([
        'unknown: value',
        'data: hello',
        '',
      ]);
      expect(events, hasLength(1));
      expect(events[0].data, 'hello');
    });

    test('field with no colon uses whole line as field name', () async {
      final events = await parse([
        'data',
        '',
      ]);
      // "data" with no colon → field name "data", value ""
      expect(events, hasLength(1));
      expect(events[0].data, '');
    });

    test('data: without space after colon', () async {
      final events = await parse([
        'data:no-space',
        '',
      ]);
      expect(events[0].data, 'no-space');
    });

    test('data: with space after colon strips one space', () async {
      final events = await parse([
        'data: with-space',
        '',
      ]);
      expect(events[0].data, 'with-space');
    });

    test('data: with multiple spaces preserves extra spaces', () async {
      final events = await parse([
        'data:  two-spaces',
        '',
      ]);
      expect(events[0].data, ' two-spaces');
    });

    test('empty data line produces empty string', () async {
      final events = await parse([
        'data: ',
        '',
      ]);
      expect(events[0].data, '');
    });

    test('no event emitted for empty lines without data', () async {
      final events = await parse(['', '', '']);
      expect(events, isEmpty);
    });

    test('multiple events in sequence', () async {
      final events = await parse([
        'data: first',
        '',
        'data: second',
        '',
      ]);
      expect(events, hasLength(2));
      expect(events[0].data, 'first');
      expect(events[1].data, 'second');
    });

    test('state resets between events', () async {
      final events = await parse([
        'id: 1',
        'event: type1',
        'data: first',
        '',
        'data: second',
        '',
      ]);
      expect(events[0].id, '1');
      expect(events[0].type, 'type1');
      expect(events[1].id, isNull);
      expect(events[1].type, isNull);
    });

    test('emits buffered event on stream close', () async {
      // No trailing empty line — should still emit
      final events = await parse(['data: orphan']);
      expect(events, hasLength(1));
      expect(events[0].data, 'orphan');
    });

    test('comment-only stream produces no events', () async {
      final events = await parse([': comment1', ': comment2']);
      expect(events, isEmpty);
    });

    test('empty id field sets id to empty string', () async {
      final events = await parse([
        'id: ',
        'data: hello',
        '',
      ]);
      expect(events[0].id, '');
    });

    test('id with no value (no colon) sets id to empty string', () async {
      final events = await parse([
        'id',
        'data: hello',
        '',
      ]);
      expect(events[0].id, '');
    });

    test('event type with no value sets type to empty string', () async {
      final events = await parse([
        'event: ',
        'data: hello',
        '',
      ]);
      expect(events[0].type, '');
    });
  });
}
