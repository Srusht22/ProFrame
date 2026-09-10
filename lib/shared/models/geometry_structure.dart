import '../../core/utilities/geometry_math.dart';
import 'opening_model.dart';
import 'primitives.dart';

/// One aperture as found in the *drawing*, still in sketch coordinates.
class StructureCell {
  final Box2 box;
  final int rowIndex;
  final int columnIndex;
  final CellOperation operation;
  final double confidence;

  /// Plain-English reason the recogniser reached this reading, shown to the
  /// user on the interpretation screen instead of an opaque result.
  final String evidence;

  const StructureCell({
    required this.box,
    required this.rowIndex,
    required this.columnIndex,
    this.operation = CellOperation.fixed,
    this.confidence = 1.0,
    this.evidence = 'No opening marks found — read as a fixed section.',
  });

  StructureCell copyWith({
    CellOperation? operation,
    double? confidence,
    String? evidence,
  }) =>
      StructureCell(
        box: box,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        operation: operation ?? this.operation,
        confidence: confidence ?? this.confidence,
        evidence: evidence ?? this.evidence,
      );
}

/// A horizontal band of the drawing, with the vertical divisions found inside
/// it. Mullions are tracked per band because a sketch very often has a full
/// width transom light on top and divisions only in the band below.
class StructureRow {
  final Box2 box;
  final List<double> mullionXs;
  final List<StructureCell> cells;

  const StructureRow({
    required this.box,
    required this.mullionXs,
    required this.cells,
  });
}

/// The drawing understood as a grid — the last stage that still lives in
/// sketch coordinates. [GeometryBuilder] converts it to millimetres.
class GeometryStructure {
  final Box2 outline;
  final List<double> transomYs;
  final List<StructureRow> rows;
  final List<DimensionPrimitive> dimensions;
  final List<NotePrimitive> notes;

  /// True when no closed outline was drawn and the overall extent of the
  /// drawing was used instead. Always surfaced to the user — an assumed
  /// outline is never presented as if it had been drawn.
  final bool outlineFromExtent;

  const GeometryStructure({
    required this.outline,
    required this.transomYs,
    required this.rows,
    this.dimensions = const [],
    this.notes = const [],
    this.outlineFromExtent = false,
  });

  static const GeometryStructure empty = GeometryStructure(
    outline: Box2(0, 0, 0, 0),
    transomYs: [],
    rows: [],
  );

  bool get isEmpty => outline.width <= 0 || outline.height <= 0 || rows.isEmpty;

  List<StructureCell> get allCells =>
      rows.expand((r) => r.cells).toList(growable: false);

  int get cellCount => allCells.length;

  int get mullionCount => rows.fold<int>(0, (sum, r) => sum + r.mullionXs.length);

  /// Proportion of the drawn outline — used to sanity-check inferred sizes and
  /// to keep the generated model faithful to what was drawn.
  double get aspectRatio => outline.height == 0 ? 1 : outline.width / outline.height;
}
