import 'package:mercure_dart/src/discovery/mercure_discovery.dart';
import 'package:test/test.dart';

void main() {
  group('parseLinkHeader', () {
    test('parses a single link with rel', () {
      final links = parseLinkHeader(
        '<https://hub.example.com/.well-known/mercure>; rel="mercure"',
      );
      expect(links, hasLength(1));
      expect(links[0].url, 'https://hub.example.com/.well-known/mercure');
      expect(links[0].rel, 'mercure');
    });

    test('parses multiple links separated by comma', () {
      final links = parseLinkHeader(
        '<https://hub.example.com>; rel="mercure", '
        '<https://example.com/books/1>; rel="self"',
      );
      expect(links, hasLength(2));
      expect(links[0].rel, 'mercure');
      expect(links[1].rel, 'self');
      expect(links[1].url, 'https://example.com/books/1');
    });

    test('handles unquoted attribute values', () {
      final links = parseLinkHeader(
        '<https://hub.example.com>; rel=mercure',
      );
      expect(links, hasLength(1));
      expect(links[0].rel, 'mercure');
    });

    test('parses additional attributes', () {
      final links = parseLinkHeader(
        '<https://hub.example.com>; rel="mercure"; type="text/event-stream"',
      );
      expect(links[0].attributes['type'], 'text/event-stream');
    });

    test('handles URLs with commas inside angle brackets', () {
      // Unusual but valid
      final links = parseLinkHeader(
        '<https://example.com/a,b>; rel="mercure"',
      );
      expect(links, hasLength(1));
      expect(links[0].url, 'https://example.com/a,b');
    });

    test('handles multiple hubs', () {
      final links = parseLinkHeader(
        '<https://hub1.example.com>; rel="mercure", '
        '<https://hub2.example.com>; rel="mercure"',
      );
      final hubs = links.where((l) => l.rel == 'mercure').toList();
      expect(hubs, hasLength(2));
    });

    test('ignores links with no URL', () {
      final links = parseLinkHeader('rel="mercure"');
      expect(links, isEmpty);
    });

    test('handles empty header', () {
      final links = parseLinkHeader('');
      expect(links, isEmpty);
    });

    test('handles spaces around semicolons', () {
      final links = parseLinkHeader(
        '<https://hub.example.com> ; rel="mercure" ; type="sse"',
      );
      expect(links, hasLength(1));
      expect(links[0].rel, 'mercure');
    });

    test('attribute keys are lowercased', () {
      final links = parseLinkHeader(
        '<https://hub.example.com>; Rel="mercure"; Type="sse"',
      );
      expect(links[0].rel, 'mercure');
      expect(links[0].attributes['type'], 'sse');
    });

    test('link with no attributes', () {
      final links = parseLinkHeader('<https://example.com>');
      expect(links, hasLength(1));
      expect(links[0].url, 'https://example.com');
      expect(links[0].rel, isNull);
    });
  });
}
