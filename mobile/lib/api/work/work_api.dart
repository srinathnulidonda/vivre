// lib/api/work/work_api.dart
import 'package:dio/dio.dart';

import '../api_exception.dart';
import '../config.dart';

class ProjectSummary {
  final String id;
  final String name;
  final String? description;
  final String? clientId;
  final String status;
  final String? coverImageUrl;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProjectSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.clientId,
    required this.status,
    required this.coverImageUrl,
    required this.startDate,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectSummary.fromJson(Map<String, dynamic> json) {
    return ProjectSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      clientId: json['client_id'] as String?,
      status: json['status'] as String? ?? 'active',
      coverImageUrl: json['cover_image_url'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
}

class ProjectDetail {
  final String id;
  final String name;
  final String? description;
  final String? clientId;
  final String status;
  final String? coverImageUrl;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int taskCount;
  final int completedTaskCount;
  final int milestoneCount;

  const ProjectDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.clientId,
    required this.status,
    required this.coverImageUrl,
    required this.startDate,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    required this.taskCount,
    required this.completedTaskCount,
    required this.milestoneCount,
  });

  factory ProjectDetail.fromJson(Map<String, dynamic> json) {
    return ProjectDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      clientId: json['client_id'] as String?,
      status: json['status'] as String? ?? 'active',
      coverImageUrl: json['cover_image_url'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'] as String)
          : null,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      taskCount: json['task_count'] as int? ?? 0,
      completedTaskCount: json['completed_task_count'] as int? ?? 0,
      milestoneCount: json['milestone_count'] as int? ?? 0,
    );
  }

  double get progress =>
      taskCount == 0 ? 0 : completedTaskCount / taskCount;
}

class MilestoneSummary {
  final String id;
  final String projectId;
  final String title;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;

  const MilestoneSummary({
    required this.id,
    required this.projectId,
    required this.title,
    required this.dueDate,
    required this.isCompleted,
    required this.completedAt,
  });

  factory MilestoneSummary.fromJson(Map<String, dynamic> json) {
    return MilestoneSummary(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      title: json['title'] as String,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }
}

class TaskSummary {
  final String id;
  final String? projectId;
  final String? milestoneId;
  final String? parentTaskId;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskSummary({
    required this.id,
    required this.projectId,
    required this.milestoneId,
    required this.parentTaskId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.completedAt,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskSummary.fromJson(Map<String, dynamic> json) {
    return TaskSummary(
      id: json['id'] as String,
      projectId: json['project_id'] as String?,
      milestoneId: json['milestone_id'] as String?,
      parentTaskId: json['parent_task_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'todo',
      priority: json['priority'] as String? ?? 'medium',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      position: json['position'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isDone => status == 'done';
  bool get isInProgress => status == 'in_progress';
  bool get isUrgent => priority == 'urgent' || priority == 'high';
}

class TaskDetail extends TaskSummary {
  final List<TaskSummary> subtasks;
  final List<String> dependencyIds;

  const TaskDetail({
    required super.id,
    required super.projectId,
    required super.milestoneId,
    required super.parentTaskId,
    required super.title,
    required super.description,
    required super.status,
    required super.priority,
    required super.dueDate,
    required super.completedAt,
    required super.position,
    required super.createdAt,
    required super.updatedAt,
    required this.subtasks,
    required this.dependencyIds,
  });

  factory TaskDetail.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSubtasks =
        json['subtasks'] as List<dynamic>? ?? const [];
    final List<dynamic> rawDeps =
        json['dependency_ids'] as List<dynamic>? ?? const [];
    return TaskDetail(
      id: json['id'] as String,
      projectId: json['project_id'] as String?,
      milestoneId: json['milestone_id'] as String?,
      parentTaskId: json['parent_task_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'todo',
      priority: json['priority'] as String? ?? 'medium',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      position: json['position'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      subtasks: rawSubtasks
          .map((dynamic e) =>
              TaskSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      dependencyIds: rawDeps.map((dynamic e) => e as String).toList(),
    );
  }
}

class FocusSessionSummary {
  final String id;
  final String? taskId;
  final String? projectId;
  final DateTime startAt;
  final DateTime? endAt;
  final int? durationSeconds;

  const FocusSessionSummary({
    required this.id,
    required this.taskId,
    required this.projectId,
    required this.startAt,
    required this.endAt,
    required this.durationSeconds,
  });

  factory FocusSessionSummary.fromJson(Map<String, dynamic> json) {
    return FocusSessionSummary(
      id: json['id'] as String,
      taskId: json['task_id'] as String?,
      projectId: json['project_id'] as String?,
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: json['end_at'] != null
          ? DateTime.parse(json['end_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  bool get isRunning => endAt == null;
}

class WorkApi {
  final Dio _dio;

  WorkApi({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  static String _date(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<List<ProjectSummary>> listProjects({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/work/projects',
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
          .map((e) => ProjectSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProjectDetail> getProject(String projectId) async {
    try {
      final Response<dynamic> response =
          await _dio.get('/work/projects/$projectId');
      return ProjectDetail.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProjectSummary> createProject({
    required String name,
    String? description,
    String? clientId,
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/work/projects',
        data: {
          'name': name,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (clientId != null) 'client_id': clientId,
          if (startDate != null) 'start_date': _date(startDate),
          if (dueDate != null) 'due_date': _date(dueDate),
        },
      );
      return ProjectSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<ProjectSummary> updateProject(
    String projectId, {
    String? name,
    String? description,
    String? status,
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch(
        '/work/projects/$projectId',
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (status != null) 'status': status,
          if (startDate != null) 'start_date': _date(startDate),
          if (dueDate != null) 'due_date': _date(dueDate),
        },
      );
      return ProjectSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      await _dio.delete('/work/projects/$projectId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<MilestoneSummary> createMilestone(
    String projectId, {
    required String title,
    DateTime? dueDate,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/work/projects/$projectId/milestones',
        data: {
          'title': title,
          if (dueDate != null) 'due_date': _date(dueDate),
        },
      );
      return MilestoneSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<MilestoneSummary> updateMilestone(
    String milestoneId, {
    String? title,
    DateTime? dueDate,
    bool? isCompleted,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch(
        '/work/milestones/$milestoneId',
        data: {
          if (title != null) 'title': title,
          if (dueDate != null) 'due_date': _date(dueDate),
          if (isCompleted != null) 'is_completed': isCompleted,
        },
      );
      return MilestoneSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteMilestone(String milestoneId) async {
    try {
      await _dio.delete('/work/milestones/$milestoneId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<TaskSummary>> listTasks({
    String? projectId,
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get(
        '/work/tasks',
        queryParameters: {
          if (projectId != null) 'project_id': projectId,
          if (status != null) 'status': status,
          'limit': limit,
          'offset': offset,
        },
      );
      final Map<String, dynamic> data =
          (response.data as Map).cast<String, dynamic>();
      final List<dynamic> items = data['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) => TaskSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<List<TaskSummary>> todayTasks() async {
    final List<TaskSummary> todo = await listTasks(status: 'todo', limit: 50);
    final List<TaskSummary> inProgress =
        await listTasks(status: 'in_progress', limit: 50);
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day);
    final DateTime end = start.add(const Duration(days: 1));

    return [...todo, ...inProgress].where((TaskSummary t) {
      final DateTime? due = t.dueDate;
      if (due == null) return false;
      final DateTime local = due.toLocal();
      return !local.isBefore(start) && local.isBefore(end);
    }).toList();
  }

  Future<TaskSummary> getTask(String taskId) async {
    try {
      final Response<dynamic> response = await _dio.get('/work/tasks/$taskId');
      return TaskSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TaskSummary> createTask({
    required String title,
    String? description,
    String? projectId,
    String? milestoneId,
    String? parentTaskId,
    String priority = 'medium',
    DateTime? dueDate,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/work/tasks',
        data: {
          'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
          if (projectId != null) 'project_id': projectId,
          if (milestoneId != null) 'milestone_id': milestoneId,
          if (parentTaskId != null) 'parent_task_id': parentTaskId,
          'priority': priority,
          if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
        },
      );
      return TaskSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<TaskSummary> updateTask(
    String taskId, {
    String? title,
    String? description,
    String? milestoneId,
    String? status,
    String? priority,
    DateTime? dueDate,
    int? position,
  }) async {
    try {
      final Response<dynamic> response = await _dio.patch(
        '/work/tasks/$taskId',
        data: {
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (milestoneId != null) 'milestone_id': milestoneId,
          if (status != null) 'status': status,
          if (priority != null) 'priority': priority,
          if (dueDate != null) 'due_date': dueDate.toUtc().toIso8601String(),
          if (position != null) 'position': position,
        },
      );
      return TaskSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _dio.delete('/work/tasks/$taskId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<FocusSessionSummary> startFocusSession({
    String? taskId,
    String? projectId,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/work/focus-sessions',
        data: {
          if (taskId != null) 'task_id': taskId,
          if (projectId != null) 'project_id': projectId,
        },
      );
      return FocusSessionSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  Future<FocusSessionSummary> stopFocusSession(String focusSessionId) async {
    try {
      final Response<dynamic> response = await _dio.post(
        '/work/focus-sessions/$focusSessionId/stop',
      );
      return FocusSessionSummary.fromJson(
        (response.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}