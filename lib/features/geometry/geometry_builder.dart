import '../../core/utilities/geometry_math.dart';
import '../../shared/models/design_region.dart';
import '../../shared/models/geometry_structure.dart';
import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';
import '../dimensions/dimension_resolver.dart';
import 'region_builder.dart';

/// Converts the drawing-space structure into the parametric product.
///
/// Proportions come straight from the sketch — a section drawn twice as wide as
/// its neighbour stays twice as wide, and the bands the user drew keep their
/// relative heights. Absolute size comes from the resolved dimensions. Nothing
/// is equalised or centred on the way through: if the drawing is lopsided, so
/// is the product.
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
    final width = dimensions.width.millimetres;
    final height = dimensions.height.millimetres;
    final outline = structure.outline;

    final rows = <GridRowSpec>[];
    for (final row in structure.rows) {
      final heightShare =
          outline.height <= 0 ? 1.0 : row.box.height / outline.height;
      rows.add(GridRowSpec(
        share: heightShare <= 0 ? 1 : heightShare,
        cells: row.cells.map((cell) {
          final widthShare =
              row.box.width <= 0 ? 1.0 : cell.box.width / row.box.width;
          return GridCellSpec(
            share: widthShare <= 0 ? 1 : widthShare,
            operation: cell.operation,
            infill: CellInfill.glass,
            glass: glass,
            swing: _defaultSwing(cell.operation),
            handle: _defaultHandle(cell.operation),
          );
        }).toList(),
      ));
    }

    if (rows.isEmpty) {
      rows.add(const GridRowSpec(cells: [GridCellSpec()]));
    }

    final regions = RegionBuilder.fromGrid(
      rows,
      Box2.fromLTWH(0, 0, width, height),
    );

    return OpeningModel(
      id: id,
      kind: kind,
      widthMm: width,
      heightMm: height,
      material: material,
      finish: finish,
      regions: _assignLock(regions),
      hasThreshold: kind == OpeningKind.door,
      hasSill: kind == OpeningKind.window,
    );
  }

  SwingDirection _defaultSwing(CellOperation operation) {
    if (!operation.isOperable || operation.isSliding) return SwingDirection.none;
    // Doors are normally hung to open into the room; casement windows open out.
    return operation.isDoorLeaf ? SwingDirection.inward : SwingDirection.outward;
  }

  HandleStyle _defaultHandle(CellOperation operation) {
    if (!operation.isOperable) return HandleStyle.none;
    if (operation.isSliding) return HandleStyle.pullBar;
    return HandleStyle.lever;
  }

  /// Puts the lock on the active leaf — the widest door leaf, and the
  /// right-hand one when two are equal, which is the usual convention.
  List<DesignRegion> _assignLock(List<DesignRegion> regions) {
    String? bestId;
    var bestWidth = -1.0;
    var bestLeft = -1.0;
    for (final region in RegionTree.all(regions)) {
      if (!region.operation.isDoorLeaf) continue;
      final width = region.rect.width;
      if (width > bestWidth || (width == bestWidth && region.rect.left > bestLeft)) {
        bestWidth = width;
        bestLeft = region.rect.left;
        bestId = region.id;
      }
    }
    if (bestId == null) return regions;
    return RegionTree.replace(regions, bestId, (r) => r.copyWith(hasLock: true));
  }
}
