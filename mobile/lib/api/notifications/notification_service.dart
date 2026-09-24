// lib/api/notifications/notification_service.dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'notifications_api.dart';
import 'notifications_stream.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final NotificationsApi _api = NotificationsApi();
  final StreamController<AppNotification> _incoming =
      StreamController<AppNotification>.broadcast();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  NotificationsStream? _stream;
  StreamSubscription<AppNotification>? _streamSub;
  Future<String?> Function()? _tokenProvider;
  bool _isRunning = false;

  Stream<AppNotification> get incoming => _incoming.stream;
  bool get isRunning => _isRunning;

  void configure({required Future<String?> Function() tokenProvider}) {
    _tokenProvider = tokenProvider;
  }

  Future<void> start() async {
    if (_isRunning || _tokenProvider == null) return;
    _isRunning = true;

    final NotificationsStream stream = NotificationsStream()
      ..configure(tokenProvider: _tokenProvider!);
    _stream = stream;

    _streamSub = stream.stream.listen((AppNotification notification) {
      if (!notification.isRead) {
        unreadCount.value = unreadCount.value + 1;
      }
      if (!_incoming.isClosed) _incoming.add(notification);
    });

    stream.connect();
    _refreshUnreadCount();
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;

    final StreamSubscription<AppNotification>? sub = _streamSub;
    final NotificationsStream? stream = _stream;
    _streamSub = null;
    _stream = null;

    await sub?.cancel();
    await stream?.dispose();

    unreadCount.value = 0;
  }

  Future<void> refreshUnreadCount() => _refreshUnreadCount();

  void markLocalRead() {
    final int current = unreadCount.value;
    if (current > 0) unreadCount.value = current - 1;
  }

  void markAllLocalRead() {
    if (unreadCount.value != 0) unreadCount.value = 0;
  }

  Future<void> _refreshUnreadCount() async {
    try {
      unreadCount.value = await _api.unreadCount();
    } catch (_) {}
  }
}