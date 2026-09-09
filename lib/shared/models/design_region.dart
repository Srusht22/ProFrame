import '../../core/utilities/geometry_math.dart';
import 'materials.dart';
import 'opening_enums.dart';

/// Which edge of a section is being talked about — for dragging a boundary,
/// for anchoring a placement, and for reporting a constraint.
enum RegionEdge { left, top, right, bottom }

extension RegionEdgeInfo on RegionEdge {
  bool get isHorizontalEdge => this == RegionEdge.top || this == RegionEdge.bottom;
  bool get isVerticalEdge => this == RegionEdge.left || this == RegionEdge.right;

  RegionEdge get opposite => switch (this) {
        RegionEdge.left => RegionEdge.right,
        RegionEdge.right => RegionEdge.left,
        RegionEdge.top => RegionEdge.bottom,
        RegionEdge.bottom => RegionEdge.top,
      };

  String get label => switch (this) {
        RegionEdge.left => 'left',
        RegionEdge.top => 'top',
        RegionEdge.right => 'right',
        RegionEdge.bottom => 'bottom',
      };
}

/// Where a section is pinned when it is placed by description rather than by
/// exact coordinates — "at the top-right", "on the left side".
enum RegionAnchor {
  topLeft,
  topCentre,
  topRight,
  centreLeft,
  centre,
  centreRight,
  bottomLeft,
  bottomCentre,
  bottomRight,
}

extension RegionAnchorInfo on RegionAnchor {
  String get label => switch (this) {
        RegionAnchor.topLeft => 'top-left',
        RegionAnchor.topCentre => 'top-centre',
        RegionAnchor.topRight => 'top-right',
        RegionAnchor.centreLeft => 'left',
        RegionAnchor.centre => 'centre',
        RegionAnchor.centreRight => 'right',
        RegionAnchor.bottomLeft => 'bottom-left',
        RegionAnchor.bottomCentre => 'bottom-centre',
        RegionAnchor.bottomRight => 'bottom-right',
      };

  /// Places a [width] x [height] box inside [container] at this anchor.
  /// The size is used exactly as given — never adjusted to look balanced.
  Box2 place(Box2 container, double width, double height) {
    final x = switch (this) {
      RegionAnchor.topLeft || RegionAnchor.centreLeft || RegionAnchor.bottomLeft =>
        container.left,
      RegionAnchor.topCentre || RegionAnchor.centre || RegionAnchor.bottomCentre =>
        container.left + (container.width - width) / 2,
      RegionAnchor.topRight || RegionAnchor.centreRight || RegionAnchor.bottomRight =>
        container.right - width,
    };
    final y = switch (this) {
      RegionAnchor.topLeft || RegionAnchor.topCentre || RegionAnchor.topRight =>
        container.top,
      RegionAnchor.centreLeft || RegionAnchor.centre || RegionAnchor.centreRight =>
        container.top + (container.height - height) / 2,
      RegionAnchor.bottomLeft ||
      RegionAnchor.bottomCentre ||
      RegionAnchor.bottomRight =>
        container.bottom - height,
    };
    return Box2.fromLTWH(x, y, width, height);
  }
}

/// One section of the product, at an exact position and size.
///
/// Sections are free-form rectangles in millimetres, measured from the
/// top-left of the product. They are deliberately **not** a grid: a 400 x 400
/// opening in the top-right corner is simply a rectangle there, and it does not
/// force a division through the rest of the design.
///
/// Nothing in the pipeline rounds, centres, squares up, equalises or otherwise
/// improves these numbers. What is stored here is what gets built.
class DesignRegion {
  final String id;

  /// What the user calls this section, when they have said.
  final String? label;

  /// Exact position and size, in millimetres, in the parent's coordinate
  /// space. For a top-level section that is the product's outer rectangle, so
  /// sections add up to the overall width and height.
  final Box2 rect;

  final CellOperation operation;
  final CellInfill infill;
  final GlassType glass;
  final PanelMaterial panel;
  final SwingDirection swing;
  final HandleStyle handle;
  final bool hasLock;
  final bool hasMesh;

  /// Handle height above the bottom of the *product*, when the user has asked
  /// for a specific one ("put the handle 100 cm from the floor").
  final double? handleHeightMm;

  /// Overrides for how thick the infill is. Null follows the glass or panel
  /// type; a value here is used exactly as given.
  final double? glassThicknessMm;
  final double? panelThicknessMm;

  /// Sections inside this one — how a leaf gets glass over a panel.
  final List<DesignRegion> children;

  const DesignRegion({
    required this.id,
    required this.rect,
    this.label,
    this.operation = CellOperation.fixed,
    this.infill = CellInfill.glass,
    this.glass = GlassType.clearDouble,
    this.panel = PanelMaterial.sandwichPanel,
    this.swing = SwingDirection.none,
    this.handle = HandleStyle.none,
    this.hasLock = false,
    this.hasMesh = false,
    this.handleHeightMm,
    this.glassThicknessMm,
    this.panelThicknessMm,
    this.children = const [],
  });

  /// The thickness the renderer and the price should use.
  double get infillThicknessMm => switch (infill) {
        CellInfill.glass => glassThicknessMm ?? glass.thicknessMm,
        CellInfill.panel || CellInfill.louvre =>
          panelThicknessMm ?? panel.thicknessMm,
        CellInfill.mesh => 2,
        CellInfill.open => 0,
      };

  double get widthMm => rect.width;
  double get heightMm => rect.height;
  double get areaM2 => (rect.width * rect.height) / 1e6;
  bool get isDivided => children.isNotEmpty;
  bool get isOperable => operation.isOperable;

  /// A short description of what this section is, for the properties panel.
  String get summary {
    final size = '${rect.width.round()} × ${rect.height.round()} mm';
    final what = operation.isOperable ? operation.label : infill.label;
    return '$size · $what';
  }

  DesignRegion copyWith({
    Box2? rect,
    String? label,
    bool clearLabel = false,
    CellOperation? operation,
    CellInfill? infill,
    GlassType? glass,
    PanelMaterial? panel,
    SwingDirection? swing,
    HandleStyle? handle,
    bool? hasLock,
    bool? hasMesh,
    double? handleHeightMm,
    bool clearHandleHeight = false,
    double? glassThicknessMm,
    double? panelThicknessMm,
    bool clearThickness = false,
    List<DesignRegion>? children,
  }) =>
      DesignRegion(
        id: id,
        rect: rect ?? this.rect,
        label: clearLabel ? null : (label ?? this.label),
        operation: operation ?? this.operation,
        infill: infill ?? this.infill,
        glass: glass ?? this.glass,
        panel: panel ?? this.panel,
        swing: swing ?? this.swing,
        handle: handle ?? this.handle,
        hasLock: hasLock ?? this.hasLock,
        hasMesh: hasMesh ?? this.hasMesh,
        handleHeightMm:
            clearHandleHeight ? null : (handleHeightMm ?? this.handleHeightMm),
        glassThicknessMm:
            clearThickness ? null : (glassThicknessMm ?? this.glassThicknessMm),
        panelThicknessMm:
            clearThickness ? null : (panelThicknessMm ?? this.panelThicknessMm),
        children: children ?? this.children,
      );

  /// Every section at or below this one, this one first.
  Iterable<DesignRegion> get selfAndDescendants sync* {
    yield this;
    for (final child in children) {
      yield* child.selfAndDescendants;
    }
  }

  /// The undivided sections — the ones that actually hold glass or a panel.
  Iterable<DesignRegion> get leaves sync* {
    if (children.isEmpty) {
      yield this;
    } else {
      for (final child in children) {
        yield* child.leaves;
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (label != null) 'label': label,
        'rect': rect.toJson(),
        'operation': operation.name,
        'infill': infill.name,
        'glass': glass.name,
        'panel': panel.name,
        'swing': swing.name,
        'handle': handle.name,
        'hasLock': hasLock,
        'hasMesh': hasMesh,
        if (handleHeightMm != null) 'handleHeightMm': handleHeightMm,
        if (glassThicknessMm != null) 'glassThicknessMm': glassThicknessMm,
        if (panelThicknessMm != null) 'panelThicknessMm': panelThicknessMm,
        if (children.isNotEmpty)
          'children': children.map((c) => c.toJson()).toList(),
      };

  factory DesignRegion.fromJson(Map<String, dynamic> json) => DesignRegion(
        id: json['id'] as String,
        label: json['label'] as String?,
        rect: Box2.fromJson(Map<String, dynamic>.from(json['rect'] as Map)),
        operation: enumByName(CellOperation.values, json['operation'], CellOperation.fixed),
        infill: enumByName(CellInfill.values, json['infill'], CellInfill.glass),
        glass: enumByName(GlassType.values, json['glass'], GlassType.clearDouble),
        panel: enumByName(PanelMaterial.values, json['panel'], PanelMaterial.sandwichPanel),
        swing: enumByName(SwingDirection.values, json['swing'], SwingDirection.none),
        handle: enumByName(HandleStyle.values, json['handle'], HandleStyle.none),
        hasLock: json['hasLock'] as bool? ?? false,
        hasMesh: json['hasMesh'] as bool? ?? false,
        handleHeightMm: (json['handleHeightMm'] as num?)?.toDouble(),
        glassThicknessMm: (json['glassThicknessMm'] as num?)?.toDouble(),
        panelThicknessMm: (json['panelThicknessMm'] as num?)?.toDouble(),
        children: ((json['children'] as List?) ?? const [])
            .map((e) => DesignRegion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Tree operations over a list of top-level sections. All of them return new
/// lists; nothing is mutated in place, so undo stays trivial.
class RegionTree {
  RegionTree._();

  static Iterable<DesignRegion> all(List<DesignRegion> regions) sync* {
    for (final region in regions) {
      yield* region.selfAndDescendants;
    }
  }

  static Iterable<DesignRegion> leaves(List<DesignRegion> regions) sync* {
    for (final region in regions) {
      yield* region.leaves;
    }
  }

  static DesignRegion? findById(List<DesignRegion> regions, String id) {
    for (final region in all(regions)) {
      if (region.id == id) return region;
    }
    return null;
  }

  /// The section that directly contains [id], or null when it is top level.
  static DesignRegion? parentOf(List<DesignRegion> regions, String id) {
    for (final region in all(regions)) {
      if (region.children.any((c) => c.id == id)) return region;
    }
    return null;
  }

  /// The sections that share a parent with [id], excluding it.
  static List<DesignRegion> siblingsOf(List<DesignRegion> regions, String id) {
    final parent = parentOf(regions, id);
    final family = parent?.children ?? regions;
    return family.where((r) => r.id != id).toList();
  }

  /// Replaces one section anywhere in the tree.
  static List<DesignRegion> replace(
    List<DesignRegion> regions,
    String id,
    DesignRegion Function(DesignRegion region) update,
  ) =>
      regions.map((region) {
        final withChildren = region.children.isEmpty
            ? region
            : region.copyWith(children: replace(region.children, id, update));
        return withChildren.id == id ? update(withChildren) : withChildren;
      }).toList();

  static List<DesignRegion> remove(List<DesignRegion> regions, String id) => regions
      .where((r) => r.id != id)
      .map((r) => r.children.isEmpty ? r : r.copyWith(children: remove(r.children, id)))
      .toList();

  /// Adds a section inside [parentId], or at the top level when it is null.
  static List<DesignRegion> insert(
    List<DesignRegion> regions,
    DesignRegion region, {
    String? parentId,
  }) {
    if (parentId == null) return [...regions, region];
    return replace(
      regions,
      parentId,
      (parent) => parent.copyWith(children: [...parent.children, region]),
    );
  }

  /// A fresh id that no existing section uses.
  static String nextId(List<DesignRegion> regions, {String prefix = 's'}) {
    final used = all(regions).map((r) => r.id).toSet();
    var index = used.length + 1;
    while (used.contains('$prefix$index')) {
      index++;
    }
    return '$prefix$index';
  }
}
