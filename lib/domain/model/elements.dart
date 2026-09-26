import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/vec2.dart';
import 'materials.dart';

/// Which face of a design the drawing and the solid show.
///
/// An elevation is drawn from the side the design is met from, and that is
/// not the same side for the two kinds. A door is drawn from **outside**,
/// because outside is where you walk up to it. A window is drawn from
/// **inside**, because inside is where you stand to open it. That is the
/// trade's convention and not a preference of this application's.
enum Face { outside, inside }

/// What the user said about an outline drawn with one side missing.
///
/// A head and two jambs with nothing across the foot is how a door frame is
/// very often built — and it is also how an outline looks when the user has
/// not finished it. The drawing cannot say which, so the user is asked, and
/// this is the answer, kept with the design so it is never asked twice.
enum OutlineGap {
  /// Built as drawn: that side carries no member.
  leaveOpen,

  /// A member is put across the gap, the side the user did not draw.
  closeIt,
}

/// What the user said, as a door or a door & window set started, it is
/// built of.
///
/// **The user decides, and nothing else does.** A door can be panel all
/// over, glass all over, or glass in some parts and panel in others — and
/// which parts is theirs to say, on the parts their own lines made. Nothing
/// here divides a part, adds a line or moves one: it says what fills the
/// parts that are there.
enum Construction {
  /// A new design that has not been asked yet. It is asked as it opens.
  pending('Not said'),

  /// Every part is a panel.
  panel('Panel'),

  /// Every part is glass.
  glass('Glass'),

  /// Some parts glass and some panel — which, the user says part by part.
  both('Panel + glass');

  const Construction(this.label);
  final String label;
}

/// A door or a window.
enum DesignKind {
  door('Door', Face.outside),
  window('Window', Face.inside),
  both('Door & window', Face.outside),

  /// Panels that slide past each other rather than swing — a patio door.
  ///
  /// Like [both] it is a fact about the assembly, chosen on the start
  /// screen: in a sliding design a `<` or a `>` says *this panel slides, that
  /// way*, rather than which side it is hinged on. Two panels marked is a
  /// pair that both slide; one marked beside a fixed light is a single
  /// slider. The drawing says which, not a template.
  sliding('Sliding', Face.outside);

  const DesignKind(this.label, this.seenFrom);
  final String label;

  /// What a single leaf can be.
  ///
  /// [both] is a fact about the *assembly* — that it holds leaves of each
  /// kind — and never about one leaf, which is a door or a window and not
  /// the two at once. So this is what the question about an opening offers
  /// and what its panel lets the user choose between; the start screen
  /// offers all three, because that one is about the assembly.
  static const List<DesignKind> leafKinds = [door, window];

  /// The kind a leaf follows while nobody has said what it is, or null when
  /// the design does not say either.
  ///
  /// **[both] is the kind that has no default, and that is the whole of what
  /// it means.** A door design says its leaves are doors until the user says
  /// otherwise, and a window design the same; an assembly the user has told
  /// us holds both says nothing about any particular leaf, so nothing is
  /// assumed for one. The leaf still opens — the mark said so, and it hangs
  /// on its hinges — but it carries no handle until the question is
  /// answered, because which handle is exactly what has not been said.
  /// Picking one would be the application deciding what a leaf is, which is
  /// the thing this whole arrangement exists to avoid.
  ///
  /// A sliding design's leaves follow a door: the user chose sliding for a
  /// set they walk through, and the leaf's own switch says otherwise.
  DesignKind? get leafDefault => switch (this) {
        both => null,
        sliding => door,
        _ => this,
      };

  /// Whether a mark in this design says a panel slides rather than swings.
  bool get slides => this == sliding;

  /// Whether a new design of this kind is asked, as it starts, what it is
  /// built of — panel, glass, or both. See [Construction].
  ///
  /// A door and a door & window set are: the user's words, *for the door
  /// and the door & window category, ask when starting*. A window and a
  /// sliding set are not asked; their parts are given glass or panel with
  /// the **Material** tool, whenever the user wants to.
  bool get asksConstruction => this == door || this == both;

  /// The face the user draws, and the face both views show.
  ///
  /// The drawing is the face they drew, so the solid's near face is theirs
  /// by construction and no view has to be turned round or mirrored. What
  /// this decides is what is on the *other* side: the ironmongery that hangs
  /// on the inside face is behind the leaf on a door and in front of it on a
  /// window.
  final Face seenFrom;
}

/// Anything in the design the user can pick, move, change or delete.
///
/// Every element carries the id of the stroke it came from, when it came from
/// one. That is the thread back to the user's own hand: it lets the canvas
/// show which of their lines became which part, and it lets a correction be
/// traced to the mark that caused it.
sealed class DesignElement {
  final String id;
  final String? fromStrokeId;

  const DesignElement({required this.id, this.fromStrokeId});

  /// What the component tree calls it.
  String get label;

  /// Where it is, for hit-testing and for the tree's ordering.
  Vec2 get anchor;

  Map<String, Object?> toJson();
}

/// The outer frame — the shape of the hole in the wall, exactly as drawn.
///
/// The outline is a polygon, not a rectangle, because the user may draw an
/// arched, angled or five-sided opening and it must be built as drawn.
class FrameElement extends DesignElement {
  final Polygon outline;

  /// How thick the frame profile is, measured inwards from the outline.
  final double profileMm;

  final Finish finish;

  /// The sides of the outline the user left open — by edge, the edge from
  /// corner `i` to the next. There is no member on an open side: a door
  /// drawn as a head and two jambs and nothing across the foot is a door
  /// with no sill, and its leaf runs down to the floor.
  ///
  /// Empty for a frame closed all round, which is every frame the user drew
  /// closed.
  final Set<int> openEdges;

  const FrameElement({
    required super.id,
    required this.outline,
    this.profileMm = 60,
    this.finish = Finish.frameDefault,
    this.openEdges = const {},
    super.fromStrokeId,
  });

  /// The daylight opening: what is left inside once the frame is taken off.
  /// On a side left open there is no frame to take off.
  Polygon get innerOutline => openEdges.isEmpty
      ? outline.inset(profileMm)
      : outline.insetEach([
          for (var i = 0; i < outline.corners.length; i++)
            openEdges.contains(i) ? 0 : profileMm,
        ]);

  /// Whether the side from corner [edge] to the next carries a member.
  bool hasMember(int edge) => !openEdges.contains(edge);

  /// The lines a drawing of this frame is made of: every side that carries
  /// a member, on the outside and on the daylight, and — where a member
  /// stops at a side left open — its cut end, across the profile.
  ///
  /// Both views draw these rather than the two outlines whole, because a
  /// whole outline has a line along the open side, and that is a member the
  /// user did not draw.
  ({List<Segment> outside, List<Segment> daylight}) get lines {
    final outer = outline.edges;
    final inner = innerOutline;
    if (openEdges.isEmpty || inner.corners.length != outline.corners.length) {
      return (outside: outer, daylight: inner.edges);
    }
    final innerEdges = inner.edges;
    final n = outline.corners.length;
    final outside = <Segment>[];
    final daylight = <Segment>[];
    for (var i = 0; i < n; i++) {
      if (hasMember(i)) {
        outside.add(outer[i]);
        daylight.add(innerEdges[i]);
        continue;
      }
      // The two members either side of the gap end here, cut square to
      // the open side.
      for (final corner in [i, (i + 1) % n]) {
        final end = Segment(outline.corners[corner], inner.corners[corner]);
        if (end.length > 0) outside.add(end);
      }
    }
    return (outside: outside, daylight: daylight);
  }

  double get widthMm => outline.width;
  double get heightMm => outline.height;

  @override
  String get label => 'Frame';

  @override
  Vec2 get anchor => outline.topLeft;

  FrameElement copyWith({
    Polygon? outline,
    double? profileMm,
    Finish? finish,
    Set<int>? openEdges,
  }) =>
      FrameElement(
        id: id,
        outline: outline ?? this.outline,
        profileMm: profileMm ?? this.profileMm,
        finish: finish ?? this.finish,
        openEdges: openEdges ?? this.openEdges,
        fromStrokeId: fromStrokeId,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'frame',
        'id': id,
        if (fromStrokeId != null) 'fromStrokeId': fromStrokeId,
        'outline': outline.toJson(),
        'profileMm': profileMm,
        'finish': finish.toJson(),
        if (openEdges.isNotEmpty) 'openEdges': (openEdges.toList()..sort()),
      };

  static FrameElement fromJson(Map<String, Object?> map) => FrameElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        outline: Polygon.fromJson(map['outline']),
        profileMm: (map['profileMm'] as num?)?.toDouble() ?? 60,
        finish: Finish.fromJson(map['finish']),
        openEdges: {
          for (final i in (map['openEdges'] as List?) ?? const [])
            (i as num).toInt(),
        },
      );
}

/// One side of the frame: the head, the sill, a jamb, or a rake on a frame
/// that is not four-sided.
///
/// Derived from the frame rather than stored beside it, because the frame is
/// one closed shape and its members are its edges. Selecting a member is a
/// way of pointing at one edge of that shape; moving it moves that edge and
/// leaves the rest of the outline where it is.
class FrameMemberElement extends DesignElement {
  final String frameId;

  /// Which edge of the frame outline this is.
  final int index;

  final Segment run;

  /// Where it sits on the frame, for naming it.
  final String placement;

  const FrameMemberElement({
    required super.id,
    required this.frameId,
    required this.index,
    required this.run,
    required this.placement,
  });

  /// The id a member of [frameId] at [index] has. Derived, so it is the same
  /// every time rather than something to store and keep in step.
  static String idFor(String frameId, int index) => '$frameId::member::$index';

  static int? indexIn(String elementId) {
    final at = elementId.indexOf('::member::');
    if (at < 0) return null;
    return int.tryParse(elementId.substring(at + '::member::'.length));
  }

  double get lengthMm => run.length;

  @override
  String get label => placement;

  @override
  Vec2 get anchor => run.midpoint;

  @override
  Map<String, Object?> toJson() => const {};
}

/// A line inside the design: a mullion, a transom, a glazing bar — whatever
/// the user drew.
///
/// It keeps the two endpoints the user gave it, so a diagonal stays diagonal.
/// A divider is never removed because it looks unusual, and never moved to
/// make the sections equal.
class DividerElement extends DesignElement {
  final Vec2 a;
  final Vec2 b;

  /// The bar's face width, in millimetres.
  final double widthMm;

  final Finish finish;

  /// The section this bar lives inside, when it lives inside one.
  ///
  /// Null means it is part of the main structure and divides the whole
  /// design. Set means it is inside that section — drawn within an opening,
  /// say — and divides only that section. An internal bar does not split the
  /// design into more top-level sections, and it travels with its parent
  /// when the parent moves or is resized.
  final String? parentId;

  const DividerElement({
    required super.id,
    required this.a,
    required this.b,
    this.widthMm = 50,
    this.finish = Finish.frameDefault,
    this.parentId,
    super.fromStrokeId,
  });

  bool get isInternal => parentId != null;

  Segment get segment => Segment(a, b);
  double get lengthMm => segment.length;
  bool get isVertical => segment.isVerticalish;
  bool get isHorizontal => segment.isHorizontalish;

  @override
  String get label => isVertical
      ? 'Vertical divider'
      : isHorizontal
          ? 'Horizontal divider'
          : 'Angled divider';

  @override
  Vec2 get anchor => segment.midpoint;

  DividerElement copyWith({
    Vec2? a,
    Vec2? b,
    double? widthMm,
    Finish? finish,
    String? parentId,
    bool clearParent = false,
  }) =>
      DividerElement(
        id: id,
        a: a ?? this.a,
        b: b ?? this.b,
        widthMm: widthMm ?? this.widthMm,
        finish: finish ?? this.finish,
        parentId: clearParent ? null : (parentId ?? this.parentId),
        fromStrokeId: fromStrokeId,
      );

  DividerElement translated(Vec2 by) => copyWith(a: a + by, b: b + by);

  @override
  Map<String, Object?> toJson() => {
        'type': 'divider',
        'id': id,
        if (fromStrokeId != null) 'fromStrokeId': fromStrokeId,
        'a': a.toJson(),
        'b': b.toJson(),
        'widthMm': widthMm,
        'finish': finish.toJson(),
        if (parentId != null) 'parentId': parentId,
      };

  static DividerElement fromJson(Map<String, Object?> map) => DividerElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        a: Vec2.fromJson(map['a']),
        b: Vec2.fromJson(map['b']),
        widthMm: (map['widthMm'] as num?)?.toDouble() ?? 50,
        finish: Finish.fromJson(map['finish']),
        parentId: map['parentId'] as String?,
      );
}

/// One area of the design, bounded by the frame and the dividers around it.
///
/// Sections are worked out from the lines the user drew — they are never laid
/// out to a template and never equalised. A section keeps the exact polygon
/// the subdivision produced.
class SectionElement extends DesignElement {
  final Polygon outline;
  final Finish finish;

  /// A name the user typed for it, if any.
  final String? name;

  /// The section this one sits inside, when it sits inside one.
  ///
  /// Null means it is one of the main divisions of the design. Set means it
  /// is part of what fills another section — a pane inside an opening, made
  /// by a bar the user drew within that opening. A section with children is
  /// not filled itself; its children fill it.
  final String? parentId;

  const SectionElement({
    required super.id,
    required this.outline,
    this.finish = Finish.glazingDefault,
    this.name,
    this.parentId,
    super.fromStrokeId,
  });

  bool get isInternal => parentId != null;

  double get widthMm => outline.width;
  double get heightMm => outline.height;
  double get areaMmSq => outline.area;

  @override
  String get label => name ?? 'Section';

  @override
  Vec2 get anchor => outline.centroid;

  SectionElement copyWith({
    Polygon? outline,
    Finish? finish,
    String? name,
    String? parentId,
    bool clearParent = false,
  }) =>
      SectionElement(
        id: id,
        outline: outline ?? this.outline,
        finish: finish ?? this.finish,
        name: name ?? this.name,
        parentId: clearParent ? null : (parentId ?? this.parentId),
        fromStrokeId: fromStrokeId,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'section',
        'id': id,
        if (fromStrokeId != null) 'fromStrokeId': fromStrokeId,
        'outline': outline.toJson(),
        'finish': finish.toJson(),
        if (name != null) 'name': name,
        if (parentId != null) 'parentId': parentId,
      };

  static SectionElement fromJson(Map<String, Object?> map) => SectionElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        outline: Polygon.fromJson(map['outline']),
        finish: Finish.fromJson(map['finish'], fallback: Finish.glazingDefault),
        name: map['name'] as String?,
        parentId: map['parentId'] as String?,
      );
}

/// How a section opens.
enum OpeningMechanism {
  fixed('Fixed', 'Does not open'),
  hingedLeft('Hinged left', 'Hinges on the left, opens from the right'),
  hingedRight('Hinged right', 'Hinges on the right, opens from the left'),
  topHung('Top hung', 'Hinges at the top, opens outward at the bottom'),
  bottomHung('Bottom hung', 'Hinges at the bottom, opens inward at the top'),
  slidingLeft('Sliding left', 'Slides to the left'),
  slidingRight('Sliding right', 'Slides to the right'),
  tiltAndTurn('Tilt and turn', 'Tilts at the top and turns on one side'),
  bifold('Bi-fold', 'Folds back in leaves'),
  pivot('Pivot', 'Turns about a central axis');

  const OpeningMechanism(this.label, this.description);
  final String label;
  final String description;

  /// The mark that says this mechanism, where one of the four does.
  ///
  /// The point is at the edge that moves, which is the edge opposite the
  /// hinge — the same rule for all four.
  String? get glyph => switch (this) {
        hingedLeft => '>',
        hingedRight => '<',
        bottomHung => '^',
        topHung => 'v',
        // On a sliding panel the point leads: `>` slides right.
        slidingRight => '>',
        slidingLeft => '<',
        _ => null,
      };

  /// Which edge the hinges are on, for drawing the opening symbol and for
  /// placing the leaf in 3D. Null when the mechanism has no single hinge edge.
  OpeningEdge? get hingeEdge => switch (this) {
        hingedLeft || tiltAndTurn => OpeningEdge.left,
        hingedRight => OpeningEdge.right,
        topHung => OpeningEdge.top,
        bottomHung => OpeningEdge.bottom,
        _ => null,
      };
}

enum OpeningEdge { left, right, top, bottom }

/// The edge a sliding leaf leads with: the side it slides towards.
extension SlideEdge on OpeningMechanism {
  /// Which edge leads, for a leaf that slides; null for one that does not.
  OpeningEdge? get slideEdge => switch (this) {
        OpeningMechanism.slidingLeft => OpeningEdge.left,
        OpeningMechanism.slidingRight => OpeningEdge.right,
        _ => null,
      };
}

/// Which way it opens relative to the viewer.
enum OpeningDirection { inward, outward, either }

/// A section that opens, and how.
///
/// It references the section it belongs to rather than copying its shape, so
/// resizing the section moves the leaf with it. The mechanism is what the
/// user drew or confirmed — never a guess the application made quietly.
class OpeningElement extends DesignElement {
  /// The section that opens — this opening's parent in the design tree.
  ///
  /// One id, and it names a section: not the frame, which is not a section,
  /// and not the design, which is the root. `Hierarchy.settleOpenings` keeps
  /// that true, so a document can no longer say that the whole door opens.
  final String sectionId;

  /// The same id, under the name the tree uses for it everywhere else.
  ///
  /// An opening is a property of one region, so where it *is* and how big it
  /// is are that region's outline — `Design.outlineOf` — and what it holds
  /// is whatever names that region as its own parent —
  /// `Design.contentsOf`. None of it is stored twice.
  String get parentId => sectionId;
  final OpeningMechanism mechanism;
  final OpeningDirection direction;

  /// True when the user said so — by marking the section with a symbol, or
  /// by answering. Nothing else sets it, because nothing else creates an
  /// opening.
  final bool confirmed;

  /// Where the user put the mark that says this section opens, and which
  /// mark it was. Kept so the drawing can show that the mark was honoured,
  /// in the place it was made.
  final Vec2? markAt;
  final String? markGlyph;

  /// How many hinges this opening carries. Null means the count follows the
  /// length of the hinged edge; a number is what the user asked for.
  final int? hingeCount;

  /// How far the outer hinges stand in from each end of the hinged edge, in
  /// millimetres. Null on either means the default stand-off.
  final double? hingeFromStartMm;
  final double? hingeFromEndMm;

  /// Where the handle sits along the edge it is on: up from the bottom on a
  /// side-hung leaf, along from the left on a top- or bottom-hung one. Null
  /// means the default height.
  final double? handleAlongMm;

  /// Whether this opening is a door or a window — **the user's answer, and
  /// null until they have given one.**
  ///
  /// One design can hold several openings and each is its own thing: a door
  /// leaf beside a window light beside another door leaf, in one frame. So
  /// the kind belongs to the opening and not only to the design around it.
  ///
  /// Null is not a door and it is not a window. It means nobody has said,
  /// and `Design.kindOf` then answers with the design's own kind — which is
  /// the kind the user chose when they started the drawing, not a guess
  /// about this leaf. Recording a default here would write down a decision
  /// they never made, which is the same reason `hingeCount` and
  /// `handleAlongMm` above are null until asked for.
  final DesignKind? kind;

  /// What form this leaf's handle takes — a lever, a knob, a pull — and
  /// null until the user says.
  ///
  /// A door has a lever until they choose otherwise and a window has its
  /// fastener; the default is read from what the leaf is rather than
  /// written down here, so it follows the leaf if they change what it is.
  final HardwareKind? handleKind;

  /// Whether a pleated insect screen runs across this leaf's opening — off
  /// until the user puts one on.
  ///
  /// A sliding panel can carry one: a slim cassette fixed at the jamb the
  /// panel closes against, and a pleated screen that fans out of it across
  /// the passage the panel uncovers, folding back in as the panel shuts. It
  /// is a thing somebody chooses to fit, so nothing puts it on for them.
  final bool pleatedScreen;

  /// Whether this leaf is opened by a sensor and a drive rather than by
  /// hand — off until the user says.
  ///
  /// An automatic entrance carries a sensor on the head above the leaves it
  /// opens. Like the screen, it is fitted because the user says so, never
  /// because a leaf looks like an entrance.
  final bool automatic;

  const OpeningElement({
    required super.id,
    required this.sectionId,
    required this.mechanism,
    this.direction = OpeningDirection.inward,
    this.confirmed = false,
    this.markAt,
    this.markGlyph,
    this.hingeCount,
    this.hingeFromStartMm,
    this.hingeFromEndMm,
    this.handleAlongMm,
    this.kind,
    this.handleKind,
    this.pleatedScreen = false,
    this.automatic = false,
    super.fromStrokeId,
  });

  @override
  String get label {
    // The glyph of what it does now, not the one that was drawn. Where they
    // differ the inspector shows both; a heading has room for one, and the
    // current state is the one worth showing.
    final glyph = mechanism.glyph ?? markGlyph;
    return glyph == null ? mechanism.label : '${mechanism.label}  $glyph';
  }

  @override
  Vec2 get anchor => markAt ?? Vec2.zero;

  /// [clearKind] puts this opening back to following the design, which is
  /// the one thing `kind: null` cannot say — the same arrangement as
  /// `clearParent` on a divider, and for the same reason.
  OpeningElement copyWith({
    OpeningMechanism? mechanism,
    OpeningDirection? direction,
    bool? confirmed,
    Vec2? markAt,
    String? markGlyph,
    int? hingeCount,
    double? hingeFromStartMm,
    double? hingeFromEndMm,
    double? handleAlongMm,
    DesignKind? kind,
    bool clearKind = false,
    HardwareKind? handleKind,
    bool? pleatedScreen,
    bool? automatic,
  }) =>
      OpeningElement(
        id: id,
        sectionId: sectionId,
        mechanism: mechanism ?? this.mechanism,
        direction: direction ?? this.direction,
        confirmed: confirmed ?? this.confirmed,
        markAt: markAt ?? this.markAt,
        markGlyph: markGlyph ?? this.markGlyph,
        hingeCount: hingeCount ?? this.hingeCount,
        hingeFromStartMm: hingeFromStartMm ?? this.hingeFromStartMm,
        hingeFromEndMm: hingeFromEndMm ?? this.hingeFromEndMm,
        handleAlongMm: handleAlongMm ?? this.handleAlongMm,
        kind: clearKind ? null : (kind ?? this.kind),
        handleKind: handleKind ?? this.handleKind,
        pleatedScreen: pleatedScreen ?? this.pleatedScreen,
        automatic: automatic ?? this.automatic,
        fromStrokeId: fromStrokeId,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'opening',
        'id': id,
        if (fromStrokeId != null) 'fromStrokeId': fromStrokeId,
        'sectionId': sectionId,
        'mechanism': mechanism.name,
        'direction': direction.name,
        'confirmed': confirmed,
        if (markAt != null) 'markAt': markAt!.toJson(),
        if (markGlyph != null) 'markGlyph': markGlyph,
        if (hingeCount != null) 'hingeCount': hingeCount,
        if (hingeFromStartMm != null) 'hingeFromStartMm': hingeFromStartMm,
        if (hingeFromEndMm != null) 'hingeFromEndMm': hingeFromEndMm,
        if (handleAlongMm != null) 'handleAlongMm': handleAlongMm,
        // Written only where the user has said, so a design they have not
        // been asked about comes back saying they have not been asked.
        if (kind != null) 'kind': kind!.name,
        if (handleKind != null) 'handleKind': handleKind!.name,
        if (pleatedScreen) 'pleatedScreen': true,
        if (automatic) 'automatic': true,
      };

  static OpeningElement fromJson(Map<String, Object?> map) => OpeningElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        sectionId: map['sectionId']! as String,
        mechanism: OpeningMechanism.values.firstWhere(
          (m) => m.name == map['mechanism'],
          orElse: () => OpeningMechanism.fixed,
        ),
        direction: OpeningDirection.values.firstWhere(
          (d) => d.name == map['direction'],
          orElse: () => OpeningDirection.inward,
        ),
        confirmed: map['confirmed'] as bool? ?? false,
        markAt: map['markAt'] == null ? null : Vec2.fromJson(map['markAt']),
        markGlyph: map['markGlyph'] as String?,
        hingeCount: (map['hingeCount'] as num?)?.toInt(),
        hingeFromStartMm: (map['hingeFromStartMm'] as num?)?.toDouble(),
        hingeFromEndMm: (map['hingeFromEndMm'] as num?)?.toDouble(),
        handleAlongMm: (map['handleAlongMm'] as num?)?.toDouble(),
        // Absent in a design saved before openings had a kind of their own,
        // and absent in one the user has not been asked about. Both mean
        // the same thing, and both load as null.
        kind: map['kind'] == null
            ? null
            : DesignKind.values.firstWhere(
                (k) => k.name == map['kind'],
                orElse: () => DesignKind.window,
              ),
        handleKind: map['handleKind'] == null
            ? null
            : HardwareKind.values.firstWhere(
                (k) => k.name == map['handleKind'],
                orElse: () => HardwareKind.lever,
              ),
        pleatedScreen: map['pleatedScreen'] as bool? ?? false,
        automatic: map['automatic'] as bool? ?? false,
      );
}

enum HardwareKind {
  handle('Handle'),
  lever('Lever'),
  knob('Knob'),
  lock('Lock'),
  hinge('Hinge'),
  letterplate('Letter plate'),
  peephole('Peephole'),
  closer('Closer'),

  /// A slim upright bar a sliding panel is pulled by. A sliding panel turns
  /// nothing, so a lever or a turned fastener would be a handle for a
  /// different kind of leaf.
  pull('Pull handle'),

  /// The slim cassette a pleated insect screen is stowed in, and the screen
  /// itself: fixed at the jamb, fanning out as its sliding panel opens.
  screen('Pleated screen'),

  /// The sensor on the head that opens an automatic entrance.
  sensor('Sensor');

  const HardwareKind(this.label);
  final String label;

  /// True when this piece is the thing a leaf is worked by, whatever form
  /// it takes.
  ///
  /// A lever, a knob and a pull are all the handle of the leaf they are on;
  /// which of them it is, is the user's choice and not a different part.
  /// Anything asking "where is this leaf's handle" asks this rather than
  /// matching one of the three, so choosing a knob does not make a leaf's
  /// handle disappear from everything that was looking for it.
  bool get isHandle =>
      this == HardwareKind.handle ||
      this == HardwareKind.lever ||
      this == HardwareKind.knob ||
      this == HardwareKind.pull;

  /// True when this piece is fixed to the **inside face** of a leaf and to
  /// nowhere else.
  ///
  /// A butt hinge is screwed to one face, and that face is the inside one:
  /// on a door, which is drawn from outside, the hinges are round the back
  /// and you do not see them. A handle, a lever, a knob and a lock go
  /// through the leaf and are worked from either side, so they are on the
  /// face you are standing at whichever that is.
  bool get onTheInsideFace =>
      this == HardwareKind.hinge ||
      // A screen is fitted on the room side of the panel it follows, where
      // it keeps the insects out; from outside it is behind that panel.
      this == HardwareKind.screen;

  /// True for a piece that belongs to an opening but is fixed to the frame
  /// rather than carried by the leaf: a screen's cassette stays at its jamb
  /// and a sensor stays on the head while the panel slides away from them.
  bool get staysOnFrame =>
      this == HardwareKind.screen || this == HardwareKind.sensor;
}

/// A piece of ironmongery, at the exact point the user put it — or the exact
/// point an opening they marked puts it.
///
/// Hardware appears where the user placed it, and on the openings the user
/// marked. Nothing is added to make a render look complete: a section with no
/// mark on it carries no hinges and no handle, however door-shaped it is.
class HardwareElement extends DesignElement {
  final HardwareKind kind;
  final Vec2 at;
  final Finish finish;

  /// Degrees clockwise from horizontal.
  final double rotation;

  /// The section this piece belongs to, when it belongs to one.
  ///
  /// Set on the hinges and handle of an opening: they are the opening's, so
  /// they travel with it, they are listed under it, and they are worked out
  /// again from the opening whenever it changes. Null on a piece the user
  /// placed themselves, which stays exactly where it was put.
  final String? parentId;

  const HardwareElement({
    required super.id,
    required this.kind,
    required this.at,
    this.rotation = 0,
    this.finish = const Finish(colour: 0xFF8A8F8C, material: MaterialKind.steel),
    this.parentId,
    super.fromStrokeId,
  });

  /// True when this piece is an opening's, rather than one the user placed.
  bool get isOpeningHardware => parentId != null;

  @override
  String get label => kind.label;

  @override
  Vec2 get anchor => at;

  HardwareElement copyWith({
    Vec2? at,
    double? rotation,
    Finish? finish,
    String? parentId,
    bool clearParent = false,
  }) =>
      HardwareElement(
        id: id,
        kind: kind,
        at: at ?? this.at,
        rotation: rotation ?? this.rotation,
        finish: finish ?? this.finish,
        parentId: clearParent ? null : (parentId ?? this.parentId),
        fromStrokeId: fromStrokeId,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'hardware',
        'id': id,
        if (fromStrokeId != null) 'fromStrokeId': fromStrokeId,
        'kind': kind.name,
        'at': at.toJson(),
        'rotation': rotation,
        'finish': finish.toJson(),
        if (parentId != null) 'parentId': parentId,
      };

  static HardwareElement fromJson(Map<String, Object?> map) => HardwareElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        kind: HardwareKind.values.firstWhere(
          (k) => k.name == map['kind'],
          orElse: () => HardwareKind.handle,
        ),
        at: Vec2.fromJson(map['at']),
        parentId: map['parentId'] as String?,
        rotation: (map['rotation'] as num?)?.toDouble() ?? 0,
        finish: Finish.fromJson(
          map['finish'],
          fallback:
              const Finish(colour: 0xFF8A8F8C, material: MaterialKind.steel),
        ),
      );
}

/// A measurement between two points.
///
/// When the user types a value, that value is the truth and the geometry is
/// scaled to match it. Until then it reports what was drawn.
class DimensionElement extends DesignElement {
  final Vec2 a;
  final Vec2 b;

  /// How far off the measured line the witness line sits, in millimetres.
  /// Negative puts it on the other side.
  final double offsetMm;

  /// What the user typed, in millimetres. Null means "whatever it measures".
  final double? statedMm;

  const DimensionElement({
    required super.id,
    required this.a,
    required this.b,
    this.offsetMm = 120,
    this.statedMm,
    super.fromStrokeId,
  });

  double get measuredMm => a.distanceTo(b);

  /// What the label shows: the typed value where there is one.
  double get valueMm => statedMm ?? measuredMm;

  bool get isStated => statedMm != null;

  @override
  String get label => '${valueMm.round()} mm';

  @override
  Vec2 get anchor => a.lerp(b, 0.5);

  DimensionElement copyWith({
    Vec2? a,
    Vec2? b,
    double? offsetMm,
    double? statedMm,
    bool clearStated = false,
  }) =>
      DimensionElement(
        id: id,
        a: a ?? this.a,
        b: b ?? this.b,
        offsetMm: offsetMm ?? this.offsetMm,
        statedMm: clearStated ? null : (statedMm ?? this.statedMm),
        fromStrokeId: fromStrokeId,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'dimension',
        'id': id,
        if (fromStrokeId != null) 'fromStrokeId': fromStrokeId,
        'a': a.toJson(),
        'b': b.toJson(),
        'offsetMm': offsetMm,
        if (statedMm != null) 'statedMm': statedMm,
      };

  static DimensionElement fromJson(Map<String, Object?> map) =>
      DimensionElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        a: Vec2.fromJson(map['a']),
        b: Vec2.fromJson(map['b']),
        offsetMm: (map['offsetMm'] as num?)?.toDouble() ?? 120,
        statedMm: (map['statedMm'] as num?)?.toDouble(),
      );
}

/// A note the user wrote on the drawing.
class TextElement extends DesignElement {
  final String text;
  final Vec2 at;
  final double sizeMm;
  final int colour;

  const TextElement({
    required super.id,
    required this.text,
    required this.at,
    this.sizeMm = 90,
    this.colour = 0xFF013E37,
    super.fromStrokeId,
  });

  @override
  String get label => text.isEmpty ? 'Note' : text;

  @override
  Vec2 get anchor => at;

  TextElement copyWith({String? text, Vec2? at, double? sizeMm, int? colour}) =>
      TextElement(
        id: id,
        text: text ?? this.text,
        at: at ?? this.at,
        sizeMm: sizeMm ?? this.sizeMm,
        colour: colour ?? this.colour,
        fromStrokeId: fromStrokeId,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'text',
        'id': id,
        if (fromStrokeId != null) 'fromStrokeId': fromStrokeId,
        'text': text,
        'at': at.toJson(),
        'sizeMm': sizeMm,
        'colour': colour,
      };

  static TextElement fromJson(Map<String, Object?> map) => TextElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        text: map['text']! as String,
        at: Vec2.fromJson(map['at']),
        sizeMm: (map['sizeMm'] as num?)?.toDouble() ?? 90,
        colour: (map['colour'] as num?)?.toInt() ?? 0xFF013E37,
      );
}

/// An arrow the user drew, pointing at something.
class ArrowElement extends DesignElement {
  final Vec2 from;
  final Vec2 to;
  final int colour;

  const ArrowElement({
    required super.id,
    required this.from,
    required this.to,
    this.colour = 0xFF013E37,
    super.fromStrokeId,
  });

  Segment get segment => Segment(from, to);

  @override
  String get label => 'Arrow';

  @override
  Vec2 get anchor => segment.midpoint;

  ArrowElement copyWith({Vec2? from, Vec2? to, int? colour}) => ArrowElement(
        id: id,
        from: from ?? this.from,
        to: to ?? this.to,
        colour: colour ?? this.colour,
        fromStrokeId: fromStrokeId,
      );

  @override
  Map<String, Object?> toJson() => {
        'type': 'arrow',
        'id': id,
        if (fromStrokeId != null) 'fromStrokeId': fromStrokeId,
        'from': from.toJson(),
        'to': to.toJson(),
        'colour': colour,
      };

  static ArrowElement fromJson(Map<String, Object?> map) => ArrowElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        from: Vec2.fromJson(map['from']),
        to: Vec2.fromJson(map['to']),
        colour: (map['colour'] as num?)?.toInt() ?? 0xFF013E37,
      );
}
