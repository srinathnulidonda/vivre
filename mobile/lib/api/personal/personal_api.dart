// lib/api/personal/personal_api.dart
import 'package:dio/dio.dart';

import '../api_exception.dart';
import '../config.dart';

class GoalSummary {
  final String id;
  final String title;
  final String? description;
  final String status;
  final DateTime? targetDate;
  final DateTime createdAt;

  const GoalSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.targetDate,
    required this.createdAt,
  });

  factory GoalSummary.fromJson(Map<String, dynamic> json) {
    return GoalSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isActive => status == 'active';
}

class KeyResultSummary {
  final String id;
  final String goalId;
  final String title;
  final double targetValue;
  final double currentValue;
  final String unit;

  const KeyResultSummary({
    required this.id,
    required this.goalId,
    required this.title,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
  });

  factory KeyResultSummary.fromJson(Map<String, dynamic> json) {
    return KeyResultSummary(
      id: json['id'] as String,
      goalId: json['goal_id'] as String,
      title: json['title'] as String,
      targetValue: (json['target_value'] as num).toDouble(),
      currentValue: (json['current_value'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }

  double get progress =>
      targetValue <= 0 ? 0 : (currentValue / targetValue).clamp(0.0, 1.0);
}

class GoalDetail {
  final GoalSummary goal;
  final List<KeyResultSummary> keyResults;

  const GoalDetail({required this.goal, required this.keyResults});
}

class HabitSummary {
  final String id;
  final String name;
  final String frequency;
  final int targetCount;
  final bool isArchived;

  const HabitSummary({
    required this.id,
    required this.name,
    required this.frequency,
    required this.targetCount,
    required this.isArchived,
  });

  factory HabitSummary.fromJson(Map<String, dynamic> json) {
    return HabitSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      frequency: json['frequency'] as String? ?? 'daily',
      targetCount: json['target_count'] as int? ?? 1,
      isArchived: json['is_archived'] as bool? ?? false,
    );
  }
}

class HabitLogSummary {
  final String id;
  final String habitId;
  final DateTime date;
  final int count;

  const HabitLogSummary({
    required this.id,
    required this.habitId,
    required this.date,
    required this.count,
  });

  factory HabitLogSummary.fromJson(Map<String, dynamic> json) {
    return HabitLogSummary(
      id: json['id'] as String,
      habitId: json['habit_id'] as String,
      date: DateTime.parse(json['date'] as String),
      count: json['count'] as int? ?? 1,
    );
  }

  bool get isToday {
    final DateTime now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

class JournalEntrySummary {
  final String id;
  final String? title;
  final String content;
  final String? mood;
  final DateTime entryDate;
  final DateTime createdAt;

  const JournalEntrySummary({
    required this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.entryDate,
    required this.createdAt,
  });

  factory JournalEntrySummary.fromJson(Map<String, dynamic> json) {
    return JournalEntrySummary(
      id: json['id'] as String,
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      mood: json['mood'] as String?,
      entryDate: DateTime.parse(json['entry_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get preview {
    final String flat = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length > 130 ? '${flat.substring(0, 130)}…' : flat;
  }
}

class PersonalApi {
  final Dio _dio;

  PersonalApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  static String _date(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<List<GoalSummary>> listGoals({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/personal/goals',
        queryParameters: {
          if (status != null) 'status': status,
          'limit': limit,
          'offset': offset,
        },
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) => GoalSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<GoalDetail> getGoalDetail(String goalId) async {
    try {
      final Response<dynamic> response =
          await _dio.get('/personal/goals/$goalId');
      final Map<String, dynamic> json =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> raw =
          json['key_results'] as List<dynamic>? ?? const [];
      return GoalDetail(
        goal: GoalSummary.fromJson(json),
        keyResults: raw
            .map((e) =>
                KeyResultSummary.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<GoalSummary> createGoal({
    required String title,
    String? description,
    DateTime? targetDate,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/personal/goals',
        data: {
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (targetDate != null) 'target_date': _date(targetDate),
        },
      );
      return GoalSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<GoalSummary> updateGoal(
    String goalId, {
    String? title,
    String? description,
    String? status,
    DateTime? targetDate,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch(
        '/personal/goals/$goalId',
        data: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (status != null) 'status': status,
          if (targetDate != null) 'target_date': _date(targetDate),
        },
      );
      return GoalSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteGoal(String goalId) async {
    try {
      await _dio.delete('/personal/goals/$goalId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<KeyResultSummary> createKeyResult(
    String goalId, {
    required String title,
    required double targetValue,
    double currentValue = 0.0,
    required String unit,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/personal/goals/$goalId/key-results',
        data: {
          'title': title,
          'target_value': targetValue,
          'current_value': currentValue,
          'unit': unit,
        },
      );
      return KeyResultSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<KeyResultSummary> updateKeyResult(
    String keyResultId, {
    String? title,
    double? targetValue,
    double? currentValue,
    String? unit,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch(
        '/personal/key-results/$keyResultId',
        data: {
          if (title != null) 'title': title,
          if (targetValue != null) 'target_value': targetValue,
          if (currentValue != null) 'current_value': currentValue,
          if (unit != null) 'unit': unit,
        },
      );
      return KeyResultSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteKeyResult(String keyResultId) async {
    try {
      await _dio.delete('/personal/key-results/$keyResultId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<HabitSummary>> listHabits({
    bool includeArchived = false,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/personal/habits',
        queryParameters: {
          'include_archived': includeArchived,
          'limit': limit,
          'offset': offset,
        },
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) => HabitSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<HabitSummary> createHabit({
    required String name,
    String frequency = 'daily',
    int targetCount = 1,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/personal/habits',
        data: {
          'name': name,
          'frequency': frequency,
          'target_count': targetCount,
        },
      );
      return HabitSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<HabitSummary> updateHabit(
    String habitId, {
    String? name,
    String? frequency,
    int? targetCount,
    bool? isArchived,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch(
        '/personal/habits/$habitId',
        data: {
          if (name != null) 'name': name,
          if (frequency != null) 'frequency': frequency,
          if (targetCount != null) 'target_count': targetCount,
          if (isArchived != null) 'is_archived': isArchived,
        },
      );
      return HabitSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteHabit(String habitId) async {
    try {
      await _dio.delete('/personal/habits/$habitId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<HabitLogSummary> logHabit(
    String habitId, {
    required DateTime logDate,
    int count = 1,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/personal/habits/$habitId/logs',
        data: {'log_date': _date(logDate), 'count': count},
      );
      return HabitLogSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<HabitLogSummary>> listHabitLogs(
    String habitId, {
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/personal/habits/$habitId/logs',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) =>
              HabitLogSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<int> habitStreak(String habitId) async {
    try {
      final Response<dynamic> response =
          await _dio.get('/personal/habits/$habitId/streak');
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      return data['streak'] as int? ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<JournalEntrySummary>> listJournalEntries({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/personal/journal',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) => JournalEntrySummary.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<JournalEntrySummary> createJournalEntry({
    String? title,
    required String content,
    String? mood,
    required DateTime entryDate,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/personal/journal',
        data: {
          if (title != null && title.isNotEmpty) 'title': title,
          'content': content,
          if (mood != null) 'mood': mood,
          'entry_date': _date(entryDate),
        },
      );
      return JournalEntrySummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<JournalEntrySummary> updateJournalEntry(
    String entryId, {
    String? title,
    String? content,
    String? mood,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch(
        '/personal/journal/$entryId',
        data: {
          if (title != null) 'title': title,
          if (content != null) 'content': content,
          if (mood != null) 'mood': mood,
        },
      );
      return JournalEntrySummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteJournalEntry(String entryId) async {
    try {
      await _dio.delete('/personal/journal/$entryId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}