import 'dart:math' as math;

import '../../core/utilities/geometry_math.dart';
import '../../shared/models/design_region.dart';
import '../../shared/models/materials.dart';
import '../../shared/models/opening_model.dart';

/// What should happen to the sections when the overall size changes.
enum ResizeMode {
  /// Sections keep their share of the product, so the design keeps its shape.
  scaleSections,

  /// Sections keep their millimetres; the validator reports whatever no longer
  /// fits rather than anything being quietly adjusted.
  keepSections,
}

/// Every structured edit to the design.
///
/// The rule these operations follow: **do exactly what was asked and nothing
/// else.** Sections are not equalised, centred, squared up or rounded. When an
/// edit cannot be carried out exactly — a section would end up too small to
/// build — it is clamped at the limit and the caller is told, rather than the
/// design being silently rearranged.
class RegionEditor {
  RegionEditor._();

  /// The narrowest section that can still be fabricated, in millimetres.
  /// A drag stops here rather than collapsing a section to nothing.
  static const double minSectionMm = 120;

  static const double _tolerance = 0.51;

  // -- whole product --------------------------------------------------------

  static OpeningModel setOverallSize(
    OpeningModel model, {
    double? widthMm,
    double? heightMm,
    ResizeMode mode = ResizeMode.scaleSections,
  }) {
    final width = (widthMm != null && widthMm > 0) ? widthMm : model.widthMm;
    final height = (heightMm != null && heightMm > 0) ? heightMm : model.heightMm;
    if (width == model.widthMm && height == model.heightMm) return model;

    if (mode == ResizeMode.keepSections) {
      return model.copyWith(widthMm: width, heightMm: height);
    }

    final scaleX = model.widthMm == 0 ? 1.0 : width / model.widthMm;
    final scaleY = model.heightMm == 0 ? 1.0 : height / model.heightMm;
    return model.copyWith(
      widthMm: width,
      heightMm: height,
      regions: _scaleAll(model.regions, scaleX, scaleY),
    );
  }

  static List<DesignRegion> _scaleAll(
    List<DesignRegion> regions,
    double scaleX,
    double scaleY,
  ) =>
      regions
          .map((region) => region.copyWith(
                rect: Box2(
                  region.rect.left * scaleX,
                  region.rect.top * scaleY,
                  region.rect.right * scaleX,
                  region.rect.bottom * scaleY,
                ),
                children: _scaleAll(region.children, scaleX, scaleY),
              ))
          .toList();

  // -- exact edits ----------------------------------------------------------

  /// Places a section at exactly this rectangle. Used by the numeric editor
  /// and by instructions that name a position.
  static OpeningModel setRect(OpeningModel model, String id, Box2 rect) =>
      model.copyWith(
        regions: RegionTree.replace(
          model.regions,
          id,
          (region) => region.copyWith(
            rect: rect,
            children: _fitChildren(region.children, region.rect, rect),
          ),
        ),
      );

  /// Sets a section's width, moving the boundary it shares with its neighbour
  /// so the totals still add up. A section against the right-hand edge grows
  /// leftwards, because its right edge is the product's edge.
  static OpeningModel setWidth(OpeningModel model, String id, double widthMm) {
    final region = model.region(id);
    if (region == null || widthMm < minSectionMm) return model;
    final container = _containerOf(model, id);
    final againstRight = region.rect.right >= container.right - _tolerance;
    final againstLeft = region.rect.left <= container.left + _tolerance;

    if (againstRight && !againstLeft) {
      return dragEdge(model, id, RegionEdge.left, region.rect.right - widthMm);
    }
    return dragEdge(model, id, RegionEdge.right, region.rect.left + widthMm);
  }

  static OpeningModel setHeight(OpeningModel model, String id, double heightMm) {
    final region = model.region(id);
    if (region == null || heightMm < minSectionMm) return model;
    final container = _containerOf(model, id);
    final againstBottom = region.rect.bottom >= container.bottom - _tolerance;
    final againstTop = region.rect.top <= container.top + _tolerance;

    if (againstBottom && !againstTop) {
      return dragEdge(model, id, RegionEdge.top, region.rect.bottom - heightMm);
    }
    return dragEdge(model, id, RegionEdge.bottom, region.rect.top + heightMm);
  }

  /// Moves a section without changing its size — "move that opening to the
  /// top-right". Neighbours are not disturbed; whatever it vacates becomes
  /// unassigned area, which the validator reports.
  static OpeningModel moveTo(OpeningModel model, String id, Vec2 topLeft) {
    final region = model.region(id);
    if (region == null) return model;
    return setRect(
      model,
      id,
      Box2.fromLTWH(topLeft.x, topLeft.y, region.rect.width, region.rect.height),
    );
  }

  /// Anchors a section in a corner or against a side of its container, at its
  /// current size.
  static OpeningModel anchor(OpeningModel model, String id, RegionAnchor anchor) {
    final region = model.region(id);
    if (region == null) return model;
    final container = _containerOf(model, id);
    final placed = anchor.place(container, region.rect.width, region.rect.height);
    return setRect(model, id, placed);
  }

  // -- boundary dragging ----------------------------------------------------

  /// How far an edge is allowed to travel, given the sections that share it.
  static ({double min, double max}) edgeLimits(
    OpeningModel model,
    String id,
    RegionEdge edge,
  ) {
    final region = model.region(id);
    if (region == null) return (min: 0, max: 0);
    final container = _containerOf(model, id);
    final position = _edgePosition(region.rect, edge);
    final affected = _affectedByEdge(model, id, edge);

    // A boundary can never leave the product: the frame is the hard limit.
    // Inside that, it can shrink a section, which leaves area assigned to
    // nothing — reported by the validator rather than quietly filled in.
    var min = edge.isVerticalEdge ? container.left : container.top;
    var max = edge.isVerticalEdge ? container.right : container.bottom;

    for (final entry in affected) {
      final rect = entry.region.rect;
      if (entry.edge == RegionEdge.left) {
        max = math.min(max, rect.right - minSectionMm);
      } else if (entry.edge == RegionEdge.right) {
        min = math.max(min, rect.left + minSectionMm);
      } else if (entry.edge == RegionEdge.top) {
        max = math.min(max, rect.bottom - minSectionMm);
      } else if (entry.edge == RegionEdge.bottom) {
        min = math.max(min, rect.top + minSectionMm);
      }
    }
    if (min > max) return (min: position, max: position);
    return (min: min, max: max);
  }

  /// Moves a boundary to [newPosition] millimetres, carrying every section that
  /// shares it. This is the same operation whether the user drags the line on
  /// screen or types a number, so both routes land on identical geometry.
  static OpeningModel dragEdge(
    OpeningModel model,
    String id,
    RegionEdge edge,
    double newPosition,
  ) {
    final region = model.region(id);
    if (region == null) return model;
    final limits = edgeLimits(model, id, edge);
    final target = newPosition.clamp(limits.min, limits.max).toDouble();
    final affected = _affectedByEdge(model, id, edge);
    if (affected.isEmpty) return model;

    var regions = model.regions;
    for (final entry in affected) {
      regions = RegionTree.replace(regions, entry.region.id, (r) {
        final next = _withEdge(r.rect, entry.edge, target);
        return r.copyWith(rect: next, children: _fitChildren(r.children, r.rect, next));
      });
    }
    return model.copyWith(regions: regions);
  }

  static List<({DesignRegion region, RegionEdge edge})> _affectedByEdge(
    OpeningModel model,
    String id,
    RegionEdge edge,
  ) {
    final region = model.region(id);
    if (region == null) return const [];
    final family = [region, ...RegionTree.siblingsOf(model.regions, id)];
    final position = _edgePosition(region.rect, edge);
    final span = _spanAcross(region.rect, edge);

    final result = <({DesignRegion region, RegionEdge edge})>[];
    for (final candidate in family) {
      final candidateSpan = _spanAcross(candidate.rect, edge);
      final overlap = math.min(span.$2, candidateSpan.$2) -
          math.max(span.$1, candidateSpan.$1);
      if (overlap <= _tolerance) continue;

      for (final side in edge.isVerticalEdge
          ? const [RegionEdge.left, RegionEdge.right]
          : const [RegionEdge.top, RegionEdge.bottom]) {
        if ((_edgePosition(candidate.rect, side) - position).abs() <= _tolerance) {
          result.add((region: candidate, edge: side));
        }
      }
    }
    return result;
  }

  static double _edgePosition(Box2 rect, RegionEdge edge) => switch (edge) {
        RegionEdge.left => rect.left,
        RegionEdge.right => rect.right,
        RegionEdge.top => rect.top,
        RegionEdge.bottom => rect.bottom,
      };

  /// The extent of a rectangle along the edge being dragged — the vertical
  /// span for a left/right edge, the horizontal span for a top/bottom one.
  static (double, double) _spanAcross(Box2 rect, RegionEdge edge) =>
      edge.isVerticalEdge ? (rect.top, rect.bottom) : (rect.left, rect.right);

  static Box2 _withEdge(Box2 rect, RegionEdge edge, double value) => switch (edge) {
        RegionEdge.left => Box2(value, rect.top, rect.right, rect.bottom),
        RegionEdge.right => Box2(rect.left, rect.top, value, rect.bottom),
        RegionEdge.top => Box2(rect.left, value, rect.right, rect.bottom),
        RegionEdge.bottom => Box2(rect.left, rect.top, rect.right, value),
      };

  // -- dividing and placing -------------------------------------------------

  /// Divides a section in two.
  ///
  /// [atMm] is an absolute position when given, otherwise the split falls at
  /// [ratio] of the section. With [inside] the two halves become panes within
  /// the original section — that is a leaf with glass over a panel; without it
  /// they replace the original as two independent sections.
  static OpeningModel divide(
    OpeningModel model,
    String id, {
    required Axis2 axis,
    double? atMm,
    double ratio = 0.5,
    bool inside = false,
  }) {
    final region = model.region(id);
    if (region == null) return model;
    final rect = region.rect;
    final start = axis == Axis2.vertical ? rect.left : rect.top;
    final extent = axis == Axis2.vertical ? rect.width : rect.height;
    // Both halves have to stay buildable, so a section this small cannot be
    // divided at all.
    if (extent < 2 * minSectionMm) return model;
    final at = (atMm ?? (start + extent * ratio))
        .clamp(start + minSectionMm, start + extent - minSectionMm)
        .toDouble();

    final firstRect = axis == Axis2.vertical
        ? Box2(rect.left, rect.top, at, rect.bottom)
        : Box2(rect.left, rect.top, rect.right, at);
    final secondRect = axis == Axis2.vertical
        ? Box2(at, rect.top, rect.right, rect.bottom)
        : Box2(rect.left, at, rect.right, rect.bottom);

    if (inside) {
      final firstId = RegionTree.nextId(model.regions, prefix: '$id.p');
      final secondId = '${firstId}b';
      return model.copyWith(
        regions: RegionTree.replace(
          model.regions,
          id,
          (r) => r.copyWith(children: [
            DesignRegion(id: firstId, rect: firstRect, glass: r.glass, panel: r.panel),
            DesignRegion(id: secondId, rect: secondRect, glass: r.glass, panel: r.panel),
          ]),
        ),
      );
    }

    final newId = RegionTree.nextId(model.regions);
    final parent = RegionTree.parentOf(model.regions, id);
    final first = region.copyWith(
      rect: firstRect,
      children: _fitChildren(region.children, rect, firstRect),
    );
    final second = DesignRegion(
      id: newId,
      rect: secondRect,
      operation: region.operation,
      infill: region.infill,
      glass: region.glass,
      panel: region.panel,
      swing: region.swing,
      handle: region.handle,
    );

    List<DesignRegion> splice(List<DesignRegion> family) {
      final index = family.indexWhere((r) => r.id == id);
      if (index < 0) return family;
      return [...family.sublist(0, index), first, second, ...family.sublist(index + 1)];
    }

    if (parent == null) {
      return model.copyWith(regions: splice(model.regions));
    }
    return model.copyWith(
      regions: RegionTree.replace(
        model.regions,
        parent.id,
        (p) => p.copyWith(children: splice(p.children)),
      ),
    );
  }

  /// Stretches a section across the whole of its container on one axis, taking
  /// the space from whatever is in the way.
  ///
  /// "Make the left section full height" is an explicit instruction, so it wins
  /// over the neighbours: sections it now covers entirely are removed, and ones
  /// it partly covers keep the area outside it.
  static OpeningModel expandToFull(OpeningModel model, String id, Axis2 axis) {
    final region = model.region(id);
    if (region == null) return model;
    final container = _containerOf(model, id);
    final rect = axis == Axis2.horizontal
        ? Box2(region.rect.left, container.top, region.rect.right, container.bottom)
        : Box2(container.left, region.rect.top, container.right, region.rect.bottom);
    if (rect == region.rect) return model;

    final parent = RegionTree.parentOf(model.regions, id);
    final family = parent?.children ?? model.regions;

    final rebuilt = <DesignRegion>[];
    for (final other in family) {
      if (other.id == id) {
        rebuilt.add(other.copyWith(
          rect: rect,
          children: _fitChildren(other.children, other.rect, rect),
        ));
        continue;
      }
      var index = 0;
      for (final piece in subtract(other.rect, rect)) {
        rebuilt.add(index == 0
            ? other.copyWith(rect: piece, children: const [])
            : other.copyWith(rect: piece, children: const []).copyWithId(
                '${other.id}_$index',
              ));
        index++;
      }
    }

    if (parent == null) return model.copyWith(regions: rebuilt);
    return model.copyWith(
      regions: RegionTree.replace(model.regions, parent.id, (p) => p.copyWith(children: rebuilt)),
    );
  }

  /// Places a section at an exact rectangle, cutting it out of whatever is
  /// already there.
  ///
  /// The remainder of an overlapped section is kept as the rectangles around
  /// the new one, so dropping a 400 x 400 opening into a corner leaves an
  /// L-shaped remainder expressed as real sections — the rest of the design is
  /// not re-divided.
  static ({OpeningModel model, String id}) placeRegion(
    OpeningModel model,
    Box2 rect, {
    CellOperation operation = CellOperation.fixed,
    CellInfill infill = CellInfill.glass,
    SwingDirection swing = SwingDirection.none,
    HandleStyle handle = HandleStyle.none,
    String? label,
  }) {
    final clamped = Box2(
      math.max(rect.left, 0),
      math.max(rect.top, 0),
      math.min(rect.right, model.widthMm),
      math.min(rect.bottom, model.heightMm),
    );
    final newId = RegionTree.nextId(model.regions);

    final remaining = <DesignRegion>[];
    for (final region in model.regions) {
      final overlap = region.rect.intersect(clamped);
      if (overlap == null) {
        remaining.add(region);
        continue;
      }
      // Keep the parts of this section that the new one does not cover.
      var index = 0;
      for (final piece in subtract(region.rect, clamped)) {
        remaining.add(region.copyWith(
          rect: piece,
          children: const [],
        ).copyWithId('${region.id}_${index++}'));
      }
    }

    final placed = DesignRegion(
      id: newId,
      rect: clamped,
      label: label,
      operation: operation,
      infill: infill,
      swing: swing,
      handle: handle,
    );
    return (model: model.copyWith(regions: [...remaining, placed]), id: newId);
  }

  static OpeningModel removeRegion(OpeningModel model, String id) =>
      model.copyWith(regions: RegionTree.remove(model.regions, id));

  /// Rectangles covering [from] but not [hole]. Empty when the hole covers it.
  static List<Box2> subtract(Box2 from, Box2 hole) {
    final overlap = from.intersect(hole);
    if (overlap == null) return [from];
    final pieces = <Box2>[];
    if (overlap.top > from.top + _tolerance) {
      pieces.add(Box2(from.left, from.top, from.right, overlap.top));
    }
    if (overlap.bottom < from.bottom - _tolerance) {
      pieces.add(Box2(from.left, overlap.bottom, from.right, from.bottom));
    }
    if (overlap.left > from.left + _tolerance) {
      pieces.add(Box2(from.left, overlap.top, overlap.left, overlap.bottom));
    }
    if (overlap.right < from.right - _tolerance) {
      pieces.add(Box2(overlap.right, overlap.top, from.right, overlap.bottom));
    }
    return pieces.where((p) => !p.isEmpty).toList();
  }

  // -- properties -----------------------------------------------------------

  static OpeningModel update(
    OpeningModel model,
    String id,
    DesignRegion Function(DesignRegion region) change,
  ) =>
      model.copyWith(regions: RegionTree.replace(model.regions, id, change));

  static OpeningModel setOperation(
    OpeningModel model,
    String id,
    CellOperation operation,
  ) =>
      update(model, id, (region) {
        final swing = operation.isOperable && !operation.isSliding
            ? (region.swing == SwingDirection.none
                ? (operation.isDoorLeaf ? SwingDirection.inward : SwingDirection.outward)
                : region.swing)
            : SwingDirection.none;
        return region.copyWith(
          operation: operation,
          swing: swing,
          handle: operation.isOperable
              ? (region.handle == HandleStyle.none ? HandleStyle.lever : region.handle)
              : HandleStyle.none,
          hasLock: operation.isDoorLeaf && region.hasLock,
        );
      });

  /// Children keep their share of the parent when the parent is resized, so a
  /// leaf's glass-over-panel proportions survive a boundary drag.
  static List<DesignRegion> _fitChildren(
    List<DesignRegion> children,
    Box2 oldRect,
    Box2 newRect,
  ) {
    if (children.isEmpty) return children;
    if (oldRect.width <= 0 || oldRect.height <= 0) return children;
    final scaleX = newRect.width / oldRect.width;
    final scaleY = newRect.height / oldRect.height;
    return children.map((child) {
      final rect = Box2(
        newRect.left + (child.rect.left - oldRect.left) * scaleX,
        newRect.top + (child.rect.top - oldRect.top) * scaleY,
        newRect.left + (child.rect.right - oldRect.left) * scaleX,
        newRect.top + (child.rect.bottom - oldRect.top) * scaleY,
      );
      return child.copyWith(
        rect: rect,
        children: _fitChildren(child.children, child.rect, rect),
      );
    }).toList();
  }

  /// The rectangle a section lives in: the product for a top-level section, or
  /// its parent's rectangle for a pane inside a leaf.
  static Box2 _containerOf(OpeningModel model, String id) =>
      RegionTree.parentOf(model.regions, id)?.rect ?? model.outerRect;
}

/// Which way a division runs.
enum Axis2 { vertical, horizontal }

extension on DesignRegion {
  /// Same section, new identity — used when one section is cut into pieces.
  DesignRegion copyWithId(String newId) => DesignRegion(
        id: newId,
        rect: rect,
        label: label,
        operation: operation,
        infill: infill,
        glass: glass,
        panel: panel,
        swing: swing,
        handle: handle,
        hasLock: hasLock,
        hasMesh: hasMesh,
        handleHeightMm: handleHeightMm,
        children: children,
      );
}
