// lib/app/home/home.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/auth/auth_api.dart';
import '../../themes/app-colors.dart';
import '../../widgets/feedback.dart';
import '../layout/bottomnav.dart';
import '../layout/topbar.dart';

class HomePage extends StatefulWidget {
  final String? userName;

  const HomePage({super.key, this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppTab _currentTab = AppTab.home;

  static const List<String> _quotes = [
    'Small steps every day\ncreate a life you\u2019re proud of.',
    'Discipline is choosing between what\nyou want now and what you want most.',
    'Progress, not perfection.',
  ];

  late final String _quoteOfTheDay =
      _quotes[DateTime.now().day % _quotes.length];

  String get _greeting {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _displayName =>
      widget.userName ?? AuthRepository.instance.currentUser?.name ?? 'there';

  void _handleTabSelected(AppTab tab) {
    if (tab == _currentTab) return;
    setState(() => _currentTab = tab);
  }

  Widget _buildTabBody() {
    switch (_currentTab) {
      case AppTab.home:
        return _GreetingTab(
          greeting: _greeting,
          displayName: _displayName,
          quote: _quoteOfTheDay,
        );
      case AppTab.notes:
        return const _PlaceholderTab(
          icon: Icons.description_outlined,
          title: 'Notes',
          message: 'Your notes will live here.',
        );
      case AppTab.work:
        return const _PlaceholderTab(
          icon: Icons.work_outline_rounded,
          title: 'Work',
          message: 'Your work will live here.',
        );
      case AppTab.personal:
        return const _PlaceholderTab(
          icon: Icons.person_outline_rounded,
          title: 'Personal',
          message: 'Your personal space will live here.',
        );
    }
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
        backgroundColor: kHomeBgTop,
        extendBody: true,
        body: SizedBox.expand(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                TopBar(
                  avatarUrl: AuthRepository.instance.currentUser?.avatarUrl,
                  onSearchTap: () => showComingSoon(context, 'Search'),
                  onNotificationsTap: () =>
                      showComingSoon(context, 'Notifications'),
                  onProfileTap: () => showComingSoon(context, 'Profile'),
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

class _GreetingTab extends StatelessWidget {
  final String greeting;
  final String displayName;
  final String quote;

  const _GreetingTab({
    required this.greeting,
    required this.displayName,
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$greeting,',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 29,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: kAccentBlue,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('\u{1F44B}', style: TextStyle(fontSize: 30)),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              '\u201C$quote\u201D',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kAccentBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kAccentBlue, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kDarkNavy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: kBodyGray,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}