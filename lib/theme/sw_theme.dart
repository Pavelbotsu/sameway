import 'package:flutter/material.dart';

import 'role_colors.dart';
import 'sw_colors.dart';
import 'sw_tokens.dart';

/// Design system v3 theme. Rebuild `MaterialApp.theme` with the new role
/// when the user switches role (F01), so `context.role` follows it.
abstract final class SwTheme {
  static ThemeData build(SwRole r) {
    final role = RoleColors.of(r);

    // Every slot is set, so no Material default below 13 px leaks through
    // (M3 has 11 and 12 px label styles).
    final text = const TextTheme(
      displayLarge: SwType.price,
      displayMedium: SwType.price,
      displaySmall: SwType.screenTitle,
      headlineLarge: SwType.screenTitle,
      headlineMedium: SwType.screenTitle,
      headlineSmall: SwType.sheetTitle,
      titleLarge: SwType.sheetTitle,
      titleMedium: SwType.appBarTitle,
      titleSmall: SwType.emphasis,
      bodyLarge: SwType.input,
      bodyMedium: SwType.body,
      bodySmall: SwType.caption,
      labelLarge: SwType.groupLabel,
      labelMedium: SwType.caption,
      labelSmall: SwType.caption,
    )
        .apply(
          fontFamily: swFontFamily,
          bodyColor: SwColors.text,
          displayColor: SwColors.text,
        )
        .copyWith(
          bodySmall: SwType.caption,
          labelMedium: SwType.caption,
          labelSmall: SwType.caption,
        );

    final scheme = ColorScheme.dark(
      primary: role.fill,
      onPrimary: SwColors.onAccent,
      secondary: role.onDark,
      onSecondary: SwColors.onAccent,
      surface: SwColors.surface1,
      onSurface: SwColors.text,
      onSurfaceVariant: SwColors.textSecondary,
      surfaceContainerLowest: SwColors.background,
      surfaceContainerLow: SwColors.surface1,
      surfaceContainer: SwColors.surface1,
      surfaceContainerHigh: SwColors.surface2,
      surfaceContainerHighest: SwColors.surface3,
      error: SwColors.danger,
      onError: SwColors.onAccent,
      outline: SwColors.fieldBorder,
      outlineVariant: SwColors.line,
      scrim: SwColors.scrim,
      shadow: Colors.transparent,
    );

    // 2 px role-coloured focus outline on every button.
    final focusSide = WidgetStateProperty.resolveWith<BorderSide?>((s) =>
        s.contains(WidgetState.focused)
            ? BorderSide(color: role.onDark, width: 2)
            : null);
    const buttonText = TextStyle(fontFamily: swFontFamily, fontSize: 16, fontWeight: FontWeight.w600);
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwRadius.button));
    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(SwRadius.field),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: swFontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: SwColors.background,
      canvasColor: SwColors.background,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [role],
      materialTapTargetSize: MaterialTapTargetSize.padded, // 48 dp targets
      dividerColor: SwColors.line,
      dividerTheme: const DividerThemeData(color: SwColors.line, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: SwColors.text, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: SwColors.background,
        foregroundColor: SwColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(SwSize.button),
          backgroundColor: role.fill,
          foregroundColor: SwColors.onAccent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: SwColors.textSecondary,
          textStyle: buttonText,
          shape: buttonShape,
          elevation: 0,
        ).copyWith(side: focusSide),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(SwSize.buttonSecondary),
          backgroundColor: SwColors.surface2,
          foregroundColor: SwColors.text,
          textStyle: buttonText,
          shape: buttonShape,
        ).copyWith(
          side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused)
              ? BorderSide(color: role.onDark, width: 2)
              : const BorderSide(color: SwColors.line)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: role.onDark,
          textStyle: buttonText,
          minimumSize: const Size(SwSize.touchAndroid, SwSize.touchAndroid),
          shape: buttonShape,
        ).copyWith(side: focusSide),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SwColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        hintStyle: const TextStyle(color: SwColors.textTertiary),
        labelStyle: const TextStyle(color: SwColors.textSecondary),
        prefixIconColor: SwColors.textSecondary,
        enabledBorder: field(SwColors.fieldBorder),
        border: field(SwColors.fieldBorder),
        disabledBorder: field(SwColors.line),
        focusedBorder: field(role.fill, 2),
        errorBorder: field(SwColors.danger, 2),
        focusedErrorBorder: field(SwColors.danger, 2),
        errorStyle: const TextStyle(fontFamily: swFontFamily, fontSize: 13, height: 1.45, color: SwColors.danger),
        errorMaxLines: 3,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: role.fill,
        selectionColor: role.tint,
        selectionHandleColor: role.fill,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: SwSize.tabBar,
        backgroundColor: SwColors.surface1,
        indicatorColor: role.tint,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: swFontFamily,
            fontSize: 13,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? role.onDark : SwColors.textSecondary)),
        iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected) ? role.onDark : SwColors.textSecondary)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: SwColors.surface1,
        modalBackgroundColor: SwColors.surface1,
        modalBarrierColor: SwColors.scrim,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false, // SwBottomSheet draws its own handle
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(SwRadius.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: SwColors.surface1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: SwColors.scrim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwRadius.dialog)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: SwColors.snackbar,
        contentTextStyle: TextStyle(fontFamily: swFontFamily, fontSize: 14, fontWeight: FontWeight.w500, color: SwColors.onAccent),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(SwRadius.field))),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? role.fill : SwColors.surface3),
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? SwColors.onAccent : SwColors.textTertiary),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: role.fill,
        linearTrackColor: SwColors.surface3,
        circularTrackColor: SwColors.surface3,
      ),
      cardTheme: CardThemeData(
        color: SwColors.surface2,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwRadius.card),
          side: const BorderSide(color: SwColors.line),
        ),
      ),
    );
  }
}
