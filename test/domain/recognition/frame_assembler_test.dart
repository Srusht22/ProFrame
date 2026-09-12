import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/recognition/frame_assembler.dart';
import 'package:proframe/domain/recognition/stroke_classifier.dart';
import 'package:proframe/domain/recognition/stroke_intent.dart';
import 'package:proframe/domain/sketch.dart';

int _next = 0;

/// A hand-drawn line from [a] to [b], sampled the way a finger would.
Stroke line(Point2 a, Point2 b, {int samples = 8}) {
  final points = <Point2>[];
  for (var i = 0; i <= samples; i++) {
    final t = i / samples;
    points.add(Point2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t));
  }
  return Stroke(
    id: 'ink${_next++}',
    points: points,
    timestampMs: _next,
  );
}

Sketch sketchOf(List<Stroke> strokes) => Sketch(strokes: strokes);

/// What the app would build from these strokes: the joined path, read by the
/// same classifier a single stroke goes through.
StrokeIntent? read(List<Stroke> strokes) {
  final joined = FrameAssembler.join(sketchOf(strokes));
  if (joined == null) return null;
  return const StrokeClassifier().classify(
    Stroke(id: 'joined', points: joined, timestampMs: 0),
  );
}

void main() {
  const topLeft = Point2(600, 500);
  const topRight = Point2(2000, 500);
  const bottomRight = Point2(2000, 1500);
  const bottomLeft = Point2(600, 1500);

  group('a box drawn side by side is still a box', () {
    test('four strokes, drawn in order, make the frame', () {
      final intent = read([
        line(topLeft, topRight),
        line(topRight, bottomRight),
        line(bottomRight, bottomLeft),
        line(bottomLeft, topLeft),
      ]);

      expect(intent, isA<FrameIntent>());
      final frame = (intent! as FrameIntent).outline;
      expect(frame.width, closeTo(1400, 1));
      expect(frame.height, closeTo(1000, 1));
    });

    test('the sides can be drawn in any order and either direction', () {
      final intent = read([
        line(bottomLeft, bottomRight), // bottom, left to right
        line(topRight, topLeft), // top, right to left
        line(topLeft, bottomLeft), // left, downwards
        line(bottomRight, topRight), // right, upwards
      ]);

      expect(intent, isA<FrameIntent>());
      expect((intent! as FrameIntent).outline.width, closeTo(1400, 1));
    });

    test('two L-shaped strokes make it too', () {
      final intent = read([
        Stroke(
          id: 'a',
          points: [...line(topLeft, topRight).points,
            ...line(topRight, bottomRight).points],
          timestampMs: 1,
        ),
        Stroke(
          id: 'b',
          points: [...line(bottomRight, bottomLeft).points,
            ...line(bottomLeft, topLeft).points],
          timestampMs: 2,
        ),
      ]);

      expect(intent, isA<FrameIntent>());
    });

    test('corners that do not quite meet are still corners', () {
      // Each side stops 30 mm short — a tenth of nothing on a 1400 mm frame,
      // and perfectly normal with a finger.
      final intent = read([
        line(const Point2(620, 500), const Point2(1980, 500)),
        line(const Point2(2000, 520), const Point2(2000, 1480)),
        line(const Point2(1980, 1500), const Point2(620, 1500)),
        line(const Point2(600, 1480), const Point2(600, 520)),
      ]);

      expect(intent, isA<FrameIntent>());
    });

    test('a scribble drawn first does not stop the frame being read', () {
      final intent = read([
        line(const Point2(2400, 1900), const Point2(2600, 2100)),
        line(topLeft, topRight),
        line(topRight, bottomRight),
        line(bottomRight, bottomLeft),
        line(bottomLeft, topLeft),
      ]);

      expect(intent, isA<FrameIntent>());
    });

    test('a sloping top drawn as four strokes keeps its slope', () {
      const lowLeft = Point2(600, 800);
      final intent = read([
        line(lowLeft, topRight), // the slope
        line(topRight, bottomRight),
        line(bottomRight, bottomLeft),
        line(bottomLeft, lowLeft),
      ]);

      expect(intent, isA<FrameIntent>());
      expect((intent! as FrameIntent).hasSlopingTop, isTrue);
    });
  });

  group('what is not a box is not joined into one', () {
    test('three sides do not close', () {
      expect(
        read([
          line(topLeft, topRight),
          line(topRight, bottomRight),
          line(bottomRight, bottomLeft),
        ]),
        anyOf(isNull, isA<DiscardedIntent>()),
      );
    });

    test('a corner left wide open is not joined', () {
      expect(
        FrameAssembler.join(sketchOf([
          line(topLeft, topRight),
          line(topRight, bottomRight),
          line(bottomRight, bottomLeft),
          // Stops 400 mm short of the top-left corner.
          line(bottomLeft, const Point2(600, 900)),
        ])),
        isNull,
      );
    });

    test('two strokes far apart are not one outline', () {
      expect(
        FrameAssembler.join(sketchOf([
          line(const Point2(300, 300), const Point2(800, 300)),
          line(const Point2(2200, 1800), const Point2(2700, 1800)),
        ])),
        isNull,
      );
    });

    test('one stroke is left to the ordinary path', () {
      expect(FrameAssembler.join(sketchOf([line(topLeft, topRight)])), isNull);
      expect(FrameAssembler.join(const Sketch()), isNull);
    });

    test('a box far too small is still too small once joined', () {
      const a = Point2(600, 500);
      const b = Point2(700, 500);
      const c = Point2(700, 600);
      const d = Point2(600, 600);
      expect(
        read([line(a, b), line(b, c), line(c, d), line(d, a)]),
        isA<DiscardedIntent>(),
        reason: 'joining strokes must not get a frame past the size rule',
      );
    });
  });
}
