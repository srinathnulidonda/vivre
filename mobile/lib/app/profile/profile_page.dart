// lib/app/profile/profile_page.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_exception.dart';
import '../../api/auth/auth_api.dart';
import '../../api/notifications/notifications_api.dart';
import '../../api/users/users_api.dart';
import '../../themes/color-palette.dart';
import '../../widgets/feedback.dart';
import '../../widgets/skeleton_loader.dart';
import 'widgets/profile_sheets.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UsersApi _users = UsersApi();
  final NotificationsApi _notifications = NotificationsApi();
  final ImagePicker _picker = ImagePicker();

  GoogleConnectionInfo? _google;
  NotificationPreferences? _preferences;
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  bool _isUpdating = false;
  bool _isLoggingOut = false;

  VivreUser? get _user => AuthRepository.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    GoogleConnectionInfo? google;
    NotificationPreferences? preferences;
    try {
      google = await _users.getGoogleConnection();
    } catch (_) {}
    try {
      preferences = await _notifications.getPreferences();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _google = google;
      _preferences = preferences;
      _isLoading = false;
    });
  }

  Future<void> _refreshUser() async {
    try {
      await AuthRepository.instance.fetchCurrentUser();
      if (!mounted) return;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    if (_isUploadingAvatar) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final VivreColors colors = sheetContext.colors;
        return Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Profile picture',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PickerOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Choose from library',
                    onTap: () =>
                        Navigator.of(sheetContext).pop(ImageSource.gallery),
                  ),
                  const SizedBox(height: 8),
                  _PickerOption(
                    icon: Icons.photo_camera_outlined,
                    label: 'Take a photo',
                    onTap: () =>
                        Navigator.of(sheetContext).pop(ImageSource.camera),
                  ),
                  if (_user?.avatarUrl != null) ...[
                    const SizedBox(height: 8),
                    _PickerOption(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove current photo',
                      isDestructive: true,
                      onTap: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (picked == null || !mounted) return;

    final Uint8List bytes = await picked.readAsBytes();
    final String mime = _contentTypeFromName(picked.name);
    if (!mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await _users.uploadAvatar(
        bytes: bytes,
        contentType: mime,
        filename: picked.name,
      );
      if (!mounted) return;
      await _refreshUser();
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      HapticFeedback.mediumImpact();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      showErrorSnackBar(context, 'Could not upload your photo.');
    }
  }

  String _contentTypeFromName(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _removeAvatar() async {
    final bool? confirmed = await _confirmDialog(
      title: 'Remove photo?',
      body: 'Your profile will fall back to the default avatar.',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await _users.deleteAvatar();
      if (!mounted) return;
      await _refreshUser();
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      HapticFeedback.mediumImpact();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      showErrorSnackBar(context, 'Could not remove your photo.');
    }
  }

  Future<void> _editName() async {
    final VivreUser? user = _user;
    if (user == null || _isUpdating) return;
    final String? name = await showNameSheet(context, initial: user.name);
    if (name == null || !mounted) return;
    await _updateProfile(name: name);
  }

  Future<void> _editTimezone() async {
    final VivreUser? user = _user;
    if (user == null || _isUpdating) return;
    final String? tz = await showTimezoneSheet(context, initial: user.timezone);
    if (tz == null || !mounted) return;
    await _updateProfile(timezone: tz);
  }

  Future<void> _updateProfile({String? name, String? timezone}) async {
    setState(() => _isUpdating = true);
    try {
      await _users.updateProfile(name: name, timezone: timezone);
      await _refreshUser();
      if (!mounted) return;
      setState(() => _isUpdating = false);
      HapticFeedback.mediumImpact();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      showErrorSnackBar(context, 'Could not update your profile.');
    }
  }

  Future<void> _togglePreference({
    required bool current,
    required Future<NotificationPreferences> Function(bool next) update,
    required NotificationPreferences optimistic,
  }) async {
    if (_preferences == null) return;
    HapticFeedback.selectionClick();
    final NotificationPreferences previous = _preferences!;
    setState(() => _preferences = optimistic);
    try {
      final NotificationPreferences fresh = await update(!current);
      if (!mounted) return;
      setState(() => _preferences = fresh);
    } catch (_) {
      if (!mounted) return;
      setState(() => _preferences = previous);
      showErrorSnackBar(context, 'Could not save that preference.');
    }
  }

  Future<void> _connectGoogle() async {
    try {
      final String url = await _users.getGoogleAuthorizeUrl();
      if (!mounted) return;
      await HapticFeedback.selectionClick();
      debugPrint('[VIVRE] Google authorize URL: $url');
      showErrorSnackBar(
        context,
        'Google sign-in page ready. Open in your browser to link.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not start Google authorization.');
    }
  }

  Future<void> _disconnectGoogle() async {
    final bool? confirmed = await _confirmDialog(
      title: 'Disconnect Google?',
      body: 'VIVRE will stop syncing with your Google account.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await _users.disconnectGoogle();
      if (!mounted) return;
      setState(() => _google = null);
      HapticFeedback.mediumImpact();
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not disconnect Google.');
    }
  }

  Future<void> _logout() async {
    final bool? confirmed = await _confirmDialog(
      title: 'Log out?',
      body: 'You can sign back in anytime.',
      confirmLabel: 'Log out',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    await AuthRepository.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    String confirmLabel = 'Confirm',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final VivreColors colors = dialogContext.colors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            body,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                confirmLabel,
                style: const TextStyle(
                  color: Color(0xFFD64545),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final VivreUser? user = _user;

    return Scaffold(
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
          'Profile',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: colors.primary,
        backgroundColor: colors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            _HeaderCard(
              user: user,
              isUploading: _isUploadingAvatar,
              onTapAvatar: _pickAvatar,
              onRemoveAvatar: (user?.avatarUrl == null) ? null : _removeAvatar,
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: 'Account'),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Name',
                  value: user?.name ?? '—',
                  onTap: _isUpdating ? null : _editName,
                ),
                _Divider(color: colors.border),
                _SettingsRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: user?.email ?? '—',
                  trailing:
                      _VerifiedChip(verified: user?.isEmailVerified ?? false),
                ),
                _Divider(color: colors.border),
                _SettingsRow(
                  icon: Icons.public_rounded,
                  label: 'Timezone',
                  value: user?.timezone ?? 'UTC',
                  onTap: _isUpdating ? null : _editTimezone,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: 'Connections'),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _GoogleRow(
                  connection: _google,
                  isLoading: _isLoading,
                  onConnect: _connectGoogle,
                  onDisconnect: _disconnectGoogle,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: 'Notifications'),
            const SizedBox(height: 8),
            _buildNotificationsSection(),
            const SizedBox(height: 28),
            _LogoutButton(
              onTap: _isLoggingOut ? null : _logout,
              isLoading: _isLoggingOut,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'VIVRE v1.0.0',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection() {
    final NotificationPreferences? p = _preferences;
    if (_isLoading) {
      return const _SettingsCard(
        children: [
          _PreferenceSkeleton(),
          _Divider(color: Color(0xFFDDE2E9)),
          _PreferenceSkeleton(),
          _Divider(color: Color(0xFFDDE2E9)),
          _PreferenceSkeleton(),
        ],
      );
    }
    if (p == null) {
      return _SettingsCard(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Could not load your preferences.',
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _PrefGroup(
          title: 'Push',
          children: [
            _PrefSwitch(
              label: 'Tasks',
              value: p.pushTasks,
              onChanged: (bool v) => _togglePreference(
                current: p.pushTasks,
                optimistic: p.copyWith(pushTasks: v),
                update: (bool next) =>
                    _notifications.updatePreferences(pushTasks: next),
              ),
            ),
            _PrefSwitch(
              label: 'Habits',
              value: p.pushHabits,
              onChanged: (bool v) => _togglePreference(
                current: p.pushHabits,
                optimistic: p.copyWith(pushHabits: v),
                update: (bool next) =>
                    _notifications.updatePreferences(pushHabits: next),
              ),
            ),
            _PrefSwitch(
              label: 'Reviews',
              value: p.pushReviews,
              onChanged: (bool v) => _togglePreference(
                current: p.pushReviews,
                optimistic: p.copyWith(pushReviews: v),
                update: (bool next) =>
                    _notifications.updatePreferences(pushReviews: next),
              ),
            ),
            _PrefSwitch(
              label: 'Goals',
              value: p.pushGoals,
              onChanged: (bool v) => _togglePreference(
                current: p.pushGoals,
                optimistic: p.copyWith(pushGoals: v),
                update: (bool next) =>
                    _notifications.updatePreferences(pushGoals: next),
              ),
            ),
            _PrefSwitch(
              label: 'Milestones',
              value: p.pushMilestones,
              onChanged: (bool v) => _togglePreference(
                current: p.pushMilestones,
                optimistic: p.copyWith(pushMilestones: v),
                update: (bool next) =>
                    _notifications.updatePreferences(pushMilestones: next),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _PrefGroup(
          title: 'Email',
          children: [
            _PrefSwitch(
              label: 'Weekly digest',
              value: p.emailDigest,
              onChanged: (bool v) => _togglePreference(
                current: p.emailDigest,
                optimistic: p.copyWith(emailDigest: v),
                update: (bool next) =>
                    _notifications.updatePreferences(emailDigest: next),
              ),
            ),
            _PrefSwitch(
              label: 'Review reminders',
              value: p.emailReviews,
              onChanged: (bool v) => _togglePreference(
                current: p.emailReviews,
                optimistic: p.copyWith(emailReviews: v),
                update: (bool next) =>
                    _notifications.updatePreferences(emailReviews: next),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _PrefGroup(
          title: 'In-app',
          children: [
            _PrefSwitch(
              label: 'Tasks',
              value: p.inappTasks,
              onChanged: (bool v) => _togglePreference(
                current: p.inappTasks,
                optimistic: p.copyWith(inappTasks: v),
                update: (bool next) =>
                    _notifications.updatePreferences(inappTasks: next),
              ),
            ),
            _PrefSwitch(
              label: 'Habits',
              value: p.inappHabits,
              onChanged: (bool v) => _togglePreference(
                current: p.inappHabits,
                optimistic: p.copyWith(inappHabits: v),
                update: (bool next) =>
                    _notifications.updatePreferences(inappHabits: next),
              ),
            ),
            _PrefSwitch(
              label: 'Reviews',
              value: p.inappReviews,
              onChanged: (bool v) => _togglePreference(
                current: p.inappReviews,
                optimistic: p.copyWith(inappReviews: v),
                update: (bool next) =>
                    _notifications.updatePreferences(inappReviews: next),
              ),
            ),
            _PrefSwitch(
              label: 'Goals',
              value: p.inappGoals,
              onChanged: (bool v) => _togglePreference(
                current: p.inappGoals,
                optimistic: p.copyWith(inappGoals: v),
                update: (bool next) =>
                    _notifications.updatePreferences(inappGoals: next),
              ),
            ),
            _PrefSwitch(
              label: 'Milestones',
              value: p.inappMilestones,
              onChanged: (bool v) => _togglePreference(
                current: p.inappMilestones,
                optimistic: p.copyWith(inappMilestones: v),
                update: (bool next) =>
                    _notifications.updatePreferences(inappMilestones: next),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final VivreUser? user;
  final bool isUploading;
  final VoidCallback onTapAvatar;
  final VoidCallback? onRemoveAvatar;

  const _HeaderCard({
    required this.user,
    required this.isUploading,
    required this.onTapAvatar,
    this.onRemoveAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final String? avatar = user?.avatarUrl;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: isUploading ? null : onTapAvatar,
            onLongPress: onRemoveAvatar,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surfaceSoft,
                    border: Border.all(color: colors.border, width: 1),
                    image: avatar != null
                        ? DecorationImage(
                            image: NetworkImage(avatar),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatar == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: colors.textSecondary,
                        )
                      : null,
                ),
                if (isUploading)
                  Container(
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user?.name ?? 'Your name',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '—',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final Color fg =
        isDestructive ? const Color(0xFFD64545) : colors.textPrimary;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: context.colors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          height: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ] else if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  final bool verified;

  const _VerifiedChip({required this.verified});

  @override
  Widget build(BuildContext context) {
    final Color fg = verified
        ? const Color(0xFF4F7F5B)
        : const Color(0xFFA8792F);
    final Color bg = verified
        ? const Color(0xFFDFF3E3)
        : const Color(0xFFFBF0C8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        verified ? 'Verified' : 'Unverified',
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          height: 1.1,
        ),
      ),
    );
  }
}

class _GoogleRow extends StatelessWidget {
  final GoogleConnectionInfo? connection;
  final bool isLoading;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _GoogleRow({
    required this.connection,
    required this.isLoading,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    final bool connected = connection != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'G',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C67C5),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isLoading
                      ? 'Checking…'
                      : connected
                          ? (connection!.googleAccountEmail)
                          : 'Not connected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: connected ? onDisconnect : onConnect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor:
                    connected ? colors.textMuted : colors.primary,
              ),
              child: Text(
                connected ? 'Disconnect' : 'Connect',
                style: TextStyle(
                  color: connected ? colors.textMuted : colors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrefGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _PrefGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 0, 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              height: 1.1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border, width: 1),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  _Divider(color: colors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PrefSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrefSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
        activeThumbColor: Colors.white,
        activeTrackColor: colors.primary,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: colors.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}

class _PreferenceSkeleton extends StatelessWidget {
  const _PreferenceSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      isLoading: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: const [
            Expanded(child: SkeletonBox(height: 14, borderRadius: 6)),
            SizedBox(width: 40),
            SkeletonBox(width: 44, height: 26, borderRadius: 13),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;

  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: color, height: 1, thickness: 0.6),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _LogoutButton({required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final VivreColors colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFD64545).withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFD64545),
                      ),
                    ),
                  )
                : const Text(
                    'Log out',
                    style: TextStyle(
                      color: Color(0xFFD64545),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}