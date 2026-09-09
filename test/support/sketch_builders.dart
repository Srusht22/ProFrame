import 'package:proframe/shared/models/sketch.dart';

/// Builds sketches the way a person draws them, so the recognition tests
/// exercise the real pipeline rather than hand-made primitives.
class SketchBuilder {
  final List<Stroke> _strokes = [];
  int _counter = 0;

  String _id() => 's${_counter++}';

  SketchBuilder twoPoint(
    SketchTool tool,
    double x1,
    double y1,
    double x2,
    double y2, {
    double? dimensionMm,
  }) {
    _strokes.add(Stroke(
      id: _id(),
      tool: tool,
      dimensionMm: dimensionMm,
      points: [
        StrokePoint(x: x1, y: y1),
        StrokePoint(x: x2, y: y2),
      ],
    ));
    return this;
  }

  SketchBuilder rectangle(double left, double top, double right, double bottom) =>
      twoPoint(SketchTool.rectangle, left, top, right, bottom);

  SketchBuilder division(double x1, double y1, double x2, double y2) =>
      twoPoint(SketchTool.division, x1, y1, x2, y2);

  SketchBuilder diagonal(double x1, double y1, double x2, double y2) =>
      twoPoint(SketchTool.diagonal, x1, y1, x2, y2);

  SketchBuilder arrow(double x1, double y1, double x2, double y2) =>
      twoPoint(SketchTool.arrow, x1, y1, x2, y2);

  SketchBuilder dimension(double x1, double y1, double x2, double y2, double mm) =>
      twoPoint(SketchTool.dimension, x1, y1, x2, y2, dimensionMm: mm);

  /// Freehand ink with the wobble a finger actually produces.
  SketchBuilder freehand(List<(double, double)> points, {double jitter = 0}) {
    var index = 0;
    _strokes.add(Stroke(
      id: _id(),
      tool: SketchTool.pen,
      points: points.map((p) {
        final wobble = jitter == 0 ? 0.0 : (index.isEven ? jitter : -jitter);
        index++;
        return StrokePoint(x: p.$1 + wobble, y: p.$2);
      }).toList(),
    ));
    return this;
  }

  SketchBuilder note(double x, double y, String text) {
    _strokes.add(Stroke(
      id: _id(),
      tool: SketchTool.note,
      text: text,
      points: [StrokePoint(x: x, y: y)],
    ));
    return this;
  }

  Sketch build() => Sketch(strokes: List.of(_strokes));
}

/// A two-panel window: outline, one mullion, casement diagonals on the left
/// section, and measured width and height.
Sketch twoPanelWindowSketch() => (SketchBuilder()
      ..rectangle(0, 0, 600, 400)
      ..division(300, 0, 300, 400)
      ..diagonal(300, 0, 0, 200)
      ..diagonal(300, 400, 0, 200)
      ..dimension(0, -60, 600, -60, 1200)
      ..dimension(660, 0, 660, 400, 800))
    .build();

/// A door with a transom light over a single leaf hinged on the right.
Sketch doorWithTransomSketch() => (SketchBuilder()
      ..rectangle(0, 0, 400, 900)
      ..division(0, 200, 400, 200)
      ..diagonal(0, 200, 400, 550)
      ..diagonal(0, 900, 400, 550)
      ..dimension(0, -60, 400, -60, 900)
      ..dimension(460, 0, 460, 900, 2100))
    .build();
