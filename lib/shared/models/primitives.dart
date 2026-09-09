import '../../core/utilities/geometry_math.dart';

/// What a recognised primitive means for the design. Keeping *structure*
/// separate from *annotation* is essential: a handwritten dimension line must
/// never end up as a bar of the door (spec §15).
enum PrimitiveRole {
  /// Part of the physical product: outline, mullion, transom, panel edge.
  structure,

  /// Describes how a leaf opens: casement diagonals, sliding arrow, arc.
  openingMark,

  /// Measurement or note. Never becomes geometry.
  annotation,
}

enum LineOrientation { horizontal, vertical, diagonal }

/// The result of interpreting one stroke. Every primitive remembers which
/// stroke produced it so the user can be shown exactly what was understood
/// and can edit the drawing behind it.
sealed class SketchPrimitive {
  final String id;
  final String strokeId;

  /// 0..1 — how sure the recogniser is. Anything below
  /// [RecognitionThresholds.confident] is surfaced for confirmation instead of
  /// being applied silently (spec §29, §53).
  final double confidence;

  const SketchPrimitive({
    required this.id,
    required this.strokeId,
    required this.confidence,
  });

  PrimitiveRole get role;
  Box2 get bounds;

  Map<String, dynamic> toJson();

  static SketchPrimitive fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'line' => LinePrimitive.fromJson(json),
      'rect' => RectanglePrimitive.fromJson(json),
      'arc' => ArcPrimitive.fromJson(json),
      'arrow' => ArrowPrimitive.fromJson(json),
      'dimension' => DimensionPrimitive.fromJson(json),
      _ => NotePrimitive.fromJson(json),
    };
  }
}

class LinePrimitive extends SketchPrimitive {
  final Vec2 start;
  final Vec2 end;
  final PrimitiveRole lineRole;

  /// Angle before straightening, kept so the UI can explain the correction
  /// ("drawn at 88°, straightened to 90°").
  final double originalAngleDeg;

  const LinePrimitive({
    required super.id,
    required super.strokeId,
    required super.confidence,
    required this.start,
    required this.end,
    required this.originalAngleDeg,
    this.lineRole = PrimitiveRole.structure,
  });

  @override
  PrimitiveRole get role => lineRole;

  @override
  Box2 get bounds => Box2.fromCorners(start, end);

  double get length => start.distanceTo(end);

  double get angleDeg => GeometryMath.undirectedAngleDeg(start, end);

  LineOrientation get orientation {
    final a = angleDeg;
    if (a < 8 || a > 172) return LineOrientation.horizontal;
    if ((a - 90).abs() < 8) return LineOrientation.vertical;
    return LineOrientation.diagonal;
  }

  bool get wasStraightened =>
      GeometryMath.angleDifference(originalAngleDeg, angleDeg) > 0.5;

  LinePrimitive copyWith({Vec2? start, Vec2? end, PrimitiveRole? lineRole, double? confidence}) =>
      LinePrimitive(
        id: id,
        strokeId: strokeId,
        confidence: confidence ?? this.confidence,
        start: start ?? this.start,
        end: end ?? this.end,
        originalAngleDeg: originalAngleDeg,
        lineRole: lineRole ?? this.lineRole,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'line',
        'id': id,
        'strokeId': strokeId,
        'confidence': confidence,
        'start': start.toJson(),
        'end': end.toJson(),
        'originalAngleDeg': originalAngleDeg,
        'role': lineRole.name,
      };

  factory LinePrimitive.fromJson(Map<String, dynamic> json) => LinePrimitive(
        id: json['id'] as String,
        strokeId: json['strokeId'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        start: Vec2.fromJson(Map<String, dynamic>.from(json['start'] as Map)),
        end: Vec2.fromJson(Map<String, dynamic>.from(json['end'] as Map)),
        originalAngleDeg: (json['originalAngleDeg'] as num?)?.toDouble() ?? 0,
        lineRole: PrimitiveRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => PrimitiveRole.structure,
        ),
      );
}

class RectanglePrimitive extends SketchPrimitive {
  final Box2 box;

  const RectanglePrimitive({
    required super.id,
    required super.strokeId,
    required super.confidence,
    required this.box,
  });

  @override
  PrimitiveRole get role => PrimitiveRole.structure;

  @override
  Box2 get bounds => box;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'rect',
        'id': id,
        'strokeId': strokeId,
        'confidence': confidence,
        'box': box.toJson(),
      };

  factory RectanglePrimitive.fromJson(Map<String, dynamic> json) => RectanglePrimitive(
        id: json['id'] as String,
        strokeId: json['strokeId'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        box: Box2.fromJson(Map<String, dynamic>.from(json['box'] as Map)),
      );
}

/// A curved stroke — an awning/hopper swing indicator, or a decorative arch.
class ArcPrimitive extends SketchPrimitive {
  final Vec2 start;
  final Vec2 end;
  final Vec2 apex;

  const ArcPrimitive({
    required super.id,
    required super.strokeId,
    required super.confidence,
    required this.start,
    required this.end,
    required this.apex,
  });

  @override
  PrimitiveRole get role => PrimitiveRole.openingMark;

  @override
  Box2 get bounds => Box2.fromPoints([start, end, apex]);

  /// How far the curve bulges away from the chord, in sketch units.
  double get sagitta => GeometryMath.distanceToLine(apex, start, end);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'arc',
        'id': id,
        'strokeId': strokeId,
        'confidence': confidence,
        'start': start.toJson(),
        'end': end.toJson(),
        'apex': apex.toJson(),
      };

  factory ArcPrimitive.fromJson(Map<String, dynamic> json) => ArcPrimitive(
        id: json['id'] as String,
        strokeId: json['strokeId'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        start: Vec2.fromJson(Map<String, dynamic>.from(json['start'] as Map)),
        end: Vec2.fromJson(Map<String, dynamic>.from(json['end'] as Map)),
        apex: Vec2.fromJson(Map<String, dynamic>.from(json['apex'] as Map)),
      );
}

/// A stroke with a head — the universal "this panel slides that way" mark.
class ArrowPrimitive extends SketchPrimitive {
  final Vec2 tail;
  final Vec2 head;

  const ArrowPrimitive({
    required super.id,
    required super.strokeId,
    required super.confidence,
    required this.tail,
    required this.head,
  });

  @override
  PrimitiveRole get role => PrimitiveRole.openingMark;

  @override
  Box2 get bounds => Box2.fromCorners(tail, head);

  Vec2 get direction => (head - tail).normalized;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'arrow',
        'id': id,
        'strokeId': strokeId,
        'confidence': confidence,
        'tail': tail.toJson(),
        'head': head.toJson(),
      };

  factory ArrowPrimitive.fromJson(Map<String, dynamic> json) => ArrowPrimitive(
        id: json['id'] as String,
        strokeId: json['strokeId'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        tail: Vec2.fromJson(Map<String, dynamic>.from(json['tail'] as Map)),
        head: Vec2.fromJson(Map<String, dynamic>.from(json['head'] as Map)),
      );
}

enum DimensionAxis { horizontal, vertical }

/// A measurement the user drew across the design. It carries the millimetre
/// value the user entered — [valueMm] is null until it is supplied, and the
/// app asks rather than inventing one (spec §10).
class DimensionPrimitive extends SketchPrimitive {
  final Vec2 start;
  final Vec2 end;
  final double? valueMm;

  const DimensionPrimitive({
    required super.id,
    required super.strokeId,
    required super.confidence,
    required this.start,
    required this.end,
    this.valueMm,
  });

  @override
  PrimitiveRole get role => PrimitiveRole.annotation;

  @override
  Box2 get bounds => Box2.fromCorners(start, end);

  double get pixelLength => start.distanceTo(end);

  DimensionAxis get axis => (end.x - start.x).abs() >= (end.y - start.y).abs()
      ? DimensionAxis.horizontal
      : DimensionAxis.vertical;

  bool get hasValue => valueMm != null && valueMm! > 0;

  DimensionPrimitive copyWith({double? valueMm, Vec2? start, Vec2? end}) =>
      DimensionPrimitive(
        id: id,
        strokeId: strokeId,
        confidence: confidence,
        start: start ?? this.start,
        end: end ?? this.end,
        valueMm: valueMm ?? this.valueMm,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': 'dimension',
        'id': id,
        'strokeId': strokeId,
        'confidence': confidence,
        'start': start.toJson(),
        'end': end.toJson(),
        if (valueMm != null) 'valueMm': valueMm,
      };

  factory DimensionPrimitive.fromJson(Map<String, dynamic> json) => DimensionPrimitive(
        id: json['id'] as String,
        strokeId: json['strokeId'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        start: Vec2.fromJson(Map<String, dynamic>.from(json['start'] as Map)),
        end: Vec2.fromJson(Map<String, dynamic>.from(json['end'] as Map)),
        valueMm: (json['valueMm'] as num?)?.toDouble(),
      );
}

/// Free text placed on the canvas. Pure annotation — carried through to the
/// technical drawing, never into the 3D model.
class NotePrimitive extends SketchPrimitive {
  final Vec2 anchor;
  final String text;

  const NotePrimitive({
    required super.id,
    required super.strokeId,
    required super.confidence,
    required this.anchor,
    required this.text,
  });

  @override
  PrimitiveRole get role => PrimitiveRole.annotation;

  @override
  Box2 get bounds => Box2(anchor.x, anchor.y, anchor.x, anchor.y);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'note',
        'id': id,
        'strokeId': strokeId,
        'confidence': confidence,
        'anchor': anchor.toJson(),
        'text': text,
      };

  factory NotePrimitive.fromJson(Map<String, dynamic> json) => NotePrimitive(
        id: json['id'] as String,
        strokeId: json['strokeId'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        anchor: Vec2.fromJson(Map<String, dynamic>.from(json['anchor'] as Map)),
        text: (json['text'] as String?) ?? '',
      );
}

/// Tuning constants for the recogniser, in one place so they can be reviewed
/// and tested rather than being scattered as magic numbers.
class RecognitionThresholds {
  RecognitionThresholds._();

  /// A stroke counts as straight when no sample deviates from its chord by
  /// more than this fraction of the chord length.
  static const double straightnessRatio = 0.055;

  /// Lines within this many degrees of an axis are straightened onto it.
  /// 88° becomes 90°; a deliberate 60° brace is left alone (spec §7).
  static const double axisSnapDeg = 12;

  /// Endpoints closer than this (in sketch units) are welded together.
  static const double weldDistance = 18;

  /// A division line must span at least this fraction of the frame to be
  /// treated as a full mullion or transom.
  static const double divisionSpanRatio = 0.62;

  /// Above this confidence the recogniser applies its reading directly;
  /// below it, the interpretation screen asks the user.
  static const double confident = 0.75;
}
