import '../../core/utilities/geometry_math.dart';
import '../../shared/models/design_region.dart';
import '../../shared/models/materials.dart';
import '../../shared/models/opening_enums.dart';

/// One section of a row, described by proportion or by an exact size.
class GridCellSpec {
  final double share;
  final double? fixedMm;
  final CellOperation operation;
  final CellInfill infill;
  final GlassType glass;
  final PanelMaterial panel;
  final SwingDirection swing;
  final HandleStyle handle;
  final bool hasLock;
  final String? label;

  /// Panes inside this section — a leaf with glass over a panel.
  final List<GridRowSpec>? sub;

  const GridCellSpec({
    this.share = 1,
    this.fixedMm,
    this.operation = CellOperation.fixed,
    this.infill = CellInfill.glass,
    this.glass = GlassType.clearDouble,
    this.panel = PanelMaterial.sandwichPanel,
    this.swing = SwingDirection.none,
    this.handle = HandleStyle.none,
    this.hasLock = false,
    this.label,
    this.sub,
  });
}

class GridRowSpec {
  final double share;
  final double? fixedMm;
  final List<GridCellSpec> cells;

  const GridRowSpec({this.share = 1, this.fixedMm, required this.cells});
}

/// Builds free-form sections from a simple row-and-column description.
///
/// This is a *convenience for producing* a regular arrangement — a sketch that
/// really is a grid, or a template. What comes out is ordinary free-form
/// sections with exact millimetre rectangles, so the moment the user drags one
/// boundary or drops an opening into a corner the design stops being a grid and
/// nothing has to be rebuilt.
class RegionBuilder {
  RegionBuilder._();

  static List<DesignRegion> fromGrid(
    List<GridRowSpec> rows,
    Box2 container, {
    String prefix = 's',
  }) {
    if (rows.isEmpty || container.isEmpty) return const [];

    final heights = GeometryMath.distributeWithFixed(
      total: container.height,
      fixed: rows.map((r) => r.fixedMm).toList(),
      shares: rows.map((r) => r.share).toList(),
    );

    final regions = <DesignRegion>[];
    var y = container.top;
    for (var ri = 0; ri < rows.length; ri++) {
      final row = rows[ri];
      final rowHeight = heights[ri];
      final widths = GeometryMath.distributeWithFixed(
        total: container.width,
        fixed: row.cells.map((c) => c.fixedMm).toList(),
        shares: row.cells.map((c) => c.share).toList(),
      );

      var x = container.left;
      for (var ci = 0; ci < row.cells.length; ci++) {
        final cell = row.cells[ci];
        final rect = Box2.fromLTWH(x, y, widths[ci], rowHeight);
        final id = '$prefix${ri}_$ci';
        regions.add(DesignRegion(
          id: id,
          rect: rect,
          label: cell.label,
          operation: cell.operation,
          infill: cell.infill,
          glass: cell.glass,
          panel: cell.panel,
          swing: cell.swing,
          handle: cell.handle,
          hasLock: cell.hasLock,
          children:
              cell.sub == null ? const [] : fromGrid(cell.sub!, rect, prefix: '$id.p'),
        ));
        x += widths[ci];
      }
      y += rowHeight;
    }
    return regions;
  }
}
