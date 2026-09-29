import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/vec2.dart';
import '../hardware/furniture.dart';
import 'design.dart';
import 'elements.dart';
import 'frame_profile.dart';
import 'opening_leaf.dart';

/// The design's geometry as every view draws it: the one answer to where
/// each part is and what shape it has.
///
/// ```
/// SAVED DESIGN  →  DesignGeometry  →  the drawing   (DesignPainter)
///                                  →  the CAD sheet (CadPainter)
///                                  →  the solid     (MeshBuilder)
/// ```
///
/// **It holds nothing of its own.** Everything here is worked out from the
/// design it was given — the frame, the bars, the sections, the openings and
/// the ironmongery — and nothing is stored back into it. It invents nothing
/// either: no division, no size and no position that is not already the
/// design's. What it settles is the handful of things each view used to work
/// out for itself and so could disagree about:
///
/// - **where a bar stops** — [barBody]; a bar of the design runs to the
///   frame's inner face and a bar inside an opening to the sash's, in all
///   three views;
/// - **what a pane is filled to** — [fillOf], the leaf's daylight rather
///   than the region's edge;
/// - **the leaf of an opening** — [leafOuter] and [leafInner];
/// - **how big each piece of ironmongery is** — [hardwareOf], sized from its
///   leaf, the same size on the sheet as in the solid.
///
/// Worked out once for each design and kept with it, so asking again for
/// the same design costs nothing and cannot answer differently.
class DesignGeometry {
  final Design design;

  DesignGeometry._(this.design);

  static final _made = Expando<DesignGeometry>('design geometry');

  /// The geometry of [design]. The same object for the same design.
  static DesignGeometry of(Design design) =>
      _made[design] ??= DesignGeometry._(design);

  final _bodies = Map<DividerElement, Polygon>.identity();
  final _hardware = Map<HardwareElement, List<Polygon>>.identity();

  FrameElement? get frame => design.frame;

  // ----------------------------------------------------------------- frame

  /// The frame's cross-section: its own profile width and the design's
  /// depth, shaped by what it is made of. See [FrameProfile].
  late final FrameProfile? frameProfile = design.frame == null
      ? null
      : FrameProfile.of(
          design.frame!.finish.material,
          width: design.frame!.profileMm,
          depth: design.depthMm,
        );

  /// Where [across] millimetres in from the outline falls on every member
  /// of the frame: the line between each outer corner and its inner one, at
  /// that share of the way — the mitre the solid sweeps the profile along.
  /// A side with no member has no line.
  List<Segment> frameLineAt(double across) {
    final frame = design.frame;
    final outer = frame?.outline;
    final inner = frame?.innerOutline;
    if (frame == null ||
        inner == null ||
        outer == null ||
        inner.corners.length != outer.corners.length ||
        frame.profileMm <= 0) {
      return const [];
    }
    final t = across / frame.profileMm;
    Vec2 at(int j) {
      final o = outer.corners[j], i = inner.corners[j];
      return o + (i - o) * t;
    }

    final n = outer.corners.length;
    return [
      for (var e = 0; e < n; e++)
        if (frame.hasMember(e)) Segment(at(e), at((e + 1) % n)),
    ];
  }

  /// The lines an elevation sees on the frame's face between the outline
  /// and the daylight: where its front face turns into the sightline.
  List<Segment> get frameSightlines => [
    for (final across in frameProfile?.sightlines ?? const <double>[])
      ...frameLineAt(across),
  ];

  // ------------------------------------------------------------------ bars

  /// The shape [bar] is trimmed to: the frame's daylight for a bar that
  /// divides the design, and what fills its section for a bar drawn inside
  /// one — the leaf's daylight inside an opening, because a glazing bar runs
  /// between the sash's faces and not over them. Null with no frame.
  Polygon? boundsOf(DividerElement bar) {
    final frame = design.frame;
    if (frame == null) return null;
    final holding = design.sectionHolding(bar.parentId);
    final section = holding == null ? null : design.sectionById(holding);
    if (section == null) return frame.innerOutline;
    return OpeningLeaf.fillOf(design, section);
  }

  /// The body of [bar] — real material, as wide as the user set it — where
  /// it lies within its bounds ([boundsOf]). Empty when none of it does.
  ///
  /// The line is never moved. An end drawn short of the edge stays where it
  /// was drawn; an end drawn past it is trimmed flush with it, square to
  /// the edge rather than to the bar, so a bar at an angle meets the frame
  /// along the frame's face instead of poking a corner through it.
  Polygon barBody(DividerElement bar) => _bodies[bar] ??= _bodyOf(bar);

  Polygon _bodyOf(DividerElement bar) {
    if (bar.segment.length < 1e-9) return const Polygon([]);
    final side = bar.segment.unit.perpendicular * (bar.widthMm / 2);
    Polygon along(Segment run) =>
        Polygon([run.a + side, run.b + side, run.b - side, run.a - side]);

    final bounds = boundsOf(bar);
    if (bounds == null || bounds.isEmpty) return along(bar.segment);
    final run = bounds.portionOf(bar.segment);
    if (run == null) return const Polygon([]);

    // Square across at both ends, when that already stays within: a bar
    // meeting the frame at a right angle, or stopping short of it.
    final square = along(run);
    if (!bounds.isConvex || square.corners.every(bounds.contains)) {
      return square;
    }

    // Otherwise the whole body, cut by the bounds.
    final cut = along(bar.segment).clippedTo(bounds);
    if (cut.isEmpty) return square;
    return _startingAt(_withoutRepeats(cut), square.corners.first);
  }

  /// [shape] with corners that repeat the one before taken out — clipping
  /// a corner that lies exactly on an edge gives it twice.
  static Polygon _withoutRepeats(Polygon shape) {
    final kept = <Vec2>[];
    for (final c in shape.corners) {
      if (kept.isEmpty || kept.last.distanceTo(c) > 1e-6) kept.add(c);
    }
    while (kept.length > 1 && kept.first.distanceTo(kept.last) <= 1e-6) {
      kept.removeLast();
    }
    return Polygon(kept);
  }

  /// [shape] listed from the corner nearest [start], so a bar's body is
  /// always written the same way round.
  static Polygon _startingAt(Polygon shape, Vec2 start) {
    if (shape.isEmpty) return shape;
    var first = 0;
    for (var i = 1; i < shape.corners.length; i++) {
      if (shape.corners[i].distanceTo(start) <
          shape.corners[first].distanceTo(start)) {
        first = i;
      }
    }
    return Polygon([
      ...shape.corners.sublist(first),
      ...shape.corners.sublist(0, first),
    ]);
  }

  // -------------------------------------------------------------- sections

  /// What fills [section]: its region, or — a pane of a sash — the part of
  /// it inside the sash's daylight. [OpeningLeaf.fillOf].
  Polygon fillOf(SectionElement section) => OpeningLeaf.fillOf(design, section);

  /// Whether [section] is a panel standing on a track: a main division of
  /// a sliding design, fixed or sliding.
  bool onTrack(SectionElement section) =>
      design.kind.slides && _mainDivisions.contains(section.id);

  late final Set<String> _mainDivisions = {
    for (final section in design.topLevelSections) section.id,
  };

  /// The outside of the leaf filling [section]: the section's own outline
  /// and nothing wider — or, for a panel on a track, [slidingPanelOf].
  Polygon leafOuter(SectionElement section) =>
      onTrack(section) ? slidingPanelOf(section) : OpeningLeaf.outerOf(section);

  /// The daylight inside the leaf filling [section] — [leafOuter] with the
  /// sash's own profile taken off all round — or null when it is too small
  /// to have any.
  Polygon? leafInner(SectionElement section) {
    final frame = design.frame;
    return frame == null
        ? null
        : OpeningLeaf.insideOf(leafOuter(section), frame);
  }

  /// A sliding design's panel in [section]: its region, reaching to the
  /// middle of each line it meets a neighbour at.
  ///
  /// The line between two sliding panels is where they meet, not a post:
  /// each panel's own stile reaches half way across it, one on each track,
  /// so the two panels together cover exactly what the line and the lights
  /// either side of it cover on the drawing.
  Polygon slidingPanelOf(SectionElement section) {
    final outline = section.outline;
    final grow = <double>[];
    for (final edge in outline.edges) {
      var by = 0.0;
      if (edge.direction.length > 1e-9) {
        for (final bar in design.topLevelDividers) {
          final line = bar.segment;
          if (line.direction.length < 1e-9) continue;
          if (edge.unit.cross(line.unit).abs() > 0.05) continue;
          final half = bar.widthMm / 2;
          if (line.distanceTo(edge.midpoint) <= half + 1) by = -half;
        }
      }
      grow.add(by);
    }
    return outline.insetEach(grow);
  }

  // ------------------------------------------------------------ ironmongery

  /// Every shape [piece] covers, seen square on: [Furniture.outlineOf].
  List<Polygon> hardwareOf(HardwareElement piece) =>
      _hardware[piece] ??= Furniture.outlineOf(design, piece);
}
