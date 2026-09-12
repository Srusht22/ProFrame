import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// The fonts the PDF is drawn with.
///
/// The `pdf` package's built-in Helvetica covers little more than Latin-1: a
/// note written in Arabic or Kurdish came out as a row of empty boxes, and so
/// did an em dash. The specification requires Unicode and the app's chosen
/// languages (section 8B), so real fonts are embedded instead.
///
/// Loaded once and cached: a TTF is around half a megabyte, and re-parsing it
/// for every export would be slow and pointless.
abstract final class ExportFonts {
  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _arabic;
  static pw.Font? _arabicBold;

  /// Reads the fonts. Safe to call repeatedly.
  static Future<void> load() async {
    if (_regular != null) return;
    _regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    _bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    _arabic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    _arabicBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf'),
    );
  }

  static bool get isLoaded => _regular != null;

  static pw.Font get regular => _require(_regular);
  static pw.Font get bold => _require(_bold);

  /// The fallback chain, so a Latin document with one Arabic note still draws
  /// both correctly: the layout engine tries the Latin face first and falls
  /// through to the Arabic one for anything it cannot render.
  static List<pw.Font> get fallback => [_require(_arabic), _require(_arabicBold)];

  /// The theme applied to the whole document.
  static pw.ThemeData get theme => pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: fallback,
      );

  static pw.Font _require(pw.Font? font) {
    final loaded = font;
    if (loaded == null) {
      throw StateError(
        'ExportFonts.load() must be awaited before building a PDF.',
      );
    }
    return loaded;
  }
}
