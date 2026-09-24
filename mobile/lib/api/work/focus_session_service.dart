// lib/api/work/focus_session_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'work_api.dart';

class ActiveFocusSession {
  final String id;
  final DateTime startAt;
  final String? taskId;
  final String? projectId;
  final String? taskLabel;
  final String? projectLabel;

  const ActiveFocusSession({
    required this.id,
    required this.startAt,
    required this.taskId,
    required this.projectId,
    required this.taskLabel,
    required this.projectLabel,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_at': startAt.toIso8601String(),
      'task_id': taskId,
      'project_id': projectId,
      'task_label': taskLabel,
      'project_label': projectLabel,
    };
  }

  factory ActiveFocusSession.fromJson(Map<String, dynamic> json) {
    return ActiveFocusSession(
      id: json['id'] as String,
      startAt: DateTime.parse(json['start_at'] as String),
      taskId: json['task_id'] as String?,
      projectId: json['project_id'] as String?,
      taskLabel: json['task_label'] as String?,
      projectLabel: json['project_label'] as String?,
    );
  }

  String get primaryLabel => taskLabel ?? projectLabel ?? 'Focus session';

  String get subtitle {
    final List<String> parts = <String>[];
    if (taskLabel != null && projectLabel != null) {
      parts.add(taskLabel!);
      parts.add(projectLabel!);
    } else if (projectLabel != null) {
      parts.add(projectLabel!);
    }
    return parts.join(' · ');
  }
}

class FocusSessionService {
  FocusSessionService._internal();
  static final FocusSessionService instance = FocusSessionService._internal();

  static const String _activeKey = 'vivre_active_focus_session';

  final WorkApi _api = WorkApi();

  final ValueNotifier<ActiveFocusSession?> active =
      ValueNotifier<ActiveFocusSession?>(null);
  final ValueNotifier<Duration> elapsed =
      ValueNotifier<Duration>(Duration.zero);

  Timer? _ticker;

  bool get isRunning => active.value != null;

  Future<void> restoreFromDisk() async {
    if (active.value != null) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_activeKey);
    if (raw == null) return;
    try {
      final ActiveFocusSession session = ActiveFocusSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      active.value = session;
      _startTicker();
    } catch (_) {
      await prefs.remove(_activeKey);
    }
  }

  Future<void> start({
    String? taskId,
    String? projectId,
    String? taskLabel,
    String? projectLabel,
  }) async {
    if (active.value != null) return;

    final FocusSessionSummary remote = await _api.startFocusSession(
      taskId: taskId,
      projectId: projectId,
    );

    final ActiveFocusSession session = ActiveFocusSession(
      id: remote.id,
      startAt: remote.startAt.toLocal(),
      taskId: taskId,
      projectId: projectId,
      taskLabel: taskLabel,
      projectLabel: projectLabel,
    );

    active.value = session;
    _startTicker();
    await _persist(session);
  }

  Future<Duration?> stop() async {
    final ActiveFocusSession? current = active.value;
    if (current == null) return null;

    final Duration finalDuration = DateTime.now().difference(current.startAt);

    try {
      await _api.stopFocusSession(current.id);
    } catch (_) {}

    _ticker?.cancel();
    _ticker = null;
    active.value = null;
    elapsed.value = Duration.zero;
    await _clearPersist();

    return finalDuration;
  }

  void _startTicker() {
    _ticker?.cancel();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final ActiveFocusSession? session = active.value;
    if (session == null) return;
    elapsed.value = DateTime.now().difference(session.startAt);
  }

  Future<void> _persist(ActiveFocusSession session) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, jsonEncode(session.toJson()));
  }

  Future<void> _clearPersist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
  }
}