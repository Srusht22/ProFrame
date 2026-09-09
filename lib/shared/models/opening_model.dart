import 'dart:math' as math;

import '../../core/utilities/geometry_math.dart';
import 'materials.dart';

/// Is this a door or a window? It changes defaults (threshold vs sill, handle
/// height, minimum sizes) but not the underlying geometry engine.
enum OpeningKind { door, window }

extension OpeningKindInfo on OpeningKind {
  String get label => this == OpeningKind.door ? 'Door' : 'Window';
}

/// Which way the hinges are and how the leaf moves. This is the single value
/// the recogniser has to get right from the diagonals on the paper.
enum CellOperation {
  fixed,
  casementLeft,
  casementRight,
  awning,
  hopper,
  slidingLeft,
  slidingRight,
  tiltTurnLeft,
  tiltTurnRight,
  doorLeafLeft,
  doorLeafRight,
}

enum HingeSide { left, right, top, bottom, none }

extension CellOperationInfo on CellOperation {
  String get label => switch (this) {
        CellOperation.fixed => 'Fixed',
        CellOperation.casementLeft => 'Casement, hinged left',
        CellOperation.casementRight => 'Casement, hinged right',
        CellOperation.awning => 'Awning (top hung)',
        CellOperation.hopper => 'Hopper (bottom hung)',
        CellOperation.slidingLeft => 'Sliding to the left',
        CellOperation.slidingRight => 'Sliding to the right',
        CellOperation.tiltTurnLeft => 'Tilt & turn, hinged left',
        CellOperation.tiltTurnRight => 'Tilt & turn, hinged right',
        CellOperation.doorLeafLeft => 'Door leaf, hinged left',
        CellOperation.doorLeafRight => 'Door leaf, hinged right',
      };

  /// A moving leaf needs its own sash profile, hinges and a handle.
  bool get isOperable => this != CellOperation.fixed;

  bool get isSliding =>
      this == CellOperation.slidingLeft || this == CellOperation.slidingRight;

  bool get isDoorLeaf =>
      this == CellOperation.doorLeafLeft || this == CellOperation.doorLeafRight;

  HingeSide get hingeSide => switch (this) {
        CellOperation.casementLeft ||
        CellOperation.tiltTurnLeft ||
        CellOperation.doorLeafLeft =>
          HingeSide.left,
        CellOperation.casementRight ||
        CellOperation.tiltTurnRight ||
        CellOperation.doorLeafRight =>
          HingeSide.right,
        CellOperation.awning => HingeSide.top,
        CellOperation.hopper => HingeSide.bottom,
        _ => HingeSide.none,
      };

  /// Mirrors the operation left↔right, used by the "flip hinge side" action.
  CellOperation get mirrored => switch (this) {
        CellOperation.casementLeft => CellOperation.casementRight,
        CellOperation.casementRight => CellOperation.casementLeft,
        CellOperation.slidingLeft => CellOperation.slidingRight,
        CellOperation.slidingRight => CellOperation.slidingLeft,
        CellOperation.tiltTurnLeft => CellOperation.tiltTurnRight,
        CellOperation.tiltTurnRight => CellOperation.tiltTurnLeft,
        CellOperation.doorLeafLeft => CellOperation.doorLeafRight,
        CellOperation.doorLeafRight => CellOperation.doorLeafLeft,
        _ => this,
      };
}

/// Which way an operable leaf swings relative to the building.
enum SwingDirection { inward, outward, none }

extension SwingDirectionInfo on SwingDirection {
  String get label => switch (this) {
        SwingDirection.inward => 'Opens inward',
        SwingDirection.outward => 'Opens outward',
        SwingDirection.none => 'No swing',
      };
}

/// What fills the aperture.
enum CellInfill { glass, panel, louvre, mesh, open }

extension CellInfillInfo on CellInfill {
  String get label => switch (this) {
        CellInfill.glass => 'Glass',
        CellInfill.panel => 'Solid panel',
        CellInfill.louvre => 'Louvre',
        CellInfill.mesh => 'Insect mesh',
        CellInfill.open => 'Open',
      };
}

/// One aperture of the product: a fixed light, a casement sash, a door leaf.
///
/// A cell may itself be divided ([subLayout]) — that is how a door leaf with
/// an upper glass light and a lower solid panel is represented.
class LayoutCell {
  final String id;

  /// Share of the row's free width. Ignored when [fixedWidthMm] is set.
  final double widthRatio;

  /// Exact width in millimetres, when the user has pinned this cell.
  final double? fixedWidthMm;

  final CellOperation operation;
  final CellInfill infill;
  final GlassType glass;
  final PanelMaterial panel;
  final SwingDirection swing;
  final HandleStyle handle;
  final bool hasLock;
  final bool hasMesh;
  final String? label;
  final OpeningLayout? subLayout;

  const LayoutCell({
    required this.id,
    this.widthRatio = 1,
    this.fixedWidthMm,
    this.operation = CellOperation.fixed,
    this.infill = CellInfill.glass,
    this.glass = GlassType.clearDouble,
    this.panel = PanelMaterial.sandwichPanel,
    this.swing = SwingDirection.none,
    this.handle = HandleStyle.none,
    this.hasLock = false,
    this.hasMesh = false,
    this.label,
    this.subLayout,
  });

  LayoutCell copyWith({
    double? widthRatio,
    double? fixedWidthMm,
    bool clearFixedWidth = false,
    CellOperation? operation,
    CellInfill? infill,
    GlassType? glass,
    PanelMaterial? panel,
    SwingDirection? swing,
    HandleStyle? handle,
    bool? hasLock,
    bool? hasMesh,
    String? label,
    OpeningLayout? subLayout,
    bool clearSubLayout = false,
  }) =>
      LayoutCell(
        id: id,
        widthRatio: widthRatio ?? this.widthRatio,
        fixedWidthMm: clearFixedWidth ? null : (fixedWidthMm ?? this.fixedWidthMm),
        operation: operation ?? this.operation,
        infill: infill ?? this.infill,
        glass: glass ?? this.glass,
        panel: panel ?? this.panel,
        swing: swing ?? this.swing,
        handle: handle ?? this.handle,
        hasLock: hasLock ?? this.hasLock,
        hasMesh: hasMesh ?? this.hasMesh,
        label: label ?? this.label,
        subLayout: clearSubLayout ? null : (subLayout ?? this.subLayout),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'widthRatio': widthRatio,
        if (fixedWidthMm != null) 'fixedWidthMm': fixedWidthMm,
        'operation': operation.name,
        'infill': infill.name,
        'glass': glass.name,
        'panel': panel.name,
        'swing': swing.name,
        'handle': handle.name,
        'hasLock': hasLock,
        'hasMesh': hasMesh,
        if (label != null) 'label': label,
        if (subLayout != null) 'subLayout': subLayout!.toJson(),
      };

  factory LayoutCell.fromJson(Map<String, dynamic> json) => LayoutCell(
        id: json['id'] as String,
        widthRatio: (json['widthRatio'] as num?)?.toDouble() ?? 1,
        fixedWidthMm: (json['fixedWidthMm'] as num?)?.toDouble(),
        operation: _enumByName(CellOperation.values, json['operation'], CellOperation.fixed),
        infill: _enumByName(CellInfill.values, json['infill'], CellInfill.glass),
        glass: _enumByName(GlassType.values, json['glass'], GlassType.clearDouble),
        panel: _enumByName(PanelMaterial.values, json['panel'], PanelMaterial.sandwichPanel),
        swing: _enumByName(SwingDirection.values, json['swing'], SwingDirection.none),
        handle: _enumByName(HandleStyle.values, json['handle'], HandleStyle.none),
        hasLock: json['hasLock'] as bool? ?? false,
        hasMesh: json['hasMesh'] as bool? ?? false,
        label: json['label'] as String?,
        subLayout: json['subLayout'] == null
            ? null
            : OpeningLayout.fromJson(Map<String, dynamic>.from(json['subLayout'] as Map)),
      );
}

/// A horizontal band of the product. Rows are separated by transoms; the cells
/// inside a row are separated by mullions.
class LayoutRow {
  final String id;
  final double heightRatio;
  final double? fixedHeightMm;
  final List<LayoutCell> cells;

  const LayoutRow({
    required this.id,
    this.heightRatio = 1,
    this.fixedHeightMm,
    required this.cells,
  });

  LayoutRow copyWith({
    double? heightRatio,
    double? fixedHeightMm,
    bool clearFixedHeight = false,
    List<LayoutCell>? cells,
  }) =>
      LayoutRow(
        id: id,
        heightRatio: heightRatio ?? this.heightRatio,
        fixedHeightMm: clearFixedHeight ? null : (fixedHeightMm ?? this.fixedHeightMm),
        cells: cells ?? this.cells,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'heightRatio': heightRatio,
        if (fixedHeightMm != null) 'fixedHeightMm': fixedHeightMm,
        'cells': cells.map((c) => c.toJson()).toList(),
      };

  factory LayoutRow.fromJson(Map<String, dynamic> json) => LayoutRow(
        id: json['id'] as String,
        heightRatio: (json['heightRatio'] as num?)?.toDouble() ?? 1,
        fixedHeightMm: (json['fixedHeightMm'] as num?)?.toDouble(),
        cells: ((json['cells'] as List?) ?? const [])
            .map((e) => LayoutCell.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Rows top-to-bottom, cells left-to-right. Nestable through
/// [LayoutCell.subLayout].
class OpeningLayout {
  final List<LayoutRow> rows;

  const OpeningLayout({required this.rows});

  factory OpeningLayout.single(LayoutCell cell) => OpeningLayout(
        rows: [LayoutRow(id: 'r0', cells: [cell])],
      );

  int get rowCount => rows.length;
  int get maxColumnCount =>
      rows.isEmpty ? 0 : rows.map((r) => r.cells.length).reduce(math.max);

  Iterable<LayoutCell> get allCells sync* {
    for (final row in rows) {
      for (final cell in row.cells) {
        yield cell;
        final sub = cell.subLayout;
        if (sub != null) yield* sub.allCells;
      }
    }
  }

  OpeningLayout copyWith({List<LayoutRow>? rows}) =>
      OpeningLayout(rows: rows ?? this.rows);

  Map<String, dynamic> toJson() => {'rows': rows.map((r) => r.toJson()).toList()};

  factory OpeningLayout.fromJson(Map<String, dynamic> json) => OpeningLayout(
        rows: ((json['rows'] as List?) ?? const [])
            .map((e) => LayoutRow.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// The single parametric description of the product. Everything downstream —
/// the technical drawing, the 3D scene, the price — is derived from this and
/// only this (spec §27, §51).
class OpeningModel {
  final String id;
  final OpeningKind kind;
  final double widthMm;
  final double heightMm;
  final FrameMaterial material;
  final FrameFinish finish;
  final OpeningLayout layout;

  /// Depth of the wall reveal the frame sits in — drives the jamb geometry.
  final double wallDepthMm;

  final bool hasThreshold;
  final bool hasSill;
  final double sillProjectionMm;

  const OpeningModel({
    required this.id,
    required this.kind,
    required this.widthMm,
    required this.heightMm,
    required this.layout,
    this.material = FrameMaterial.aluminium,
    this.finish = FrameFinish.naturalAnodised,
    this.wallDepthMm = 200,
    this.hasThreshold = false,
    this.hasSill = false,
    this.sillProjectionMm = 40,
  });

  /// A sensible starting point when the user picks a type before drawing.
  factory OpeningModel.blank(OpeningKind kind, {String id = 'model'}) {
    final isDoor = kind == OpeningKind.door;
    return OpeningModel(
      id: id,
      kind: kind,
      widthMm: isDoor ? 900 : 1200,
      heightMm: isDoor ? 2100 : 1400,
      hasThreshold: isDoor,
      hasSill: !isDoor,
      layout: OpeningLayout.single(
        LayoutCell(
          id: 'c0',
          operation: isDoor ? CellOperation.doorLeafRight : CellOperation.fixed,
          infill: CellInfill.glass,
          swing: isDoor ? SwingDirection.inward : SwingDirection.none,
          handle: isDoor ? HandleStyle.lever : HandleStyle.none,
          hasLock: isDoor,
        ),
      ),
    );
  }

  double get areaM2 => (widthMm * heightMm) / 1e6;

  int get operableCellCount =>
      layout.allCells.where((c) => c.operation.isOperable).length;

  OpeningModel copyWith({
    OpeningKind? kind,
    double? widthMm,
    double? heightMm,
    FrameMaterial? material,
    FrameFinish? finish,
    OpeningLayout? layout,
    double? wallDepthMm,
    bool? hasThreshold,
    bool? hasSill,
    double? sillProjectionMm,
  }) =>
      OpeningModel(
        id: id,
        kind: kind ?? this.kind,
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        material: material ?? this.material,
        finish: finish ?? this.finish,
        layout: layout ?? this.layout,
        wallDepthMm: wallDepthMm ?? this.wallDepthMm,
        hasThreshold: hasThreshold ?? this.hasThreshold,
        hasSill: hasSill ?? this.hasSill,
        sillProjectionMm: sillProjectionMm ?? this.sillProjectionMm,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'material': material.name,
        'finish': finish.name,
        'wallDepthMm': wallDepthMm,
        'hasThreshold': hasThreshold,
        'hasSill': hasSill,
        'sillProjectionMm': sillProjectionMm,
        'layout': layout.toJson(),
      };

  factory OpeningModel.fromJson(Map<String, dynamic> json) => OpeningModel(
        id: json['id'] as String,
        kind: _enumByName(OpeningKind.values, json['kind'], OpeningKind.window),
        widthMm: (json['widthMm'] as num).toDouble(),
        heightMm: (json['heightMm'] as num).toDouble(),
        material: _enumByName(FrameMaterial.values, json['material'], FrameMaterial.aluminium),
        finish: _enumByName(FrameFinish.values, json['finish'], FrameFinish.naturalAnodised),
        wallDepthMm: (json['wallDepthMm'] as num?)?.toDouble() ?? 200,
        hasThreshold: json['hasThreshold'] as bool? ?? false,
        hasSill: json['hasSill'] as bool? ?? false,
        sillProjectionMm: (json['sillProjectionMm'] as num?)?.toDouble() ?? 40,
        layout: OpeningLayout.fromJson(Map<String, dynamic>.from(json['layout'] as Map)),
      );

  /// Manufacturing limits. Not a hard block — the user is warned, because a
  /// factory may legitimately build outside a generic envelope.
  List<String> validate() {
    final issues = <String>[];
    if (widthMm < 200) issues.add('Width ${widthMm.round()} mm is below the 200 mm minimum.');
    if (heightMm < 200) issues.add('Height ${heightMm.round()} mm is below the 200 mm minimum.');
    if (widthMm > 6000) issues.add('Width ${widthMm.round()} mm exceeds the 6000 mm span limit.');
    if (heightMm > 4000) issues.add('Height ${heightMm.round()} mm exceeds the 4000 mm span limit.');
    final solved = OpeningSolver.solve(this);
    for (final cell in solved.leaves) {
      if (cell.aperture.width < 120 || cell.aperture.height < 120) {
        issues.add(
          'Section ${cell.path} is only ${cell.aperture.width.round()} × '
          '${cell.aperture.height.round()} mm — too small to fabricate.',
        );
      }
      if (cell.spec.operation.isOperable && cell.aperture.width > 1200) {
        issues.add(
          'Opening leaf ${cell.path} is ${cell.aperture.width.round()} mm wide; '
          'leaves over 1200 mm sag and need reinforcement.',
        );
      }
    }
    return issues;
  }
}

// ---------------------------------------------------------------------------
// Solver: parametric model -> absolute millimetre geometry
// ---------------------------------------------------------------------------

/// A mullion (vertical) or transom (horizontal) bar, in absolute millimetres.
class SolvedBar {
  final String id;
  final Box2 rect;
  final bool vertical;
  final int depthLevel;

  const SolvedBar({
    required this.id,
    required this.rect,
    required this.vertical,
    this.depthLevel = 0,
  });

  double get lengthMm => vertical ? rect.height : rect.width;
}

/// A cell resolved to real coordinates.
///
/// [aperture] is the hole in the surrounding frame. For an operable leaf the
/// sash profile sits inside that hole and [glazingRect] is the visible glass
/// or panel inside the sash. For a fixed light the sash is absent and the
/// glazing sits directly in the aperture behind the bead.
class SolvedCell {
  final LayoutCell spec;
  final String path;
  final int rowIndex;
  final int columnIndex;
  final Box2 aperture;
  final Box2 sashRect;
  final Box2 glazingRect;
  final List<SolvedCell> children;
  final List<SolvedBar> childBars;

  const SolvedCell({
    required this.spec,
    required this.path,
    required this.rowIndex,
    required this.columnIndex,
    required this.aperture,
    required this.sashRect,
    required this.glazingRect,
    this.children = const [],
    this.childBars = const [],
  });

  bool get isLeaf => children.isEmpty;
  bool get hasSash => spec.operation.isOperable;

  double get glazingAreaM2 => (glazingRect.width * glazingRect.height) / 1e6;
}

/// The fully resolved product: every bar and every cell in millimetres,
/// measured from the top-left of the outer frame.
class SolvedOpening {
  final OpeningModel model;
  final Box2 outerRect;
  final Box2 innerRect;
  final List<SolvedCell> topCells;
  final List<SolvedBar> bars;

  const SolvedOpening({
    required this.model,
    required this.outerRect,
    required this.innerRect,
    required this.topCells,
    required this.bars,
  });

  /// Every undivided cell, including those nested inside a divided leaf.
  List<SolvedCell> get leaves {
    final result = <SolvedCell>[];
    void walk(SolvedCell c) {
      if (c.isLeaf) {
        result.add(c);
      } else {
        for (final child in c.children) {
          walk(child);
        }
      }
    }

    for (final c in topCells) {
      walk(c);
    }
    return result;
  }

  /// Every cell at any level, parents included.
  List<SolvedCell> get allCells {
    final result = <SolvedCell>[];
    void walk(SolvedCell c) {
      result.add(c);
      for (final child in c.children) {
        walk(child);
      }
    }

    for (final c in topCells) {
      walk(c);
    }
    return result;
  }

  /// Every bar at any level.
  List<SolvedBar> get allBars {
    final result = <SolvedBar>[...bars];
    void walk(SolvedCell c) {
      result.addAll(c.childBars);
      for (final child in c.children) {
        walk(child);
      }
    }

    for (final c in topCells) {
      walk(c);
    }
    return result;
  }

  double get totalGlassAreaM2 => leaves
      .where((c) => c.spec.infill == CellInfill.glass)
      .fold<double>(0, (sum, c) => sum + c.glazingAreaM2);

  double get totalPanelAreaM2 => leaves
      .where((c) => c.spec.infill == CellInfill.panel || c.spec.infill == CellInfill.louvre)
      .fold<double>(0, (sum, c) => sum + c.glazingAreaM2);

  /// Outer frame perimeter in linear metres.
  double get framePerimeterM => 2 * (model.widthMm + model.heightMm) / 1000;

  /// Total mullion + transom length in linear metres.
  double get barLengthM =>
      allBars.fold<double>(0, (sum, b) => sum + b.lengthMm) / 1000;

  /// Total sash profile perimeter in linear metres.
  double get sashPerimeterM => allCells
      .where((c) => c.hasSash)
      .fold<double>(0, (sum, c) => sum + 2 * (c.sashRect.width + c.sashRect.height) / 1000);
}

/// Turns an [OpeningModel] into absolute geometry. Pure, deterministic and
/// fully unit-testable — no widget, no canvas, no renderer involved.
class OpeningSolver {
  OpeningSolver._();

  /// Millimetres the glazing bead covers on each edge of an aperture.
  static const double glazingBeadMm = 14;

  static SolvedOpening solve(OpeningModel model) {
    final frameFace = model.material.frameFaceMm;
    final outer = Box2(0, 0, model.widthMm, model.heightMm);
    final inner = Box2(
      frameFace,
      frameFace,
      model.widthMm - frameFace,
      model.heightMm - frameFace,
    );

    final result = _solveLayout(
      layout: model.layout,
      region: inner,
      material: model.material,
      pathPrefix: '',
      depthLevel: 0,
    );

    return SolvedOpening(
      model: model,
      outerRect: outer,
      innerRect: inner,
      topCells: result.cells,
      bars: result.bars,
    );
  }

  static _LayoutResult _solveLayout({
    required OpeningLayout layout,
    required Box2 region,
    required FrameMaterial material,
    required String pathPrefix,
    required int depthLevel,
  }) {
    final cells = <SolvedCell>[];
    final bars = <SolvedBar>[];
    if (layout.rows.isEmpty || region.width <= 0 || region.height <= 0) {
      return _LayoutResult(cells, bars);
    }

    final barFace = material.mullionFaceMm;
    final rowGaps = (layout.rows.length - 1) * barFace;
    final rowHeights = _distribute(
      total: region.height - rowGaps,
      fixed: layout.rows.map((r) => r.fixedHeightMm).toList(),
      ratios: layout.rows.map((r) => r.heightRatio).toList(),
    );

    var y = region.top;
    for (var ri = 0; ri < layout.rows.length; ri++) {
      final row = layout.rows[ri];
      final rowHeight = rowHeights[ri];
      final rowRegion = Box2(region.left, y, region.right, y + rowHeight);

      final colGaps = (row.cells.length - 1) * barFace;
      final cellWidths = _distribute(
        total: rowRegion.width - colGaps,
        fixed: row.cells.map((c) => c.fixedWidthMm).toList(),
        ratios: row.cells.map((c) => c.widthRatio).toList(),
      );

      var x = rowRegion.left;
      for (var ci = 0; ci < row.cells.length; ci++) {
        final cell = row.cells[ci];
        final aperture = Box2(x, rowRegion.top, x + cellWidths[ci], rowRegion.bottom);
        cells.add(_solveCell(
          spec: cell,
          aperture: aperture,
          material: material,
          path: pathPrefix.isEmpty ? 'r$ri.c$ci' : '$pathPrefix/r$ri.c$ci',
          rowIndex: ri,
          columnIndex: ci,
          depthLevel: depthLevel,
        ));
        x += cellWidths[ci];

        if (ci < row.cells.length - 1) {
          bars.add(SolvedBar(
            id: '${pathPrefix}m$ri$ci',
            rect: Box2(x, rowRegion.top, x + barFace, rowRegion.bottom),
            vertical: true,
            depthLevel: depthLevel,
          ));
          x += barFace;
        }
      }

      y += rowHeight;
      if (ri < layout.rows.length - 1) {
        bars.add(SolvedBar(
          id: '${pathPrefix}t$ri',
          rect: Box2(region.left, y, region.right, y + barFace),
          vertical: false,
          depthLevel: depthLevel,
        ));
        y += barFace;
      }
    }

    return _LayoutResult(cells, bars);
  }

  static SolvedCell _solveCell({
    required LayoutCell spec,
    required Box2 aperture,
    required FrameMaterial material,
    required String path,
    required int rowIndex,
    required int columnIndex,
    required int depthLevel,
  }) {
    final sashFace = material.sashFaceMm;
    final hasSash = spec.operation.isOperable;

    // A sliding leaf overlaps the frame instead of sitting flush inside it,
    // which is why sliding sashes visibly overlap each other in reality.
    final sashRect = hasSash ? aperture : aperture;
    final innerAperture = hasSash
        ? Box2(
            aperture.left + sashFace,
            aperture.top + sashFace,
            aperture.right - sashFace,
            aperture.bottom - sashFace,
          )
        : aperture;

    final sub = spec.subLayout;
    if (sub != null && sub.rows.isNotEmpty) {
      final nested = _solveLayout(
        layout: sub,
        region: innerAperture,
        material: material,
        pathPrefix: '$path/',
        depthLevel: depthLevel + 1,
      );
      return SolvedCell(
        spec: spec,
        path: path,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        aperture: aperture,
        sashRect: sashRect,
        glazingRect: innerAperture,
        children: nested.cells,
        childBars: nested.bars,
      );
    }

    final glazing = Box2(
      innerAperture.left + glazingBeadMm,
      innerAperture.top + glazingBeadMm,
      innerAperture.right - glazingBeadMm,
      innerAperture.bottom - glazingBeadMm,
    );

    return SolvedCell(
      spec: spec,
      path: path,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      aperture: aperture,
      sashRect: sashRect,
      glazingRect: glazing,
    );
  }

  /// Splits [total] honouring any pinned millimetre sizes and sharing what is
  /// left across the remaining ratios. Guarantees the parts sum to [total].
  static List<double> _distribute({
    required double total,
    required List<double?> fixed,
    required List<double> ratios,
  }) {
    final result = List<double>.filled(fixed.length, 0);
    var remaining = total;
    final flexible = <int>[];

    for (var i = 0; i < fixed.length; i++) {
      final f = fixed[i];
      if (f != null && f > 0) {
        result[i] = math.min(f, math.max(remaining, 0));
        remaining -= result[i];
      } else {
        flexible.add(i);
      }
    }

    if (flexible.isEmpty) {
      // Everything pinned: absorb any leftover into the last part so the sum
      // still matches the outer dimension exactly.
      if (result.isNotEmpty && remaining.abs() > 1e-9) {
        result[result.length - 1] += remaining;
      }
      return result;
    }

    final shares = GeometryMath.distribute(
      math.max(remaining, 0),
      flexible.map((i) => ratios[i] <= 0 ? 1.0 : ratios[i]).toList(),
    );
    for (var k = 0; k < flexible.length; k++) {
      result[flexible[k]] = shares[k];
    }
    return result;
  }
}

class _LayoutResult {
  final List<SolvedCell> cells;
  final List<SolvedBar> bars;
  const _LayoutResult(this.cells, this.bars);
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);
