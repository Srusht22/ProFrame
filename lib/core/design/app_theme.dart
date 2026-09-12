import 'package:flutter/material.dart';

import 'tokens.dart';

/// The application's single [ThemeData].
///
/// Every colour comes from [AppColors]; nothing here introduces a new one.
/// The scheme is built by hand rather than with `ColorScheme.fromSeed`,
/// because a seeded scheme would shift the two brand colours to whatever the
/// tonal-palette algorithm prefers and they have to stay exact
/// (spec section 7).
abstract final class AppTheme {
  static ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.deepGreen,
        onPrimary: AppColors.cream,
        primaryContainer: AppColors.deepGreenHover,
        onPrimaryContainer: AppColors.cream,
        secondary: AppColors.deepGreen,
        onSecondary: AppColors.cream,
        secondaryContainer: AppColors.cream,
        onSecondaryContainer: AppColors.deepGreen,
        surface: AppColors.surface,
        onSurface: AppColors.deepGreen,
        surfaceContainerLowest: AppColors.canvasSurface,
        surfaceContainer: AppColors.cream,
        onSurfaceVariant: AppColors.mutedText,
        outline: AppColors.outline,
        outlineVariant: AppColors.outline,
        error: AppColors.danger,
        onError: Color(0xFFFFFFFF),
        errorContainer: AppColors.dangerSurface,
        onErrorContainer: AppColors.danger,
      );

  static ThemeData light() {
    final scheme = colorScheme;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      fontFamily: AppFonts.family,
      fontFamilyFallback: AppFonts.fallback,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepGreen,
        foregroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: false,
      ),
      // Every button style below sets a minimum size rather than relying on
      // Material's default 40dp height, which is under the 48dp floor.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepGreen,
          foregroundColor: AppColors.cream,
          minimumSize: const Size(AppSizing.minTouchTarget, AppSizing.minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepGreen,
          minimumSize: const Size(AppSizing.minTouchTarget, AppSizing.minTouchTarget),
          side: const BorderSide(color: AppColors.deepGreen, width: 1.5),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.deepGreen,
          minimumSize: const Size(AppSizing.minTouchTarget, AppSizing.minTouchTarget),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.deepGreen,
          minimumSize: const Size(AppSizing.minTouchTarget, AppSizing.minTouchTarget),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvasSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.deepGreen, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
      // Material's default is 40dp on desktop-class densities; the floor is 48.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
  }

  static TextTheme _textTheme(TextTheme base) => base
      .apply(
        bodyColor: AppColors.deepGreen,
        displayColor: AppColors.deepGreen,
      )
      .copyWith(
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.deepGreen,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.deepGreen,
        ),
        bodyMedium: base.bodyMedium?.copyWith(color: AppColors.deepGreen),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      );

  const AppTheme._();
}
