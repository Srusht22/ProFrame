import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/vec2.dart';
import '../sketch/stroke.dart';
import 'elements.dart';

/// A door or a window.
enum DesignKind {
  door('Door'),
  window('Window');

  const DesignKind(this.label);
  final String label;
}

/// One design: the user's drawing, and the structured geometry read from it.
///
/// The three things §13 asks for live side by side here — the original
/// sketch, the structured geometry, and everything the 3D model is built
/// from. The sketch is never overwritten by the geometry, so the user can
/// always compare what they drew with what was made of it.
class Design {
  final String id;
  final String name;
  final DesignKind kind;

  /// The user's own marks. Kept for the life of the design.
  final Sketch sketch;

  /// The outer frame, once there is one.
  final FrameElement? frame;

  final List<DividerElement> dividers;
  final List<SectionElement> sections;
  final List<OpeningElement> openings;
  final List<HardwareElement> hardware;
  final List<DimensionElement> dimensions;
  final List<TextElement> texts;
  final List<ArrowElement> arrows;

  /// How thick the whole thing is, front to back — the depth of the 3D model.
  final double depthMm;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Design({
    required this.id,
    required this.name,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    this.sketch = const Sketch(),
    this.frame,
    this.dividers = const [],
    this.sections = const [],
    this.openings = const [],
    this.hardware = const [],
    this.dimensions = const [],
    this.texts = const [],
    this.arrows = const [],
    this.depthMm = 70,
  });

  factory Design.empty({
    required String id,
    required DesignKind kind,
    String? name,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return Design(
      id: id,
      name: name ?? 'Untitled ${kind.label.toLowerCase()}',
      kind: kind,
      createdAt: at,
      updatedAt: at,
    );
  }

  /// Everything selectable, in the order the component tree shows it.
  List<DesignElement> get allElements => [
        ?frame,
        ...frameMembers,
        ...dividers,
        ...sections,
        ...openings,
        ...hardware,
        ...dimensions,
        ...texts,
        ...arrows,
      ];

  /// The sides of the frame — head, sill, jambs — as separate parts.
  ///
  /// Worked out from the outline each time rather than stored, so they can
  /// never disagree with the shape they are the sides of.
  List<FrameMemberElement> get frameMembers {
    final outline = frame?.outline;
    if (outline == null || outline.isEmpty) return const [];

    final edges = outline.edges;
    final middleY = (outline.top + outline.bottom) / 2;
    final middleX = (outline.left + outline.right) / 2;

    return [
      for (var i = 0; i < edges.length; i++)
        FrameMemberElement(
          id: FrameMemberElement.idFor(frame!.id, i),
          frameId: frame!.id,
          index: i,
          run: edges[i],
          placement: _placementOf(edges[i], middleX, middleY),
        ),
    ];
  }

  static String _placementOf(Segment edge, double middleX, double middleY) {
    final at = edge.midpoint;
    if (edge.isHorizontalish) return at.y < middleY ? 'Head' : 'Sill';
    if (edge.isVerticalish) {
      return at.x < middleX ? 'Left jamb' : 'Right jamb';
    }
    // A frame that is not four-sided has sides that are neither. They are
    // named for where they are rather than for what they would be on a
    // rectangle, because there is no honest name for them there.
    final vertical = at.y < middleY ? 'upper' : 'lower';
    final horizontal = at.x < middleX ? 'left' : 'right';
    return 'Raking $vertical $horizontal side';
  }

  bool get hasGeometry => frame != null || dividers.isNotEmpty;

  /// The extent of the design in millimetres, from the frame when there is
  /// one and from whatever has been drawn when there is not.
  Polygon? get bounds {
    if (frame != null) return frame!.outline;
    final points = <Vec2>[
      for (final d in dividers) ...[d.a, d.b],
      for (final s in sections) ...s.outline.corners,
    ];
    if (points.isEmpty) return null;
    var left = points.first.x, right = left, top = points.first.y, bottom = top;
    for (final p in points) {
      if (p.x < left) left = p.x;
      if (p.x > right) right = p.x;
      if (p.y < top) top = p.y;
      if (p.y > bottom) bottom = p.y;
    }
    return Polygon.rect(left, top, right, bottom);
  }

  double get widthMm => frame?.widthMm ?? bounds?.width ?? 0;
  double get heightMm => frame?.heightMm ?? bounds?.height ?? 0;

  DesignElement? elementById(String elementId) {
    for (final e in allElements) {
      if (e.id == elementId) return e;
    }
    return null;
  }

  SectionElement? sectionById(String sectionId) {
    for (final s in sections) {
      if (s.id == sectionId) return s;
    }
    return null;
  }

  /// The opening on a section, when it has one.
  OpeningElement? openingOf(String sectionId) {
    for (final o in openings) {
      if (o.sectionId == sectionId) return o;
    }
    return null;
  }

  Design copyWith({
    String? name,
    DesignKind? kind,
    Sketch? sketch,
    FrameElement? frame,
    bool clearFrame = false,
    List<DividerElement>? dividers,
    List<SectionElement>? sections,
    List<OpeningElement>? openings,
    List<HardwareElement>? hardware,
    List<DimensionElement>? dimensions,
    List<TextElement>? texts,
    List<ArrowElement>? arrows,
    double? depthMm,
    DateTime? updatedAt,
  }) =>
      Design(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        sketch: sketch ?? this.sketch,
        frame: clearFrame ? null : (frame ?? this.frame),
        dividers: dividers ?? this.dividers,
        sections: sections ?? this.sections,
        openings: openings ?? this.openings,
        hardware: hardware ?? this.hardware,
        dimensions: dimensions ?? this.dimensions,
        texts: texts ?? this.texts,
        arrows: arrows ?? this.arrows,
        depthMm: depthMm ?? this.depthMm,
      );

  /// Replaces one element with an edited copy of itself, wherever it lives.
  Design withElement(DesignElement element) => switch (element) {
        FrameElement() => copyWith(frame: element),
        // A member is a view of one edge of the frame, not a thing of its
        // own to store. Moving it means moving that edge, which is what
        // DesignEdits.moveFrameMember does.
        FrameMemberElement() => this,
        DividerElement() => copyWith(dividers: [
            for (final d in dividers) if (d.id == element.id) element else d,
          ]),
        SectionElement() => copyWith(sections: [
            for (final s in sections) if (s.id == element.id) element else s,
          ]),
        OpeningElement() => copyWith(openings: [
            for (final o in openings) if (o.id == element.id) element else o,
          ]),
        HardwareElement() => copyWith(hardware: [
            for (final h in hardware) if (h.id == element.id) element else h,
          ]),
        DimensionElement() => copyWith(dimensions: [
            for (final d in dimensions) if (d.id == element.id) element else d,
          ]),
        TextElement() => copyWith(texts: [
            for (final t in texts) if (t.id == element.id) element else t,
          ]),
        ArrowElement() => copyWith(arrows: [
            for (final a in arrows) if (a.id == element.id) element else a,
          ]),
      };

  /// Removes an element the user deleted. Sections are not removed here —
  /// they follow from the dividers, so deleting a divider is what changes
  /// them.
  Design withoutElement(String elementId) => copyWith(
        clearFrame: frame?.id == elementId,
        dividers: [for (final d in dividers) if (d.id != elementId) d],
        openings: [
          for (final o in openings)
            if (o.id != elementId && o.sectionId != elementId) o,
        ],
        hardware: [for (final h in hardware) if (h.id != elementId) h],
        dimensions: [for (final d in dimensions) if (d.id != elementId) d],
        texts: [for (final t in texts) if (t.id != elementId) t],
        arrows: [for (final a in arrows) if (a.id != elementId) a],
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'depthMm': depthMm,
        'sketch': sketch.toJson(),
        if (frame != null) 'frame': frame!.toJson(),
        'dividers': [for (final d in dividers) d.toJson()],
        'sections': [for (final s in sections) s.toJson()],
        'openings': [for (final o in openings) o.toJson()],
        'hardware': [for (final h in hardware) h.toJson()],
        'dimensions': [for (final d in dimensions) d.toJson()],
        'texts': [for (final t in texts) t.toJson()],
        'arrows': [for (final a in arrows) a.toJson()],
      };

  static Design fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    List<Map<String, Object?>> list(String key) => [
          for (final e in (map[key] as List<Object?>? ?? const []))
            e! as Map<String, Object?>,
        ];
    return Design(
      id: map['id']! as String,
      name: map['name']! as String,
      kind: DesignKind.values.firstWhere(
        (k) => k.name == map['kind'],
        orElse: () => DesignKind.window,
      ),
      createdAt: DateTime.parse(map['createdAt']! as String),
      updatedAt: DateTime.parse(map['updatedAt']! as String),
      depthMm: (map['depthMm'] as num?)?.toDouble() ?? 70,
      sketch: Sketch.fromJson(map['sketch']),
      frame: map['frame'] == null
          ? null
          : FrameElement.fromJson(map['frame']! as Map<String, Object?>),
      dividers: [for (final e in list('dividers')) DividerElement.fromJson(e)],
      sections: [for (final e in list('sections')) SectionElement.fromJson(e)],
      openings: [for (final e in list('openings')) OpeningElement.fromJson(e)],
      hardware: [for (final e in list('hardware')) HardwareElement.fromJson(e)],
      dimensions: [
        for (final e in list('dimensions')) DimensionElement.fromJson(e),
      ],
      texts: [for (final e in list('texts')) TextElement.fromJson(e)],
      arrows: [for (final e in list('arrows')) ArrowElement.fromJson(e)],
    );
  }
}
