import 'package:flutter/material.dart';

/// The look of the application.
///
/// Deep green and warm cream, and as little of anything else as possible.
/// The canvas is the product; everything here exists to stay out of its way.
abstract final class AppTheme {
  static const Color primary = Color(0xFF013E37);
  static const Color accent = Color(0xFFFFEFB3);

  static const Color ink = Color(0xFF0C1613);
  static const Color muted = Color(0xFF5C6B66);
  static const Color hairline = Color(0xFFD9E0DD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFFCFCFA);
  static const Color shell = Color(0xFFF2F4F2);

  /// The green the drawing is made in — the colour of a pencil on a plan.
  static const Color drawnInk = primary;

  /// What a selected part is outlined in.
  static const Color selection = Color(0xFFB8860B);


  static const String fontFamily = 'Noto Sans';

  /// Buttons in Material 3 replace the inherited text style rather than
  /// merging with it, so a button theme that sets a size without a family
  /// loses the family. This is the one place that pairing is written down.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static ThemeData build() {
    const scheme = ColorScheme.light(
      primary: primary,
      onPrimary: accent,
      secondary: accent,
      onSecondary: primary,
      surface: surface,
      onSurface: ink,
      error: Color(0xFFB3261E),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: shell,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: accent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: accent,
          letterSpacing: 0.2,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: accent,
          textStyle: buttonLabel,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          textStyle: buttonLabel,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: const BorderSide(color: hairline, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: hairline,
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        bodyMedium: TextStyle(fontSize: 14.5, height: 1.45, color: ink),
        bodySmall: TextStyle(fontSize: 13, height: 1.4, color: muted),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: muted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// A colour to show a part in when it is selected.
  static Color selectionFor(Color base) =>
      Color.alphaBlend(selection.withValues(alpha: 0.35), base);
}
