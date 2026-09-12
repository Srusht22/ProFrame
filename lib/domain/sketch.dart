import 'geometry/point2.dart';

/// One pen stroke exactly as the user drew it.
///
/// The original ink is kept in the saved project for the life of the design so
/// the user can compare what they drew against what was built, and undo the
/// interpretation without redrawing (spec section 4).
class Stroke {
  final String id;
  final List<Point2> points;

  /// Milliseconds since the drawing session started. Used to order strokes and
  /// to separate a quick tap from a deliberate line.
  final int timestampMs;

  const Stroke({
    required this.id,
    required this.points,
    this.timestampMs = 0,
  });

  bool get isEmpty => points.isEmpty;
  int get pointCount => points.length;

  /// Straight-line distance from first point to last. A near-zero value with
  /// many points means a scribble or a circled mark, not a line.
  double get spanMm =>
      points.length < 2 ? 0 : points.first.distanceTo(points.last);

  /// Total distance travelled along the stroke.
  double get pathLengthMm {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += points[i - 1].distanceTo(points[i]);
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': [for (final p in points) p.toJson()],
        't': timestampMs,
      };

  static Stroke fromJson(Object? json, {String path = 'stroke'}) {
    if (json is! Map) throw FormatException('$path must be an object, got $json');
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id must be a non-empty string, got $id');
    }
    final rawPoints = json['points'];
    if (rawPoints is! List) {
      throw FormatException('$path.points must be a list, got $rawPoints');
    }
    final timestamp = json['t'];
    return Stroke(
      id: id,
      points: [
        for (var i = 0; i < rawPoints.length; i++)
          Point2.fromJson(rawPoints[i], path: '$path.points[$i]'),
      ],
      timestampMs: timestamp is int ? timestamp : 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! Stroke ||
        other.id != id ||
        other.timestampMs != timestampMs ||
        other.points.length != points.length) {
      return false;
    }
    for (var i = 0; i < points.length; i++) {
      if (points[i] != other.points[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, timestampMs, Object.hashAll(points));

  @override
  String toString() => 'Stroke($id, ${points.length} points)';
}

/// Everything the user drew, in order.
class Sketch {
  final List<Stroke> strokes;

  const Sketch({this.strokes = const []});

  bool get isEmpty => strokes.isEmpty;

  Sketch withStroke(Stroke stroke) => Sketch(strokes: [...strokes, stroke]);

  Map<String, dynamic> toJson() => {
        'strokes': [for (final s in strokes) s.toJson()],
      };

  static Sketch fromJson(Object? json, {String path = 'sketch'}) {
    if (json is! Map) throw FormatException('$path must be an object, got $json');
    final raw = json['strokes'];
    if (raw is! List) {
      throw FormatException('$path.strokes must be a list, got $raw');
    }
    return Sketch(
      strokes: [
        for (var i = 0; i < raw.length; i++)
          Stroke.fromJson(raw[i], path: '$path.strokes[$i]'),
      ],
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! Sketch || other.strokes.length != strokes.length) return false;
    for (var i = 0; i < strokes.length; i++) {
      if (strokes[i] != other.strokes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(strokes);
}
