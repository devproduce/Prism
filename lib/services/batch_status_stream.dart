import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:prism/utils/constants.dart';

/// Server-Sent Events client for batch status stream under /images/batch/.
/// Uses package:http streaming (http 1.x). No eventsource package (http 0.13 pin).
///
/// Spec: no Authorization header; batch UUID is the access token.
class BatchStatusStream {
  http.Client? _client;
  StreamSubscription<String>? _sub;
  bool _disposed = false;
  int _generation = 0;

  static bool isTerminalStatus(String status) {
    switch (status) {
      case 'completed':
      case 'failed':
      case 'error':
      case 'timeout':
        return true;
      default:
        return false;
    }
  }

  void disconnect() {
    _disposed = true;
    _generation++;
    unawaited(_sub?.cancel());
    _sub = null;
    _client?.close();
    _client = null;
  }

  /// Opens the SSE connection and returns once the response stream is subscribed.
  /// Parses `status` SSE events and forwards status, message, and error to the callback.
  /// On handshake failure, stream errors, or unexpected disconnect, reports via onConnectionError so the caller can start REST polling fallback.
  Future<void> connect({
    required String batchId,
    required void Function(String status, String? message, String? error)
        onStatus,
    required void Function(Object error) onConnectionError,
  }) async {
    disconnect();
    _disposed = false;
    final gen = _generation;

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/images/batch/$batchId/stream',
    );
    final client = http.Client();
    _client = client;

    try {
      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';
      // Intentionally no Authorization (per API spec).

      final streamed = await client.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('SSE connect'),
      );

      if (streamed.statusCode != 200) {
        onConnectionError(
          StateError('SSE HTTP ${streamed.statusCode}'),
        );
        disconnect();
        return;
      }

      final parser = _SseEventParser(
        onEventBlock: (eventName, dataPayload) {
          if (_disposed || gen != _generation) return;
          if (eventName == 'heartbeat' || dataPayload.trim() == 'ping') {
            return;
          }
          if (eventName != null &&
              eventName != 'status' &&
              !_looksLikeStatusJson(dataPayload)) {
            return;
          }
          _emitStatusFromJson(dataPayload, onStatus);
        },
      );

      var carry = '';
      _sub = streamed.stream.transform(utf8.decoder).listen(
        (chunk) {
          if (_disposed || gen != _generation) return;
          carry += chunk;
          while (true) {
            final nl = carry.indexOf('\n');
            if (nl == -1) break;
            var line = carry.substring(0, nl);
            carry = carry.substring(nl + 1);
            if (line.endsWith('\r')) {
              line = line.substring(0, line.length - 1);
            }
            parser.addLine(line);
          }
        },
        onError: (Object e, StackTrace _) {
          if (!_disposed && gen == _generation) {
            onConnectionError(e);
          }
          if (gen == _generation) disconnect();
        },
        onDone: () {
          if (!_disposed && gen == _generation) {
            onConnectionError(StateError('SSE connection closed'));
          }
          if (gen == _generation) disconnect();
        },
        cancelOnError: false,
      );
    } catch (e, _) {
      if (!_disposed) {
        onConnectionError(e);
      }
      disconnect();
    }
  }

  static bool _looksLikeStatusJson(String data) {
    final t = data.trim();
    return t.startsWith('{') && t.contains('"status"');
  }

  static void _emitStatusFromJson(
    String data,
    void Function(String status, String? message, String? error) onStatus,
  ) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      final statusRaw = map['status'];
      if (statusRaw is! String) return;
      final String status = statusRaw;
      final messageRaw = map['message'];
      final String? message = messageRaw is String ? messageRaw : null;
      final errRaw = map['error'];
      final String? err = errRaw is String ? errRaw : null;
      onStatus(status, message, err);
    } catch (_) {
      // ignore malformed chunks
    }
  }
}

class _SseEventParser {
  _SseEventParser({required this.onEventBlock});

  final void Function(String? eventName, String data) onEventBlock;

  String? _event;
  final List<String> _dataLines = [];

  void addLine(String line) {
    if (line.isEmpty) {
      if (_dataLines.isNotEmpty) {
        final payload = _dataLines.join('\n');
        final ev = _event;
        _event = null;
        _dataLines.clear();
        onEventBlock(ev, payload);
      }
      return;
    }
    if (line.startsWith(':')) {
      return;
    }
    final colon = line.indexOf(':');
    if (colon == -1) {
      return;
    }
    final field = line.substring(0, colon);
    var value = line.substring(colon + 1);
    if (value.startsWith(' ')) {
      value = value.substring(1);
    }
    if (field == 'event') {
      _event = value.trim();
    } else if (field == 'data') {
      _dataLines.add(value);
    }
  }
}


