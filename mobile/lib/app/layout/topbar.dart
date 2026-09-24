// lib/app/layout/topbar.dart
import 'package:flutter/material.dart';

import '../../themes/color-palette.dart';

class TopBar extends StatelessWidget {
  final String? avatarUrl;
  final bool isOnline;
  final int unreadNotifications;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  const TopBar({
    super.key,
    this.avatarUrl,
    this.isOnline = true,
    this.unreadNotifications = 0,
    this.onSearchTap,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          const _BrandMark(size: 30),
          const Spacer(),
          _IconAction(
            icon: Icons.search_rounded,
            label: 'Search',
            onTap: onSearchTap,
          ),
          const SizedBox(width: 4),
          _IconAction(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            onTap: onNotificationsTap,
            badgeCount: unreadNotifications,
          ),
          const SizedBox(width: 8),
          _Avatar(
            avatarUrl: avatarUrl,
            online: isOnline,
            onTap: onProfileTap,
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final double size;

  const _BrandMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/onboarding/logo.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.eco_rounded,
        size: size,
        color: context.colors.primary,
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final int badgeCount;

  const _IconAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: colors.textSecondary, size: 22),
                if (badgeCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _Badge(count: badgeCount),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final String text = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.background, width: 1.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final bool online;
  final VoidCallback? onTap;

  const _Avatar({this.avatarUrl, this.online = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Semantics(
      button: true,
      label: 'Profile',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceSoft,
                  border: Border.all(color: colors.border, width: 1),
                  image: avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl == null
                    ? Icon(
                        Icons.person_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      )
                    : null,
              ),
              if (online)
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.background, width: 2),
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