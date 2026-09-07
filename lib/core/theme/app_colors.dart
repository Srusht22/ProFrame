import 'package:flutter/material.dart';

/// ProFrame brand & design-system colors.
///
/// The two brand colors are fixed by the company identity and must not be
/// substituted: [brandDarkGreen] and [brandCream]. Every other color in this
/// file is a supporting neutral / semantic color chosen to keep the two
/// brand colors used deliberately (navigation, primary actions, selected
/// states, key accents) rather than smeared across the whole UI.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------
  // Brand
  // ---------------------------------------------------------------------
  static const Color brandDarkGreen = Color(0xFF013E37);
  static const Color brandDarkGreenDeep = Color(0xFF012722);
  static const Color brandDarkGreenLight = Color(0xFF0B5A4F);
  static const Color brandCream = Color(0xFFFFEFB3);
  static const Color brandCreamDeep = Color(0xFFF5DD86);
  static const Color brandCreamSoft = Color(0xFFFFF8E4);

  // ---------------------------------------------------------------------
  // Neutrals (light theme surfaces)
  // ---------------------------------------------------------------------
  static const Color neutralWhite = Color(0xFFFFFFFF);
  static const Color neutralOffWhite = Color(0xFFFAF9F5);
  static const Color neutralSurface = Color(0xFFF3F2EC);
  static const Color neutralBorder = Color(0xFFE3E1D7);
  static const Color neutralDivider = Color(0xFFEAE8DE);

  static const Color textPrimary = Color(0xFF14201E);
  static const Color textSecondary = Color(0xFF4D5B58);
  static const Color textMuted = Color(0xFF8A968F);
  static const Color textOnDark = Color(0xFFF6F5EF);
  static const Color textOnDarkMuted = Color(0xFFB8C5C1);

  // ---------------------------------------------------------------------
  // Neutrals (dark theme surfaces)
  // ---------------------------------------------------------------------
  static const Color darkBackground = Color(0xFF0C1211);
  static const Color darkSurface = Color(0xFF121D1B);
  static const Color darkSurfaceElevated = Color(0xFF17251F);
  static const Color darkBorder = Color(0xFF23342F);

  // ---------------------------------------------------------------------
  // Semantic
  // ---------------------------------------------------------------------
  static const Color success = Color(0xFF2E7D5B);
  static const Color successSurface = Color(0xFFE4F3EA);
  static const Color warning = Color(0xFFB8781F);
  static const Color warningSurface = Color(0xFFFBF0DC);
  static const Color error = Color(0xFFB3372B);
  static const Color errorSurface = Color(0xFFFBE7E4);
  static const Color info = Color(0xFF2E6B8A);
  static const Color infoSurface = Color(0xFFE4F0F6);
  static const Color disabled = Color(0xFFC7CBC5);

  /// Status colors used consistently across quotations/orders/manufacturing
  /// badges regardless of the exact entity status enum.
  static const Map<String, Color> statusPalette = {
    'draft': textMuted,
    'pending': warning,
    'sent': info,
    'viewed': info,
    'confirmed': brandDarkGreenLight,
    'inProduction': warning,
    'qualityControl': Color(0xFF7C5AC0),
    'ready': info,
    'accepted': success,
    'approved': success,
    'delivered': success,
    'installed': success,
    'completed': success,
    'rejected': error,
    'expired': disabled,
    'cancelled': error,
  };
}
