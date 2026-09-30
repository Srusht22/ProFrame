import 'dart:math' as math;

import '../geometry/tolerances.dart';
import '../model/design.dart';
import '../model/design_tree.dart';
import '../model/elements.dart';

/// Which way a chain of dimensions runs.
enum DimensionAxis { horizontal, vertical }

/// Which side of the drawing a chain of dimensions stands on.
///
/// The drawing is dimensioned the way an elevation is: what the whole is
/// divided into and how big the whole is, along the foot and down the left;
/// the openings, and what each divided part is divided into, along the head
/// and down the right. So every kind of figure has its own place, and a
/// reader who knows the convention knows which one they are looking at.
enum DimensionSide {
  bottom(DimensionAxis.horizontal),
  left(DimensionAxis.vertical),
  top(DimensionAxis.horizontal),
  right(DimensionAxis.vertical);

  const DimensionSide(this.axis);
  final DimensionAxis axis;
}

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

  /// One of the main divisions' daylight, across or down.
  daylight,

  /// An opening: the region the user marked, across or down.
  opening,

  /// One pane of a divided part — a division made inside a section, such
  /// as the glass above a rail and the panel below it.
  division,
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

  /// Which side of the drawing it stands on: the foot or the left unless
  /// it says otherwise.
  final DimensionSide side;

  const DimensionChain({
    required this.axis,
    required this.runs,
    this.row = 0,
    DimensionSide? side,
  }) : side =
           side ??
           (axis == DimensionAxis.horizontal
               ? DimensionSide.bottom
               : DimensionSide.left);

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
    // Beyond the row of divisions along the same side, where there is one;
    // nearest the drawing where there is not, rather than a row's width out
    // from nothing.
    int overallRow(DimensionAxis axis) =>
        chains.any((c) => c.axis == axis) ? 1 : 0;
    chains.add(DimensionChain(
      axis: DimensionAxis.horizontal,
      row: overallRow(DimensionAxis.horizontal),
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
      row: overallRow(DimensionAxis.vertical),
      runs: [
        ChainRun(
          fromMm: outer.top,
          toMm: outer.bottom,
          note: 'Overall',
          of: ChainRunOf.overall,
        ),
      ],
    ));

    chains.addAll(_openingsAndDivisions(design));
    return chains;
  }

  /// The chains along the head and down the right: nearest the drawing, what
  /// each divided part is divided into; beyond them, each opening's width
  /// and height.
  ///
  /// Each is read off a section that is there — an opening's own region, a
  /// pane the user's line made — and nothing else. Parts whose figures would
  /// run over one another along a side go on rows of their own, so no two
  /// figures on a row ever measure overlapping lengths.
  static List<DimensionChain> _openingsAndDivisions(Design design) {
    final out = <DimensionChain>[];
    final tree = DesignTree.of(design);
    for (final side in const [DimensionSide.top, DimensionSide.right]) {
      final axis = side.axis;
      final divisions = <List<ChainRun>>[];
      for (final branch in tree.everySection) {
        if (branch.panes.length < 2) continue;
        if (!_squareWithin(design, branch)) continue;
        final panes = [
          for (final pane in branch.panes) ?design.sectionById(pane.sectionId),
        ];
        final bands = _bandsOf(panes, axis, 'Division', ChainRunOf.division);
        if (bands.length > 1) divisions.add(bands);
      }
      final openings = <List<ChainRun>>[];
      for (final opening in design.openingsInOrder) {
        final section = design.sectionById(opening.sectionId);
        if (section == null) continue;
        final box = section.outline;
        openings.add([
          ChainRun(
            fromMm: axis == DimensionAxis.horizontal ? box.left : box.top,
            toMm: axis == DimensionAxis.horizontal ? box.right : box.bottom,
            note: 'Opening',
            of: ChainRunOf.opening,
            sectionId: section.id,
          ),
        ]);
      }
      var row = 0;
      for (final groups in [divisions, openings]) {
        final rows = _packed(_once(groups));
        for (final runs in rows) {
          out.add(DimensionChain(
            axis: axis,
            runs: runs,
            row: row++,
            side: side,
          ));
        }
      }
    }
    return out;
  }

  /// Whether every bar drawn inside [branch] runs along an axis — the same
  /// question [isRectilinear] asks of the design, asked of one part.
  static bool _squareWithin(Design design, TreeSection branch) {
    for (final id in branch.barIds) {
      final bar = design.dividerById(id);
      if (bar == null) continue;
      if (!bar.isVertical && !bar.isHorizontal) return false;
    }
    return true;
  }

  /// [groups] with each measurement written once: a part whose runs are
  /// exactly those of one already there — three openings side by side, the
  /// same height, each divided at the same place — says nothing new down
  /// the side, and a second row of the same figures would only leave the
  /// reader wondering which is which.
  static List<List<ChainRun>> _once(List<List<ChainRun>> groups) {
    bool same(List<ChainRun> a, List<ChainRun> b) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if ((a[i].fromMm - b[i].fromMm).abs() > Tol.sameLengthMm ||
            (a[i].toMm - b[i].toMm).abs() > Tol.sameLengthMm) {
          return false;
        }
      }
      return true;
    }

    final kept = <List<ChainRun>>[];
    for (final group in groups) {
      final sorted = [...group]..sort((a, b) => a.fromMm.compareTo(b.fromMm));
      if (kept.any((k) => same(k, sorted))) continue;
      kept.add(sorted);
    }
    return kept;
  }

  /// [groups] — each the runs of one part, which stay together — put on as
  /// few rows as they fit on without any two overlapping: each on the
  /// first row it is clear of.
  static List<List<ChainRun>> _packed(List<List<ChainRun>> groups) {
    final rows = <List<ChainRun>>[];
    for (final group in groups) {
      final from = group.map((r) => r.fromMm).reduce(math.min);
      final to = group.map((r) => r.toMm).reduce(math.max);
      List<ChainRun>? home;
      for (final row in rows) {
        final clear = row.every(
          (r) =>
              r.toMm <= from + Tol.sameLengthMm ||
              r.fromMm >= to - Tol.sameLengthMm,
        );
        if (clear) {
          home = row;
          break;
        }
      }
      if (home == null) rows.add(home = []);
      home.addAll(group);
    }
    for (final row in rows) {
      row.sort((a, b) => a.fromMm.compareTo(b.fromMm));
    }
    return rows;
  }

  /// True when every bar that divides the design runs along an axis, so the
  /// bands down the outside of the drawing mean something.
  ///
  /// The design's own bars, at the design's own level — the chains outside
  /// the drawing measure the main divisions, so those are what decide
  /// whether a band is a real thing. A diagonal glazing bar inside one sash
  /// makes that sash's own panes unbandable; it says nothing about the
  /// lights either side of it, and it must not strike the figures off a
  /// drawing that is otherwise square.
  static bool isRectilinear(Design design) {
    for (final divider in design.topLevelDividers) {
      if (!divider.isVertical && !divider.isHorizontal) return false;
    }
    return true;
  }

  /// The distinct daylight bands along one axis, taken from the sections
  /// themselves so the numbers and the drawing cannot disagree.
  static List<ChainRun> _bands(Design design, DimensionAxis axis) =>
      // The main divisions. What is inside one of them is dimensioned by a
      // chain of its own, along the head or down the right.
      _bandsOf(design.topLevelSections, axis, 'Daylight', ChainRunOf.daylight);

  /// The distinct bands [sections] make along one axis.
  static List<ChainRun> _bandsOf(
    List<SectionElement> sections,
    DimensionAxis axis,
    String note,
    ChainRunOf of,
  ) {
    final spans = <(double, double, String)>[];
    for (final section in sections) {
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
        note: note,
        of: of,
        sectionId: sectionId,
      ));
      reachedTo = math.max(reachedTo, to);
    }
    return runs;
  }
}
