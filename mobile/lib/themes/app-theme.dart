// lib/themes/app-theme.dart
import 'package:flutter/material.dart';

import 'color-palette.dart';
import 'spacing.dart';
import 'text-styles.dart';

class VivreTheme {
  static ThemeData get light => _build(VivreColors.light);
  static ThemeData get dark => _build(VivreColors.dark);

  static ThemeData _build(VivreColors palette) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: palette.brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: palette.onPrimary,
      secondary: palette.aiFocus,
      onSecondary: palette.onPrimary,
      error: palette.overdue,
      onError: palette.onPrimary,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      outline: palette.border,
    );

    final TextTheme textTheme = TextTheme(
      displayLarge: VivreTextStyles.displayLarge.copyWith(color: palette.textPrimary),
      displayMedium: VivreTextStyles.displayMedium.copyWith(color: palette.textPrimary),
      displaySmall: VivreTextStyles.displaySmall.copyWith(color: palette.textPrimary),
      headlineLarge: VivreTextStyles.headlineLarge.copyWith(color: palette.textPrimary),
      headlineMedium: VivreTextStyles.headlineMedium.copyWith(color: palette.textPrimary),
      headlineSmall: VivreTextStyles.headlineSmall.copyWith(color: palette.textPrimary),
      titleLarge: VivreTextStyles.titleLarge.copyWith(color: palette.textPrimary),
      titleMedium: VivreTextStyles.titleMedium.copyWith(color: palette.textPrimary),
      titleSmall: VivreTextStyles.titleSmall.copyWith(color: palette.textSecondary),
      bodyLarge: VivreTextStyles.bodyLarge.copyWith(color: palette.textPrimary),
      bodyMedium: VivreTextStyles.bodyMedium.copyWith(color: palette.textSecondary),
      bodySmall: VivreTextStyles.bodySmall.copyWith(color: palette.textMuted),
      labelLarge: VivreTextStyles.labelLarge.copyWith(color: palette.onPrimary),
      labelMedium: VivreTextStyles.labelMedium.copyWith(color: palette.textSecondary),
      labelSmall: VivreTextStyles.labelSmall.copyWith(color: palette.textMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      fontFamily: VivreTextStyles.fontFamily,
      scaffoldBackgroundColor: palette.background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: [palette],
      dividerColor: palette.border,
      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: VivreTextStyles.headlineMedium.copyWith(color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VivreRadius.xl),
          side: BorderSide(color: palette.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VivreSpacing.md,
          vertical: VivreSpacing.sm,
        ),
        hintStyle: VivreTextStyles.bodyLarge.copyWith(color: palette.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VivreRadius.pill),
          borderSide: BorderSide(color: palette.surfaceSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VivreRadius.pill),
          borderSide: BorderSide(color: palette.surfaceSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VivreRadius.pill),
          borderSide: BorderSide(color: palette.focus, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VivreRadius.pill),
          borderSide: BorderSide(color: palette.overdue, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(VivreRadius.pill),
          borderSide: BorderSide(color: palette.overdue, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          disabledBackgroundColor: palette.primary.withValues(alpha: 0.6),
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          textStyle: VivreTextStyles.titleLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VivreRadius.pill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.surface,
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          minimumSize: const Size.fromHeight(46),
          textStyle: VivreTextStyles.titleMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VivreRadius.pill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: VivreTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconTheme: IconThemeData(color: palette.textSecondary),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VivreRadius.xxl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.textPrimary,
        contentTextStyle: VivreTextStyles.bodyMedium.copyWith(color: palette.background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VivreRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.primary
              : Colors.transparent,
        ),
        side: BorderSide(color: palette.border, width: 1.4),
      ),
    );
  }
}