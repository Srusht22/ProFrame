import 'package:flutter/rendering.dart';

/// One recorded drawing operation.
typedef DrawCall = ({String method, Paint paint});

/// A [Canvas] that remembers what it was asked to draw.
///
/// Flutter's own `paints` matcher checks calls strictly in order, which makes
/// an assertion about "the frame is painted in the chosen finish" break every
/// time the drawing order changes for an unrelated reason. Recording the calls
/// and asking questions about the set is both stronger and steadier — and it
/// is deterministic on every machine, unlike a rasterised golden.
///
/// Everything not overridden below is swallowed by [noSuchMethod]; the painter
/// only needs the few operations captured here.
class RecordingCanvas implements Canvas {
  final List<DrawCall> calls = [];

  /// Every colour a path was filled or stroked with.
  Iterable<Color> get pathColors =>
      calls.where((c) => c.method == 'drawPath').map((c) => c.paint.color);

  Iterable<Color> get lineColors =>
      calls.where((c) => c.method == 'drawLine').map((c) => c.paint.color);

  /// Paths drawn with a gradient rather than a flat fill.
  int get shadedPathCount => calls
      .where((c) => c.method == 'drawPath' && c.paint.shader != null)
      .length;

  int get pathCount => calls.where((c) => c.method == 'drawPath').length;
  int get lineCount => calls.where((c) => c.method == 'drawLine').length;

  /// Line widths used, for telling a dashed glyph from a mesh hatch.
  Iterable<double> get lineWidths =>
      calls.where((c) => c.method == 'drawLine').map((c) => c.paint.strokeWidth);

  /// Whether a path was drawn in [color].
  ///
  /// Compared as packed ARGB rather than with `==`: a Color does not survive
  /// a round trip through `Paint.color` by equality, because the components
  /// are stored as floats and lose a little precision on the way. The packed
  /// int is stable.
  bool drewPathIn(Color color) =>
      pathColors.any((c) => c.toARGB32() == color.toARGB32());

  bool drewLineIn(Color color) =>
      lineColors.any((c) => c.toARGB32() == color.toARGB32());

  @override
  void drawPath(Path path, Paint paint) =>
      calls.add((method: 'drawPath', paint: paint));

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) =>
      calls.add((method: 'drawLine', paint: paint));

  @override
  void drawRect(Rect rect, Paint paint) =>
      calls.add((method: 'drawRect', paint: paint));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
