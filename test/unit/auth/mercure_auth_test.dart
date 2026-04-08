import 'package:mercure_dart/src/auth/mercure_auth.dart';
import 'package:test/test.dart';

void main() {
  group('MercureAuth', () {
    test('Bearer holds a token', () {
      const auth = Bearer('my-jwt-token');
      expect(auth.token, 'my-jwt-token');
    });

    test('Cookie has default name', () {
      const auth = Cookie('cookie-value');
      expect(auth.value, 'cookie-value');
      expect(auth.name, 'mercureAuthorization');
    });

    test('Cookie accepts custom name', () {
      const auth = Cookie('val', name: 'customCookie');
      expect(auth.name, 'customCookie');
    });

    test('QueryParam holds a token', () {
      const auth = QueryParam('my-token');
      expect(auth.token, 'my-token');
    });

    test('sealed class exhaustive switch', () {
      const MercureAuth auth = Bearer('t');
      final result = switch (auth) {
        Bearer(:final token) => 'bearer:$token',
        Cookie(:final value, :final name) => 'cookie:$name=$value',
        QueryParam(:final token) => 'query:$token',
      };
      expect(result, 'bearer:t');
    });

    test('sealed class pattern matching on Cookie', () {
      const MercureAuth auth = Cookie('v', name: 'n');
      final result = switch (auth) {
        Bearer(:final token) => 'bearer:$token',
        Cookie(:final value, :final name) => 'cookie:$name=$value',
        QueryParam(:final token) => 'query:$token',
      };
      expect(result, 'cookie:n=v');
    });

    test('sealed class pattern matching on QueryParam', () {
      const MercureAuth auth = QueryParam('qp');
      final result = switch (auth) {
        Bearer(:final token) => 'bearer:$token',
        Cookie(:final value, :final name) => 'cookie:$name=$value',
        QueryParam(:final token) => 'query:$token',
      };
      expect(result, 'query:qp');
    });
  });
}
