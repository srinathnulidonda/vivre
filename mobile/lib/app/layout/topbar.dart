// lib/app/layout/topbar.dart
import 'package:flutter/material.dart';

import '../../themes/app-colors.dart';

class TopBar extends StatelessWidget {
  final bool hasUnreadNotifications;
  final String? avatarUrl;
  final bool isOnline;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onProfileTap;

  const TopBar({
    super.key,
    this.hasUnreadNotifications = true,
    this.avatarUrl,
    this.isOnline = true,
    this.onSearchTap,
    this.onNotificationsTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const _BrandLogo(size: 32),
          const SizedBox(width: 10),
          const Spacer(),
          _CircleIconButton(
            icon: Icons.search_rounded,
            semanticLabel: 'Search',
            onTap: onSearchTap,
          ),
          const SizedBox(width: 8),
          _CircleIconButton(
            icon: Icons.notifications_none_rounded,
            semanticLabel: 'Notifications',
            onTap: onNotificationsTap,
            showDot: hasUnreadNotifications,
            dotColor: kNotifyRed,
          ),
          const SizedBox(width: 10),
          _Avatar(avatarUrl: avatarUrl, online: isOnline, onTap: onProfileTap),
        ],
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  final double size;
  const _BrandLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kBrandLogoAsset,
      height: size,
      width: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.eco_rounded, size: size, color: kAccentBlue),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final bool showDot;
  final Color dotColor;

  const _CircleIconButton({
    required this.icon,
    required this.semanticLabel,
    this.onTap,
    this.showDot = false,
    this.dotColor = kNotifyRed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.06),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Semantics(
                button: true,
                label: semanticLabel,
                child: Icon(
                  icon,
                  color: Colors.black.withValues(alpha: 0.7),
                  size: 19,
                ),
              ),
              if (showDot)
                Positioned(
                  top: 7,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: kHomeBgTop, width: 1.5),
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

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final bool online;
  final VoidCallback? onTap;

  const _Avatar({this.avatarUrl, this.online = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Profile',
        child: SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Colors.black.withValues(alpha: 0.05),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person_rounded,
                        color: Colors.black45, size: 19)
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
                      color: kOnlineGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: kHomeBgTop, width: 2),
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