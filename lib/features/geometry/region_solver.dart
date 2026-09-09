
import '../../core/utilities/geometry_math.dart';
import '../../shared/models/design_region.dart';
import '../../shared/models/opening_model.dart';

/// A length of profile between or around the sections — a mullion, a transom,
/// or the piece of frame that surrounds a section placed in a corner.
///
/// These are *derived*, never authored: whatever area of the product is not
/// claimed by a section is structure, so an opening dropped into the middle of
/// a design automatically gets correct profile around it.
class SolvedBar {
  final String id;
  final Box2 rect;
  final int depthLevel;

  const SolvedBar({required this.id, required this.rect, this.depthLevel = 0});

  bool get vertical => rect.height >= rect.width;
  double get lengthMm => vertical ? rect.height : rect.width;
}

/// A section resolved to real coordinates.
class SolvedRegion {
  final DesignRegion spec;

  /// The section as the user specified it, in product coordinates.
  final Box2 rect;

  /// The hole left once the frame and any surrounding bars are taken off.
  final Box2 aperture;

  /// The leaf profile, when this section opens. Equal to [aperture] otherwise.
  final Box2 sashRect;

  /// The visible glass or panel.
  final Box2 glazingRect;

  final List<SolvedRegion> children;
  final List<SolvedBar> childBars;
  final int depthLevel;

  const SolvedRegion({
    required this.spec,
    required this.rect,
    required this.aperture,
    required this.sashRect,
    required this.glazingRect,
    this.children = const [],
    this.childBars = const [],
    this.depthLevel = 0,
  });

  String get id => spec.id;
  bool get isLeaf => children.isEmpty;
  bool get hasSash => spec.operation.isOperable;
  double get glazingAreaM2 => (glazingRect.width * glazingRect.height) / 1e6;
}

/// The fully resolved product.
class SolvedOpening {
  final OpeningModel model;
  final Box2 outerRect;
  final Box2 innerRect;
  final List<SolvedRegion> topRegions;
  final List<SolvedBar> bars;

  const SolvedOpening({
    required this.model,
    required this.outerRect,
    required this.innerRect,
    required this.topRegions,
    required this.bars,
  });

  List<SolvedRegion> get allRegions {
    final result = <SolvedRegion>[];
    void walk(SolvedRegion r) {
      result.add(r);
      for (final child in r.children) {
        walk(child);
      }
    }

    for (final r in topRegions) {
      walk(r);
    }
    return result;
  }

  List<SolvedRegion> get leaves => allRegions.where((r) => r.isLeaf).toList();

  List<SolvedBar> get allBars {
    final result = <SolvedBar>[...bars];
    for (final region in allRegions) {
      result.addAll(region.childBars);
    }
    return result;
  }

  SolvedRegion? byId(String id) {
    for (final region in allRegions) {
      if (region.id == id) return region;
    }
    return null;
  }

  /// The section under a point in product coordinates — the deepest one, so
  /// tapping a glazed panel inside a leaf selects the panel, not the leaf.
  SolvedRegion? regionAt(Vec2 point) {
    SolvedRegion? found;
    for (final region in allRegions) {
      if (region.rect.contains(point)) {
        if (found == null || region.depthLevel >= found.depthLevel) found = region;
      }
    }
    return found;
  }

  double get framePerimeterM => 2 * (model.widthMm + model.heightMm) / 1000;

  double get barLengthM => allBars.fold<double>(0, (s, b) => s + b.lengthMm) / 1000;

  double get sashPerimeterM => allRegions
      .where((r) => r.hasSash)
      .fold<double>(0, (s, r) => s + 2 * (r.sashRect.width + r.sashRect.height) / 1000);

  double get totalGlassAreaM2 => leaves
      .where((r) => r.spec.infill == CellInfill.glass)
      .fold<double>(0, (s, r) => s + r.glazingAreaM2);

  double get totalPanelAreaM2 => leaves
      .where((r) =>
          r.spec.infill == CellInfill.panel || r.spec.infill == CellInfill.louvre)
      .fold<double>(0, (s, r) => s + r.glazingAreaM2);
}

/// Turns the parametric model into absolute geometry.
///
/// Pure and deterministic: the same model always yields the same millimetres,
/// and no step here adjusts a size the user specified.
class RegionSolver {
  RegionSolver._();

  /// Two edges within this many millimetres are treated as the same edge.
  static const double edgeTolerance = 0.51;

  static SolvedOpening solve(OpeningModel model) {
    final frameFace = model.frameFaceMm;
    final barFace = model.mullionFaceMm;
    final outer = model.outerRect;
    final inner = outer.deflateEdges(
      left: frameFace,
      top: frameFace,
      right: frameFace,
      bottom: frameFace,
    );

    final solved = model.regions
        .map((region) => _solveRegion(
              region: region,
              containerRect: outer,
              containerInner: inner,
              sashFace: model.sashFaceMm,
              glazingBead: model.glazingBeadMm,
              barFace: barFace,
              depthLevel: 0,
            ))
        .toList();

    final bars = _fillBars(
      container: inner,
      holes: solved.map((r) => r.aperture).toList(),
      prefix: 'b',
      depthLevel: 0,
    );

    return SolvedOpening(
      model: model,
      outerRect: outer,
      innerRect: inner,
      topRegions: solved,
      bars: bars,
    );
  }

  static SolvedRegion _solveRegion({
    required DesignRegion region,
    required Box2 containerRect,
    required Box2 containerInner,
    required double sashFace,
    required double glazingBead,
    required double barFace,
    required int depthLevel,
  }) {
    final aperture = apertureFor(
      rect: region.rect,
      containerRect: containerRect,
      containerInner: containerInner,
      barFace: barFace,
    );

    final hasSash = region.operation.isOperable;
    final sashInner = hasSash
        ? aperture.deflateEdges(
            left: sashFace,
            top: sashFace,
            right: sashFace,
            bottom: sashFace,
          )
        : aperture;

    if (region.children.isNotEmpty) {
      final children = region.children
          .map((child) => _solveRegion(
                region: child,
                containerRect: region.rect,
                containerInner: sashInner,
                sashFace: sashFace,
                glazingBead: glazingBead,
                barFace: barFace,
                depthLevel: depthLevel + 1,
              ))
          .toList();
      final childBars = _fillBars(
        container: sashInner,
        holes: children.map((c) => c.aperture).toList(),
        prefix: '${region.id}.b',
        depthLevel: depthLevel + 1,
      );
      return SolvedRegion(
        spec: region,
        rect: region.rect,
        aperture: aperture,
        sashRect: aperture,
        glazingRect: sashInner,
        children: children,
        childBars: childBars,
        depthLevel: depthLevel,
      );
    }

    final glazing = sashInner.deflateEdges(
      left: glazingBead,
      top: glazingBead,
      right: glazingBead,
      bottom: glazingBead,
    );

    return SolvedRegion(
      spec: region,
      rect: region.rect,
      aperture: aperture,
      sashRect: aperture,
      glazingRect: glazing,
      depthLevel: depthLevel,
    );
  }

  /// The hole a section gets.
  ///
  /// An edge that sits on the outside of its container is bounded by the frame,
  /// so it takes the frame's face. An edge in the middle of the product is
  /// shared with whatever is next to it, so each side takes half the bar. That
  /// is why sections specified as 400 + 1600 in a 2000 mm product still add up
  /// to exactly 2000 mm.
  static Box2 apertureFor({
    required Box2 rect,
    required Box2 containerRect,
    required Box2 containerInner,
    required double barFace,
  }) {
    final half = barFace / 2;
    final left = (rect.left <= containerRect.left + edgeTolerance)
        ? containerInner.left
        : rect.left + half;
    final top = (rect.top <= containerRect.top + edgeTolerance)
        ? containerInner.top
        : rect.top + half;
    final right = (rect.right >= containerRect.right - edgeTolerance)
        ? containerInner.right
        : rect.right - half;
    final bottom = (rect.bottom >= containerRect.bottom - edgeTolerance)
        ? containerInner.bottom
        : rect.bottom - half;
    return Box2(left, top, right, bottom);
  }

  /// Everything inside [container] that no section claims becomes profile.
  ///
  /// The area is cut on every section edge into a grid, the covered cells are
  /// dropped, and what is left is merged back into as few boxes as possible.
  /// This works for any arrangement — including a section floating in a corner,
  /// where the result is an L of profile around it.
  static List<SolvedBar> _fillBars({
    required Box2 container,
    required List<Box2> holes,
    required String prefix,
    required int depthLevel,
  }) {
    if (container.isEmpty) return const [];
    final live = holes.where((h) => !h.isEmpty).toList();
    if (live.isEmpty) {
      return [
        SolvedBar(id: '${prefix}0', rect: container, depthLevel: depthLevel),
      ];
    }

    final xs = _cuts(
      container.left,
      container.right,
      live.expand((h) => [h.left, h.right]),
    );
    final ys = _cuts(
      container.top,
      container.bottom,
      live.expand((h) => [h.top, h.bottom]),
    );

    // Mark each grid cell as covered or not.
    final rows = ys.length - 1;
    final columns = xs.length - 1;
    if (rows <= 0 || columns <= 0) return const [];
    final covered = List.generate(
      rows,
      (r) => List.generate(columns, (c) {
        final centre = Vec2((xs[c] + xs[c + 1]) / 2, (ys[r] + ys[r + 1]) / 2);
        return live.any((h) => h.contains(centre));
      }),
    );

    // Merge runs across each row, then merge identical runs down the rows.
    final pieces = <_FillPiece>[];
    for (var r = 0; r < rows; r++) {
      var c = 0;
      while (c < columns) {
        if (covered[r][c]) {
          c++;
          continue;
        }
        var end = c;
        while (end + 1 < columns && !covered[r][end + 1]) {
          end++;
        }
        pieces.add(_FillPiece(xs[c], ys[r], xs[end + 1], ys[r + 1]));
        c = end + 1;
      }
    }

    final merged = <_FillPiece>[];
    for (final piece in pieces) {
      final match = merged.indexWhere((m) =>
          (m.left - piece.left).abs() < 1e-6 &&
          (m.right - piece.right).abs() < 1e-6 &&
          (m.bottom - piece.top).abs() < 1e-6);
      if (match >= 0) {
        merged[match] = _FillPiece(
          merged[match].left,
          merged[match].top,
          merged[match].right,
          piece.bottom,
        );
      } else {
        merged.add(piece);
      }
    }

    var index = 0;
    return merged
        .map((p) => SolvedBar(
              id: '$prefix${index++}',
              rect: Box2(p.left, p.top, p.right, p.bottom),
              depthLevel: depthLevel,
            ))
        .toList();
  }

  static List<double> _cuts(double start, double end, Iterable<double> inner) {
    final values = <double>{start, end};
    for (final value in inner) {
      if (value > start + 1e-6 && value < end - 1e-6) values.add(value);
    }
    final sorted = values.toList()..sort();
    // Collapse cuts that are the same edge within tolerance.
    final result = <double>[sorted.first];
    for (final value in sorted.skip(1)) {
      if (value - result.last > 1e-6) result.add(value);
    }
    return result;
  }
}

class _FillPiece {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _FillPiece(this.left, this.top, this.right, this.bottom);
}

/// Number of hinges a leaf of this height needs. Shared by the 3D model, the
/// price and the validator so they can never disagree.
int hingeCountForLeaf(double leafHeightMm, {bool isDoor = false}) {
  if (isDoor) {
    if (leafHeightMm <= 2100) return 3;
    if (leafHeightMm <= 2600) return 4;
    return 5;
  }
  if (leafHeightMm <= 900) return 2;
  if (leafHeightMm <= 1600) return 3;
  return 4;
}
