import '../model/design.dart';

/// How many rows and columns of sections a design has.
///
/// Counted with a tolerance rather than exactly, because a hand-drawn frame
/// is a millimetre or two out of square and its sections inherit that. Two
/// panes whose tops differ by one millimetre are side by side in one row,
/// however different the numbers look.
abstract final class SectionBands {
  /// Sections whose edges are within this fraction of the design's own size
  /// are in the same band.
  static const double fraction = 0.02;

  static int rows(Design design) => _bands(
        [for (final s in design.topLevelSections) s.outline.top],
        design.heightMm,
      );

  static int columns(Design design) => _bands(
        [for (final s in design.topLevelSections) s.outline.left],
        design.widthMm,
      );

  static int _bands(List<double> edges, double spanMm) {
    if (edges.isEmpty) return 0;
    final tolerance = spanMm * fraction;
    final bands = <double>[];
    for (final edge in edges) {
      if (bands.any((b) => (b - edge).abs() <= tolerance)) continue;
      bands.add(edge);
    }
    return bands.length;
  }
}
