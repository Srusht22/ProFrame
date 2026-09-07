import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Central Material 3 theme, heavily customized to the ProFrame brand.
///
/// Design intent: dark green (#013E37) drives navigation, primary actions
/// and selected states; cream (#FFEFB3) is reserved for highlight surfaces,
/// key accents and "selected configuration" chips. Everything else is a
/// neutral so the two brand colors keep their weight instead of being used
/// everywhere at full intensity (per the brand guidance).
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.brandDarkGreen,
      onPrimary: AppColors.neutralWhite,
      primaryContainer: AppColors.brandCream,
      onPrimaryContainer: AppColors.brandDarkGreenDeep,
      secondary: AppColors.brandCreamDeep,
      onSecondary: AppColors.brandDarkGreenDeep,
      surface: AppColors.neutralWhite,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.neutralSurface,
      error: AppColors.error,
      onError: AppColors.neutralWhite,
      outline: AppColors.neutralBorder,
      outlineVariant: AppColors.neutralDivider,
    );

    return _base(
      scheme: scheme,
      textTheme: AppTypography.light,
      scaffoldBackground: AppColors.neutralOffWhite,
      surface: AppColors.neutralWhite,
      border: AppColors.neutralBorder,
      elevatedShadow: Colors.black.withOpacity(0.06),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.brandCream,
      onPrimary: AppColors.brandDarkGreenDeep,
      primaryContainer: AppColors.brandDarkGreenLight,
      onPrimaryContainer: AppColors.brandCream,
      secondary: AppColors.brandCream,
      onSecondary: AppColors.brandDarkGreenDeep,
      surface: AppColors.darkSurface,
      onSurface: AppColors.textOnDark,
      surfaceContainerHighest: AppColors.darkSurfaceElevated,
      error: Color(0xFFE38178),
      onError: Color(0xFF3D0B06),
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkBorder,
    );

    return _base(
      scheme: scheme,
      textTheme: AppTypography.dark,
      scaffoldBackground: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      border: AppColors.darkBorder,
      elevatedShadow: Colors.black.withOpacity(0.35),
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required TextTheme textTheme,
    required Color scaffoldBackground,
    required Color surface,
    required Color border,
    required Color elevatedShadow,
  }) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.brandDarkGreen,
        selectedIconTheme: const IconThemeData(color: AppColors.brandCream),
        unselectedIconTheme: IconThemeData(
          color: AppColors.textOnDarkMuted.withOpacity(0.85),
        ),
        selectedLabelTextStyle: const TextStyle(
          color: AppColors.brandCream,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.textOnDarkMuted.withOpacity(0.85),
          fontSize: 12,
        ),
        indicatorColor: Colors.white.withOpacity(0.10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.brandDarkGreen,
        indicatorColor: Colors.white.withOpacity(0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.brandCream : AppColors.textOnDarkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.brandCream : AppColors.textOnDarkMuted,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandDarkGreen,
          foregroundColor: AppColors.neutralWhite,
          disabledBackgroundColor: AppColors.disabled,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandCream,
          foregroundColor: AppColors.brandDarkGreenDeep,
          minimumSize: const Size(64, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(64, 50),
          side: BorderSide(color: border, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandDarkGreen,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.neutralSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.brandDarkGreen, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.65)),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.45)),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.neutralSurface,
        selectedColor: AppColors.brandCream,
        secondarySelectedColor: AppColors.brandCream,
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: AppColors.brandDarkGreenDeep),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.brandDarkGreenDeep,
        contentTextStyle: const TextStyle(color: AppColors.textOnDark, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.brandDarkGreenDeep,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        textStyle: const TextStyle(color: AppColors.textOnDark, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandDarkGreen,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(
          isDark ? AppColors.darkSurfaceElevated : AppColors.neutralSurface,
        ),
        dataRowColor: WidgetStateProperty.all(surface),
        dividerThickness: 1,
        headingTextStyle: textTheme.labelMedium,
        dataTextStyle: textTheme.bodyMedium,
      ),
      shadowColor: elevatedShadow,
      visualDensity: VisualDensity.standard,
    );
  }
}
