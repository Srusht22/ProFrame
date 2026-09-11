import '../../core/utilities/geometry_math.dart';
import '../../shared/models/design_region.dart';
import '../../shared/models/geometry_structure.dart';
import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';
import '../dimensions/dimension_resolver.dart';

/// Converts the sections read from the drawing into the parametric product.
///
/// This is a straight, proportional mapping: the drawing's outline becomes the
/// product's outline, and every section keeps exactly its position and size
/// relative to that outline. A section drawn at a third of the way across stays
/// at a third of the way across. Nothing is squared up, equalised or nudged
/// towards a tidier arrangement.
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

    final scaleX = outline.width <= 0 ? 1.0 : width / outline.width;
    final scaleY = outline.height <= 0 ? 1.0 : height / outline.height;

    Box2 toProduct(Box2 box) => Box2(
          (box.left - outline.left) * scaleX,
          (box.top - outline.top) * scaleY,
          (box.right - outline.left) * scaleX,
          (box.bottom - outline.top) * scaleY,
        );

    final regions = <DesignRegion>[
      for (final section in structure.sections)
        DesignRegion(
          id: section.id,
          rect: toProduct(section.box),
          operation: section.operation,
          infill: CellInfill.glass,
          glass: glass,
          swing: _defaultSwing(section.operation),
          handle: _defaultHandle(section.operation),
        ),
    ];

    return OpeningModel(
      id: id,
      kind: kind,
      widthMm: width,
      heightMm: height,
      material: material,
      finish: finish,
      regions: _assignLock(
        regions.isEmpty
            ? [DesignRegion(id: 's0', rect: Box2.fromLTWH(0, 0, width, height))]
            : regions,
      ),
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
