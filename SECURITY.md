# Security Policy

## Scope

This policy covers the **mercure_dart** Dart package — the client library for the [Mercure protocol](https://mercure.rocks). It does **not** cover the Mercure hub server itself. For hub security issues, refer to [dunglas/mercure](https://github.com/dunglas/mercure/security).

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Instead, please report them privately:

1. **GitHub Security Advisories** (preferred) — go to [Security Advisories](https://github.com/owlnext/mercure_dart/security/advisories) and click "Report a vulnerability".
2. **Email** — contact the maintainers at the email listed in the repository owner's GitHub profile.

Include:

- Description of the vulnerability
- Steps to reproduce
- Impact assessment (what can an attacker do?)
- Suggested fix, if you have one

We will acknowledge receipt within **48 hours** and aim to provide a fix or mitigation within **7 days** for critical issues.

## Known Security Considerations

### Query parameter authentication

The Mercure protocol allows passing JWT tokens as a URL query parameter (`?authorization=<token>`). This is used as a fallback on web platforms where `EventSource` does not support custom headers.

**Risk**: Tokens in URLs may be logged by proxies, CDNs, browser history, and server access logs.

**Mitigation**: Prefer cookie-based authentication on web (`withCredentials: true`). Use query parameter auth only when cookies are not an option. On non-web platforms (mobile, desktop, server), the package uses the `Authorization` header by default.

### Token handling

This package does not store, cache, or persist tokens. Tokens are passed by the caller and used only for the duration of the request. The caller is responsible for secure token storage and rotation.
