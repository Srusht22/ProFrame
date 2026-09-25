import 'package:flutter/material.dart';

import '../canvas/cad_style.dart';

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

  /// The light appearance: the one the application was drawn in.
  static ThemeData build() => _build(Palette.light);

  /// The dark appearance.
  static ThemeData dark() => _build(Palette.dark);

  static ThemeData _build(Palette p) {
    final dark = p.brightness == Brightness.dark;
    final scheme = dark
        ? ColorScheme.dark(
            primary: p.primary,
            onPrimary: p.onPrimary,
            secondary: accent,
            onSecondary: primary,
            surface: p.surface,
            onSurface: p.ink,
            onSurfaceVariant: p.muted,
            surfaceContainerLowest: p.shell,
            surfaceContainerLow: p.surface,
            surfaceContainer: p.surface,
            surfaceContainerHigh: p.raised,
            surfaceContainerHighest: p.raised,
            outline: p.muted,
            outlineVariant: p.hairline,
            error: const Color(0xFFF2B8B5),
            onError: const Color(0xFF601410),
          )
        : const ColorScheme.light(
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
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: p.shell,
      canvasColor: p.surface,
      splashFactory: InkSparkle.splashFactory,
      extensions: [p],
      appBarTheme: AppBarTheme(
        backgroundColor: p.band,
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
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.band,
          foregroundColor: accent,
          // Off is plainly off in either appearance, and still legible.
          disabledBackgroundColor: p.ink.withValues(alpha: 0.1),
          disabledForegroundColor: p.ink.withValues(alpha: 0.42),
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
          foregroundColor: p.primary,
          textStyle: buttonLabel,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          side: BorderSide(color: p.hairline, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.hairline,
        thumbColor: p.primary,
        overlayColor: p.primary.withValues(alpha: 0.12),
        trackHeight: 4,
        // Small enough that the halo stays inside the slider's own box and
        // does not print over whatever is beside it.
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        isDense: true,
        hintStyle: TextStyle(color: p.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: 0.3),
        selectionHandleColor: p.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFE4EBE8) : const Color(0xFF26302D),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          color: dark ? const Color(0xFF0C1613) : Colors.white,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.raised,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(fontFamily: fontFamily, color: p.ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.raised,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.raised,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? p.raised : const Color(0xFF26302D),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: dark ? p.ink : Colors.white,
        ),
        actionTextColor: dark ? p.primary : accent,
      ),
      iconTheme: IconThemeData(color: p.ink),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w700,
          color: p.ink,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
        bodyMedium: TextStyle(fontSize: 14.5, height: 1.45, color: p.ink),
        bodySmall: TextStyle(fontSize: 13, height: 1.4, color: p.muted),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.muted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// A colour to show a part in when it is selected.
  static Color selectionFor(Color base) =>
      Color.alphaBlend(selection.withValues(alpha: 0.35), base);
}

/// The colours of one appearance, light or dark, by what each is *for*.
///
/// The light appearance is exactly the colours [AppTheme] has always had.
/// The dark one is not those colours inverted: every role is chosen afresh
/// to be read against the dark surface it will sit on, and the one colour
/// that plays two roles in the light — the house green, which is both the
/// band a heading sits on and the colour of a chosen icon — is split in two
/// here, because dark green lettering on a dark surface would vanish.
///
/// Reached by `context.palette` from anything with a context; a painter is
/// handed one, and defaults to [light], so a painter built without being
/// told draws exactly as it always has.
@immutable
class Palette extends ThemeExtension<Palette> {
  final Brightness brightness;

  /// The house colour as it reads *on* a surface: a chosen icon, a chosen
  /// word, a focus ring, an outline. Deep green on light; a clear mint on
  /// dark.
  final Color primary;

  /// What stands on a fill of [primary].
  final Color onPrimary;

  /// The house colour as a *ground*: a heading's band, a filled button, the
  /// chosen tool's pill. Deep green in both appearances, carrying [onBand].
  final Color band;
  final Color onBand;

  /// A note to the user laid across the work — a question about the sheet,
  /// a drawing not yet read — and what is written on it. Cream on light; a
  /// deep olive with cream lettering on dark, so it does not glare.
  final Color notice;
  final Color onNotice;

  final Color ink;
  final Color muted;
  final Color hairline;
  final Color surface;

  /// A surface over a surface: a menu, a dialog, a card lifted off a panel.
  final Color raised;
  final Color canvas;
  final Color shell;

  /// What a selected part is outlined in.
  final Color selection;

  /// The colour of a shadow: always darker than what casts it.
  final Color shadow;

  /// The ink a new stroke is drawn in when nothing else has been chosen.
  final Color drawnInk;

  /// The 3D view's backdrop, top to bottom, and the line the model stands on.
  final Color skyTop;
  final Color skyBottom;
  final Color groundLine;

  /// The edges of a solid.
  final Color modelEdge;

  /// The technical drawing, and the sheet the user draws on.
  final CadColours cad;

  const Palette({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.band,
    required this.onBand,
    required this.notice,
    required this.onNotice,
    required this.ink,
    required this.muted,
    required this.hairline,
    required this.surface,
    required this.raised,
    required this.canvas,
    required this.shell,
    required this.selection,
    required this.shadow,
    required this.drawnInk,
    required this.skyTop,
    required this.skyBottom,
    required this.groundLine,
    required this.modelEdge,
    required this.cad,
  });

  static const light = Palette(
    brightness: Brightness.light,
    primary: AppTheme.primary,
    onPrimary: AppTheme.accent,
    band: AppTheme.primary,
    onBand: AppTheme.accent,
    notice: AppTheme.accent,
    onNotice: AppTheme.primary,
    ink: AppTheme.ink,
    muted: AppTheme.muted,
    hairline: AppTheme.hairline,
    surface: AppTheme.surface,
    raised: AppTheme.surface,
    canvas: AppTheme.canvas,
    shell: AppTheme.shell,
    selection: AppTheme.selection,
    shadow: AppTheme.ink,
    drawnInk: AppTheme.drawnInk,
    skyTop: Color(0xFFF8FAF9),
    skyBottom: Color(0xFFE2E8E6),
    groundLine: AppTheme.ink,
    modelEdge: AppTheme.ink,
    cad: Cad.paper,
  );

  /// Dark, and quiet: near-black greens rather than grey, so it is still
  /// this application; lettering at a comfortable off-white rather than
  /// pure white; each step between surfaces enough to see an edge by.
  static const dark = Palette(
    brightness: Brightness.dark,
    primary: Color(0xFF7FD3C2),
    onPrimary: Color(0xFF042620),
    band: Color(0xFF0C4A42),
    onBand: AppTheme.accent,
    notice: Color(0xFF2E2A17),
    onNotice: Color(0xFFFFE7A3),
    ink: Color(0xFFE4EBE8),
    muted: Color(0xFF9FAEA9),
    hairline: Color(0xFF2C3835),
    surface: Color(0xFF171F1D),
    raised: Color(0xFF1F2926),
    canvas: Color(0xFF141C1A),
    shell: Color(0xFF0E1412),
    selection: Color(0xFFE8B84A),
    shadow: Colors.black,
    drawnInk: Color(0xFF7FD3C2),
    skyTop: Color(0xFF1E2826),
    skyBottom: Color(0xFF0F1614),
    groundLine: Color(0xFFE4EBE8),
    modelEdge: Color(0xFF050807),
    cad: Cad.night,
  );

  bool get isDark => brightness == Brightness.dark;

  /// The edge of a swatch: a colour the user chose is shown as it is, and
  /// a dark one on a dark panel needs an edge that can be seen to be seen
  /// at all.
  Color get edge => isDark ? muted.withValues(alpha: 0.6) : hairline;

  /// The palette in effect where [context] is.
  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>() ?? light;

  /// [colour] as it has to be drawn on the drawing's sheet to be seen: see
  /// [legibleOn].
  Color legible(Color colour) => legibleOn(cad.sheet, colour);

  /// A colour to show a part in when it is selected.
  Color selectionFor(Color base) =>
      Color.alphaBlend(selection.withValues(alpha: 0.35), base);

  @override
  Palette copyWith() => this;

  // An appearance is one set or the other; halfway between them is neither.
  @override
  Palette lerp(Palette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// `context.palette`: the colours in effect here.
extension PaletteOf on BuildContext {
  Palette get palette => Palette.of(this);
}
