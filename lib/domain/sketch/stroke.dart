import 'dart:math' as math;

import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';

/// One sample from the pen, with whatever the input device told us.
class StrokeSample {
  /// Where, in millimetres on the sheet.
  final Vec2 at;

  /// Milliseconds since the stroke started. Speed tells a deliberate corner
  /// from a fast sweep, so it is kept.
  final int atMs;

  /// 0..1 where the device reports it, 1 where it does not.
  final double pressure;

  const StrokeSample(this.at, {this.atMs = 0, this.pressure = 1});

  StrokeSample movedTo(Vec2 point) =>
      StrokeSample(point, atMs: atMs, pressure: pressure);

  Map<String, Object?> toJson() => {
        'at': at.toJson(),
        'atMs': atMs,
        if (pressure != 1) 'pressure': pressure,
      };

  static StrokeSample fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return StrokeSample(
      Vec2.fromJson(map['at']),
      atMs: (map['atMs'] as num?)?.toInt() ?? 0,
      pressure: (map['pressure'] as num?)?.toDouble() ?? 1,
    );
  }
}

/// What the user had selected when they drew this.
enum StrokeTool { pen, line, rectangle, polyline, dimension, arrow }

/// A single mark by the user, exactly as it was made.
///
/// This is the record of what the user actually drew. Recognition reads it
/// and produces geometry beside it; nothing ever writes back into it and
/// nothing ever deletes it. The user can always see their own hand.
class Stroke {
  final String id;
  final List<StrokeSample> samples;
  final StrokeTool tool;

  /// The colour the user drew in, as 0xAARRGGBB. The domain has no Flutter
  /// import, so it is a plain int here.
  final int colour;

  /// Pen width in millimetres on the sheet.
  final double widthMm;

  const Stroke({
    required this.id,
    required this.samples,
    this.tool = StrokeTool.pen,
    this.colour = 0xFF013E37,
    this.widthMm = 6,
  });

  List<Vec2> get points => [for (final s in samples) s.at];

  Vec2 get start => samples.first.at;
  Vec2 get end => samples.last.at;

  bool get isEmpty => samples.length < 2;

  /// The length of the path actually travelled, not the distance between the
  /// ends — a scribbled circle is long and goes nowhere.
  double get pathLength {
    var total = 0.0;
    for (var i = 1; i < samples.length; i++) {
      total += samples[i - 1].at.distanceTo(samples[i].at);
    }
    return total;
  }

  double get left => points.map((p) => p.x).reduce(math.min);
  double get right => points.map((p) => p.x).reduce(math.max);
  double get top => points.map((p) => p.y).reduce(math.min);
  double get bottom => points.map((p) => p.y).reduce(math.max);
  double get width => right - left;
  double get height => bottom - top;

  /// The size of the thing drawn, used to scale every tolerance that should
  /// be relative rather than absolute.
  double get diagonal => math.sqrt(width * width + height * height);

  Vec2 get centre => Vec2((left + right) / 2, (top + bottom) / 2);

  /// True when the pen came back to where it started, relative to the size of
  /// what was drawn — a closed shape.
  bool get isClosed {
    if (samples.length < 4) return false;
    final span = math.max(diagonal, Tol.minLineMm);
    return start.distanceTo(end) <= span * Tol.closeFraction;
  }

  /// The straight line from the first sample to the last.
  Segment get chord => Segment(start, end);

  /// The furthest any sample strays from [chord], in millimetres. Small means
  /// the user was drawing a straight line.
  double get bow {
    if (samples.length < 3) return 0;
    final line = chord;
    if (line.length < 1e-9) return pathLength / 2;
    var worst = 0.0;
    for (final sample in samples) {
      worst = math.max(worst, line.distanceTo(sample.at));
    }
    return worst;
  }

  Stroke copyWith({String? id, List<StrokeSample>? samples, int? colour}) =>
      Stroke(
        id: id ?? this.id,
        samples: samples ?? this.samples,
        tool: tool,
        colour: colour ?? this.colour,
        widthMm: widthMm,
      );

  Stroke translated(Vec2 by) =>
      copyWith(samples: [for (final s in samples) s.movedTo(s.at + by)]);

  Map<String, Object?> toJson() => {
        'id': id,
        'tool': tool.name,
        'colour': colour,
        'widthMm': widthMm,
        'samples': [for (final s in samples) s.toJson()],
      };

  static Stroke fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return Stroke(
      id: map['id']! as String,
      tool: StrokeTool.values.firstWhere(
        (t) => t.name == map['tool'],
        orElse: () => StrokeTool.pen,
      ),
      colour: (map['colour'] as num?)?.toInt() ?? 0xFF013E37,
      widthMm: (map['widthMm'] as num?)?.toDouble() ?? 6,
      samples: [
        for (final s in map['samples']! as List<Object?>)
          StrokeSample.fromJson(s),
      ],
    );
  }
}

/// Every mark the user has made, in the order they made them.
///
/// Kept for the life of the design. Recognition reads from here and writes
/// elsewhere; the user can hide the ink, but the application never discards
/// it, so the drawing they made is always recoverable.
class Sketch {
  final List<Stroke> strokes;

  const Sketch({this.strokes = const []});

  bool get isEmpty => strokes.isEmpty;
  int get length => strokes.length;

  Sketch add(Stroke stroke) => Sketch(strokes: [...strokes, stroke]);

  Sketch replace(Stroke stroke) => Sketch(strokes: [
        for (final s in strokes) if (s.id == stroke.id) stroke else s,
      ]);

  /// Removes a stroke the user explicitly erased. This is the only way ink
  /// ever leaves a sketch, and it is always the user's own doing.
  Sketch erase(String id) =>
      Sketch(strokes: [for (final s in strokes) if (s.id != id) s]);

  Stroke? byId(String id) {
    for (final s in strokes) {
      if (s.id == id) return s;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'strokes': [for (final s in strokes) s.toJson()],
      };

  static Sketch fromJson(Object? json) {
    if (json == null) return const Sketch();
    final map = json as Map<String, Object?>;
    return Sketch(strokes: [
      for (final s in (map['strokes'] as List<Object?>? ?? const []))
        Stroke.fromJson(s),
    ]);
  }
}
