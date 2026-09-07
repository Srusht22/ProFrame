/// 8pt spacing / radius / elevation scale used across the design system.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  /// Breakpoints for the adaptive shell.
  static const double breakpointCompact = 600; // phones
  static const double breakpointMedium = 1024; // tablets / small laptops
  static const double breakpointExpanded = 1440; // desktop
}
