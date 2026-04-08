import 'dart:async';
// ignore: deprecated_member_use
import 'dart:html';

import '../auth/mercure_auth.dart';
import '../models/mercure_event.dart';
import '../models/publish_options.dart';
import 'mercure_transport.dart';

/// dart:html transport implementation using native [EventSource] and [HttpRequest].
///
/// The browser's EventSource handles SSE parsing and reconnection natively.
/// No [SseLineDecoder] or [SseParser] needed on this platform.
final class MercureTransportWeb extends MercureTransport {
  EventSource? _eventSource;

  MercureTransportWeb();

  @override
  Stream<MercureEvent> subscribe({
    required Uri hubUrl,
    required List<String> topics,
    MercureAuth? auth,
    String? lastEventId,
  }) {
    final controller = StreamController<MercureEvent>();
    final url = _buildSubscribeUrl(hubUrl, topics, auth, lastEventId);

    // EventSource sends cookies automatically with withCredentials: true
    final useCookies = auth is Cookie;
    final eventSource = EventSource(
      url.toString(),
      withCredentials: useCookies,
    );
    _eventSource = eventSource;

    eventSource.onMessage.listen((MessageEvent event) {
      controller.add(MercureEvent(
        id: event.lastEventId.isEmpty ? null : event.lastEventId,
        type: event.type == 'message' ? null : event.type,
        data: event.data as String? ?? '',
      ));
    });

    eventSource.onError.listen((Event event) {
      // EventSource reconnects automatically on network errors.
      // We only forward the error if the connection is permanently closed.
      if (eventSource.readyState == EventSource.CLOSED) {
        controller.addError(
          StateError('EventSource connection closed permanently.'),
        );
        controller.close();
      }
    });

    controller.onCancel = () {
      eventSource.close();
      _eventSource = null;
    };

    return controller.stream;
  }

  @override
  Future<String> publish({
    required Uri hubUrl,
    required MercureAuth auth,
    required PublishOptions options,
  }) async {
    final body = _encodeFormFields(options.toFormFields());

    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
    };

    // Apply auth header for publish (fetch supports custom headers)
    switch (auth) {
      case Bearer(:final token):
        headers['Authorization'] = 'Bearer $token';
      case Cookie():
        // Cookies are sent automatically by the browser
        break;
      case QueryParam(:final token):
        hubUrl = hubUrl.replace(queryParameters: {
          ...hubUrl.queryParameters,
          'authorization': token,
        });
    }

    final response = await HttpRequest.request(
      hubUrl.toString(),
      method: 'POST',
      requestHeaders: headers,
      sendData: body,
      withCredentials: auth is Cookie,
    );

    if (response.status != 200) {
      throw StateError(
        'Publish failed: ${response.status} ${response.responseText}',
      );
    }

    return (response.responseText ?? '').trim();
  }

  @override
  Future<TransportResponse> get(Uri url, {MercureAuth? auth}) async {
    final headers = <String, String>{};
    var requestUrl = url;

    switch (auth) {
      case Bearer(:final token):
        headers['Authorization'] = 'Bearer $token';
      case Cookie():
        break;
      case QueryParam(:final token):
        requestUrl = url.replace(queryParameters: {
          ...url.queryParameters,
          'authorization': token,
        });
      case null:
        break;
    }

    final response = await HttpRequest.request(
      requestUrl.toString(),
      method: 'GET',
      requestHeaders: headers,
      withCredentials: auth is Cookie,
    );

    final responseHeaders = <String, String>{};
    response.responseHeaders.forEach((key, value) {
      responseHeaders[key] = value;
    });

    return TransportResponse(
      statusCode: response.status ?? 0,
      headers: responseHeaders,
      body: response.responseText ?? '',
    );
  }

  @override
  void close() {
    _eventSource?.close();
    _eventSource = null;
  }

  /// Builds the subscribe URL with topic query parameters.
  ///
  /// On web, bearer auth falls back to query param since
  /// EventSource doesn't support custom headers.
  Uri _buildSubscribeUrl(
    Uri hubUrl,
    List<String> topics,
    MercureAuth? auth,
    String? lastEventId,
  ) {
    final queryParams = <String, List<String>>{};

    hubUrl.queryParametersAll.forEach((key, values) {
      queryParams[key] = List.of(values);
    });

    queryParams['topic'] = topics;

    // Bearer falls back to query param for EventSource
    if (auth is Bearer) {
      queryParams['authorization'] = [auth.token];
    } else if (auth is QueryParam) {
      queryParams['authorization'] = [auth.token];
    }

    // lastEventId as query param for initial connection
    if (lastEventId != null) {
      queryParams['Last-Event-ID'] = [lastEventId];
    }

    return hubUrl.replace(queryParameters: queryParams);
  }

  /// Encodes form fields as application/x-www-form-urlencoded.
  String _encodeFormFields(List<MapEntry<String, String>> fields) {
    return fields
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
  }
}

/// Factory function matching the stub's signature.
MercureTransport createMercureTransport() => MercureTransportWeb();
