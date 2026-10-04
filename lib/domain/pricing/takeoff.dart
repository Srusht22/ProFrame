import '../dimensions/measurements.dart';
import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/design_geometry.dart';
import '../model/elements.dart';
import '../model/infill.dart';
import '../model/materials.dart';
import 'measurement.dart';

/// What a design is made of, measured the way the factory measures it.
///
/// **It reads the canonical design and nothing else**, through the
/// geometry every view draws from — the frame's outline, `DesignGeometry`
/// for a bar's body and a pane's fill, the opening's own region — so what
/// is priced is what is drawn and built. It holds nothing, changes nothing,
/// and makes no geometry: an angled design is measured as the polygon it
/// is, never squared or boxed.
///
/// Each piece of geometry is counted **once**, in **one** category:
///
/// | Category | What | Measured |
/// | --- | --- | --- |
/// | Normal profile | the frame's border, every bar of the design and every line inside an opening | metres |
/// | Opening profile | the profile round each opening | metres, each opening once |
/// | Other profile | a sliding design's track | metres |
/// | Panel, glass | each part, as it is cut | square metres |
/// | Hardware | each piece | by the piece |
///
/// A line inside an opening is the opening's — it is listed against it —
/// and is cut from the normal profile, so it is in the normal profile and
/// never in the opening's perimeter. An opening's perimeter is its own
/// region's outline, so two openings either side of a mullion each count
/// their own side and the mullion is counted once, as a bar.
class PricingTakeoff {
  /// The frame's overall size, in centimetres, as the user reads it.
  final double widthCm;
  final double heightCm;

  /// The area inside the frame's outline — the polygon's own.
  final SquareMetres area;

  /// The frame's own finish: its material and its colour.
  final Finish frameFinish;

  final List<ProfileRun> runs;
  final List<RegionTakeoff> regions;
  final List<OpeningTakeoff> openings;
  final List<PieceTakeoff> pieces;

  const PricingTakeoff({
    required this.widthCm,
    required this.heightCm,
    required this.area,
    required this.frameFinish,
    required this.runs,
    required this.regions,
    required this.openings,
    required this.pieces,
  });

  Metres _sum(bool Function(ProfileRun) which) =>
      runs.where(which).fold(Metres.zero, (sum, r) => sum + r.length);

  /// The frame's border alone.
  Metres get border => _sum((r) => r.use == ProfileUse.border);

  /// Every bar and every line inside an opening.
  Metres get dividers => _sum((r) => r.use == ProfileUse.divider);

  Metres get normalProfile => _sum((r) => r.use.isNormal);
  Metres get openingProfile => _sum((r) => r.use == ProfileUse.opening);
  Metres get otherProfile => _sum((r) => r.use == ProfileUse.track);
  Metres get totalProfile => normalProfile + openingProfile + otherProfile;

  SquareMetres get glassArea => regions
      .where((r) => r.isGlass)
      .fold(SquareMetres.zero, (sum, r) => sum + r.area);
  SquareMetres get panelArea => regions
      .where((r) => r.isPanel)
      .fold(SquareMetres.zero, (sum, r) => sum + r.area);

  int get glassRegions => regions.where((r) => r.isGlass).length;
  int get panelRegions => regions.where((r) => r.isPanel).length;

  /// How many pieces of ironmongery of each kind.
  Map<HardwareKind, int> get hardwareCounts {
    final counts = <HardwareKind, int>{};
    for (final p in pieces) {
      counts[p.kind] = (counts[p.kind] ?? 0) + 1;
    }
    return counts;
  }

  MeasurementSummary get summary => MeasurementSummary(
    normalProfile: normalProfile,
    openingProfile: openingProfile,
    otherProfile: otherProfile,
    panelArea: panelArea,
    glassArea: glassArea,
    hardwarePieces: pieces.length,
    openings: openings.length,
  );

  /// Why [design] cannot be measured, or null where it can.
  ///
  /// A frame of nothing, or a coordinate that is not a number, has no size
  /// to measure; that is said rather than measured as zero or as NaN.
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

    // The border: every side of the outline that carries a member, so a
    // side left open is not charged as profile.
    var borderMm = 0.0;
    final edges = outline.edges;
    for (var i = 0; i < edges.length; i++) {
      if (frame.hasMember(i)) borderMm += edges[i].length;
    }

    final runs = <ProfileRun>[
      ProfileRun(
        id: frame.id,
        use: ProfileUse.border,
        label: 'Frame border',
        length: Metres.ofMm(borderMm),
        finish: frame.finish,
      ),
      // Every bar, once — the design's own and those inside an opening —
      // at the length its body is cut to: the canonical body every view
      // draws, from the face it starts at to the face it ends at.
      for (final bar in design.dividers)
        ProfileRun(
          id: bar.id,
          use: ProfileUse.divider,
          label: bar.isInternal ? 'Line inside an opening' : 'Bar',
          length: Metres.ofMm(_cutLength(geometry.barBody(bar), bar.segment)),
          finish: bar.finish,
          openingId: design.openingHolding(bar.parentId)?.id,
        ),
    ];

    final openings = <OpeningTakeoff>[];
    for (final opening in design.openingsInOrder) {
      final section = design.sectionById(opening.sectionId);
      if (section == null) continue;
      // The opening's own region, as the drawing and the solid hang its
      // leaf in it.
      final perimeter = Metres.ofMm(_perimeter(section.outline));
      final slides = opening.mechanism.slideEdge != null;
      runs.add(
        ProfileRun(
          id: opening.id,
          use: ProfileUse.opening,
          label: design.nameOf(opening),
          length: perimeter,
          // A leaf is made in the frame's profile.
          finish: frame.finish,
          openingId: opening.id,
        ),
      );
      openings.add(
        OpeningTakeoff(
          id: opening.id,
          name: design.nameOf(opening),
          kind: design.kindOf(opening),
          slides: slides,
          perimeter: perimeter,
          area: SquareMetres.ofMm2(section.outline.area),
        ),
      );
    }

    // A sliding design's track runs the frame's width, once, however many
    // panels run on it.
    if (openings.any((o) => o.slides)) {
      runs.add(
        ProfileRun(
          id: '${frame.id}-track',
          use: ProfileUse.track,
          label: 'Sliding track',
          length: Metres.ofMm(outline.width),
          finish: frame.finish,
        ),
      );
    }

    final regions = <RegionTakeoff>[
      for (final part in Infill.partsOf(design))
        RegionTakeoff(
          id: part.id,
          name: Infill.nameOf(design, part),
          // What it is cut to: the fill, stopping at the sash or the bar.
          area: SquareMetres.ofMm2(geometry.fillOf(part).area),
          finish: part.finish,
          openingId:
              design.openingHolding(part.parentId)?.id ??
              design.openingOf(part.id)?.id,
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
      area: SquareMetres.ofMm2(outline.area),
      frameFinish: frame.finish,
      runs: runs,
      regions: regions,
      openings: openings,
      pieces: pieces,
    );
  }

  static double _perimeter(Polygon shape) =>
      shape.edges.fold(0, (sum, e) => sum + e.length);

  /// How long a bar is cut: its body's reach along its own line, long
  /// point to long point where an end is cut at an angle.
  static double _cutLength(Polygon body, Segment line) {
    if (line.length <= 0) return 0;
    final along = line.unit;
    double at(Vec2 p) => (p - line.a).dot(along);
    final ats = [for (final c in body.corners) at(c)];
    if (ats.isEmpty) return line.length;
    final reach =
        ats.reduce((a, b) => a > b ? a : b) -
        ats.reduce((a, b) => a < b ? a : b);
    return reach.isFinite && reach > 0 ? reach : line.length;
  }
}

/// What a run of profile is.
enum ProfileUse {
  /// The frame's border.
  border,

  /// A bar of the design, or a line inside an opening.
  divider,

  /// The profile round an opening.
  opening,

  /// A sliding design's track.
  track;

  /// Cut from the normal profile.
  bool get isNormal => this == border || this == divider;
}

/// One run of profile, measured.
class ProfileRun {
  final String id;
  final ProfileUse use;
  final String label;
  final Metres length;

  /// What it is made of: the material and colour it is priced by.
  final Finish finish;

  /// The opening it belongs to, if it does.
  final String? openingId;

  const ProfileRun({
    required this.id,
    required this.use,
    required this.label,
    required this.length,
    required this.finish,
    this.openingId,
  });
}

/// A part — a pane of glass or a panel — measured as it is cut.
class RegionTakeoff {
  final String id;
  final String name;
  final SquareMetres area;
  final Finish finish;
  final String? openingId;

  const RegionTakeoff({
    required this.id,
    required this.name,
    required this.area,
    required this.finish,
    this.openingId,
  });

  bool get isGlass => Infill.isGlass(finish);
  bool get isPanel => Infill.isPanel(finish);
}

/// An opening, measured.
class OpeningTakeoff {
  final String id;
  final String name;

  /// What the leaf is — the user's answer, or the design's kind it follows
  /// — or null where nobody has said.
  final DesignKind? kind;
  final bool slides;
  final Metres perimeter;
  final SquareMetres area;

  const OpeningTakeoff({
    required this.id,
    required this.name,
    required this.kind,
    required this.slides,
    required this.perimeter,
    required this.area,
  });
}

/// A piece of ironmongery.
class PieceTakeoff {
  final String id;
  final HardwareKind kind;
  final String? openingId;

  const PieceTakeoff({required this.id, required this.kind, this.openingId});
}
