import '../../core/utilities/geometry_math.dart';

/// The tool that produced a stroke. The recognition stage uses this as a hint
/// but never as gospel — a stroke drawn with the freehand pen can still be
/// recognised as a straight line or a rectangle.
enum SketchTool {
  pen,
  line,
  rectangle,
  division,
  diagonal,
  arc,
  arrow,
  dimension,
  note,
  eraser,
  select,
  pan,
}

extension SketchToolInfo on SketchTool {
  bool get producesInk => switch (this) {
        SketchTool.eraser || SketchTool.select || SketchTool.pan => false,
        _ => true,
      };

  /// Two-point tools are dragged from A to B; the pen is sampled continuously.
  bool get isTwoPoint => switch (this) {
        SketchTool.line ||
        SketchTool.rectangle ||
        SketchTool.division ||
        SketchTool.diagonal ||
        SketchTool.arrow ||
        SketchTool.dimension =>
          true,
        _ => false,
      };

  String get label => switch (this) {
        SketchTool.pen => 'Freehand',
        SketchTool.line => 'Line',
        SketchTool.rectangle => 'Rectangle',
        SketchTool.division => 'Division',
        SketchTool.diagonal => 'Opening',
        SketchTool.arc => 'Arc',
        SketchTool.arrow => 'Arrow',
        SketchTool.dimension => 'Dimension',
        SketchTool.note => 'Note',
        SketchTool.eraser => 'Eraser',
        SketchTool.select => 'Select',
        SketchTool.pan => 'Pan',
      };
}

/// A single sampled point of ink. Pressure is captured when the input device
/// reports it (Apple Pencil, S-Pen, active styluses) and defaults to 1.0 for
/// a finger or a mouse.
class StrokePoint {
  final double x;
  final double y;
  final double pressure;
  final int timestampMs;

  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
    this.timestampMs = 0,
  });

  Vec2 get position => Vec2(x, y);

  StrokePoint copyWith({double? x, double? y, double? pressure}) => StrokePoint(
        x: x ?? this.x,
        y: y ?? this.y,
        pressure: pressure ?? this.pressure,
        timestampMs: timestampMs,
      );

  Map<String, dynamic> toJson() =>
      {'x': x, 'y': y, 'p': pressure, 't': timestampMs};

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        pressure: (json['p'] as num?)?.toDouble() ?? 1.0,
        timestampMs: (json['t'] as num?)?.toInt() ?? 0,
      );
}

/// Raw ink exactly as the user drew it. Strokes are never discarded when a
/// design is interpreted — the sketch stays the editable source of truth so
/// the user can go back and change the drawing (spec §27).
class Sketch {
  final List<Stroke> strokes;

  const Sketch({this.strokes = const []});

  bool get isEmpty => strokes.isEmpty;
  bool get isNotEmpty => strokes.isNotEmpty;

  Box2 get bounds {
    final points = <Vec2>[];
    for (final s in strokes) {
      points.addAll(s.points.map((p) => p.position));
    }
    return Box2.fromPoints(points);
  }

  Sketch copyWith({List<Stroke>? strokes}) =>
      Sketch(strokes: strokes ?? this.strokes);

  Map<String, dynamic> toJson() =>
      {'strokes': strokes.map((s) => s.toJson()).toList()};

  factory Sketch.fromJson(Map<String, dynamic> json) => Sketch(
        strokes: ((json['strokes'] as List?) ?? const [])
            .map((e) => Stroke.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class Stroke {
  final String id;
  final SketchTool tool;
  final List<StrokePoint> points;
  final double width;

  /// Text carried by a note, a dimension value or a label. Handwriting is not
  /// transcribed on device (see [HandwritingRecognizer]); the user types the
  /// value and the ink stays alongside it.
  final String? text;

  /// Millimetre value the user attached to a dimension stroke, if any.
  final double? dimensionMm;

  const Stroke({
    required this.id,
    required this.tool,
    required this.points,
    this.width = 2.4,
    this.text,
    this.dimensionMm,
  });

  List<Vec2> get positions => points.map((p) => p.position).toList();

  Vec2 get start => points.first.position;
  Vec2 get end => points.last.position;

  Box2 get bounds => Box2.fromPoints(positions);

  double get inkLength => GeometryMath.pathLength(positions);

  /// Average reported pressure — drives stroke weight on pressure-capable
  /// devices without affecting geometry.
  double get averagePressure => points.isEmpty
      ? 1.0
      : points.map((p) => p.pressure).reduce((a, b) => a + b) / points.length;

  Stroke copyWith({
    List<StrokePoint>? points,
    SketchTool? tool,
    double? width,
    String? text,
    double? dimensionMm,
    bool clearDimension = false,
  }) =>
      Stroke(
        id: id,
        tool: tool ?? this.tool,
        points: points ?? this.points,
        width: width ?? this.width,
        text: text ?? this.text,
        dimensionMm: clearDimension ? null : (dimensionMm ?? this.dimensionMm),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tool': tool.name,
        'width': width,
        if (text != null) 'text': text,
        if (dimensionMm != null) 'dimensionMm': dimensionMm,
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
        id: json['id'] as String,
        tool: SketchTool.values.firstWhere(
          (t) => t.name == json['tool'],
          orElse: () => SketchTool.pen,
        ),
        width: (json['width'] as num?)?.toDouble() ?? 2.4,
        text: json['text'] as String?,
        dimensionMm: (json['dimensionMm'] as num?)?.toDouble(),
        points: ((json['points'] as List?) ?? const [])
            .map((e) => StrokePoint.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
