/// Authentication strategy for Mercure hub requests.
///
/// The transport layer applies the chosen strategy to outgoing requests.
/// Priority per spec: Authorization header > query param > cookie.
///
/// See https://mercure.rocks/spec#authorization
sealed class MercureAuth {
  const MercureAuth();
}

/// Bearer token authentication via the `Authorization` header.
///
/// The transport sends `Authorization: Bearer <token>`.
/// Note: on web, `EventSource` does not support custom headers,
/// so the transport falls back to [QueryParam] for subscriptions.
final class Bearer extends MercureAuth {
  final String token;
  const Bearer(this.token);
}

/// Cookie-based authentication.
///
/// The transport sets the cookie on the request. On web,
/// `EventSource` sends cookies automatically with `withCredentials: true`.
final class Cookie extends MercureAuth {
  final String value;
  final String name;
  const Cookie(this.value, {this.name = 'mercureAuthorization'});
}

/// Query parameter authentication.
///
/// The token is appended as `?authorization=<token>` on the request URL.
/// This is the fallback for web subscribers that cannot use headers.
/// Not recommended due to token exposure in logs and browser history.
final class QueryParam extends MercureAuth {
  final String token;
  const QueryParam(this.token);
}
