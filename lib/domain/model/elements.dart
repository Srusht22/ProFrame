import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/vec2.dart';
import 'materials.dart';

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

  const FrameElement({
    required super.id,
    required this.outline,
    this.profileMm = 60,
    this.finish = Finish.frameDefault,
    super.fromStrokeId,
  });

  /// The daylight opening: what is left inside once the frame is taken off.
  Polygon get innerOutline => outline.inset(profileMm);

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
  }) =>
      FrameElement(
        id: id,
        outline: outline ?? this.outline,
        profileMm: profileMm ?? this.profileMm,
        finish: finish ?? this.finish,
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
      };

  static FrameElement fromJson(Map<String, Object?> map) => FrameElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        outline: Polygon.fromJson(map['outline']),
        profileMm: (map['profileMm'] as num?)?.toDouble() ?? 60,
        finish: Finish.fromJson(map['finish']),
      );
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

  const DividerElement({
    required super.id,
    required this.a,
    required this.b,
    this.widthMm = 50,
    this.finish = Finish.frameDefault,
    super.fromStrokeId,
  });

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
  }) =>
      DividerElement(
        id: id,
        a: a ?? this.a,
        b: b ?? this.b,
        widthMm: widthMm ?? this.widthMm,
        finish: finish ?? this.finish,
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
      };

  static DividerElement fromJson(Map<String, Object?> map) => DividerElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        a: Vec2.fromJson(map['a']),
        b: Vec2.fromJson(map['b']),
        widthMm: (map['widthMm'] as num?)?.toDouble() ?? 50,
        finish: Finish.fromJson(map['finish']),
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

  const SectionElement({
    required super.id,
    required this.outline,
    this.finish = Finish.glazingDefault,
    this.name,
    super.fromStrokeId,
  });

  double get widthMm => outline.width;
  double get heightMm => outline.height;
  double get areaMmSq => outline.area;

  @override
  String get label => name ?? 'Section';

  @override
  Vec2 get anchor => outline.centroid;

  SectionElement copyWith({Polygon? outline, Finish? finish, String? name}) =>
      SectionElement(
        id: id,
        outline: outline ?? this.outline,
        finish: finish ?? this.finish,
        name: name ?? this.name,
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
      };

  static SectionElement fromJson(Map<String, Object?> map) => SectionElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        outline: Polygon.fromJson(map['outline']),
        finish: Finish.fromJson(map['finish'], fallback: Finish.glazingDefault),
        name: map['name'] as String?,
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

/// Which way it opens relative to the viewer.
enum OpeningDirection { inward, outward, either }

/// A section that opens, and how.
///
/// It references the section it belongs to rather than copying its shape, so
/// resizing the section moves the leaf with it. The mechanism is what the
/// user drew or confirmed — never a guess the application made quietly.
class OpeningElement extends DesignElement {
  final String sectionId;
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

  const OpeningElement({
    required super.id,
    required this.sectionId,
    required this.mechanism,
    this.direction = OpeningDirection.inward,
    this.confirmed = false,
    this.markAt,
    this.markGlyph,
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

  OpeningElement copyWith({
    OpeningMechanism? mechanism,
    OpeningDirection? direction,
    bool? confirmed,
    Vec2? markAt,
    String? markGlyph,
  }) =>
      OpeningElement(
        id: id,
        sectionId: sectionId,
        mechanism: mechanism ?? this.mechanism,
        direction: direction ?? this.direction,
        confirmed: confirmed ?? this.confirmed,
        markAt: markAt ?? this.markAt,
        markGlyph: markGlyph ?? this.markGlyph,
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
  closer('Closer');

  const HardwareKind(this.label);
  final String label;
}

/// A piece of ironmongery, at the exact point the user put it.
///
/// Hardware appears only where the user drew or placed it. Nothing is added
/// to make a render look complete.
class HardwareElement extends DesignElement {
  final HardwareKind kind;
  final Vec2 at;
  final Finish finish;

  /// Degrees clockwise from horizontal.
  final double rotation;

  const HardwareElement({
    required super.id,
    required this.kind,
    required this.at,
    this.rotation = 0,
    this.finish = const Finish(colour: 0xFF8A8F8C, material: MaterialKind.steel),
    super.fromStrokeId,
  });

  @override
  String get label => kind.label;

  @override
  Vec2 get anchor => at;

  HardwareElement copyWith({Vec2? at, double? rotation, Finish? finish}) =>
      HardwareElement(
        id: id,
        kind: kind,
        at: at ?? this.at,
        rotation: rotation ?? this.rotation,
        finish: finish ?? this.finish,
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
      };

  static HardwareElement fromJson(Map<String, Object?> map) => HardwareElement(
        id: map['id']! as String,
        fromStrokeId: map['fromStrokeId'] as String?,
        kind: HardwareKind.values.firstWhere(
          (k) => k.name == map['kind'],
          orElse: () => HardwareKind.handle,
        ),
        at: Vec2.fromJson(map['at']),
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
