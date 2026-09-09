import 'dart:math' as math;

import '../../../core/utilities/geometry_math.dart';
import '../../../shared/models/materials.dart';
import '../../../shared/models/opening_model.dart';
import '../../geometry/region_solver.dart';
import '../../../shared/models/scene_3d.dart';

/// Turns the parametric model into an explicit 3D assembly.
///
/// This runs in Dart, not in the renderer, for three reasons: the placement
/// rules are the same ones the technical drawing uses, the result is a plain
/// data structure that can be asserted in tests, and the JavaScript side is
/// reduced to "make a box of this size at this position" — it cannot invent
/// geometry of its own (§51, §64).
class SceneBuilder {
  /// Height of a door handle above the bottom of the frame, in millimetres.
  static const double doorHandleHeightMm = 1050;

  static const double hingeRadiusMm = 9;
  static const double hingeLengthMm = 95;
  static const double beadDepthMm = 12;

  const SceneBuilder();

  Scene3D build(OpeningModel model, {RenderStyle style = RenderStyle.realistic}) {
    final solved = RegionSolver.solve(model);
    final parts = <ScenePart>[];
    final materials = <String, SceneMaterial>{};

    final frameDepth = model.frameDepthMm;
    final frameFace = model.frameFaceMm;
    final w = model.widthMm;
    final h = model.heightMm;

    materials['frame'] = _frameMaterial(model);
    materials['bead'] = _beadMaterial(model);
    materials['hardware'] = const SceneMaterial(
      key: 'hardware',
      color: 0xB6BCC2,
      roughness: 0.28,
      metalness: 0.92,
    );

    // ---- outer frame ------------------------------------------------------
    parts.add(_box(
      id: 'frame.head',
      role: PartRole.frameHead,
      sizeMm: Vec3(w, frameFace, frameDepth),
      centre: _toScene(model, Vec2(w / 2, frameFace / 2), 0),
      materialKey: 'frame',
    ));
    parts.add(_box(
      id: 'frame.sill',
      role: PartRole.frameSill,
      sizeMm: Vec3(w, frameFace, frameDepth),
      centre: _toScene(model, Vec2(w / 2, h - frameFace / 2), 0),
      materialKey: 'frame',
    ));
    final jambHeight = h - 2 * frameFace;
    parts.add(_box(
      id: 'frame.jamb.left',
      role: PartRole.frameJambLeft,
      sizeMm: Vec3(frameFace, jambHeight, frameDepth),
      centre: _toScene(model, Vec2(frameFace / 2, h / 2), 0),
      materialKey: 'frame',
    ));
    parts.add(_box(
      id: 'frame.jamb.right',
      role: PartRole.frameJambRight,
      sizeMm: Vec3(frameFace, jambHeight, frameDepth),
      centre: _toScene(model, Vec2(w - frameFace / 2, h / 2), 0),
      materialKey: 'frame',
    ));

    // ---- mullions and transoms -------------------------------------------
    for (final bar in solved.allBars) {
      parts.add(_box(
        id: 'bar.${bar.id}',
        role: bar.vertical ? PartRole.mullion : PartRole.transom,
        sizeMm: Vec3(bar.rect.width, bar.rect.height, frameDepth - 4),
        centre: _toScene(model, bar.rect.center, 0),
        materialKey: 'frame',
      ));
    }

    // ---- leaves -----------------------------------------------------------
    for (final cell in solved.leaves) {
      _buildCell(model, cell, parts, materials);
    }
    // Sashes exist on parent cells too (a divided door leaf still has a leaf
    // frame around its sub-sections).
    for (final cell in solved.allRegions.where((c) => !c.isLeaf && c.hasSash)) {
      _buildSashFrame(model, cell, parts);
      _buildHardware(model, cell, parts);
    }

    // ---- threshold and sill ----------------------------------------------
    if (model.hasThreshold) {
      materials['threshold'] = SceneMaterial(
        key: 'threshold',
        color: 0x9AA0A6,
        roughness: 0.4,
        metalness: 0.8,
      );
      parts.add(_box(
        id: 'threshold',
        role: PartRole.threshold,
        sizeMm: Vec3(w, 22, frameDepth + 16),
        centre: _toScene(model, Vec2(w / 2, h + 11), 0),
        materialKey: 'threshold',
      ));
    }
    if (model.hasSill) {
      materials['sill'] = const SceneMaterial(
        key: 'sill',
        color: 0xD8D5CE,
        roughness: 0.62,
        metalness: 0.15,
      );
      final sillDepth = frameDepth + model.sillProjectionMm;
      parts.add(_box(
        id: 'sill',
        role: PartRole.windowSill,
        sizeMm: Vec3(w + 120, 32, sillDepth),
        centre: Vec3(0, -h / 2 - 16, (sillDepth - frameDepth) / 2),
        materialKey: 'sill',
      ));
    }

    return Scene3D(
      modelId: model.id,
      widthMm: w,
      heightMm: h,
      depthMm: frameDepth,
      parts: parts,
      materials: materials,
      dimensions: _dimensions(model),
      style: style,
    );
  }

  // -------------------------------------------------------------------------

  void _buildCell(
    OpeningModel model,
    SolvedRegion cell,
    List<ScenePart> parts,
    Map<String, SceneMaterial> materials,
  ) {
    if (cell.hasSash) {
      _buildSashFrame(model, cell, parts);
      _buildHardware(model, cell, parts);
    }

    final zOffset = _sashZOffset(model, cell);
    final rect = cell.glazingRect;
    if (rect.width <= 0 || rect.height <= 0) return;

    switch (cell.spec.infill) {
      case CellInfill.glass:
        final key = 'glass.${cell.spec.glass.name}';
        materials.putIfAbsent(key, () => _glassMaterial(cell.spec.glass));
        parts.add(_box(
          id: 'glass.${cell.id}',
          role: PartRole.glass,
          sizeMm: Vec3(rect.width, rect.height, cell.spec.infillThicknessMm),
          centre: _toScene(model, rect.center, zOffset),
          materialKey: key,
          cellPath: cell.id,
        ));
        _buildBeads(model, cell, parts, zOffset);
      case CellInfill.panel:
        final key = 'panel.${cell.spec.panel.name}';
        materials.putIfAbsent(key, () => _panelMaterial(model, cell.spec.panel));
        parts.add(_box(
          id: 'panel.${cell.id}',
          role: PartRole.panel,
          sizeMm: Vec3(rect.width, rect.height, cell.spec.infillThicknessMm),
          centre: _toScene(model, rect.center, zOffset),
          materialKey: key,
          cellPath: cell.id,
        ));
        _buildBeads(model, cell, parts, zOffset);
      case CellInfill.louvre:
        final key = 'panel.${cell.spec.panel.name}';
        materials.putIfAbsent(key, () => _panelMaterial(model, cell.spec.panel));
        final bladeHeight = 60.0;
        final count = math.max(2, (rect.height / bladeHeight).floor());
        final spacing = rect.height / count;
        for (var i = 0; i < count; i++) {
          final y = rect.top + spacing * (i + 0.5);
          parts.add(_box(
            id: 'louvre.${cell.id}.$i',
            role: PartRole.louvreBlade,
            sizeMm: Vec3(rect.width, spacing * 0.8, 14),
            centre: _toScene(model, Vec2(rect.center.x, y), zOffset),
            rotationDeg: const Vec3(-22, 0, 0),
            materialKey: key,
            cellPath: cell.id,
          ));
        }
      case CellInfill.mesh:
        materials.putIfAbsent(
          'mesh',
          () => const SceneMaterial(
            key: 'mesh',
            color: 0x3A3F42,
            roughness: 0.9,
            opacity: 0.55,
          ),
        );
        parts.add(_box(
          id: 'mesh.${cell.id}',
          role: PartRole.mesh,
          sizeMm: Vec3(rect.width, rect.height, 2),
          centre: _toScene(model, rect.center, zOffset + model.frameDepthMm / 2 - 6),
          materialKey: 'mesh',
          cellPath: cell.id,
        ));
      case CellInfill.open:
        break;
    }

    if (cell.spec.hasMesh && cell.spec.infill != CellInfill.mesh) {
      materials.putIfAbsent(
        'mesh',
        () => const SceneMaterial(
          key: 'mesh',
          color: 0x3A3F42,
          roughness: 0.9,
          opacity: 0.55,
        ),
      );
      parts.add(_box(
        id: 'mesh.${cell.id}.add',
        role: PartRole.mesh,
        sizeMm: Vec3(cell.aperture.width, cell.aperture.height, 2),
        centre: _toScene(model, cell.aperture.center, -model.frameDepthMm / 2 + 4),
        materialKey: 'mesh',
        cellPath: cell.id,
      ));
    }
  }

  /// Four sash members — two stiles and two rails — exactly like the real
  /// profile, never a single slab.
  void _buildSashFrame(OpeningModel model, SolvedRegion cell, List<ScenePart> parts) {
    final face = model.sashFaceMm;
    final depth = model.sashDepthMm;
    final rect = cell.sashRect;
    final z = _sashZOffset(model, cell);

    parts.add(_box(
      id: 'sash.${cell.id}.top',
      role: PartRole.sashRail,
      sizeMm: Vec3(rect.width, face, depth),
      centre: _toScene(model, Vec2(rect.center.x, rect.top + face / 2), z),
      materialKey: 'frame',
      cellPath: cell.id,
    ));
    parts.add(_box(
      id: 'sash.${cell.id}.bottom',
      role: PartRole.sashRail,
      sizeMm: Vec3(rect.width, face, depth),
      centre: _toScene(model, Vec2(rect.center.x, rect.bottom - face / 2), z),
      materialKey: 'frame',
      cellPath: cell.id,
    ));
    final stileHeight = math.max(rect.height - 2 * face, 1.0);
    parts.add(_box(
      id: 'sash.${cell.id}.left',
      role: PartRole.sashStile,
      sizeMm: Vec3(face, stileHeight, depth),
      centre: _toScene(model, Vec2(rect.left + face / 2, rect.center.y), z),
      materialKey: 'frame',
      cellPath: cell.id,
    ));
    parts.add(_box(
      id: 'sash.${cell.id}.right',
      role: PartRole.sashStile,
      sizeMm: Vec3(face, stileHeight, depth),
      centre: _toScene(model, Vec2(rect.right - face / 2, rect.center.y), z),
      materialKey: 'frame',
      cellPath: cell.id,
    ));
  }

  void _buildBeads(OpeningModel model, SolvedRegion cell, List<ScenePart> parts, double z) {
    final rect = cell.glazingRect;
    final bead = model.glazingBeadMm;
    final zBead = z + model.frameDepthMm / 2 - beadDepthMm / 2 - 4;
    final horizontalWidth = rect.width + 2 * bead;

    parts
      ..add(_box(
        id: 'bead.${cell.id}.top',
        role: PartRole.glazingBead,
        sizeMm: Vec3(horizontalWidth, bead, beadDepthMm),
        centre: _toScene(model, Vec2(rect.center.x, rect.top - bead / 2), zBead),
        materialKey: 'bead',
        cellPath: cell.id,
      ))
      ..add(_box(
        id: 'bead.${cell.id}.bottom',
        role: PartRole.glazingBead,
        sizeMm: Vec3(horizontalWidth, bead, beadDepthMm),
        centre: _toScene(model, Vec2(rect.center.x, rect.bottom + bead / 2), zBead),
        materialKey: 'bead',
        cellPath: cell.id,
      ))
      ..add(_box(
        id: 'bead.${cell.id}.left',
        role: PartRole.glazingBead,
        sizeMm: Vec3(bead, rect.height, beadDepthMm),
        centre: _toScene(model, Vec2(rect.left - bead / 2, rect.center.y), zBead),
        materialKey: 'bead',
        cellPath: cell.id,
      ))
      ..add(_box(
        id: 'bead.${cell.id}.right',
        role: PartRole.glazingBead,
        sizeMm: Vec3(bead, rect.height, beadDepthMm),
        centre: _toScene(model, Vec2(rect.right + bead / 2, rect.center.y), zBead),
        materialKey: 'bead',
        cellPath: cell.id,
      ));
  }

  void _buildHardware(OpeningModel model, SolvedRegion cell, List<ScenePart> parts) {
    final operation = cell.spec.operation;
    if (!operation.isOperable) return;

    final rect = cell.sashRect;
    final z = _sashZOffset(model, cell);
    final frameDepth = model.frameDepthMm;
    final hingeSide = operation.hingeSide;

    // Hinges — count follows leaf height, the way a fabricator specifies them.
    if (!operation.isSliding && hingeSide != HingeSide.none) {
      final count = hingeCountFor(rect.height, isDoor: operation.isDoorLeaf);
      final vertical = hingeSide == HingeSide.left || hingeSide == HingeSide.right;
      final span = vertical ? rect.height : rect.width;
      final inset = math.min(span * 0.12, 220.0);
      final usable = span - 2 * inset;

      for (var i = 0; i < count; i++) {
        final t = count == 1 ? 0.5 : i / (count - 1);
        final along = inset + usable * t;
        final Vec2 position;
        final Vec3 rotation;
        switch (hingeSide) {
          case HingeSide.left:
            position = Vec2(rect.left, rect.top + along);
            rotation = Vec3.zero;
          case HingeSide.right:
            position = Vec2(rect.right, rect.top + along);
            rotation = Vec3.zero;
          case HingeSide.top:
            position = Vec2(rect.left + along, rect.top);
            rotation = const Vec3(0, 0, 90);
          case HingeSide.bottom:
            position = Vec2(rect.left + along, rect.bottom);
            rotation = const Vec3(0, 0, 90);
          case HingeSide.none:
            continue;
        }
        final zHinge = cell.spec.swing == SwingDirection.outward
            ? frameDepth / 2 - hingeRadiusMm
            : -frameDepth / 2 + hingeRadiusMm;
        parts.add(ScenePart(
          id: 'hinge.${cell.id}.$i',
          role: PartRole.hinge,
          shape: PartShape.cylinder,
          size: Vec3(hingeRadiusMm, hingeLengthMm, hingeRadiusMm),
          center: _toScene(model, position, zHinge),
          rotationDeg: rotation,
          materialKey: 'hardware',
          cellPath: cell.id,
        ));
      }
    }

    if (cell.spec.handle == HandleStyle.none) return;

    // Handle sits opposite the hinges, at working height.
    // A height the user asked for wins over the convention.
    final requested = cell.spec.handleHeightMm;
    final handleY = requested != null
        ? model.heightMm - requested
        : (operation.isDoorLeaf
            ? math.min(model.heightMm - doorHandleHeightMm, rect.bottom - 120)
            : rect.center.y);
    final onLeft = hingeSide == HingeSide.right;
    final handleX = operation.isSliding
        ? (operation == CellOperation.slidingLeft ? rect.right - 60 : rect.left + 60)
        : (onLeft ? rect.left + 60 : rect.right - 60);
    final zHandle = z - frameDepth / 2 - 14;

    parts.add(ScenePart(
      id: 'handle.${cell.id}.rose',
      role: PartRole.handleRose,
      shape: PartShape.cylinder,
      size: const Vec3(26, 14, 26),
      center: _toScene(model, Vec2(handleX, handleY), zHandle),
      rotationDeg: const Vec3(90, 0, 0),
      materialKey: 'hardware',
      cellPath: cell.id,
    ));

    switch (cell.spec.handle) {
      case HandleStyle.lever:
        final direction = onLeft ? 1.0 : -1.0;
        parts.add(_box(
          id: 'handle.${cell.id}.lever',
          role: PartRole.handle,
          sizeMm: const Vec3(120, 20, 20),
          centre: _toScene(model, Vec2(handleX + direction * 60, handleY), zHandle - 12),
          materialKey: 'hardware',
          cellPath: cell.id,
        ));
      case HandleStyle.pullBar:
        parts.add(_box(
          id: 'handle.${cell.id}.bar',
          role: PartRole.handle,
          sizeMm: Vec3(28, math.min(rect.height * 0.55, 900), 28),
          centre: _toScene(model, Vec2(handleX, rect.center.y), zHandle - 14),
          materialKey: 'hardware',
          cellPath: cell.id,
        ));
      case HandleStyle.knob:
        parts.add(ScenePart(
          id: 'handle.${cell.id}.knob',
          role: PartRole.handle,
          shape: PartShape.cylinder,
          size: const Vec3(28, 46, 28),
          center: _toScene(model, Vec2(handleX, handleY), zHandle - 24),
          rotationDeg: const Vec3(90, 0, 0),
          materialKey: 'hardware',
          cellPath: cell.id,
        ));
      case HandleStyle.cremone:
        parts.add(_box(
          id: 'handle.${cell.id}.cremone',
          role: PartRole.handle,
          sizeMm: Vec3(22, rect.height - 2 * model.sashFaceMm, 22),
          centre: _toScene(model, Vec2(handleX, rect.center.y), zHandle - 10),
          materialKey: 'hardware',
          cellPath: cell.id,
        ));
      case HandleStyle.none:
        break;
    }

    if (cell.spec.hasLock) {
      parts.add(ScenePart(
        id: 'lock.${cell.id}',
        role: PartRole.lockCylinder,
        shape: PartShape.cylinder,
        size: const Vec3(14, 22, 14),
        center: _toScene(model, Vec2(handleX, handleY + 120), zHandle + 4),
        rotationDeg: const Vec3(90, 0, 0),
        materialKey: 'hardware',
        cellPath: cell.id,
      ));
    }
  }

  /// Number of hinges a leaf of this height needs.
  static int hingeCountFor(double leafHeightMm, {bool isDoor = false}) =>
      hingeCountForLeaf(leafHeightMm, isDoor: isDoor);

  /// Where a leaf sits through the depth of the frame. Outward-opening leaves
  /// sit towards the outside, inward-opening ones towards the inside, and
  /// sliding leaves sit in separate tracks so they visibly overlap.
  double _sashZOffset(OpeningModel model, SolvedRegion cell) {
    final operation = cell.spec.operation;
    if (!operation.isOperable) return 0;
    final frameDepth = model.frameDepthMm;
    final sashDepth = model.sashDepthMm;
    final travel = (frameDepth - sashDepth) / 2;
    if (operation.isSliding) {
      return operation == CellOperation.slidingLeft ? travel : -travel;
    }
    return cell.spec.swing == SwingDirection.outward ? travel : -travel;
  }

  List<SceneDimension> _dimensions(OpeningModel model) {
    final halfW = model.widthMm / 2;
    final halfH = model.heightMm / 2;
    final z = model.frameDepthMm / 2 + 120;
    return [
      SceneDimension(
        label: '${model.widthMm.round()} mm',
        from: Vec3(-halfW, -halfH - 90, z),
        to: Vec3(halfW, -halfH - 90, z),
      ),
      SceneDimension(
        label: '${model.heightMm.round()} mm',
        from: Vec3(halfW + 90, -halfH, z),
        to: Vec3(halfW + 90, halfH, z),
      ),
      SceneDimension(
        label: '${model.frameDepthMm.round()} mm deep',
        from: Vec3(-halfW - 90, halfH, -model.frameDepthMm / 2),
        to: Vec3(-halfW - 90, halfH, model.frameDepthMm / 2),
      ),
    ];
  }

  ScenePart _box({
    required String id,
    required PartRole role,
    required Vec3 sizeMm,
    required Vec3 centre,
    required String materialKey,
    Vec3 rotationDeg = Vec3.zero,
    String? cellPath,
  }) =>
      ScenePart(
        id: id,
        role: role,
        shape: PartShape.box,
        size: sizeMm,
        center: centre,
        rotationDeg: rotationDeg,
        materialKey: materialKey,
        cellPath: cellPath,
      );

  /// Elevation coordinates (origin top-left, y down) to scene coordinates
  /// (origin centre, y up).
  Vec3 _toScene(OpeningModel model, Vec2 point, double z) =>
      Vec3(point.x - model.widthMm / 2, model.heightMm / 2 - point.y, z);

  SceneMaterial _frameMaterial(OpeningModel model) => SceneMaterial(
        key: 'frame',
        color: model.finish.colorValue,
        roughness: (model.material.roughness + model.finish.roughnessBias).clamp(0.05, 1).toDouble(),
        metalness: model.material.metalness,
        clearcoat: model.material == FrameMaterial.wood ? 0.25 : 0.0,
      );

  SceneMaterial _beadMaterial(OpeningModel model) => SceneMaterial(
        key: 'bead',
        color: _darken(model.finish.colorValue, 0.12),
        roughness: (model.material.roughness + 0.08).clamp(0.05, 1).toDouble(),
        metalness: model.material.metalness,
      );

  SceneMaterial _glassMaterial(GlassType glass) => SceneMaterial(
        key: 'glass.${glass.name}',
        color: glass.tintColor,
        roughness: glass.roughness,
        metalness: 0,
        opacity: glass.renderOpacity,
        transmission: glass.transmission,
        clearcoat: glass.reflectivity,
      );

  SceneMaterial _panelMaterial(OpeningModel model, PanelMaterial panel) => SceneMaterial(
        key: 'panel.${panel.name}',
        color: switch (panel) {
          PanelMaterial.sandwichPanel => model.finish.colorValue,
          PanelMaterial.aluminiumSheet => model.finish.colorValue,
          PanelMaterial.mdf => 0xE3DCD1,
          PanelMaterial.solidWood => 0x8A5A2B,
          PanelMaterial.louvre => model.finish.colorValue,
        },
        roughness: panel == PanelMaterial.aluminiumSheet ? 0.4 : 0.72,
        metalness: panel == PanelMaterial.aluminiumSheet ? 0.8 : 0.05,
      );

  int _darken(int color, double amount) {
    final r = ((color >> 16) & 0xFF) * (1 - amount);
    final g = ((color >> 8) & 0xFF) * (1 - amount);
    final b = (color & 0xFF) * (1 - amount);
    return (r.round() << 16) | (g.round() << 8) | b.round();
  }
}
