import '../auth/mercure_auth.dart';
import '../transport/mercure_transport.dart';
import '../transport/mercure_transport_factory.dart';

/// Result of a Mercure hub discovery.
final class DiscoveryResult {
  /// The discovered hub URL(s).
  ///
  /// A resource may advertise multiple hubs. Typically there is one.
  final List<Uri> hubUrls;

  /// The canonical topic URL for the resource (`rel=self`).
  ///
  /// Falls back to the requested resource URL if not present.
  final Uri topicUrl;

  const DiscoveryResult({
    required this.hubUrls,
    required this.topicUrl,
  });
}

/// Discovers the Mercure hub URL(s) for a given resource.
///
/// Performs a GET on [resourceUrl] and parses the `Link` headers
/// from the response to find `rel=mercure` (hub URLs) and
/// `rel=self` (canonical topic URL).
///
/// ```dart
/// final result = await discoverMercureHub(
///   'https://example.com/books/1',
/// );
/// print(result.hubUrls); // [https://example.com/.well-known/mercure]
/// print(result.topicUrl); // https://example.com/books/1
/// ```
Future<DiscoveryResult> discoverMercureHub(
  String resourceUrl, {
  MercureAuth? auth,
  MercureTransport? transport,
}) async {
  final t = transport ?? createMercureTransport();
  final ownsTransport = transport == null;

  try {
    final response = await t.get(Uri.parse(resourceUrl), auth: auth);

    final linkHeader = response.headers['link'];
    if (linkHeader == null) {
      throw StateError(
        'No Link header found in response from $resourceUrl',
      );
    }

    final links = parseLinkHeader(linkHeader);

    final hubUrls = links
        .where((l) => l.rel == 'mercure')
        .map((l) => Uri.parse(l.url))
        .toList(growable: false);

    if (hubUrls.isEmpty) {
      throw StateError(
        'No rel="mercure" Link found in response from $resourceUrl',
      );
    }

    final selfLinks = links.where((l) => l.rel == 'self');
    final topicUrl = selfLinks.isNotEmpty
        ? Uri.parse(selfLinks.first.url)
        : Uri.parse(resourceUrl);

    return DiscoveryResult(hubUrls: hubUrls, topicUrl: topicUrl);
  } finally {
    if (ownsTransport) t.close();
  }
}

/// A parsed entry from an HTTP `Link` header.
final class LinkEntry {
  final String url;
  final String? rel;
  final Map<String, String> attributes;

  const LinkEntry({
    required this.url,
    this.rel,
    this.attributes = const {},
  });
}

/// Parses an HTTP `Link` header value into a list of [LinkEntry].
///
/// Handles:
/// - Multiple links separated by `,`
/// - Attributes separated by `;`
/// - Quoted and unquoted attribute values
/// - Multiple `Link` header values joined with `, `
///
/// Example input:
/// `<https://hub.example.com>; rel="mercure", <https://example.com/foo>; rel="self"`
List<LinkEntry> parseLinkHeader(String header) {
  final entries = <LinkEntry>[];

  // Split on commas that are NOT inside angle brackets
  final linkStrings = _splitLinks(header);

  for (final linkStr in linkStrings) {
    final trimmed = linkStr.trim();
    if (trimmed.isEmpty) continue;

    // Extract URL from angle brackets
    final urlMatch = RegExp(r'<([^>]*)>').firstMatch(trimmed);
    if (urlMatch == null) continue;

    final url = urlMatch.group(1)!;
    final rest = trimmed.substring(urlMatch.end);

    // Parse attributes
    final attributes = <String, String>{};
    final attrPattern =
        RegExp(r';\s*(\w[\w.-]*)(?:\s*=\s*(?:"([^"]*)"|([^\s;,]*)))?');
    for (final match in attrPattern.allMatches(rest)) {
      final key = match.group(1)!.toLowerCase();
      final value = match.group(2) ?? match.group(3) ?? '';
      attributes[key] = value;
    }

    entries.add(LinkEntry(
      url: url,
      rel: attributes['rel'],
      attributes: attributes,
    ));
  }

  return entries;
}

/// Splits a Link header value on `,` delimiters that are outside `< >`.
List<String> _splitLinks(String header) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;

  for (var i = 0; i < header.length; i++) {
    final c = header[i];
    if (c == '<') {
      depth++;
    } else if (c == '>') {
      depth--;
    } else if (c == ',' && depth == 0) {
      parts.add(header.substring(start, i));
      start = i + 1;
    }
  }

  parts.add(header.substring(start));
  return parts;
}
