import 'package:mercure_dart/src/models/publish_options.dart';
import 'package:test/test.dart';

void main() {
  group('PublishOptions', () {
    test('constructs with required topics only', () {
      final opts = PublishOptions(topics: ['https://example.com/foo']);
      expect(opts.topics, ['https://example.com/foo']);
      expect(opts.data, isNull);
      expect(opts.private, isFalse);
      expect(opts.id, isNull);
      expect(opts.type, isNull);
      expect(opts.retry, isNull);
    });

    group('toFormFields', () {
      test('single topic with data', () {
        final opts = PublishOptions(
          topics: ['https://example.com/foo'],
          data: 'the content',
        );
        final fields = opts.toFormFields();
        expect(fields, hasLength(2));
        expect(fields[0].key, 'topic');
        expect(fields[0].value, 'https://example.com/foo');
        expect(fields[1].key, 'data');
        expect(fields[1].value, 'the content');
      });

      test('multiple topics produce repeated topic fields', () {
        final opts = PublishOptions(
          topics: [
            'https://example.com/foo',
            'https://example.com/bar',
          ],
        );
        final fields = opts.toFormFields();
        final topicFields =
            fields.where((e) => e.key == 'topic').map((e) => e.value).toList();
        expect(topicFields, [
          'https://example.com/foo',
          'https://example.com/bar',
        ]);
      });

      test('private=on when private is true', () {
        final opts = PublishOptions(
          topics: ['t'],
          private: true,
        );
        final fields = opts.toFormFields();
        final privateField = fields.firstWhere((e) => e.key == 'private');
        expect(privateField.value, 'on');
      });

      test('private field absent when false', () {
        final opts = PublishOptions(topics: ['t']);
        final fields = opts.toFormFields();
        expect(
          fields.where((e) => e.key == 'private'),
          isEmpty,
        );
      });

      test('all optional fields', () {
        final opts = PublishOptions(
          topics: ['t'],
          data: 'd',
          private: true,
          id: 'my-id',
          type: 'my-type',
          retry: 3000,
        );
        final fields = opts.toFormFields();
        final keys = fields.map((e) => e.key).toList();
        expect(keys, ['topic', 'data', 'private', 'id', 'type', 'retry']);
        expect(
          fields.firstWhere((e) => e.key == 'retry').value,
          '3000',
        );
      });

      test('null data is omitted', () {
        final opts = PublishOptions(topics: ['t']);
        final fields = opts.toFormFields();
        expect(fields.where((e) => e.key == 'data'), isEmpty);
      });
    });

    group('topic validation', () {
      test('throws on empty topics list', () {
        expect(
          () => PublishOptions(topics: []),
          throwsArgumentError,
        );
      });

      test('throws on empty topic string', () {
        expect(
          () => PublishOptions(topics: ['']),
          throwsArgumentError,
        );
      });

      test('throws when one topic is empty among valid ones', () {
        expect(
          () => PublishOptions(topics: ['https://example.com/ok', '']),
          throwsArgumentError,
        );
      });
    });
  });
}
