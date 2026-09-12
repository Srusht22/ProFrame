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

  /// Glazing in the 2.5D viewer. A cool tint rather than a transparent hole,
  /// because a pane has to read as glass against a cream background.
  static const Color glassTint = Color(0xFFBBD2D6);
  static const Color glassHighlight = Color(0xFFE8F2F3);

  /// Handles and hinges. Deliberately not the product finish: hardware is a
  /// fitting, and showing it in the frame colour would hide it.
  static const Color hardware = Color(0xFF9AA0A2);
  static const Color hardwareEdge = Color(0xFF5E6467);
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

/// The application's type.
abstract final class AppFonts {
  /// The interface font. Bundled, so the app looks and reads the same on every
  /// device rather than inheriting whatever the platform supplies.
  static const String family = 'Noto Sans';

  /// Tried for anything the Latin face cannot draw — Arabic and Kurdish notes,
  /// which the factory writes routinely. Without this they would render as
  /// empty boxes on a device with no Arabic font installed.
  static const List<String> fallback = ['Noto Sans Arabic'];

  const AppFonts._();
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

/// Line weights and hit sizes for the drawing canvas, in logical pixels.
///
/// Here rather than in the painter so the canvas has no magic numbers in it
/// (spec section 7), and so the painter and the hit-testing agree by
/// construction rather than by two people remembering the same figure.
abstract final class AppCanvasMetrics {
  /// Wet ink, before the stroke has been read.
  static const double inkWidth = 3;

  /// The frame, once recognised and snapped.
  static const double frameWidth = 4;

  /// A mullion or transom.
  static const double dividerWidth = 3;

  /// A selected divider, thickened so the selection is not colour-only.
  static const double selectedDividerWidth = 6;

  /// How near a finger has to land to grab a divider.
  static const double dividerGrabRadius = 24;

  /// Dimension line weight and the length of its end ticks.
  static const double dimensionWidth = 1.5;
  static const double dimensionTick = 6;

  /// Gap between the frame and its dimension line.
  static const double dimensionOffset = 28;

  /// The note marker drawn in the corner of a panel that has one.
  static const double noteMarkerRadius = 11;

  /// The opening symbol drawn inside a Z panel.
  static const double openingSymbolInset = 14;

  const AppCanvasMetrics._();
}

/// Line weights for the 2.5D viewer, in logical pixels.
///
/// Separate from [AppCanvasMetrics] because the viewer draws a solid object
/// and the canvas draws a sketch; sharing one set of weights would make one of
/// them wrong.
abstract final class AppViewerMetrics {
  /// The outline around every solid surface, so shape survives shading.
  static const double surfaceEdge = 1;

  /// The dashed opening symbol.
  static const double glyphWidth = 2;
  static const double glyphDash = 9;
  static const double glyphGap = 6;

  /// The insect-screen hatch.
  static const double meshWidth = 0.7;

  /// Padding around the product inside the viewport, as a fraction of the
  /// smaller axis — room for a sash to swing out without clipping.
  static const double viewportMargin = 0.14;

  /// Zoom limits for the pinch gesture.
  static const double minZoom = 0.5;
  static const double maxZoom = 5;

  const AppViewerMetrics._();
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 240);

  /// How long a sash takes to swing in the 2.5D preview.
  ///
  /// 320 ms: inside the 250-400 ms the spec asks for, and long enough that the
  /// hinge side can be read from the motion rather than only from the symbol.
  static const Duration sashSwing = Duration(milliseconds: 320);

  const AppDurations._();
}
