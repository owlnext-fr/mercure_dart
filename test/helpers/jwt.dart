import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Minimal JWT HS256 generator for test purposes only.
///
/// Not intended for production use — no validation, no claims checking.
/// Uses package:crypto (transitive dev_dependency via package:test).
String generateJwt({
  required Map<String, dynamic> payload,
  required String secret,
}) {
  final header = {'alg': 'HS256', 'typ': 'JWT'};

  final encodedHeader = _base64UrlEncode(jsonEncode(header));
  final encodedPayload = _base64UrlEncode(jsonEncode(payload));
  final signingInput = '$encodedHeader.$encodedPayload';

  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = hmac.convert(utf8.encode(signingInput));
  final signature = _base64UrlEncodeBytes(Uint8List.fromList(digest.bytes));

  return '$signingInput.$signature';
}

/// Generates a Mercure publisher JWT.
String generatePublisherJwt({
  required String secret,
  List<String> publish = const ['*'],
}) {
  return generateJwt(
    payload: {
      'mercure': {'publish': publish},
    },
    secret: secret,
  );
}

/// Generates a Mercure subscriber JWT.
String generateSubscriberJwt({
  required String secret,
  List<String> subscribe = const ['*'],
  Map<String, dynamic>? payload,
}) {
  return generateJwt(
    payload: {
      'mercure': {
        'subscribe': subscribe,
        if (payload != null) 'payload': payload,
      },
    },
    secret: secret,
  );
}

String _base64UrlEncode(String input) {
  return _base64UrlEncodeBytes(utf8.encode(input));
}

String _base64UrlEncodeBytes(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}
