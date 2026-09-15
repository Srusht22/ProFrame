import 'dart:math' as math;

import '../geometry/tolerances.dart';
import '../model/design.dart';

/// Which way a chain of dimensions runs.
enum DimensionAxis { horizontal, vertical }

/// What a measurement measures, so that changing the number changes the
/// right thing.
///
/// A dimension on this drawing is not a caption. Each one names a piece of
/// geometry, and typing a new value into it is an instruction to that piece
/// of geometry — which is only possible if the figure knows what it came
/// from.
enum ChainRunOf {
  /// The whole frame, across or down.
  overall,

  /// One section's daylight, across or down.
  daylight,
}

/// One measurement in a chain: from here to there, along the axis.
class ChainRun {
  final double fromMm;
  final double toMm;

  /// What is being measured, for the drawing's own legend.
  final String note;

  /// The kind of geometry this figure measures.
  final ChainRunOf of;

  /// The section it measures, when it measures one. Null on an overall.
  final String? sectionId;

  const ChainRun({
    required this.fromMm,
    required this.toMm,
    this.note = '',
    this.of = ChainRunOf.daylight,
    this.sectionId,
  });

  double get valueMm => toMm - fromMm;
  double get middleMm => (fromMm + toMm) / 2;
}

/// A row of dimensions along one side of the drawing.
class DimensionChain {
  final DimensionAxis axis;
  final List<ChainRun> runs;

  /// How far out from the drawing this row sits, 0 being nearest.
  final int row;

  const DimensionChain({
    required this.axis,
    required this.runs,
    this.row = 0,
  });

  bool get isEmpty => runs.isEmpty;
}

/// Works out the dimensions a technical drawing of this design would carry.
///
/// Every figure here is a measurement of geometry that already exists — the
/// daylight width of a section that is there, the overall size of the frame
/// that is there. Nothing in this file decides what a dimension ought to be,
/// and nothing it produces can move a line: the chains are read off the
/// design and drawn beside it.
abstract final class DimensionChains {
  /// The chains for [design], nearest row first.
  static List<DimensionChain> of(Design design) {
    final frame = design.frame;
    if (frame == null) return const [];

    final chains = <DimensionChain>[];

    // Daylight openings, when the design is drawn to the axes. On a design
    // with a diagonal in it a band means nothing, so it is not drawn rather
    // than being drawn wrong.
    if (isRectilinear(design)) {
      final across = _bands(design, DimensionAxis.horizontal);
      if (across.length > 1) {
        chains.add(DimensionChain(
          axis: DimensionAxis.horizontal,
          runs: across,
        ));
      }
      final down = _bands(design, DimensionAxis.vertical);
      if (down.length > 1) {
        chains.add(DimensionChain(axis: DimensionAxis.vertical, runs: down));
      }
    }

    final outer = frame.outline;
    final overallRow = chains.isEmpty ? 0 : 1;
    chains.add(DimensionChain(
      axis: DimensionAxis.horizontal,
      row: overallRow,
      runs: [
        ChainRun(
          fromMm: outer.left,
          toMm: outer.right,
          note: 'Overall',
          of: ChainRunOf.overall,
        ),
      ],
    ));
    chains.add(DimensionChain(
      axis: DimensionAxis.vertical,
      row: overallRow,
      runs: [
        ChainRun(
          fromMm: outer.top,
          toMm: outer.bottom,
          note: 'Overall',
          of: ChainRunOf.overall,
        ),
      ],
    ));

    return chains;
  }

  /// True when every bar runs along an axis, so bands mean something.
  static bool isRectilinear(Design design) {
    for (final divider in design.dividers) {
      if (!divider.isVertical && !divider.isHorizontal) return false;
    }
    return true;
  }

  /// The distinct daylight bands along one axis, taken from the sections
  /// themselves so the numbers and the drawing cannot disagree.
  static List<ChainRun> _bands(Design design, DimensionAxis axis) {
    // The main divisions. What is inside one of them is dimensioned by its
    // own label rather than by a chain along the outside of the design.
    final spans = <(double, double, String)>[];
    for (final section in design.topLevelSections) {
      final span = axis == DimensionAxis.horizontal
          ? (section.outline.left, section.outline.right, section.id)
          : (section.outline.top, section.outline.bottom, section.id);
      final already = spans.any((s) =>
          (s.$1 - span.$1).abs() <= Tol.sameLengthMm &&
          (s.$2 - span.$2).abs() <= Tol.sameLengthMm);
      if (!already) spans.add(span);
    }

    // Only the bands that stack up into one row: a section that starts or
    // ends part way through another one belongs to a different column, and
    // dimensioning them together would produce a chain that does not add up.
    spans.sort((a, b) => a.$1.compareTo(b.$1));
    final runs = <ChainRun>[];
    var reachedTo = -double.infinity;
    for (final (from, to, sectionId) in spans) {
      if (from < reachedTo - Tol.sameLengthMm) continue;
      runs.add(ChainRun(
        fromMm: from,
        toMm: to,
        note: 'Daylight',
        sectionId: sectionId,
      ));
      reachedTo = math.max(reachedTo, to);
    }
    return runs;
  }
}
