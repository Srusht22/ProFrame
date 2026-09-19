import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/vec2.dart';
import '../sketch/stroke.dart';
import 'elements.dart';
import 'hierarchy.dart';

/// A door or a window.
enum DesignKind {
  door('Door'),
  window('Window');

  const DesignKind(this.label);
  final String label;
}

/// One design: the user's drawing, and the structured geometry read from it.
///
/// **This is the only model.** The sketch, the technical drawing and the
/// solid are three ways of looking at what is in here, not three documents
/// that have to be kept in step:
///
/// ```
///                    Design
///                      |
///        +-------------+-------------+
///        |             |             |
///     the sheet    CAD drawing    3D model
///      (sketch)     (painter)     (mesh)
/// ```
///
/// Each view is a function of this object and holds no geometry of its own.
/// The CAD painter reads it and draws; `MeshBuilder.build` reads it and
/// returns a mesh that nothing keeps. Change a bar here and both views show
/// it, because there is nowhere else for either of them to be looking.
///
/// The one thing that is not a view of this is the user's own sketch, which
/// lives inside it and is never overwritten by the geometry read from it —
/// so what they drew can always be compared with what was made of it.
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

  // ------------------------------------------------------------- hierarchy
  //
  // The design is a tree, not a list. A bar drawn inside an opening belongs
  // to that opening: it divides the opening, not the design, and it travels
  // with the opening when the opening moves. These are the four questions
  // the rest of the application asks about that tree.

  /// The main divisions of the design — what the frame itself encloses.
  List<SectionElement> get topLevelSections =>
      [for (final s in sections) if (s.parentId == null) s];

  /// The bars that divide the design as a whole.
  List<DividerElement> get topLevelDividers =>
      [for (final d in dividers) if (d.parentId == null) d];

  /// The ids that mean "inside [sectionId]".
  ///
  /// A section that opens is named two ways: by its own id, and by the id of
  /// the opening on it. The opening's id is the form the model writes down,
  /// because an opening is authored and a section is derived — but both are
  /// understood, so every question asked of this design gets the same answer
  /// whichever form the caller knows about.
  Set<String> _namesFor(String sectionId) {
    final opening = openingOf(sectionId);
    return opening == null ? {sectionId} : {sectionId, opening.id};
  }

  /// The sections that fill [sectionId], made by the bars drawn inside it.
  List<SectionElement> childSectionsOf(String sectionId) {
    final names = _namesFor(sectionId);
    return [for (final s in sections) if (names.contains(s.parentId)) s];
  }

  /// The bars drawn inside [sectionId].
  List<DividerElement> childDividersOf(String sectionId) {
    final names = _namesFor(sectionId);
    return [for (final d in dividers) if (names.contains(d.parentId)) d];
  }

  /// True when this section is filled by other sections rather than by glass
  /// or a panel of its own.
  bool hasChildren(String sectionId) {
    final names = _namesFor(sectionId);
    return sections.any((s) => names.contains(s.parentId));
  }

  /// The section a thing lives in, whether its parent names the section or
  /// the opening on it. Null when it is top-level geometry.
  ///
  /// This is the one place the two forms are turned back into one answer.
  String? sectionHolding(String? parentId) {
    if (parentId == null) return null;
    final opening = openingById(parentId);
    return opening?.sectionId ?? parentId;
  }

  /// The opening a thing belongs to, or null when it belongs to no opening.
  ///
  /// **This is how top-level geometry is told from an opening's own.** A bar
  /// that divides the design answers null; a bar drawn inside an opening
  /// answers that opening, whichever form its `parentId` is written in.
  OpeningElement? openingHolding(String? parentId) {
    if (parentId == null) return null;
    return openingById(parentId) ?? openingOf(parentId);
  }

  /// Where an opening is and how big it is: the outline of its own section,
  /// and nothing wider.
  ///
  /// Derived, never stored. An opening carrying its own x, y, width and
  /// height would be a second copy of the section's shape, and the two would
  /// part company the first time a bar beside it moved — which is the whole
  /// class of bug this model exists to make impossible. The opening is a
  /// property of a region; the region has the shape.
  Polygon? outlineOf(OpeningElement opening) =>
      sectionById(opening.sectionId)?.outline;

  /// Everything the opening owns: the lines drawn inside it, the panes those
  /// lines make, whatever is inside those in turn, and its hardware.
  ///
  /// Nothing outside the opening's own section is ever in this list, because
  /// membership is `parentId` and `parentId` is set only by the user putting
  /// something there.
  List<DesignElement> contentsOf(OpeningElement opening) => [
        ...descendantsOf(opening.sectionId),
        for (final piece in hardware)
          if (piece.parentId == opening.sectionId ||
              piece.parentId == opening.id)
            piece,
      ];

  /// Everything inside [sectionId], at any depth: the bars drawn in it, the
  /// sections they make, and whatever is inside those in turn.
  ///
  /// Guarded against a section that has somehow become its own ancestor:
  /// this walks a tree, and a document that is not one should give a short
  /// answer rather than no answer at all.
  List<DesignElement> descendantsOf(String sectionId, {Set<String>? seen}) {
    final visited = seen ?? <String>{};
    if (!visited.add(sectionId)) return const [];

    final out = <DesignElement>[];
    for (final divider in childDividersOf(sectionId)) {
      out.add(divider);
    }
    for (final child in childSectionsOf(sectionId)) {
      if (child.id == sectionId) continue;
      out
        ..add(child)
        ..addAll(descendantsOf(child.id, seen: visited));
    }
    return out;
  }

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

  DividerElement? dividerById(String dividerId) {
    for (final d in dividers) {
      if (d.id == dividerId) return d;
    }
    return null;
  }

  OpeningElement? openingById(String openingId) {
    for (final o in openings) {
      if (o.id == openingId) return o;
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
  }) {
    // Every edit passes through here, so this is where the two things that
    // can never be true are kept untrue: a section is never inside itself or
    // inside one that is not there, and an opening always names exactly one
    // section of this design — never the frame, which is not a section, and
    // never a section that has gone. That is what makes "the whole door is
    // not an opening" a fact about the document rather than a rule each edit
    // has to remember.
    //
    // A *bar* whose section has gone is deliberately left alone here. That
    // one has a better answer than "it divides the design": `SectionBuilder`
    // looks for whatever now holds it, and only falls back to the design
    // when nothing does. Clearing it earlier would let a stale reference
    // reshape the top-level subdivision before that reconciliation had run,
    // and take the opening it came from with it.
    final theOpenings = openings ?? this.openings;
    final owned = Hierarchy.underOpenings(
      dividers ?? this.dividers,
      sections ?? this.sections,
      theOpenings,
    );
    final live = Hierarchy.settle(owned.sections, theOpenings);
    return Design(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      sketch: sketch ?? this.sketch,
      frame: clearFrame ? null : (frame ?? this.frame),
      dividers: owned.dividers,
      sections: live,
      openings: Hierarchy.settleOpenings(theOpenings, live),
      hardware: hardware ?? this.hardware,
      dimensions: dimensions ?? this.dimensions,
      texts: texts ?? this.texts,
      arrows: arrows ?? this.arrows,
      depthMm: depthMm ?? this.depthMm,
    );
  }

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

    // A design saved before the hierarchy was enforced can hold a parent
    // that is not there, or an opening on a section that has gone. It is
    // read as what it means rather than refused. A bar is settled here as
    // well as a section, because there is no rebuild between the file and
    // the first look at it, and a bar belonging to neither the design nor a
    // real section would be drawn by nothing.
    final loadedOpenings = [
      for (final e in list('openings')) OpeningElement.fromJson(e),
    ];
    final loaded = Hierarchy.underOpenings(
      [for (final e in list('dividers')) DividerElement.fromJson(e)],
      [for (final e in list('sections')) SectionElement.fromJson(e)],
      loadedOpenings,
    );
    final loadedSections = Hierarchy.settle(loaded.sections, loadedOpenings);
    // The openings are settled before the bars, so a bar can only name an
    // opening that survived: naming one that was itself dropped would leave
    // it belonging to nothing, and drawn by nothing.
    final liveOpenings =
        Hierarchy.settleOpenings(loadedOpenings, loadedSections);

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
      dividers: Hierarchy.settleDividers(
        loaded.dividers,
        loadedSections,
        liveOpenings,
      ),
      sections: loadedSections,
      openings: liveOpenings,
      hardware: [for (final e in list('hardware')) HardwareElement.fromJson(e)],
      dimensions: [
        for (final e in list('dimensions')) DimensionElement.fromJson(e),
      ],
      texts: [for (final e in list('texts')) TextElement.fromJson(e)],
      arrows: [for (final e in list('arrows')) ArrowElement.fromJson(e)],
    );
  }
}
