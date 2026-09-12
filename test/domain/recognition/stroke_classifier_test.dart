import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/panel.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/recognition/stroke_classifier.dart';
import 'package:proframe/domain/recognition/stroke_intent.dart';
import 'package:proframe/domain/sketch.dart';

/// Turns corner points into a stroke with the wobble a finger actually
/// produces, so the tests exercise rough input rather than perfect input.
Stroke handDrawn(
  List<Point2> corners, {
  String id = 'k1',
  double wobbleMm = 6,
  int samplesPerSegment = 14,
}) {
  final random = math.Random(20260912);
  final points = <Point2>[];
  for (var i = 0; i < corners.length - 1; i++) {
    final from = corners[i];
    final to = corners[i + 1];
    for (var step = 0; step < samplesPerSegment; step++) {
      final t = step / samplesPerSegment;
      points.add(Point2(
        from.x + (to.x - from.x) * t + (random.nextDouble() - 0.5) * wobbleMm,
        from.y + (to.y - from.y) * t + (random.nextDouble() - 0.5) * wobbleMm,
      ));
    }
  }
  points.add(corners.last);
  return Stroke(id: id, points: points);
}

/// A 1200 x 900 frame with its top-left corner at the origin.
final frame = Polygon.rectangle(width: 1200, height: 900);

Panel wholeFrame() => Panel.fixed(id: 'p1', boundary: frame);

void main() {
  group('the frame', () {
    test('a rough closed loop with four corners becomes a frame', () {
      const classifier = StrokeClassifier();
      final stroke = handDrawn(const [
        Point2(0, 0),
        Point2(1200, 0),
        Point2(1200, 900),
        Point2(0, 900),
        Point2(0, 0),
      ]);

      final intent = classifier.classify(stroke);

      expect(intent, isA<FrameIntent>());
      final rectangle = (intent as FrameIntent).outline;
      expect(rectangle.isRectangle, isTrue);
      expect(rectangle.cornerCount, 4);
      // Fitted to the extent of the ink, so a wobbly loop still gives square
      // corners (spec Phase 2, item 2).
      expect(rectangle.width, closeTo(1200, 20));
      expect(rectangle.height, closeTo(900, 20));
    });

    test('a loop that does not quite close is still a frame', () {
      const classifier = StrokeClassifier();
      // Ends 80 mm short, as a hand-drawn box usually does.
      final stroke = handDrawn(const [
        Point2(0, 0),
        Point2(1200, 0),
        Point2(1200, 900),
        Point2(0, 900),
        Point2(0, 80),
      ]);

      expect(classifier.classify(stroke), isA<FrameIntent>());
    });

    test('an open L shape is not a frame', () {
      const classifier = StrokeClassifier();
      final stroke = handDrawn(const [
        Point2(0, 0),
        Point2(0, 900),
        Point2(1200, 900),
      ]);

      expect(classifier.classify(stroke), isA<DiscardedIntent>());
    });

    test('a tiny scribble is not a frame', () {
      const classifier = StrokeClassifier();
      final stroke = handDrawn(const [
        Point2(0, 0),
        Point2(40, 0),
        Point2(40, 30),
        Point2(0, 30),
        Point2(0, 0),
      ]);

      expect(classifier.classify(stroke), isA<DiscardedIntent>());
    });

    test('nothing can be drawn before a frame exists', () {
      const classifier = StrokeClassifier();
      final divider = handDrawn(const [Point2(600, 0), Point2(600, 900)]);

      final intent = classifier.classify(divider);

      expect(intent, isA<DiscardedIntent>());
      expect((intent as DiscardedIntent).reason, contains('frame'));
    });
  });

  group('sloping tops are kept, not levelled', () {
    test('a frame with unequal side heights keeps both', () {
      // Spec section 4: straight sloping tops with unequal side heights.
      const classifier = StrokeClassifier();
      final stroke = handDrawn(
        const [
          Point2(0, 200),
          Point2(1200, 0),
          Point2(1200, 900),
          Point2(0, 900),
          Point2(0, 200),
        ],
        wobbleMm: 5,
      );

      final intent = classifier.classify(stroke);

      expect(intent, isA<FrameIntent>());
      final frame = intent as FrameIntent;
      expect(frame.hasSlopingTop, isTrue);
      expect(frame.outline.isRectangle, isFalse);
      expect(frame.outline.slopingEdges, hasLength(1));
      // The left side is taller than the right, and stays that way.
      final left = frame.outline.vertices.first;
      final right = frame.outline.vertices[1];
      expect(left.y, greaterThan(right.y));
    });

    test('the two heights survive into the outline', () {
      const classifier = StrokeClassifier();
      final stroke = handDrawn(
        const [
          Point2(0, 300),
          Point2(1000, 0),
          Point2(1000, 1000),
          Point2(0, 1000),
          Point2(0, 300),
        ],
        wobbleMm: 4,
      );

      final frame = classifier.classify(stroke) as FrameIntent;
      final edges = frame.outline.edges;
      final leftEdge = edges.firstWhere(
        (e) => e.start.x < 50 && e.end.x < 50,
      );
      final rightEdge = edges.firstWhere(
        (e) => e.start.x > 950 && e.end.x > 950,
      );

      // 700 tall on the left, 1000 on the right, within hand tolerance.
      expect(leftEdge.length, closeTo(700, 40));
      expect(rightEdge.length, closeTo(1000, 40));
    });

    test('a level top drawn by hand is still a rectangle', () {
      // The wobble on a level line must not be mistaken for a slope.
      const classifier = StrokeClassifier();
      final stroke = handDrawn(
        const [
          Point2(0, 0),
          Point2(1200, 14),
          Point2(1200, 900),
          Point2(0, 900),
          Point2(0, 0),
        ],
        wobbleMm: 8,
      );

      final frame = classifier.classify(stroke) as FrameIntent;

      expect(frame.hasSlopingTop, isFalse);
      expect(frame.outline.isRectangle, isTrue);
    });

    test('the slope threshold sits between a wobble and an intended slope', () {
      const classifier = StrokeClassifier();

      // 1200 across with 40 mm of fall is 1.9 degrees — wobble.
      final shallow = classifier.classify(
        handDrawn(
          const [
            Point2(0, 40),
            Point2(1200, 0),
            Point2(1200, 900),
            Point2(0, 900),
            Point2(0, 40),
          ],
          wobbleMm: 2,
        ),
      ) as FrameIntent;

      // 1200 across with 300 mm of fall is 14 degrees — intended.
      final real = classifier.classify(
        handDrawn(
          const [
            Point2(0, 300),
            Point2(1200, 0),
            Point2(1200, 900),
            Point2(0, 900),
            Point2(0, 300),
          ],
          wobbleMm: 2,
        ),
      ) as FrameIntent;

      expect(shallow.hasSlopingTop, isFalse);
      expect(real.hasSlopingTop, isTrue);
    });
  });

  group('dividers', () {
    late StrokeClassifier classifier;

    setUp(() {
      classifier = StrokeClassifier(frame: frame, panels: [wholeFrame()]);
    });

    test('a shaky vertical stroke becomes a snapped mullion', () {
      final stroke = handDrawn(
        const [Point2(600, 40), Point2(612, 860)],
        wobbleMm: 10,
      );

      final intent = classifier.classify(stroke);

      expect(intent, isA<VerticalDividerIntent>());
      // Snapped to a single x: exactly vertical, whatever the hand did.
      expect((intent as VerticalDividerIntent).atX, closeTo(606, 15));
      expect(intent.panelId, 'p1');
    });

    test('a shaky horizontal stroke becomes a snapped transom', () {
      final stroke = handDrawn(
        const [Point2(40, 300), Point2(1160, 312)],
        wobbleMm: 10,
      );

      final intent = classifier.classify(stroke);

      expect(intent, isA<HorizontalDividerIntent>());
      expect((intent as HorizontalDividerIntent).atY, closeTo(306, 15));
    });

    test('a diagonal stroke is discarded, not snapped to the nearer axis', () {
      // Snapping this would invent a divider the user did not draw.
      final stroke = handDrawn(const [Point2(200, 150), Point2(1000, 750)]);

      expect(classifier.classify(stroke), isA<DiscardedIntent>());
    });

    test('a stroke drawn outside the frame is discarded', () {
      final stroke = handDrawn(const [Point2(1400, 100), Point2(1400, 800)]);

      final intent = classifier.classify(stroke);

      expect(intent, isA<DiscardedIntent>());
      expect((intent as DiscardedIntent).reason, contains('outside'));
    });

    test('a divider hard against an edge is discarded', () {
      // 20 mm from the left edge leaves nothing buildable beside it.
      final stroke = handDrawn(const [Point2(20, 100), Point2(20, 800)]);

      expect(classifier.classify(stroke), isA<DiscardedIntent>());
    });

    test('a divider lands in the panel it was drawn across, not the first one',
        () {
      final split = StrokeClassifier(
        frame: frame,
        panels: [
          Panel.fixed(
            id: 'left',
            boundary: Polygon.rectangle(width: 600, height: 900),
          ),
          Panel.fixed(
            id: 'right',
            boundary: Polygon.rectangle(
              width: 600,
              height: 900,
              topLeft: const Point2(600, 0),
            ),
          ),
        ],
      );
      final stroke = handDrawn(const [Point2(900, 60), Point2(900, 840)]);

      final intent = split.classify(stroke);

      expect(intent, isA<VerticalDividerIntent>());
      expect((intent as VerticalDividerIntent).panelId, 'right');
    });
  });

  group('chevrons mark a panel as opening', () {
    late StrokeClassifier classifier;

    setUp(() {
      classifier = StrokeClassifier(frame: frame, panels: [wholeFrame()]);
    });

    test('a ">" hinges the panel on the right', () {
      // Point to the right: the arms come back to the left.
      final stroke = handDrawn(const [
        Point2(400, 300),
        Point2(800, 450),
        Point2(400, 600),
      ]);

      final intent = classifier.classify(stroke);

      expect(intent, isA<ChevronIntent>());
      expect((intent as ChevronIntent).hingeSide, HingeSide.right);
      expect(intent.panelId, 'p1');
    });

    test('a "<" hinges the panel on the left', () {
      final stroke = handDrawn(const [
        Point2(800, 300),
        Point2(400, 450),
        Point2(800, 600),
      ]);

      final intent = classifier.classify(stroke);

      expect(intent, isA<ChevronIntent>());
      expect((intent as ChevronIntent).hingeSide, HingeSide.left);
    });

    test('a "v" pointing down is not a chevron', () {
      // The apex must stick out sideways. A v is a different mark and this
      // release does not know what it means, so it is dropped.
      final stroke = handDrawn(const [
        Point2(400, 300),
        Point2(600, 700),
        Point2(800, 300),
      ]);

      expect(classifier.classify(stroke), isA<DiscardedIntent>());
    });

    test('a kinked line is not a chevron', () {
      // 15 mm of sideways wander over 600 mm of stroke is a wobble.
      final stroke = handDrawn(const [
        Point2(600, 150),
        Point2(585, 450),
        Point2(600, 750),
      ]);

      expect(classifier.classify(stroke), isNot(isA<ChevronIntent>()));
    });

    test('a chevron lands in the panel it was drawn in', () {
      final split = StrokeClassifier(
        frame: frame,
        panels: [
          Panel.fixed(
            id: 'left',
            boundary: Polygon.rectangle(width: 600, height: 900),
          ),
          Panel.fixed(
            id: 'right',
            boundary: Polygon.rectangle(
              width: 600,
              height: 900,
              topLeft: const Point2(600, 0),
            ),
          ),
        ],
      );
      final stroke = handDrawn(const [
        Point2(700, 300),
        Point2(1050, 450),
        Point2(700, 600),
      ]);

      final intent = split.classify(stroke);

      expect(intent, isA<ChevronIntent>());
      expect((intent as ChevronIntent).panelId, 'right');
      expect(intent.hingeSide, HingeSide.right);
    });
  });

  group('anything else is dropped', () {
    late StrokeClassifier classifier;

    setUp(() {
      classifier = StrokeClassifier(frame: frame, panels: [wholeFrame()]);
    });

    test('a tap is not a stroke', () {
      const tap = Stroke(id: 'k', points: [Point2(600, 400)]);

      expect(classifier.classify(tap), isA<DiscardedIntent>());
    });

    test('a scribble is not a divider', () {
      final stroke = handDrawn(const [
        Point2(300, 300),
        Point2(500, 500),
        Point2(300, 500),
        Point2(500, 300),
        Point2(300, 400),
      ]);

      expect(classifier.classify(stroke), isA<DiscardedIntent>());
    });
  });

  test('classification is deterministic', () {
    // The same drawing must always be read the same way: these users were
    // promised a tool, not a model that changes its mind (spec section 1).
    final classifier = StrokeClassifier(frame: frame, panels: [wholeFrame()]);
    final stroke = handDrawn(const [Point2(600, 40), Point2(610, 860)]);

    final first = classifier.classify(stroke);
    final second = classifier.classify(stroke);

    expect(first.runtimeType, second.runtimeType);
    expect(
      (first as VerticalDividerIntent).atX,
      (second as VerticalDividerIntent).atX,
    );
  });
}
