import 'dart:math' as math;

import '../../core/errors/app_exception.dart';
import '../../core/utilities/geometry_math.dart';
import '../../shared/models/geometry_structure.dart';
import '../../shared/models/opening_model.dart';
import '../../shared/models/primitives.dart';

/// One dividing line, reduced to where it actually runs.
class _Cut {
  /// x for a vertical cut, y for a horizontal one.
  final double position;

  /// How far it extends along the other axis.
  final double start;
  final double end;

  const _Cut(this.position, this.start, this.end);

  double get length => end - start;
}

/// Reads the drawing as a set of sections.
///
/// **The drawing is the design.** Every line the user drew is a cut, and two
/// neighbouring areas stay joined unless a line actually separates them. That
/// single rule is what makes a divider crossing only half the design produce
/// exactly the sections it creates, and a rectangle drawn inside the frame stay
/// a section of its own — instead of everything being flattened into rows and
/// columns.
///
/// Nothing here equalises, centres, straightens up or drops a line because the
/// result would look tidier.
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
    final tolerance = math.max(frame.width, frame.height) * 0.04;

    // -- what the user drew inside the frame --------------------------------
    final innerRects = primitives
        .whereType<RectanglePrimitive>()
        .map((r) => r.box)
        .where((box) => !_isSameAs(box, frame, tolerance))
        .where((box) => frame.inflate(tolerance).contains(box.center))
        .toList();

    final lines = primitives
        .whereType<LinePrimitive>()
        .where((l) => l.role == PrimitiveRole.structure)
        .where((l) => !_isOnOutline(l, frame, tolerance))
        .where((l) => frame.inflate(tolerance).contains(l.bounds.center))
        .toList();

    final verticalCuts = <_Cut>[];
    final horizontalCuts = <_Cut>[];

    for (final line in lines) {
      final b = line.bounds;
      switch (line.orientation) {
        case LineOrientation.vertical:
          verticalCuts.add(_Cut((line.start.x + line.end.x) / 2, b.top, b.bottom));
        case LineOrientation.horizontal:
          horizontalCuts.add(_Cut((line.start.y + line.end.y) / 2, b.left, b.right));
        case LineOrientation.diagonal:
          break; // a diagonal is an opening mark, never a division
      }
    }

    // A rectangle drawn inside the frame cuts along all four of its edges.
    for (final box in innerRects) {
      verticalCuts
        ..add(_Cut(box.left, box.top, box.bottom))
        ..add(_Cut(box.right, box.top, box.bottom));
      horizontalCuts
        ..add(_Cut(box.top, box.left, box.right))
        ..add(_Cut(box.bottom, box.left, box.right));
    }

    final sectionBoxes = _subdivide(
      frame: frame,
      verticalCuts: verticalCuts,
      horizontalCuts: horizontalCuts,
      tolerance: tolerance,
    );

    // -- read each section --------------------------------------------------
    final openingMarks =
        primitives.where((p) => p.role == PrimitiveRole.openingMark).toList();

    final sections = <StructureSection>[];
    for (var i = 0; i < sectionBoxes.length; i++) {
      final box = sectionBoxes[i];
      final explicit = innerRects.any((r) => _isSameAs(r, box, tolerance));
      sections.add(_readSection(
        id: 's$i',
        box: box,
        marks: openingMarks,
        outline: frame,
        kind: kind,
        drawnExplicitly: explicit,
      ));
    }

    final dividers = <StructureDivider>[
      for (final cut in verticalCuts)
        StructureDivider(
          span: Box2(cut.position, cut.start, cut.position, cut.end),
          vertical: true,
          full: cut.length >= frame.height * divisionSpanRatio,
        ),
      for (final cut in horizontalCuts)
        StructureDivider(
          span: Box2(cut.start, cut.position, cut.end, cut.position),
          vertical: false,
          full: cut.length >= frame.width * divisionSpanRatio,
        ),
    ];

    return GeometryStructure(
      outline: frame,
      sections: sections,
      dividers: dividers,
      dimensions: primitives.whereType<DimensionPrimitive>().toList(),
      notes: primitives.whereType<NotePrimitive>().toList(),
      outlineFromExtent: fromExtent,
    );
  }

  // -- planar subdivision ---------------------------------------------------

  /// Cuts the frame on every drawn line, then joins neighbouring pieces back
  /// together wherever no line separates them.
  ///
  /// This is the whole reason a half-width divider works: the boundary it
  /// covers stays a boundary, and the boundary it does not reach is dissolved,
  /// so the two areas on that side remain one section.
  List<Box2> _subdivide({
    required Box2 frame,
    required List<_Cut> verticalCuts,
    required List<_Cut> horizontalCuts,
    required double tolerance,
  }) {
    final xs = _coordinates(frame.left, frame.right, verticalCuts, tolerance);
    final ys = _coordinates(frame.top, frame.bottom, horizontalCuts, tolerance);

    final columns = xs.length - 1;
    final rows = ys.length - 1;
    if (columns <= 0 || rows <= 0) return [frame];

    // Union-find over the grid of pieces.
    final parent = List<int>.generate(rows * columns, (i) => i);
    int find(int a) {
      var root = a;
      while (parent[root] != root) {
        root = parent[root];
      }
      var walk = a;
      while (parent[walk] != root) {
        final next = parent[walk];
        parent[walk] = root;
        walk = next;
      }
      return root;
    }

    void union(int a, int b) {
      final rootA = find(a);
      final rootB = find(b);
      if (rootA != rootB) parent[rootB] = rootA;
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final index = r * columns + c;
        // Join with the piece to the right unless a vertical line divides them.
        if (c + 1 < columns &&
            !_covered(verticalCuts, xs[c + 1], ys[r], ys[r + 1], tolerance)) {
          union(index, index + 1);
        }
        // Join with the piece below unless a horizontal line divides them.
        if (r + 1 < rows &&
            !_covered(horizontalCuts, ys[r + 1], xs[c], xs[c + 1], tolerance)) {
          union(index, index + columns);
        }
      }
    }

    // Each joined group becomes as few rectangles as it takes to cover it.
    final groups = <int, List<int>>{};
    for (var i = 0; i < rows * columns; i++) {
      groups.putIfAbsent(find(i), () => []).add(i);
    }

    final boxes = <Box2>[];
    for (final cells in groups.values) {
      boxes.addAll(_rectanglesFor(cells, xs, ys, rows, columns));
    }
    boxes.sort((a, b) {
      final byTop = a.top.compareTo(b.top);
      return byTop != 0 ? byTop : a.left.compareTo(b.left);
    });
    return boxes;
  }

  /// Covers a set of grid pieces with as few rectangles as possible: merge
  /// runs across each row, then merge identical runs down the rows.
  List<Box2> _rectanglesFor(
    List<int> cells,
    List<double> xs,
    List<double> ys,
    int rows,
    int columns,
  ) {
    final member = List.generate(rows, (_) => List<bool>.filled(columns, false));
    for (final index in cells) {
      member[index ~/ columns][index % columns] = true;
    }

    final runs = <({int row, int from, int to})>[];
    for (var r = 0; r < rows; r++) {
      var c = 0;
      while (c < columns) {
        if (!member[r][c]) {
          c++;
          continue;
        }
        var end = c;
        while (end + 1 < columns && member[r][end + 1]) {
          end++;
        }
        runs.add((row: r, from: c, to: end));
        c = end + 1;
      }
    }

    final merged = <({int top, int bottom, int from, int to})>[];
    for (final run in runs) {
      final match = merged.indexWhere(
        (m) => m.from == run.from && m.to == run.to && m.bottom + 1 == run.row,
      );
      if (match >= 0) {
        merged[match] = (
          top: merged[match].top,
          bottom: run.row,
          from: run.from,
          to: run.to,
        );
      } else {
        merged.add((top: run.row, bottom: run.row, from: run.from, to: run.to));
      }
    }

    return merged
        .map((m) => Box2(xs[m.from], ys[m.top], xs[m.to + 1], ys[m.bottom + 1]))
        .toList();
  }

  /// The cut positions along one axis, with near-identical lines treated as
  /// the same line so two strokes for one divider do not make two.
  List<double> _coordinates(
    double start,
    double end,
    List<_Cut> cuts,
    double tolerance,
  ) {
    final values = <double>[start, end];
    for (final cut in cuts) {
      if (cut.position > start + tolerance && cut.position < end - tolerance) {
        values.add(cut.position);
      }
    }
    values.sort();
    final result = <double>[values.first];
    for (final value in values.skip(1)) {
      if (value - result.last > tolerance) result.add(value);
    }
    if (result.length == 1) result.add(end);
    return result;
  }

  /// Whether a drawn line actually runs along this boundary. A line that stops
  /// short leaves the boundary open, which is the point.
  bool _covered(
    List<_Cut> cuts,
    double at,
    double from,
    double to,
    double tolerance,
  ) {
    for (final cut in cuts) {
      if ((cut.position - at).abs() > tolerance) continue;
      if (cut.start <= from + tolerance && cut.end >= to - tolerance) return true;
    }
    return false;
  }

  bool _isSameAs(Box2 a, Box2 b, double tolerance) =>
      (a.left - b.left).abs() < tolerance &&
      (a.top - b.top).abs() < tolerance &&
      (a.right - b.right).abs() < tolerance &&
      (a.bottom - b.bottom).abs() < tolerance;

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
      final onEdge =
          (y - outline.top).abs() < tolerance || (y - outline.bottom).abs() < tolerance;
      return onEdge && b.width > outline.width * 0.5;
    }
    if (line.orientation == LineOrientation.vertical) {
      final x = (line.start.x + line.end.x) / 2;
      final onEdge =
          (x - outline.left).abs() < tolerance || (x - outline.right).abs() < tolerance;
      return onEdge && b.height > outline.height * 0.5;
    }
    return false;
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
    if (box.width < 20 || box.height < 20) return null;
    return box;
  }

  // -- opening direction ----------------------------------------------------

  StructureSection _readSection({
    required String id,
    required Box2 box,
    required List<SketchPrimitive> marks,
    required Box2 outline,
    required OpeningKind kind,
    required bool drawnExplicitly,
  }) {
    final inside = marks.where((m) => _markBelongsTo(box, m)).toList();
    final isFullHeightAtBottom =
        (box.bottom - outline.bottom).abs() < outline.height * 0.05 &&
            box.height > outline.height * 0.5;

    StructureSection build(
      CellOperation operation,
      double confidence,
      String evidence,
    ) =>
        StructureSection(
          id: id,
          box: box,
          operation: operation,
          confidence: confidence,
          evidence: evidence,
          drawnExplicitly: drawnExplicitly,
        );

    if (inside.isEmpty) {
      return build(
        CellOperation.fixed,
        drawnExplicitly ? 0.6 : 0.9,
        drawnExplicitly
            ? 'You drew this section on its own but did not mark how it opens.'
            : 'No opening marks in this section — read as fixed glazing.',
      );
    }

    final arrows = inside.whereType<ArrowPrimitive>().toList();
    if (arrows.isNotEmpty) {
      final arrow = arrows.first;
      final horizontal =
          (arrow.head.x - arrow.tail.x).abs() >= (arrow.head.y - arrow.tail.y).abs();
      if (horizontal) {
        final toRight = arrow.head.x > arrow.tail.x;
        return build(
          toRight ? CellOperation.slidingRight : CellOperation.slidingLeft,
          0.85,
          'Horizontal arrow pointing ${toRight ? 'right' : 'left'} — '
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
        return build(
          _operationForSide(side, kind, isFullHeightAtBottom),
          0.9,
          'Two diagonals meeting at the ${_sideName(side)} — '
          'hinges read as ${_sideName(side)}.',
        );
      }
      return build(
        _operationForSide(_Side.right, kind, isFullHeightAtBottom),
        0.45,
        'Diagonals found but they do not meet at one edge — '
        'the hinge side is a guess.',
      );
    }

    if (diagonals.length == 1) {
      final side = _sideFromSingleDiagonal(diagonals.first, box);
      return build(
        _operationForSide(side, kind, isFullHeightAtBottom),
        0.5,
        'One diagonal only — a single line cannot say which side the hinges '
        'are on. Best guess: ${_sideName(side)}.',
      );
    }

    final arcs = inside.whereType<ArcPrimitive>().toList();
    if (arcs.isNotEmpty) {
      final side = _nearestSide(arcs.first.apex, box);
      return build(
        _operationForSide(side, kind, isFullHeightAtBottom),
        0.55,
        'Swing arc found — read as opening from the ${_sideName(side)}.',
      );
    }

    return build(
      CellOperation.fixed,
      0.7,
      'Marks found but not recognised as an opening symbol — left as fixed.',
    );
  }

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

  /// The point where two diagonals meet. In elevation drawings the apex of the
  /// triangle sits on the hinge side.
  Vec2? _findConvergence(List<LinePrimitive> diagonals, Box2 box) {
    final tolerance = math.max(box.width, box.height) * 0.22;
    final endpoints = <Vec2>[];
    for (final l in diagonals) {
      endpoints
        ..add(l.start)
        ..add(l.end);
    }
    for (var i = 0; i < endpoints.length; i++) {
      final group = <Vec2>[endpoints[i]];
      for (var j = 0; j < endpoints.length; j++) {
        if (i == j) continue;
        if (endpoints[i].distanceTo(endpoints[j]) <= tolerance) {
          group.add(endpoints[j]);
        }
      }
      if (group.length >= 2) {
        final sum = group.reduce((a, b) => a + b);
        return sum / group.length.toDouble();
      }
    }
    return null;
  }

  _Side _sideFromSingleDiagonal(LinePrimitive line, Box2 box) {
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

  CellOperation _operationForSide(
    _Side side,
    OpeningKind kind,
    bool isDoorLeafCandidate,
  ) {
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
