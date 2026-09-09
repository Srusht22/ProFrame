import '../../shared/models/geometry_structure.dart';
import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';
import '../dimensions/dimension_resolver.dart';

/// Converts the drawing-space structure into the parametric product.
///
/// Proportions come straight from the sketch — a section drawn twice as wide
/// as its neighbour stays twice as wide — while the absolute size comes from
/// the resolved dimensions. That is what makes the generated product look like
/// what was drawn instead of a generic template (§17, §51).
class GeometryBuilder {
  const GeometryBuilder();

  OpeningModel build({
    required GeometryStructure structure,
    required DimensionResolution dimensions,
    required OpeningKind kind,
    String id = 'model',
    FrameMaterial material = FrameMaterial.aluminium,
    FrameFinish finish = FrameFinish.naturalAnodised,
    GlassType glass = GlassType.clearDouble,
  }) {
    final outline = structure.outline;
    final rows = <LayoutRow>[];

    final doorLeafCells = <String>[];

    for (var ri = 0; ri < structure.rows.length; ri++) {
      final row = structure.rows[ri];
      final heightRatio = outline.height <= 0 ? 1.0 : row.box.height / outline.height;

      final cells = <LayoutCell>[];
      for (var ci = 0; ci < row.cells.length; ci++) {
        final cell = row.cells[ci];
        final widthRatio = row.box.width <= 0 ? 1.0 : cell.box.width / row.box.width;
        final operation = cell.operation;
        final cellId = 'r$ri.c$ci';
        if (operation.isDoorLeaf) doorLeafCells.add(cellId);

        cells.add(LayoutCell(
          id: cellId,
          widthRatio: widthRatio <= 0 ? 1 : widthRatio,
          operation: operation,
          infill: CellInfill.glass,
          glass: glass,
          swing: _defaultSwing(operation),
          handle: _defaultHandle(operation),
          hasLock: false,
        ));
      }

      rows.add(LayoutRow(
        id: 'r$ri',
        heightRatio: heightRatio <= 0 ? 1 : heightRatio,
        cells: cells,
      ));
    }

    var layout = OpeningLayout(
      rows: rows.isEmpty
          ? [
              LayoutRow(id: 'r0', cells: [
                LayoutCell(id: 'r0.c0', operation: CellOperation.fixed, glass: glass),
              ])
            ]
          : rows,
    );

    layout = _assignLock(layout);

    return OpeningModel(
      id: id,
      kind: kind,
      widthMm: dimensions.width.millimetres,
      heightMm: dimensions.height.millimetres,
      material: material,
      finish: finish,
      layout: layout,
      hasThreshold: kind == OpeningKind.door,
      hasSill: kind == OpeningKind.window,
    );
  }

  SwingDirection _defaultSwing(CellOperation operation) {
    if (!operation.isOperable) return SwingDirection.none;
    if (operation.isSliding) return SwingDirection.none;
    // Doors are normally hung to open into the room; casement windows open out.
    return operation.isDoorLeaf ? SwingDirection.inward : SwingDirection.outward;
  }

  HandleStyle _defaultHandle(CellOperation operation) {
    if (!operation.isOperable) return HandleStyle.none;
    if (operation.isDoorLeaf) return HandleStyle.lever;
    if (operation.isSliding) return HandleStyle.pullBar;
    return HandleStyle.lever;
  }

  /// Puts the lock on the active leaf — the widest door leaf, and the
  /// right-hand one when two leaves are equal, which is the usual convention.
  OpeningLayout _assignLock(OpeningLayout layout) {
    String? bestId;
    var bestWidth = -1.0;
    for (final row in layout.rows) {
      for (final cell in row.cells) {
        if (!cell.operation.isDoorLeaf) continue;
        if (cell.widthRatio >= bestWidth) {
          bestWidth = cell.widthRatio;
          bestId = cell.id;
        }
      }
    }
    if (bestId == null) return layout;

    return OpeningLayout(
      rows: layout.rows
          .map((row) => row.copyWith(
                cells: row.cells
                    .map((c) => c.id == bestId ? c.copyWith(hasLock: true) : c)
                    .toList(),
              ))
          .toList(),
    );
  }
}
