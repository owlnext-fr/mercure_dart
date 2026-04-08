import 'package:mercure_dart/src/models/mercure_event.dart';
import 'package:test/test.dart';

void main() {
  group('MercureEvent', () {
    test('constructs with required data only', () {
      const event = MercureEvent(data: 'hello');
      expect(event.data, 'hello');
      expect(event.id, isNull);
      expect(event.type, isNull);
      expect(event.retry, isNull);
    });

    test('constructs with all fields', () {
      const event = MercureEvent(
        id: 'urn:uuid:abc',
        type: 'update',
        data: '{"foo":"bar"}',
        retry: 5000,
      );
      expect(event.id, 'urn:uuid:abc');
      expect(event.type, 'update');
      expect(event.data, '{"foo":"bar"}');
      expect(event.retry, 5000);
    });

    test('allows empty data string', () {
      const event = MercureEvent(data: '');
      expect(event.data, '');
    });

    test('equality: same fields are equal', () {
      const a = MercureEvent(id: '1', type: 't', data: 'd', retry: 100);
      const b = MercureEvent(id: '1', type: 't', data: 'd', retry: 100);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality: different fields are not equal', () {
      const a = MercureEvent(data: 'a');
      const b = MercureEvent(data: 'b');
      expect(a, isNot(equals(b)));
    });

    test('toString contains all fields', () {
      const event = MercureEvent(id: '1', type: 't', data: 'd', retry: 100);
      final s = event.toString();
      expect(s, contains('id: 1'));
      expect(s, contains('type: t'));
      expect(s, contains('data: d'));
      expect(s, contains('retry: 100'));
    });
  });
}
