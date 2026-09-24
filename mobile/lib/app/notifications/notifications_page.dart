// lib/app/notifications/notifications_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/notifications/notification_service.dart';
import '../../api/notifications/notifications_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/skeleton_loader.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationsApi _api = NotificationsApi();

  List<AppNotification> _notifications = const [];
  StreamSubscription<AppNotification>? _liveSub;
  bool _isLoading = true;
  bool _showUnreadOnly = false;
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _liveSub =
        NotificationService.instance.incoming.listen(_handleLiveNotification);
    _load();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final List<AppNotification> items = await _api.list(
        unreadOnly: _showUnreadOnly,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications = const [];
        _isLoading = false;
      });
    }
  }

  void _handleLiveNotification(AppNotification notification) {
    if (!mounted) return;
    if (_showUnreadOnly && notification.isRead) return;

    final List<AppNotification> rest = _notifications
        .where((AppNotification n) => n.id != notification.id)
        .toList();
    setState(() {
      _notifications = [notification, ...rest];
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await _api.markRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((AppNotification n) => n.id == notification.id
                ? n.copyWith(readAt: DateTime.now())
                : n)
            .toList();
      });
      NotificationService.instance.markLocalRead();
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    if (_isMarkingAll) return;
    final bool hasUnread =
        _notifications.any((AppNotification n) => !n.isRead);
    if (!hasUnread) return;

    setState(() => _isMarkingAll = true);
    try {
      await _api.markAllRead();
      if (!mounted) return;
      final DateTime now = DateTime.now();
      setState(() {
        _notifications = _notifications
            .map((AppNotification n) => n.isRead ? n : n.copyWith(readAt: now))
            .toList();
        _isMarkingAll = false;
      });
      NotificationService.instance.markAllLocalRead();
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isMarkingAll = false);
      showErrorSnackBar(context, 'Could not mark all as read. Try again.');
    }
  }

  Future<void> _toggleFilter() async {
    setState(() => _showUnreadOnly = !_showUnreadOnly);
    await _load();
  }

  int get _unreadCount =>
      _notifications.where((AppNotification n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: colors.background,
      ),
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: colors.textPrimary,
          ),
          titleSpacing: 0,
          title: Text(
            'Notifications',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _isMarkingAll ? null : _markAllRead,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colors.primary,
                ),
                child: _isMarkingAll
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Mark all read',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _FilterBar(
              unreadOnly: _showUnreadOnly,
              unreadCount: _unreadCount,
              onTap: _toggleFilter,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _NotificationsSkeleton();
    }
    if (_notifications.isEmpty) {
      return _EmptyState(unreadOnly: _showUnreadOnly);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: context.colors.primary,
      backgroundColor: context.colors.surface,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (BuildContext context, int index) {
          final AppNotification notification = _notifications[index];
          return _NotificationTile(
            notification: notification,
            onTap: () => _markRead(notification),
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final bool unreadOnly;
  final int unreadCount;
  final VoidCallback onTap;

  const _FilterBar({
    required this.unreadOnly,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            selected: !unreadOnly,
            onTap: unreadOnly ? onTap : null,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: unreadCount > 0 ? 'Unread · $unreadCount' : 'Unread',
            selected: unreadOnly,
            onTap: unreadOnly ? null : onTap,
            accent: colors.primary,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? accent;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final Color base = accent ?? colors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? base : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? base : colors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : colors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  static const Map<String, (IconData, Color, Color)> _typeStyles = {
    'task': (
      Icons.check_circle_outline_rounded,
      Color(0xFF2C67C5),
      Color(0xFFDCEAFB)
    ),
    'habit': (
      Icons.eco_outlined,
      Color(0xFF2F6B3F),
      Color(0xFFDFF3E3)
    ),
    'review': (
      Icons.auto_awesome_outlined,
      Color(0xFF4B3F91),
      Color(0xFFE6E1F9)
    ),
    'goal': (
      Icons.flag_outlined,
      Color(0xFF8A5A24),
      Color(0xFFFBE7D2)
    ),
    'milestone': (
      Icons.emoji_events_outlined,
      Color(0xFF8A6D1E),
      Color(0xFFFBF0C8)
    ),
  };

  (IconData, Color, Color) _resolveStyle() {
    final String type = notification.notificationType.toLowerCase();
    for (final MapEntry<String, (IconData, Color, Color)> entry
        in _typeStyles.entries) {
      if (type.contains(entry.key)) return entry.value;
    }
    return (
      Icons.notifications_outlined,
      const Color(0xFF2C67C5),
      const Color(0xFFDCEAFB)
    );
  }

  String get _relative {
    final Duration diff =
        DateTime.now().difference(notification.createdAt.toLocal());
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final DateTime d = notification.createdAt.toLocal();
    return '${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final (IconData icon, Color fg, Color bg) = _resolveStyle();
    final bool unread = !notification.isRead;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread
                  ? colors.primary.withValues(alpha: 0.24)
                  : colors.border,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relative,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool unreadOnly;

  const _EmptyState({required this.unreadOnly});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                unreadOnly
                    ? Icons.mark_email_read_outlined
                    : Icons.notifications_none_rounded,
                color: colors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              unreadOnly ? 'You\u2019re all caught up' : 'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              unreadOnly
                  ? 'Nothing unread. Check back later.'
                  : 'We\u2019ll let you know when something happens.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(width: 42, height: 42, borderRadius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 15, borderRadius: 6),
                    SizedBox(height: 8),
                    SkeletonBox(width: 180, height: 12, borderRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}