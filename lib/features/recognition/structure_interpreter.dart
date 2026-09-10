import 'dart:math' as math;

import '../../core/errors/app_exception.dart';
import '../../core/utilities/geometry_math.dart';
import '../../shared/models/geometry_structure.dart';
import '../../shared/models/opening_model.dart';
import '../../shared/models/primitives.dart';

/// Reads primitives as a product: an outer frame, the bars that divide it, and
/// what each resulting section does.
///
/// This is rule-based on purpose. The rules are the ones a fabricator uses
/// when reading a sketch — a closed outline is the frame, a line crossing it
/// is a mullion or transom, converging diagonals point at the hinge side — and
/// each rule reports how sure it is so the user can correct it (§14, §29).
class StructureInterpreter {
  final double divisionSpanRatio;

  const StructureInterpreter({
    this.divisionSpanRatio = RecognitionThresholds.divisionSpanRatio,
  });

  GeometryStructure interpret(
    List<SketchPrimitive> primitives, {
    required OpeningKind kind,
    bool useDrawingExtent = false,
  }) {
    var outline = _findOutline(primitives);
    var fromExtent = false;

    if (outline == null && useDrawingExtent) {
      outline = _extentOf(primitives);
      fromExtent = outline != null;
    }

    if (outline == null) {
      throw const InterpretationException(
        'No closed outline found. Draw the outside shape of the door or window first.',
      );
    }
    final frame = outline;

    final edgeTolerance = math.max(frame.width, frame.height) * 0.06;

    final structureLines = primitives
        .whereType<LinePrimitive>()
        .where((l) => l.role == PrimitiveRole.structure)
        .toList();

    final interior = structureLines
        .where((l) => !_isOnOutline(l, frame, edgeTolerance))
        .where((l) => frame.inflate(edgeTolerance).contains(l.start) ||
            frame.inflate(edgeTolerance).contains(l.end))
        .toList();

    // Full-width horizontals become transoms and split the frame into bands.
    final transomLines = interior
        .where((l) => l.orientation == LineOrientation.horizontal)
        .where((l) => l.bounds.width >= frame.width * divisionSpanRatio)
        .toList();
    final transomYs = _cluster(
      transomLines.map((l) => (l.start.y + l.end.y) / 2).toList(),
      edgeTolerance,
    )..sort();

    final rowBounds = <Box2>[];
    var top = frame.top;
    for (final y in transomYs) {
      if (y <= top + 1 || y >= frame.bottom - 1) continue;
      rowBounds.add(Box2(frame.left, top, frame.right, y));
      top = y;
    }
    rowBounds.add(Box2(frame.left, top, frame.right, frame.bottom));

    final verticalLines = interior
        .where((l) => l.orientation == LineOrientation.vertical)
        .toList();

    final openingMarks = primitives
        .where((p) => p.role == PrimitiveRole.openingMark)
        .toList();

    final rows = <StructureRow>[];
    for (var ri = 0; ri < rowBounds.length; ri++) {
      final rowBox = rowBounds[ri];
      // A vertical line belongs to this band when it runs through most of it.
      final mullionXs = _cluster(
        verticalLines
            .where((l) => _verticalOverlap(l, rowBox) >= rowBox.height * divisionSpanRatio)
            .map((l) => (l.start.x + l.end.x) / 2)
            .where((x) => x > rowBox.left + edgeTolerance && x < rowBox.right - edgeTolerance)
            .toList(),
        edgeTolerance,
      )..sort();

      final cells = <StructureCell>[];
      var left = rowBox.left;
      final boundaries = [...mullionXs, rowBox.right];
      for (var ci = 0; ci < boundaries.length; ci++) {
        final cellBox = Box2(left, rowBox.top, boundaries[ci], rowBox.bottom);
        cells.add(_readCell(
          box: cellBox,
          rowIndex: ri,
          columnIndex: ci,
          marks: openingMarks,
          outline: frame,
          kind: kind,
        ));
        left = boundaries[ci];
      }
      rows.add(StructureRow(box: rowBox, mullionXs: mullionXs, cells: cells));
    }

    return GeometryStructure(
      outline: frame,
      transomYs: transomYs,
      rows: rows,
      dimensions: primitives.whereType<DimensionPrimitive>().toList(),
      notes: primitives.whereType<NotePrimitive>().toList(),
      outlineFromExtent: fromExtent,
    );
  }

  /// The overall extent of everything drawn that is part of the product.
  ///
  /// Only used when the user explicitly asks for it, because it is a reading of
  /// the drawing rather than something they drew. Measurements and notes are
  /// left out — they sit outside the frame and would inflate it.
  Box2? _extentOf(List<SketchPrimitive> primitives) {
    final parts = primitives
        .where((p) => p.role != PrimitiveRole.annotation)
        .map((p) => p.bounds)
        .toList();
    if (parts.isEmpty) return null;

    var box = parts.first;
    for (final part in parts.skip(1)) {
      box = box.union(part);
    }
    // Too thin to be a product: two parallel lines are not a frame.
    if (box.width < 20 || box.height < 20) return null;
    return box;
  }

  // -- outline --------------------------------------------------------------

  Box2? _findOutline(List<SketchPrimitive> primitives) {
    RectanglePrimitive? largest;
    for (final r in primitives.whereType<RectanglePrimitive>()) {
      if (largest == null || r.box.area > largest.box.area) largest = r;
    }
    if (largest != null && largest.box.area > 100) return largest.box;

    // No rectangle stroke: four lines drawn as a frame also make an outline.
    final lines = primitives
        .whereType<LinePrimitive>()
        .where((l) => l.role == PrimitiveRole.structure)
        .toList();
    if (lines.length < 4) return null;

    final box = Box2.fromPoints(lines.expand((l) => [l.start, l.end]));
    if (box.area < 100) return null;

    final tolerance = math.max(box.width, box.height) * 0.08;
    final hasTop = lines.any((l) =>
        l.orientation == LineOrientation.horizontal &&
        (l.bounds.top - box.top).abs() < tolerance &&
        l.bounds.width > box.width * 0.6);
    final hasBottom = lines.any((l) =>
        l.orientation == LineOrientation.horizontal &&
        (l.bounds.bottom - box.bottom).abs() < tolerance &&
        l.bounds.width > box.width * 0.6);
    final hasLeft = lines.any((l) =>
        l.orientation == LineOrientation.vertical &&
        (l.bounds.left - box.left).abs() < tolerance &&
        l.bounds.height > box.height * 0.6);
    final hasRight = lines.any((l) =>
        l.orientation == LineOrientation.vertical &&
        (l.bounds.right - box.right).abs() < tolerance &&
        l.bounds.height > box.height * 0.6);

    return (hasTop && hasBottom && hasLeft && hasRight) ? box : null;
  }

  bool _isOnOutline(LinePrimitive line, Box2 outline, double tolerance) {
    final b = line.bounds;
    if (line.orientation == LineOrientation.horizontal) {
      final y = (line.start.y + line.end.y) / 2;
      final onEdge = (y - outline.top).abs() < tolerance || (y - outline.bottom).abs() < tolerance;
      return onEdge && b.width > outline.width * 0.5;
    }
    if (line.orientation == LineOrientation.vertical) {
      final x = (line.start.x + line.end.x) / 2;
      final onEdge = (x - outline.left).abs() < tolerance || (x - outline.right).abs() < tolerance;
      return onEdge && b.height > outline.height * 0.5;
    }
    return false;
  }

  double _verticalOverlap(LinePrimitive line, Box2 row) {
    final top = math.max(line.bounds.top, row.top);
    final bottom = math.min(line.bounds.bottom, row.bottom);
    return math.max(0, bottom - top);
  }

  /// Groups nearby coordinates so two strokes for the same mullion do not
  /// produce two bars.
  List<double> _cluster(List<double> values, double tolerance) {
    if (values.isEmpty) return <double>[];
    final sorted = [...values]..sort();
    final result = <double>[];
    var groupStart = sorted.first;
    var sum = sorted.first;
    var count = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] - groupStart <= tolerance) {
        sum += sorted[i];
        count++;
      } else {
        result.add(sum / count);
        groupStart = sorted[i];
        sum = sorted[i];
        count = 1;
      }
    }
    result.add(sum / count);
    return result;
  }

  // -- opening direction ----------------------------------------------------

  StructureCell _readCell({
    required Box2 box,
    required int rowIndex,
    required int columnIndex,
    required List<SketchPrimitive> marks,
    required Box2 outline,
    required OpeningKind kind,
  }) {
    final inside = marks.where((m) => _markBelongsTo(box, m)).toList();
    final isFullHeightAtBottom =
        (box.bottom - outline.bottom).abs() < outline.height * 0.05 &&
            box.height > outline.height * 0.5;

    if (inside.isEmpty) {
      return StructureCell(
        box: box,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        operation: CellOperation.fixed,
        confidence: 0.9,
        evidence: 'No opening marks in this section — read as fixed glazing.',
      );
    }

    final arrows = inside.whereType<ArrowPrimitive>().toList();
    if (arrows.isNotEmpty) {
      final arrow = arrows.first;
      final horizontal = (arrow.head.x - arrow.tail.x).abs() >=
          (arrow.head.y - arrow.tail.y).abs();
      if (horizontal) {
        final toRight = arrow.head.x > arrow.tail.x;
        return StructureCell(
          box: box,
          rowIndex: rowIndex,
          columnIndex: columnIndex,
          operation: toRight ? CellOperation.slidingRight : CellOperation.slidingLeft,
          confidence: 0.85,
          evidence: 'Horizontal arrow pointing ${toRight ? 'right' : 'left'} — '
              'read as a sliding leaf.',
        );
      }
    }

    final diagonals = inside
        .whereType<LinePrimitive>()
        .where((l) => l.orientation == LineOrientation.diagonal)
        .toList();

    if (diagonals.length >= 2) {
      final apex = _findConvergence(diagonals, box);
      if (apex != null) {
        final side = _nearestSide(apex, box);
        final operation = _operationForSide(side, kind, isFullHeightAtBottom);
        return StructureCell(
          box: box,
          rowIndex: rowIndex,
          columnIndex: columnIndex,
          operation: operation,
          confidence: 0.9,
          evidence: 'Two diagonals meeting at the ${_sideName(side)} — '
              'hinges read as ${_sideName(side)}.',
        );
      }
      return StructureCell(
        box: box,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        operation: _operationForSide(_Side.right, kind, isFullHeightAtBottom),
        confidence: 0.45,
        evidence: 'Diagonals found but they do not meet at one edge — '
            'the hinge side is a guess.',
      );
    }

    if (diagonals.length == 1) {
      final line = diagonals.first;
      final side = _sideFromSingleDiagonal(line, box);
      return StructureCell(
        box: box,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        operation: _operationForSide(side, kind, isFullHeightAtBottom),
        confidence: 0.5,
        evidence: 'One diagonal only — a single line cannot say which side the '
            'hinges are on. Best guess: ${_sideName(side)}.',
      );
    }

    final arcs = inside.whereType<ArcPrimitive>().toList();
    if (arcs.isNotEmpty) {
      final arc = arcs.first;
      final side = _nearestSide(arc.apex, box);
      return StructureCell(
        box: box,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
        operation: _operationForSide(side, kind, isFullHeightAtBottom),
        confidence: 0.55,
        evidence: 'Swing arc found — read as opening from the ${_sideName(side)}.',
      );
    }

    return StructureCell(
      box: box,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
      operation: CellOperation.fixed,
      confidence: 0.7,
      evidence: 'Marks found but not recognised as an opening symbol — '
          'left as fixed.',
    );
  }

  /// The point where two diagonals meet. In elevation drawings the apex of the
  /// triangle sits on the hinge side.
  /// Whether an opening mark belongs to this section. A perfectly horizontal
  /// arrow has a zero-height bounding box, so an area-only test would silently
  /// drop it — the case that matters most for sliding leaves.
  bool _markBelongsTo(Box2 box, SketchPrimitive mark) {
    final bounds = mark.bounds;
    final margin = math.max(box.width, box.height) * 0.05;
    if (!box.inflate(margin).contains(bounds.center)) return false;
    if (bounds.area <= 0) {
      return box.inflate(margin).contains(bounds.topLeft) &&
          box.inflate(margin).contains(bounds.bottomRight);
    }
    return box.overlapRatio(bounds) > 0.55;
  }

  Vec2? _findConvergence(List<LinePrimitive> diagonals, Box2 box) {
    final tolerance = math.max(box.width, box.height) * 0.22;
    final endpoints = <Vec2>[];
    for (final l in diagonals) {
      endpoints..add(l.start)..add(l.end);
    }
    for (var i = 0; i < endpoints.length; i++) {
      final group = <Vec2>[endpoints[i]];
      for (var j = 0; j < endpoints.length; j++) {
        if (i == j) continue;
        if (endpoints[i].distanceTo(endpoints[j]) <= tolerance) group.add(endpoints[j]);
      }
      if (group.length >= 2) {
        final sum = group.reduce((a, b) => a + b);
        return sum / group.length.toDouble();
      }
    }
    return null;
  }

  _Side _sideFromSingleDiagonal(LinePrimitive line, Box2 box) {
    // Whichever endpoint is closer to the middle of an edge is the apex.
    final startScore = _midEdgeScore(line.start, box);
    final endScore = _midEdgeScore(line.end, box);
    final apex = startScore <= endScore ? line.start : line.end;
    return _nearestSide(apex, box);
  }

  double _midEdgeScore(Vec2 p, Box2 box) {
    final mids = [
      Vec2(box.left, box.center.y),
      Vec2(box.right, box.center.y),
      Vec2(box.center.x, box.top),
      Vec2(box.center.x, box.bottom),
    ];
    return mids.map((m) => m.distanceTo(p)).reduce(math.min);
  }

  _Side _nearestSide(Vec2 p, Box2 box) {
    final distances = <_Side, double>{
      _Side.left: (p.x - box.left).abs(),
      _Side.right: (box.right - p.x).abs(),
      _Side.top: (p.y - box.top).abs(),
      _Side.bottom: (box.bottom - p.y).abs(),
    };
    var best = _Side.left;
    var bestDistance = double.infinity;
    distances.forEach((side, d) {
      if (d < bestDistance) {
        bestDistance = d;
        best = side;
      }
    });
    return best;
  }

  CellOperation _operationForSide(_Side side, OpeningKind kind, bool isDoorLeafCandidate) {
    final asDoor = kind == OpeningKind.door && isDoorLeafCandidate;
    return switch (side) {
      _Side.left => asDoor ? CellOperation.doorLeafLeft : CellOperation.casementLeft,
      _Side.right => asDoor ? CellOperation.doorLeafRight : CellOperation.casementRight,
      _Side.top => CellOperation.awning,
      _Side.bottom => CellOperation.hopper,
    };
  }

  String _sideName(_Side side) => switch (side) {
        _Side.left => 'left',
        _Side.right => 'right',
        _Side.top => 'top',
        _Side.bottom => 'bottom',
      };
}

enum _Side { left, right, top, bottom }
