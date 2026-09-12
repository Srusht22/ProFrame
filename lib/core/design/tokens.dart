import 'package:flutter/widgets.dart';

/// The single place brand colour, spacing, radius and timing values are
/// defined.
///
/// Widgets read from here or from [ThemeData]; no widget in this project
/// declares its own `Color(0x...)` (spec section 7). A token that is not used
/// yet is not declared here — the palette grows with the screens that need it.
abstract final class AppColors {
  /// Brand cream. The main background and the text/icon colour that sits on
  /// [deepGreen].
  static const Color cream = Color(0xFFFFEFB3);

  /// Brand deep green. Primary buttons, headings, navigation and drawing
  /// tools, and the text/icon colour that sits on [cream].
  static const Color deepGreen = Color(0xFF013E37);

  /// A lighter green for hover/pressed states and secondary emphasis. Derived
  /// from [deepGreen] rather than invented, so the family stays consistent.
  static const Color deepGreenHover = Color(0xFF02564C);

  /// Restrained neutral surfaces for forms, canvas areas and panels
  /// (spec section 7). The drawing surface is deliberately near-white so a
  /// pencil stroke reads the way it does on paper.
  static const Color surface = Color(0xFFFBFAF5);
  static const Color canvasSurface = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFD6D2C4);
  static const Color mutedText = Color(0xFF5A5F5B);

  /// Status colours. These are never the *only* signal — every state that uses
  /// one also carries a label or an icon (spec section 7, accessibility).
  static const Color danger = Color(0xFF8C1D18);
  static const Color dangerSurface = Color(0xFFFBEAE8);
  static const Color caution = Color(0xFF6B4E00);
  static const Color cautionSurface = Color(0xFFFDF3D6);

  /// Brand colours are not product colours. What the door or window is
  /// actually finished in is chosen by the user from a finish catalogue
  /// (`domain/product/finish.dart`), never from this class.
  const AppColors._();
}

/// Spacing scale. A 4dp base, because the 48dp minimum touch target divides
/// evenly into it.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  const AppSpacing._();
}

abstract final class AppRadius {
  static const double sm = 6;
  static const double md = 12;
  static const double lg = 20;

  const AppRadius._();
}

/// Sizes that exist for accessibility reasons rather than aesthetic ones.
abstract final class AppSizing {
  /// Minimum interactive size in logical pixels. The users are factory workers
  /// operating a tablet with work gloves on, so this is a floor that applies
  /// to every control, not a target for the important ones
  /// (spec section 7).
  static const double minTouchTarget = 48;

  /// The two large product choices on the first screen.
  static const double primaryChoiceMinHeight = 96;

  /// Width of the properties panel on expanded layouts.
  static const double propertiesPanelWidth = 320;

  /// Width of the tool rail on expanded layouts.
  static const double toolRailWidth = 88;

  const AppSizing._();
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 240);

  /// How long a sash takes to swing in the 3D preview. Long enough to read the
  /// hinge side from the motion.
  static const Duration sashSwing = Duration(milliseconds: 900);

  const AppDurations._();
}
