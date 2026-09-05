class AppConstants {
  static const String appName = 'ProFrame';
  static const String appTagline = 'Parametric 3D Product Configurator';

  // Default Window Parameters (in mm)
  static const double defaultWidthMm = 1200.0;
  static const double defaultHeightMm = 1500.0;
  static const double defaultDepthMm = 50.0;
  static const int defaultSections = 2;

  // Window Dimension Limits (in mm)
  static const double minWidthMm = 400.0;
  static const double maxWidthMm = 4000.0;
  static const double minHeightMm = 400.0;
  static const double maxHeightMm = 3000.0;
  static const double minDepthMm = 30.0;
  static const double maxDepthMm = 120.0;

  // Section Limits
  static const int minSections = 1;
  static const int maxSections = 5;

  // Ergonomic factory handle standard height
  static const double defaultHandleHeightMm = 1050.0;
}
