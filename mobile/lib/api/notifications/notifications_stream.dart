// lib/api/notifications/notifications_stream.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config.dart';
import 'notifications_api.dart';

class NotificationsStream {
  NotificationsStream({Duration? initialRetry})
      : _nextRetry = initialRetry ?? const Duration(seconds: 1);

  final StreamController<AppNotification> _controller =
      StreamController<AppNotification>.broadcast();

  HttpClient? _client;
  StreamSubscription<String>? _subscription;
  Timer? _reconnectTimer;
  Duration _nextRetry;
  String? _buffer;
  bool _closed = false;
  Future<String?> Function()? _tokenProvider;

  Stream<AppNotification> get stream => _controller.stream;

  void configure({required Future<String?> Function() tokenProvider}) {
    _tokenProvider = tokenProvider;
  }

  Future<void> connect() async {
    if (_closed || _subscription != null) return;
    try {
      final String? token = await _tokenProvider?.call();
      if (token == null || token.isEmpty) {
        _scheduleReconnect();
        return;
      }

      final HttpClient client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(minutes: 5);
      _client = client;

      final Uri uri = Uri.parse('${ApiConfig.baseUrl}/notifications/stream');
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        client.close(force: true);
        _client = null;
        _scheduleReconnect();
        return;
      }

      _nextRetry = const Duration(seconds: 1);

      _subscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleLine,
            onError: (_) => _scheduleReconnect(),
            onDone: _scheduleReconnect,
            cancelOnError: true,
          );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleLine(String line) {
    if (line.isEmpty) {
      final String? data = _buffer;
      _buffer = null;
      if (data == null || data.isEmpty) return;
      try {
        final Map<String, dynamic> json =
            (jsonDecode(data) as Map).cast<String, dynamic>();
        if (!_controller.isClosed) {
          _controller.add(AppNotification.fromJson(json));
        }
      } catch (_) {}
      return;
    }

    if (line.startsWith(':')) return;

    if (line.startsWith('data:')) {
      final String chunk = line.substring(5).trimLeft();
      _buffer = _buffer == null ? chunk : '$_buffer\n$chunk';
    }
  }

  void _scheduleReconnect() {
    _cleanupConnection();
    if (_closed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_nextRetry, connect);
    final int ms = (_nextRetry.inMilliseconds * 2).clamp(1000, 30000);
    _nextRetry = Duration(milliseconds: ms);
  }

  void _cleanupConnection() {
    _subscription?.cancel();
    _subscription = null;
    _buffer = null;
    _client?.close(force: true);
    _client = null;
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupConnection();
    await _controller.close();
  }
}