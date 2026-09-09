/// Application-wide constants. Nothing about geometry, pricing or materials
/// lives here — those belong to their own domain files.
class AppConstants {
  AppConstants._();

  static const String appName = 'ProFrame';
  static const String appTagline = 'Draw it. Get the real thing.';

  /// Storage keys.
  static const String designsKey = 'proframe.designs.v1';
  static const String draftKey = 'proframe.draft.v1';
  static const String pricingKey = 'proframe.pricing.v1';

  /// Autosave cadence while drawing or editing (§56).
  static const Duration autosaveInterval = Duration(seconds: 8);

  /// Canvas.
  static const double gridSpacing = 24;
  static const double minZoom = 0.25;
  static const double maxZoom = 6.0;
  static const int maxUndoSteps = 120;

  /// File extension for a shareable project file (§48).
  static const String projectFileExtension = 'proframe';
}
