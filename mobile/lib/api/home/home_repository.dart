// lib/api/home/home_repository.dart
import '../auth/auth_api.dart';
import '../health/health_api.dart';
import '../notes/notes_api.dart';
import '../notifications/notifications_api.dart';
import '../personal/personal_api.dart';
import '../reviews/reviews_api.dart';
import '../shared/shared_api.dart';
import '../work/work_api.dart';

class HomeSnapshot {
  final List<TimelineEntry> timeline;
  final int unreadNotifications;
  final List<NoteSummary> recentNotes;
  final int totalNotes;
  final List<TaskSummary> todayTasks;
  final int totalActiveGoals;
  final List<HabitSummary> habits;
  final Map<String, int> habitStreaks;
  final DailyMetricsSummary? todayMetrics;
  final DailyReviewSummary? dailyReview;

  const HomeSnapshot({
    required this.timeline,
    required this.unreadNotifications,
    required this.recentNotes,
    required this.totalNotes,
    required this.todayTasks,
    required this.totalActiveGoals,
    required this.habits,
    required this.habitStreaks,
    required this.todayMetrics,
    required this.dailyReview,
  });

  static const HomeSnapshot empty = HomeSnapshot(
    timeline: <TimelineEntry>[],
    unreadNotifications: 0,
    recentNotes: <NoteSummary>[],
    totalNotes: 0,
    todayTasks: <TaskSummary>[],
    totalActiveGoals: 0,
    habits: <HabitSummary>[],
    habitStreaks: <String, int>{},
    todayMetrics: null,
    dailyReview: null,
  );

  bool get hasDailyReview =>
      dailyReview != null && (dailyReview?.hasContent ?? false);
}

class HomeRepository {
  HomeRepository._internal();
  static final HomeRepository instance = HomeRepository._internal();

  final NotificationsApi _notifications = NotificationsApi();
  final NotesApi _notes = NotesApi();
  final WorkApi _work = WorkApi();
  final PersonalApi _personal = PersonalApi();
  final HealthApi _health = HealthApi();
  final ReviewsApi _reviews = ReviewsApi();
  final SharedApi _shared = SharedApi();

  Future<HomeSnapshot> load() async {
    final DateTime now = DateTime.now();

    final Future<int> unread = _safeInt(() => _notifications.unreadCount());
    final Future<List<TimelineEntry>> timeline =
        _safeList(() => _shared.timeline(now));
    final Future<List<NoteSummary>> recentNotes =
        _safeList(() => _notes.recent(limit: 3));
    final Future<List<TaskSummary>> todayTasks =
        _safeList(() => _work.todayTasks());
    final Future<List<HabitSummary>> habits =
        _safeList(() => _personal.listHabits(limit: 5));
    final Future<List<GoalSummary>> goals =
        _safeList(() => _personal.listGoals(status: 'active', limit: 50));
    final Future<DailyMetricsSummary?> metrics =
        _safeNull(() => _health.todayMetrics());
    final Future<DailyReviewSummary?> review =
        _safeNull(() => _reviews.dailyReview(now));

    final List<HabitSummary> habitList = await habits;
    final Future<Map<String, int>> streaks = _loadStreaks(habitList);
    final List<NoteSummary> noteList = await recentNotes;

    return HomeSnapshot(
      unreadNotifications: await unread,
      timeline: await timeline,
      recentNotes: noteList,
      totalNotes: noteList.length,
      todayTasks: await todayTasks,
      totalActiveGoals: (await goals).length,
      habits: habitList,
      habitStreaks: await streaks,
      todayMetrics: await metrics,
      dailyReview: await review,
    );
  }

  Future<Map<String, int>> _loadStreaks(List<HabitSummary> habits) async {
    final Map<String, int> result = <String, int>{};
    final List<HabitSummary> top = habits.take(3).toList();
    final List<Future<MapEntry<String, int>>> futures = top.map(
      (HabitSummary habit) async {
        try {
          final int streak = await _personal.habitStreak(habit.id);
          return MapEntry<String, int>(habit.id, streak);
        } catch (_) {
          return MapEntry<String, int>(habit.id, 0);
        }
      },
    ).toList();

    if (futures.isEmpty) return result;

    final List<MapEntry<String, int>> entries = await Future.wait(futures);
    for (final MapEntry<String, int> entry in entries) {
      result[entry.key] = entry.value;
    }
    return result;
  }

  Future<int> _safeInt(Future<int> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return 0;
    }
  }

  Future<List<T>> _safeList<T>(Future<List<T>> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return <T>[];
    }
  }

  Future<T?> _safeNull<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }
}