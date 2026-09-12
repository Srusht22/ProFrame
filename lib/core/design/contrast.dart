import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.1 relative luminance and contrast ratio.
///
/// This lives in the app rather than only in the tests because the finish
/// picker has to decide whether to draw a swatch's label in black or white
/// over a product colour the user chose, and guessing from lightness alone
/// gets that wrong for saturated colours.
abstract final class Contrast {
  /// WCAG AA for body text.
  static const double aa = 4.5;

  /// WCAG AA for text at or above 18pt / 14pt bold, and for UI component
  /// boundaries.
  static const double aaLarge = 3.0;

  /// WCAG AAA for body text.
  static const double aaa = 7.0;

  /// Relative luminance of [color], 0 (black) to 1 (white).
  ///
  /// Any alpha is ignored: a translucent colour's contrast depends on what is
  /// behind it, so callers must composite first.
  static double relativeLuminance(Color color) {
    double channel(double component) => component <= 0.04045
        ? component / 12.92
        : math.pow((component + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// Contrast ratio between two opaque colours, from 1 (identical) to 21
  /// (black on white). Order does not matter.
  static double ratio(Color a, Color b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Whichever of [options] reads most clearly on [background].
  static Color mostReadableOn(Color background, List<Color> options) {
    assert(options.isNotEmpty, 'needs at least one candidate');
    var best = options.first;
    var bestRatio = ratio(background, best);
    for (final option in options.skip(1)) {
      final candidate = ratio(background, option);
      if (candidate > bestRatio) {
        best = option;
        bestRatio = candidate;
      }
    }
    return best;
  }

  const Contrast._();
}
