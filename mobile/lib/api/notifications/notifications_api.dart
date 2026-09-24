// lib/api/notifications/notifications_api.dart
import 'package:dio/dio.dart';

import '../api_exception.dart';
import '../config.dart';

class AppNotification {
  final String id;
  final String notificationType;
  final String channel;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime? sentAt;
  final DateTime? failedAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.notificationType,
    required this.channel,
    required this.payload,
    required this.readAt,
    required this.sentAt,
    required this.failedAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      notificationType: json['notification_type'] as String,
      channel: json['channel'] as String,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      failedAt: json['failed_at'] != null
          ? DateTime.parse(json['failed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      notificationType: notificationType,
      channel: channel,
      payload: payload,
      readAt: readAt ?? this.readAt,
      sentAt: sentAt,
      failedAt: failedAt,
      createdAt: createdAt,
    );
  }

  bool get isRead => readAt != null;

  String get title {
    final Object? fromPayload = payload['title'];
    if (fromPayload is String && fromPayload.isNotEmpty) return fromPayload;
    return _fallbackTitle(notificationType);
  }

  String get body {
    final Object? fromPayload = payload['body'] ?? payload['message'];
    if (fromPayload is String && fromPayload.isNotEmpty) return fromPayload;
    return 'You have a new notification.';
  }

  static String _fallbackTitle(String type) {
    final String normalized = type.replaceAll('_', ' ').toLowerCase();
    if (normalized.isEmpty) return 'Notification';
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class NotificationPreferences {
  final bool pushTasks;
  final bool pushHabits;
  final bool pushReviews;
  final bool pushGoals;
  final bool pushMilestones;
  final bool emailDigest;
  final bool emailReviews;
  final bool inappTasks;
  final bool inappHabits;
  final bool inappReviews;
  final bool inappGoals;
  final bool inappMilestones;

  const NotificationPreferences({
    required this.pushTasks,
    required this.pushHabits,
    required this.pushReviews,
    required this.pushGoals,
    required this.pushMilestones,
    required this.emailDigest,
    required this.emailReviews,
    required this.inappTasks,
    required this.inappHabits,
    required this.inappReviews,
    required this.inappGoals,
    required this.inappMilestones,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      pushTasks: json['push_tasks'] as bool? ?? true,
      pushHabits: json['push_habits'] as bool? ?? true,
      pushReviews: json['push_reviews'] as bool? ?? true,
      pushGoals: json['push_goals'] as bool? ?? true,
      pushMilestones: json['push_milestones'] as bool? ?? true,
      emailDigest: json['email_digest'] as bool? ?? true,
      emailReviews: json['email_reviews'] as bool? ?? true,
      inappTasks: json['inapp_tasks'] as bool? ?? true,
      inappHabits: json['inapp_habits'] as bool? ?? true,
      inappReviews: json['inapp_reviews'] as bool? ?? true,
      inappGoals: json['inapp_goals'] as bool? ?? true,
      inappMilestones: json['inapp_milestones'] as bool? ?? true,
    );
  }

  NotificationPreferences copyWith({
    bool? pushTasks,
    bool? pushHabits,
    bool? pushReviews,
    bool? pushGoals,
    bool? pushMilestones,
    bool? emailDigest,
    bool? emailReviews,
    bool? inappTasks,
    bool? inappHabits,
    bool? inappReviews,
    bool? inappGoals,
    bool? inappMilestones,
  }) {
    return NotificationPreferences(
      pushTasks: pushTasks ?? this.pushTasks,
      pushHabits: pushHabits ?? this.pushHabits,
      pushReviews: pushReviews ?? this.pushReviews,
      pushGoals: pushGoals ?? this.pushGoals,
      pushMilestones: pushMilestones ?? this.pushMilestones,
      emailDigest: emailDigest ?? this.emailDigest,
      emailReviews: emailReviews ?? this.emailReviews,
      inappTasks: inappTasks ?? this.inappTasks,
      inappHabits: inappHabits ?? this.inappHabits,
      inappReviews: inappReviews ?? this.inappReviews,
      inappGoals: inappGoals ?? this.inappGoals,
      inappMilestones: inappMilestones ?? this.inappMilestones,
    );
  }
}

class NotificationsApi {
  final Dio _dio;

  NotificationsApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  Future<int> unreadCount() async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/notifications',
        queryParameters: const {'unread_only': true, 'limit': 1, 'offset': 0},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      return data['total'] as int? ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<AppNotification>> list({
    bool unreadOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/notifications',
        queryParameters: {
          'unread_only': unreadOnly,
          'limit': limit,
          'offset': offset,
        },
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) =>
              AppNotification.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _dio.patch('/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<int> markAllRead() async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/notifications/read-all',
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      return data['marked_count'] as int? ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> registerDeviceToken(String token) async {
    try {
      await _dio.post(
        '/notifications/device-tokens',
        data: {'device_token': token},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> unregisterDeviceToken(String token) async {
    try {
      await _dio.delete(
        '/notifications/device-tokens',
        data: {'device_token': token},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<NotificationPreferences> getPreferences() async {
    try {
      final Response<dynamic> response =
          await _dio.get('/notifications/preferences');
      return NotificationPreferences.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<NotificationPreferences> updatePreferences({
    bool? pushTasks,
    bool? pushHabits,
    bool? pushReviews,
    bool? pushGoals,
    bool? pushMilestones,
    bool? emailDigest,
    bool? emailReviews,
    bool? inappTasks,
    bool? inappHabits,
    bool? inappReviews,
    bool? inappGoals,
    bool? inappMilestones,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch(
        '/notifications/preferences',
        data: {
          if (pushTasks != null) 'push_tasks': pushTasks,
          if (pushHabits != null) 'push_habits': pushHabits,
          if (pushReviews != null) 'push_reviews': pushReviews,
          if (pushGoals != null) 'push_goals': pushGoals,
          if (pushMilestones != null) 'push_milestones': pushMilestones,
          if (emailDigest != null) 'email_digest': emailDigest,
          if (emailReviews != null) 'email_reviews': emailReviews,
          if (inappTasks != null) 'inapp_tasks': inappTasks,
          if (inappHabits != null) 'inapp_habits': inappHabits,
          if (inappReviews != null) 'inapp_reviews': inappReviews,
          if (inappGoals != null) 'inapp_goals': inappGoals,
          if (inappMilestones != null) 'inapp_milestones': inappMilestones,
        },
      );
      return NotificationPreferences.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}