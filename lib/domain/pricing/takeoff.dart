import '../dimensions/measurements.dart';
import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../model/design.dart';
import '../model/design_geometry.dart';
import '../model/elements.dart';
import '../model/infill.dart';
import '../model/materials.dart';

/// What a design is made of, measured: the quantities a price multiplies.
///
/// **It reads the canonical design and nothing else**, through the same
/// geometry every view draws from — `DesignGeometry` for a bar's body, a
/// pane's fill and a leaf's outline, `Infill.partsOf` for the parts — so
/// what is priced is what is drawn and built. It works nothing out that the
/// design does not already say, holds nothing, and changes nothing: no
/// geometry is made, squared or tidied for it. An angled design's area is
/// its outline's own, not its box's.
///
/// Every figure comes out in the units a price is quoted in — metres of
/// profile, square metres of glass — turned from the design's millimetres
/// here and only here.
class PricingTakeoff {
  /// The frame's overall size, in centimetres, as the user reads it.
  final double widthCm;
  final double heightCm;

  /// The area inside the frame's outline — the polygon's own, square or
  /// not — in square metres.
  final double areaM2;

  /// The length of the frame's members: every side of the outline that
  /// carries one, so a side left open is not charged as profile.
  final double frameMetres;

  /// The frame's own finish: its material and its colour.
  final Finish frameFinish;

  /// Joints of the frame that are not square: corners where a side meets
  /// the next at anything but a right angle, or along a slope.
  final int angledJoints;

  final List<BarTakeoff> bars;
  final List<PaneTakeoff> panes;
  final List<LeafTakeoff> leaves;
  final List<PieceTakeoff> pieces;

  const PricingTakeoff({
    required this.widthCm,
    required this.heightCm,
    required this.areaM2,
    required this.frameMetres,
    required this.frameFinish,
    required this.angledJoints,
    required this.bars,
    required this.panes,
    required this.leaves,
    required this.pieces,
  });

  double get widthM => widthCm / 100;

  int get openings => leaves.length;
  int get glassRegions => panes.where((p) => p.isGlass).length;
  int get panelRegions => panes.where((p) => p.isPanel).length;
  int get dividers => bars.length;

  /// How many pieces of ironmongery of each kind.
  Map<HardwareKind, int> get hardwareCounts {
    final counts = <HardwareKind, int>{};
    for (final p in pieces) {
      counts[p.kind] = (counts[p.kind] ?? 0) + 1;
    }
    return counts;
  }

  /// Why [design] cannot be measured, or null where it can.
  ///
  /// A frame of nothing, or a coordinate that is not a number, has no size
  /// to price; that is said rather than priced at zero or at NaN.
  static String? problemWith(Design design) {
    final frame = design.frame;
    if (frame == null) return 'Nothing has been drawn yet.';
    final outline = frame.outline;
    final finite = outline.corners.every((c) => c.x.isFinite && c.y.isFinite);
    if (!finite || outline.corners.length < 3) {
      return 'The outline cannot be measured.';
    }
    if (!(outline.width > 0) || !(outline.height > 0) || !(outline.area > 0)) {
      return 'The design has no width or no height.';
    }
    return null;
  }

  /// Whether the user has given the design its overall width and height.
  static bool sizesGiven(Design design) =>
      Measurements.knowsOverall(design, MeasureAxis.across) &&
      Measurements.knowsOverall(design, MeasureAxis.down);

  /// [design] measured. Call [problemWith] first: a design it objects to
  /// has nothing here to measure.
  static PricingTakeoff of(Design design) {
    final frame = design.frame!;
    final geometry = DesignGeometry.of(design);
    final outline = frame.outline;

    var frameMm = 0.0;
    final edges = outline.edges;
    for (var i = 0; i < edges.length; i++) {
      if (frame.hasMember(i)) frameMm += edges[i].length;
    }

    final bars = <BarTakeoff>[
      for (final bar in design.dividers)
        BarTakeoff(
          id: bar.id,
          // The bar's body as every view draws it — trimmed to the frame's
          // inner face, or to its sash's daylight — over its width.
          metres: _finite(geometry.barBody(bar).area / bar.widthMm / 1000),
          finish: bar.finish,
          openingId: design.openingHolding(bar.parentId)?.id,
        ),
    ];

    final panes = <PaneTakeoff>[
      for (final part in Infill.partsOf(design))
        PaneTakeoff(
          id: part.id,
          name: Infill.nameOf(design, part),
          // What it is cut to: the fill, stopping at the sash or the bar.
          areaM2: _finite(geometry.fillOf(part).area / 1e6),
          finish: part.finish,
          openingId:
              design.openingHolding(part.parentId)?.id ??
              design.openingOf(part.id)?.id,
        ),
    ];

    final leaves = <LeafTakeoff>[
      for (final opening in design.openingsInOrder)
        if (design.sectionById(opening.sectionId) case final section?)
          LeafTakeoff(
            id: opening.id,
            name: design.nameOf(opening),
            kind: design.kindOf(opening),
            slides: opening.mechanism.slideEdge != null,
            metres: _finite(_perimeter(geometry.leafOuter(section)) / 1000),
            areaM2: _finite(geometry.leafOuter(section).area / 1e6),
          ),
    ];

    final pieces = <PieceTakeoff>[
      for (final piece in design.hardware)
        PieceTakeoff(
          id: piece.id,
          kind: piece.kind,
          openingId: design.openingHolding(piece.parentId)?.id,
        ),
    ];

    return PricingTakeoff(
      widthCm: outline.width / 10,
      heightCm: outline.height / 10,
      areaM2: outline.area / 1e6,
      frameMetres: frameMm / 1000,
      frameFinish: frame.finish,
      angledJoints: _angledJoints(outline),
      bars: bars,
      panes: panes,
      leaves: leaves,
      pieces: pieces,
    );
  }

  static double _perimeter(Polygon shape) =>
      shape.edges.fold(0, (sum, e) => sum + e.length);

  static double _finite(double v) => v.isFinite && v > 0 ? v : 0;

  /// Corners whose two sides are not level and upright: every end of a
  /// sloped side is a joint cut at an angle.
  static int _angledJoints(Polygon outline) {
    final edges = outline.edges;
    var joints = 0;
    for (var i = 0; i < edges.length; i++) {
      final a = edges[i];
      final b = edges[(i + 1) % edges.length];
      bool square(Segment e) => e.a.x == e.b.x || e.a.y == e.b.y;
      if (!square(a) || !square(b)) joints++;
    }
    return joints;
  }
}

/// A bar, measured.
class BarTakeoff {
  final String id;
  final double metres;
  final Finish finish;

  /// The opening it is drawn inside, or null for a bar of the design.
  final String? openingId;

  const BarTakeoff({
    required this.id,
    required this.metres,
    required this.finish,
    this.openingId,
  });
}

/// A part — a pane of glass or a panel — measured as it is cut.
class PaneTakeoff {
  final String id;
  final String name;
  final double areaM2;
  final Finish finish;
  final String? openingId;

  const PaneTakeoff({
    required this.id,
    required this.name,
    required this.areaM2,
    required this.finish,
    this.openingId,
  });

  bool get isGlass => Infill.isGlass(finish);
  bool get isPanel => Infill.isPanel(finish);
}

/// A leaf, measured: its sash's run of profile and its area.
class LeafTakeoff {
  final String id;
  final String name;

  /// What the leaf is — the user's answer, or the design's kind it follows
  /// — or null where nobody has said.
  final DesignKind? kind;

  /// Whether it slides rather than turns.
  final bool slides;
  final double metres;
  final double areaM2;

  const LeafTakeoff({
    required this.id,
    required this.name,
    required this.kind,
    required this.slides,
    required this.metres,
    required this.areaM2,
  });
}

/// A piece of ironmongery.
class PieceTakeoff {
  final String id;
  final HardwareKind kind;
  final String? openingId;

  const PieceTakeoff({required this.id, required this.kind, this.openingId});
}
