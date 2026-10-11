import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/recognition/stroke_fit.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// Pausing with the pen down straightens the line just drawn.
//
// **What snaps on the screen is exactly what gets built.** The straightening
// is `StrokeFitter.fit` — the same corners the design is read from — drawn
// back onto the sheet. So the wobble along each run comes out, every corner
// the user drew stays at its angle, both ends stay where the pen put them,
// and nothing is invented for the look of it.

Stroke shaky(List<Vec2> through, {double wobble = 6, int seed = 3}) {
  final random = math.Random(seed);
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 40; i++) {
      final at = through[leg].lerp(through[leg + 1], i / 40);
      final edge = i == 0 && leg == 0;
      samples.add(
        StrokeSample(
          edge
              ? at
              : Vec2(
                  at.x + (random.nextDouble() - 0.5) * wobble,
                  at.y + (random.nextDouble() - 0.5) * wobble,
                ),
        ),
      );
    }
  }
  samples.add(StrokeSample(through.last));
  return Stroke(id: 's', samples: samples);
}

double offTheLine(Vec2 p, Vec2 a, Vec2 b) {
  final d = b - a;
  return (d.cross(p - a) / d.length).abs();
}

void main() {
  group('a line', () {
    test('comes out as its two ends, exactly where the pen put them', () {
      const from = Vec2(100, 100);
      const to = Vec2(900, 400);
      final corners = StrokeFitter.straightRuns(shaky(const [from, to]))!;
      expect(corners, [from, to]);
    });

    test('keeps the angle it was drawn at', () {
      // Twenty degrees is a slope, not a hand, and it stays a slope.
      const from = Vec2(0, 0);
      final to = Vec2(800 * math.cos(0.35), 800 * math.sin(0.35));
      final corners = StrokeFitter.straightRuns(shaky([from, to]))!;
      final angle = math.atan2(
        corners.last.y - corners.first.y,
        corners.last.x - corners.first.x,
      );
      expect(angle, closeTo(0.35, 1e-9));
    });

    test('two degrees off level is squared, as the reading squares it', () {
      const from = Vec2(0, 300);
      final to = Vec2(900, 300 + 900 * math.tan(2 * math.pi / 180));
      final corners = StrokeFitter.straightRuns(shaky([from, to]))!;
      expect(corners.first.y, closeTo(corners.last.y, 1e-9));
      // About its middle, so neither end is the one that moved.
      expect(corners.first.y, closeTo((from.y + to.y) / 2, 1e-9));
    });
  });

  group('a shape of several runs', () {
    test('keeps every corner the user drew, and only those', () {
      const corners = [Vec2(0, 0), Vec2(0, 1000), Vec2(700, 1000)];
      final straight = StrokeFitter.straightRuns(shaky(corners))!;
      expect(straight, hasLength(3));
      expect(straight.first, corners.first);
      expect(straight.last, corners.last);
      expect(
        straight[1].distanceTo(corners[1]),
        lessThan(10),
        reason: 'the corner is where it was drawn, give or take the shake',
      );
    });

    test('a box closes back on itself', () {
      final straight = StrokeFitter.straightRuns(
        shaky(const [
          Vec2(0, 0),
          Vec2(1200, 0),
          Vec2(1200, 1500),
          Vec2(0, 1500),
          Vec2(3, 2),
        ]),
      )!;
      expect(straight.first, straight.last, reason: 'closed');
      expect(straight, hasLength(5), reason: 'four corners, four runs');
    });

    test('a > comes out as the chevron it is, point and all', () {
      const mark = [Vec2(0, 0), Vec2(300, 200), Vec2(0, 400)];
      final straight = StrokeFitter.straightRuns(shaky(mark, wobble: 4))!;
      expect(straight, hasLength(3));
      expect(straight[1].distanceTo(mark[1]), lessThan(8));
    });

    test('every sample of the result lies on one of its runs', () {
      final straight = StrokeFitter.straightRuns(
        shaky(const [Vec2(0, 0), Vec2(0, 1000), Vec2(700, 1000)]),
      )!;
      final ink = StrokeFitter.samplesAlong(straight, spacingMm: 20);
      for (final sample in ink) {
        var nearest = double.infinity;
        for (var i = 1; i < straight.length; i++) {
          nearest = math.min(
            nearest,
            offTheLine(sample.at, straight[i - 1], straight[i]),
          );
        }
        expect(nearest, lessThan(1e-6));
      }
    });
  });

  group('and nothing is invented', () {
    test('a dot or a scribble is left as it was', () {
      final dot = Stroke(
        id: 'dot',
        samples: const [StrokeSample(Vec2(10, 10)), StrokeSample(Vec2(11, 10))],
      );
      expect(StrokeFitter.straightRuns(dot), isNull);
    });

    test('the straightened line is the line the design reads', () {
      // The whole point: straightening shows the reading, it does not make
      // a different one. The fit of the straightened ink is the fit of the
      // hand-drawn ink.
      final hand = shaky(const [Vec2(0, 0), Vec2(0, 1000), Vec2(700, 1000)]);
      final straight = StrokeFitter.straightRuns(hand)!;
      final again = StrokeFitter.fit(
        Stroke(
          id: 'again',
          samples: StrokeFitter.samplesAlong(straight, spacingMm: 15),
        ),
      );
      expect(again.vertices, hasLength(straight.length));
      for (var i = 0; i < straight.length; i++) {
        expect(again.vertices[i].distanceTo(straight[i]), lessThan(1e-6));
      }
    });
  });

  group('laid down as ink', () {
    test('every corner kept exactly, and no gap wider than asked', () {
      const corners = [Vec2(0, 0), Vec2(500, 0), Vec2(500, 333)];
      final ink = StrokeFitter.samplesAlong(corners, spacingMm: 40);
      expect(ink.first.at, corners.first);
      expect(ink.last.at, corners.last);
      expect(ink.map((s) => s.at), contains(corners[1]));
      for (var i = 1; i < ink.length; i++) {
        expect(ink[i - 1].at.distanceTo(ink[i].at), lessThanOrEqualTo(40));
      }
    });
  });
}
