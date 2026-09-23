// lib/themes/color-palette.dart
import 'package:flutter/material.dart';

class VivreColors extends ThemeExtension<VivreColors> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primarySoft;
  final Color onPrimary;
  final Color focus;
  final Color success;
  final Color dueSoon;
  final Color overdue;
  final Color info;
  final Color aiFocus;
  final Brightness brightness;

  const VivreColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primarySoft,
    required this.onPrimary,
    required this.focus,
    required this.success,
    required this.dueSoon,
    required this.overdue,
    required this.info,
    required this.aiFocus,
    required this.brightness,
  });

  static const VivreColors light = VivreColors(
    background: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFEEF1F5),
    textPrimary: Color(0xFF171A21),
    textSecondary: Color(0xFF5F6877),
    textMuted: Color(0xFF8992A0),
    border: Color(0xFFDDE2E9),
    primary: Color(0xFF2C67C5),
    primaryLight: Color(0xFF5B8FE3),
    primaryDark: Color(0xFF2055A7),
    primarySoft: Color(0xFFE8F0FF),
    onPrimary: Color(0xFFFFFFFF),
    focus: Color(0xFF527DD1),
    success: Color(0xFF4F7F5B),
    dueSoon: Color(0xFFA8792F),
    overdue: Color(0xFFA94D3D),
    info: Color(0xFF2C67C5),
    aiFocus: Color(0xFF7957C7),
    brightness: Brightness.light,
  );

  static const VivreColors dark = VivreColors(
    background: Color(0xFF14161C),
    surface: Color(0xFF1E212B),
    surfaceElevated: Color(0xFF252936),
    surfaceSoft: Color(0xFF2C303D),
    textPrimary: Color(0xFFECE9E1),
    textSecondary: Color(0xFF9BA3AF),
    textMuted: Color(0xFF6F7785),
    border: Color(0xFF343946),
    primary: Color(0xFF2C67C5),
    primaryLight: Color(0xFF5B8FE3),
    primaryDark: Color(0xFF1E4F9A),
    primarySoft: Color(0xFF2C303D),
    onPrimary: Color(0xFFFFFFFF),
    focus: Color(0xFF7C9EF5),
    success: Color(0xFF6B8F71),
    dueSoon: Color(0xFFC9974B),
    overdue: Color(0xFFB85C4A),
    info: Color(0xFF5B8FE3),
    aiFocus: Color(0xFF9B7AE8),
    brightness: Brightness.dark,
  );

  @override
  VivreColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? primarySoft,
    Color? onPrimary,
    Color? focus,
    Color? success,
    Color? dueSoon,
    Color? overdue,
    Color? info,
    Color? aiFocus,
    Brightness? brightness,
  }) {
    return VivreColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      focus: focus ?? this.focus,
      success: success ?? this.success,
      dueSoon: dueSoon ?? this.dueSoon,
      overdue: overdue ?? this.overdue,
      info: info ?? this.info,
      aiFocus: aiFocus ?? this.aiFocus,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  VivreColors lerp(ThemeExtension<VivreColors>? other, double t) {
    if (other is! VivreColors) return this;
    return VivreColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      success: Color.lerp(success, other.success, t)!,
      dueSoon: Color.lerp(dueSoon, other.dueSoon, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      info: Color.lerp(info, other.info, t)!,
      aiFocus: Color.lerp(aiFocus, other.aiFocus, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

extension VivreColorsContext on BuildContext {
  VivreColors get colors => Theme.of(this).extension<VivreColors>()!;
}