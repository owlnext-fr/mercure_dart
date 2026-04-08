import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../auth/mercure_auth.dart';
import '../models/mercure_event.dart';
import '../models/publish_options.dart';
import '../sse/sse_line_decoder.dart';
import '../sse/sse_parser.dart';
import 'mercure_transport.dart';

/// dart:io transport implementation using [HttpClient].
///
/// Handles SSE via manual parsing ([SseLineDecoder] + [SseParser]),
/// reconnection with exponential backoff and Last-Event-ID,
/// and form-urlencoded publishing.
final class MercureTransportIo extends MercureTransport {
  final HttpClient _client = HttpClient();
  final Random _random = Random();

  /// Default reconnection delay in milliseconds (used as base for backoff).
  static const _defaultRetryMs = 3000;

  /// Maximum reconnection delay in milliseconds.
  static const _maxRetryMs = 60000;

  MercureTransportIo();

  @override
  Stream<MercureEvent> subscribe({
    required Uri hubUrl,
    required List<String> topics,
    MercureAuth? auth,
    String? lastEventId,
  }) {
    final controller = StreamController<MercureEvent>();
    var baseRetryMs = _defaultRetryMs;
    var currentLastEventId = lastEventId;
    var closed = false;
    var attempt = 0;
    HttpClientRequest? activeRequest;

    Future<void> connect() async {
      while (!closed) {
        try {
          final url = _buildSubscribeUrl(hubUrl, topics, auth);
          final request = await _client.getUrl(url);
          activeRequest = request;

          request.headers.set('Accept', 'text/event-stream');
          request.headers.set('Cache-Control', 'no-cache');

          if (currentLastEventId != null) {
            request.headers.set('Last-Event-ID', currentLastEventId!);
          }

          _applyAuthToRequest(request, auth);

          final response = await request.close();

          if (response.statusCode != 200) {
            final body =
                await response.transform(const SystemEncoding().decoder).join();
            controller.addError(
              HttpException(
                'Subscription failed: ${response.statusCode} $body',
                uri: url,
              ),
            );
            // Don't reconnect on auth errors
            if (response.statusCode == 401 || response.statusCode == 403) {
              if (!closed) {
                closed = true;
                await controller.close();
              }
              return;
            }
            // Reconnect with backoff on other errors
            await _backoff(baseRetryMs, attempt++);
            continue;
          }

          // Connection succeeded — reset attempt counter
          attempt = 0;

          await for (final event in response
              .transform(const SseLineDecoder())
              .transform(const SseParser())) {
            if (closed) break;

            // Update base retry delay if the server sent a hint
            if (event.retry != null) {
              baseRetryMs = event.retry!;
            }

            // Track last event ID for reconnection
            if (event.id != null) {
              currentLastEventId = event.id;
            }

            controller.add(event);
          }

          // Stream ended normally — reconnect unless closed
          if (closed) break;
          await _backoff(baseRetryMs, attempt++);
        } catch (e, st) {
          if (closed) break;
          controller.addError(e, st);
          await _backoff(baseRetryMs, attempt++);
        }
      }
    }

    controller.onListen = () {
      connect();
    };
    controller.onCancel = () {
      closed = true;
      activeRequest?.abort();
    };

    return controller.stream;
  }

  /// Waits with exponential backoff and jitter.
  ///
  /// Delay = min(maxRetry, baseDelay * 2^attempt) + random jitter (0-25%).
  Future<void> _backoff(int baseMs, int attempt) {
    final exponential = baseMs * (1 << min(attempt, 10));
    final capped = min(exponential, _maxRetryMs);
    final jitter = (capped * 0.25 * _random.nextDouble()).round();
    return Future<void>.delayed(Duration(milliseconds: capped + jitter));
  }

  @override
  Future<String> publish({
    required Uri hubUrl,
    required MercureAuth auth,
    required PublishOptions options,
  }) async {
    final request = await _client.postUrl(hubUrl);
    request.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    _applyAuthToRequest(request, auth);

    final body = _encodeFormFields(options.toFormFields());
    request.write(body);

    final response = await request.close();
    final responseBody =
        await response.transform(const SystemEncoding().decoder).join();

    if (response.statusCode != 200) {
      throw HttpException(
        'Publish failed: ${response.statusCode} $responseBody',
        uri: hubUrl,
      );
    }

    return responseBody.trim();
  }

  @override
  Future<TransportResponse> get(Uri url, {MercureAuth? auth}) async {
    final request = await _client.getUrl(url);
    _applyAuthToRequest(request, auth);

    final response = await request.close();
    final body =
        await response.transform(const SystemEncoding().decoder).join();

    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });

    return TransportResponse(
      statusCode: response.statusCode,
      headers: headers,
      body: body,
    );
  }

  @override
  void close() {
    _client.close(force: true);
  }

  /// Builds the subscribe URL with topic query parameters.
  Uri _buildSubscribeUrl(
    Uri hubUrl,
    List<String> topics,
    MercureAuth? auth,
  ) {
    final queryParams = <String, List<String>>{};

    // Preserve existing query parameters
    hubUrl.queryParametersAll.forEach((key, values) {
      queryParams[key] = List.of(values);
    });

    // Add topics
    queryParams['topic'] = topics;

    // Add auth query param if needed
    if (auth is QueryParam) {
      queryParams['authorization'] = [auth.token];
    }

    return hubUrl.replace(queryParameters: queryParams);
  }

  /// Applies authentication to an HTTP request.
  void _applyAuthToRequest(HttpClientRequest request, MercureAuth? auth) {
    switch (auth) {
      case Bearer(:final token):
        request.headers.set('Authorization', 'Bearer $token');
      case Cookie(:final value, :final name):
        request.headers.set('Cookie', '$name=$value');
      case QueryParam():
        // Handled in URL building
        break;
      case null:
        break;
    }
  }

  /// Encodes form fields as application/x-www-form-urlencoded.
  ///
  /// Supports duplicate keys (e.g. multiple `topic` fields).
  String _encodeFormFields(List<MapEntry<String, String>> fields) {
    return fields
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }
}

/// Factory function matching the stub's signature.
MercureTransport createMercureTransport() => MercureTransportIo();
