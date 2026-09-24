// lib/app/home/home.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/auth/auth_api.dart';
import '../../api/home/home_repository.dart';
import '../../api/notifications/notification_service.dart';
import '../../api/reviews/reviews_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/feedback.dart';
import '../health/health_page.dart';
import '../layout/bottomnav.dart';
import '../layout/topbar.dart';
import '../notes/notes_tab.dart';
import '../notifications/notifications_page.dart';
import '../personal/personal_tab.dart';
import '../profile/profile_page.dart';
import '../search/search_page.dart';
import '../work/work_tab.dart';
import 'widgets/daily_review_sheet.dart';
import 'widgets/home_cards.dart';

class HomePage extends StatefulWidget {
  final String? userName;

  const HomePage({super.key, this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppTab _currentTab = AppTab.home;
  final Set<AppTab> _visited = <AppTab>{AppTab.home};

  HomeSnapshot? _snapshot;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final HomeSnapshot snapshot = await HomeRepository.instance.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() => _load();

  String get _greeting {
    final int hour = DateTime.now().hour;
    if (hour < 5) return 'Still up';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 22) return 'Good evening';
    return 'Good night';
  }

  String get _firstName {
    final String raw = widget.userName ??
        AuthRepository.instance.currentUser?.name ??
        'there';
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  void _handleTabSelected(AppTab tab) {
    if (tab == _currentTab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentTab = tab;
      _visited.add(tab);
    });
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  Future<void> _openDailyReview() async {
    final DailyReviewSummary? result = await showDailyReviewSheet(
      context,
      existing: _snapshot?.dailyReview,
    );
    if (result == null || !mounted) return;
    await _load();
  }

  Future<void> _openHealth() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HealthPage()),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildSingleTab(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return _buildHomeTab();
      case AppTab.notes:
        return const NotesTab();
      case AppTab.work:
        return const WorkTab();
      case AppTab.personal:
        return const PersonalTab();
    }
  }

  Widget _buildTabBody() {
    return IndexedStack(
      index: _currentTab.index,
      children: AppTab.values
          .map((AppTab tab) => _visited.contains(tab)
              ? _buildSingleTab(tab)
              : const SizedBox.shrink())
          .toList(),
    );
  }

  List<StatItem> _buildStats(HomeSnapshot? s) {
    final int tasks = s?.todayTasks.length ?? 0;
    final int notes = s?.recentNotes.length ?? 0;
    final int goals = s?.totalActiveGoals ?? 0;
    final int habits = s?.habits.length ?? 0;
    return [
      StatItem(
        icon: Icons.check_circle_outline_rounded,
        value: tasks.toString(),
        label: 'Tasks',
        color: const Color(0xFF2C67C5),
      ),
      StatItem(
        icon: Icons.description_outlined,
        value: notes.toString(),
        label: 'Notes',
        color: const Color(0xFF4B3F91),
      ),
      StatItem(
        icon: Icons.eco_outlined,
        value: goals.toString(),
        label: 'Goals',
        color: const Color(0xFF2F6B3F),
      ),
      StatItem(
        icon: Icons.repeat_rounded,
        value: habits.toString(),
        label: 'Habits',
        color: const Color(0xFF8A6D1E),
      ),
    ];
  }

  Widget _buildHomeTab() {
    final HomeSnapshot? s = _snapshot;
    final bool loading = _isLoading;
    final VivreColors colors = context.colors;

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: GreetingSection(
              greeting: _greeting,
              name: _firstName,
              date: DateTime.now(),
            ),
          ),
          SliverToBoxAdapter(
            child: TodayCard(
              timeline: s?.timeline ?? const [],
              isLoading: loading,
              onViewAll: () => showComingSoon(context, 'Timeline'),
            ),
          ),
          SliverToBoxAdapter(
            child: QuickStatsRow(stats: _buildStats(s)),
          ),
          SliverToBoxAdapter(
            child: HealthCard(
              metrics: s?.todayMetrics,
              isLoading: loading,
              onOpen: _openHealth,
            ),
          ),
          if (loading || (s?.habits.isNotEmpty ?? false))
            SliverToBoxAdapter(
              child: HabitsCard(
                habits: s?.habits ?? const [],
                streaks: s?.habitStreaks ?? const {},
                isLoading: loading,
                onViewAll: () => _handleTabSelected(AppTab.personal),
              ),
            ),
          if (loading || (s?.recentNotes.isNotEmpty ?? false))
            SliverToBoxAdapter(
              child: RecentNotesCard(
                notes: s?.recentNotes ?? const [],
                isLoading: loading,
                onViewAll: () => _handleTabSelected(AppTab.notes),
                onNoteTap: (note) => showComingSoon(context, note.title),
              ),
            ),
          SliverToBoxAdapter(
            child: DailyReviewCard(
              review: s?.dailyReview,
              isLoading: loading,
              onReflect: _openDailyReview,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: context.colors.background,
        extendBody: true,
        body: SizedBox.expand(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: NotificationService.instance.unreadCount,
                  builder: (BuildContext context, int unreadCount, _) {
                    return TopBar(
                      avatarUrl:
                          AuthRepository.instance.currentUser?.avatarUrl,
                      unreadNotifications: unreadCount,
                      onSearchTap: _openSearch,
                      onNotificationsTap: _openNotifications,
                      onProfileTap: _openProfile,
                    );
                  },
                ),
                Expanded(child: _buildTabBody()),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentTab: _currentTab,
          onTabSelected: _handleTabSelected,
          onAddTap: () => showComingSoon(context, 'Quick add'),
        ),
      ),
    );
  }
}