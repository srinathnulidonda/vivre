// lib/api/health/health_api.dart
import 'package:dio/dio.dart';

import '../api_exception.dart';
import '../config.dart';

class DailyMetricsSummary {
  final String id;
  final DateTime metricDate;
  final int steps;
  final double distanceMeters;
  final double activeCalories;

  const DailyMetricsSummary({
    required this.id,
    required this.metricDate,
    required this.steps,
    required this.distanceMeters,
    required this.activeCalories,
  });

  factory DailyMetricsSummary.fromJson(Map<String, dynamic> json) {
    return DailyMetricsSummary(
      id: json['id'] as String,
      metricDate: DateTime.parse(json['metric_date'] as String),
      steps: json['steps'] as int? ?? 0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
      activeCalories: (json['active_calories'] as num?)?.toDouble() ?? 0,
    );
  }

  double get distanceKm => distanceMeters / 1000;

  bool get isToday {
    final DateTime now = DateTime.now();
    return metricDate.year == now.year &&
        metricDate.month == now.month &&
        metricDate.day == now.day;
  }
}

class SleepSummary {
  final String id;
  final DateTime sleepDate;
  final DateTime startAt;
  final DateTime endAt;
  final int durationMinutes;
  final String? quality;

  const SleepSummary({
    required this.id,
    required this.sleepDate,
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    required this.quality,
  });

  factory SleepSummary.fromJson(Map<String, dynamic> json) {
    return SleepSummary(
      id: json['id'] as String,
      sleepDate: DateTime.parse(json['sleep_date'] as String),
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      quality: json['quality'] as String?,
    );
  }

  bool get isToday {
    final DateTime now = DateTime.now();
    return sleepDate.year == now.year &&
        sleepDate.month == now.month &&
        sleepDate.day == now.day;
  }

  String get durationLabel {
    final int hours = durationMinutes ~/ 60;
    final int minutes = durationMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}

class WorkoutSummary {
  final String id;
  final String workoutType;
  final DateTime startAt;
  final DateTime? endAt;
  final int? durationMinutes;
  final double? calories;
  final double? distanceMeters;

  const WorkoutSummary({
    required this.id,
    required this.workoutType,
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    required this.calories,
    required this.distanceMeters,
  });

  factory WorkoutSummary.fromJson(Map<String, dynamic> json) {
    return WorkoutSummary(
      id: json['id'] as String,
      workoutType: json['workout_type'] as String,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: json['end_at'] != null
          ? DateTime.parse(json['end_at'] as String)
          : null,
      durationMinutes: json['duration_minutes'] as int?,
      calories: (json['calories'] as num?)?.toDouble(),
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
    );
  }

  double? get distanceKm =>
      distanceMeters == null ? null : distanceMeters! / 1000;

  String get durationLabel {
    final int minutes = durationMinutes ?? 0;
    if (minutes < 60) return '${minutes} min';
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  String get timeLabel {
    final DateTime local = startAt.toLocal();
    final String h = local.hour.toString().padLeft(2, '0');
    final String m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

enum DevicePlatform {
  appleHealth('apple_health', 'Apple Health'),
  googleHealthConnect('google_health_connect', 'Google Health Connect'),
  fitbit('fitbit', 'Fitbit'),
  garmin('garmin', 'Garmin'),
  other('other', 'Other');

  const DevicePlatform(this.value, this.label);
  final String value;
  final String label;

  static DevicePlatform fromValue(String value) {
    for (final DevicePlatform p in DevicePlatform.values) {
      if (p.value == value) return p;
    }
    return DevicePlatform.other;
  }
}

class DeviceConnectionSummary {
  final String id;
  final DevicePlatform platform;
  final String status;
  final DateTime? connectedAt;
  final DateTime? disconnectedAt;

  const DeviceConnectionSummary({
    required this.id,
    required this.platform,
    required this.status,
    required this.connectedAt,
    required this.disconnectedAt,
  });

  factory DeviceConnectionSummary.fromJson(Map<String, dynamic> json) {
    return DeviceConnectionSummary(
      id: json['id'] as String,
      platform: DevicePlatform.fromValue(json['platform'] as String),
      status: json['status'] as String? ?? 'connected',
      connectedAt: json['connected_at'] != null
          ? DateTime.parse(json['connected_at'] as String)
          : null,
      disconnectedAt: json['disconnected_at'] != null
          ? DateTime.parse(json['disconnected_at'] as String)
          : null,
    );
  }

  bool get isConnected => status == 'connected';
}

class HealthApi {
  final Dio _dio;

  HealthApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  static String _date(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  Future<List<DailyMetricsSummary>> listDailyMetrics({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/health-metrics/daily-metrics',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) =>
              DailyMetricsSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<DailyMetricsSummary?> todayMetrics() async {
    final List<DailyMetricsSummary> metrics = await listDailyMetrics(limit: 7);
    for (final DailyMetricsSummary m in metrics) {
      if (m.isToday) return m;
    }
    return null;
  }

  Future<DailyMetricsSummary> upsertDailyMetrics({
    required DateTime metricDate,
    required int steps,
    required double distanceMeters,
    required double activeCalories,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/health-metrics/daily-metrics',
        data: {
          'metric_date': _date(metricDate),
          'steps': steps,
          'distance_meters': distanceMeters,
          'active_calories': activeCalories,
        },
      );
      return DailyMetricsSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<SleepSummary>> listSleepRecords({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/health-metrics/sleep',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) =>
              SleepSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<SleepSummary?> todaySleep() async {
    final List<SleepSummary> records = await listSleepRecords(limit: 7);
    for (final SleepSummary r in records) {
      if (r.isToday) return r;
    }
    return null;
  }

  Future<SleepSummary> upsertSleepRecord({
    required DateTime sleepDate,
    required DateTime startAt,
    required DateTime endAt,
    required int durationMinutes,
    String? quality,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/health-metrics/sleep',
        data: {
          'sleep_date': _date(sleepDate),
          'start_at': startAt.toUtc().toIso8601String(),
          'end_at': endAt.toUtc().toIso8601String(),
          'duration_minutes': durationMinutes,
          if (quality != null) 'quality': quality,
        },
      );
      return SleepSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<WorkoutSummary>> listWorkouts({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/health-metrics/workouts',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) =>
              WorkoutSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<WorkoutSummary> createWorkout({
    required String workoutType,
    required DateTime startAt,
    DateTime? endAt,
    int? durationMinutes,
    double? calories,
    double? distanceMeters,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/health-metrics/workouts',
        data: {
          'workout_type': workoutType,
          'start_at': startAt.toUtc().toIso8601String(),
          if (endAt != null) 'end_at': endAt.toUtc().toIso8601String(),
          if (durationMinutes != null) 'duration_minutes': durationMinutes,
          if (calories != null) 'calories': calories,
          if (distanceMeters != null) 'distance_meters': distanceMeters,
        },
      );
      return WorkoutSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteWorkout(String workoutId) async {
    try {
      await _dio.delete('/health-metrics/workouts/$workoutId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<DeviceConnectionSummary>> listDeviceConnections() async {
    try {
      final Response<dynamic> response =
          await _dio.get('/health-metrics/device-connections');
      final List<dynamic> items = response.data as List<dynamic>;
      return items
          .map((e) => DeviceConnectionSummary.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<DeviceConnectionSummary> connectDevice(DevicePlatform platform) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/health-metrics/device-connections',
        data: {'platform': platform.value},
      );
      return DeviceConnectionSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<DeviceConnectionSummary> disconnectDevice(String connectionId) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/health-metrics/device-connections/$connectionId/disconnect',
      );
      return DeviceConnectionSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}