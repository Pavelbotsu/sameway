import 'package:flutter/material.dart';
import 'app_colors.dart';

// Seed-based Material 3 tonal palette derived from the brand teal.
// Per user preference (secondary > primary), teal is now the dominant
// theme accent: it seeds the M3 palette so primaryContainer / surfaceTint /
// etc. all skew teal, and overrides scheme.primary so built-in Material
// widgets (FilledButton, Switch, SnackBar action) pick teal by default.
// AppColors.primary (purple) is kept on scheme.secondary so it remains
// available via `Theme.of(context).colorScheme.secondary` without losing
// brand identity in the role-color semantics (driver=purple, passenger=teal).
ColorScheme _brandScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.teal,
    brightness: Brightness.dark,
  );
  return base.copyWith(
    primary: AppColors.teal,
    secondary: AppColors.primary,
    surface: AppColors.surface,
    error: AppColors.error,
    onSurface: AppColors.textPrimary,
  );
}

ThemeData buildAppTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: _brandScheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 38,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // backgroundColor intentionally omitted — naked ElevatedButtons
          // now adopt colorScheme.primary (teal) instead of hardcoding
          // purple. Per-call styleFrom overrides keep their explicit colors.
          foregroundColor: Colors.white,
          // M3 spec minimum (64×48); per-call SizedBox or styleFrom override
          // sets full-width where intended. Avoids the infinite-width crash
          // when an ElevatedButton is placed inside a Row without Expanded.
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
        ),
      ),
      // Catches stray `ScaffoldMessenger.showSnackBar(SnackBar(...))` calls
      // (Flutter built-ins, plugins, future code) so they at least adopt the
      // branded surface/radius/border instead of the default M3 toast.
      // Call sites that want icon + retry CTA should use BrandedSnack.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        elevation: 8,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13.5,
          height: 1.25,
        ),
        actionTextColor: AppColors.teal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.border.withValues(alpha: 0.9),
            width: 1,
          ),
        ),
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      ),
    );
