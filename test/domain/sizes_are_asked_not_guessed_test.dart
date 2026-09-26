import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// A hand drawing has proportions and no scale, so a size read off it is a
// guess. The user's words: *never write any number for width and height as
// a guess — ask the width and height of everything: the border, the opening
// part, the glass, a line in the opening.* And: *when we change the numbers
// and apply it, it doesn't change to the new one.*
//
// That last one was two faults. The overall width and height scaled the
// whole design in proportion, so typing the height undid the width just
// typed. And a size moved the geometry but not the ink it was read from, so
// the next reading of the sheet — **Read again**, or reading after drawing
// anything — built the design from the ink and every typed size was gone.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      // A little wobble, as a hand draws.
      final at = through[leg].lerp(through[leg + 1], i / 24);
      final wobble = ((i * 7919) % 11 - 5) * 0.6;
      samples.add(StrokeSample(Vec2(at.x + wobble, at.y - wobble)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A door: a line across it, and a `>` in the light below.
Design door() => Design(
  id: 'door',
  name: 'Door',
  kind: DesignKind.door,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  measured: const {},
  sketch: Sketch(
    strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(1000, 0),
        Vec2(1000, 2000),
        Vec2(0, 2000),
        Vec2(0, 0),
      ]),
      pen('mark', const [Vec2(200, 1200), Vec2(800, 1500), Vec2(200, 1800)]),
      pen('line', const [Vec2(0, 900), Vec2(1000, 900)]),
    ],
  ),
);

/// A window of three lights across, the middle one marked.
Design window() => Design(
  id: 'window',
  name: 'Window',
  kind: DesignKind.window,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  measured: const {},
  sketch: Sketch(
    strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(3000, 0),
        Vec2(3000, 1500),
        Vec2(0, 1500),
        Vec2(0, 0),
      ]),
      pen('left', const [Vec2(900, 0), Vec2(900, 1500)]),
      pen('right', const [Vec2(2100, 0), Vec2(2100, 1500)]),
      pen('mark', const [Vec2(1250, 400), Vec2(1750, 750), Vec2(1250, 1100)]),
    ],
  ),
);

Design read(Design design) => Measurements.keepAfterReading(
  design,
  SketchInterpreter.interpret(design).design,
);

Measure measureOf(Design design, bool Function(Measure) where) =>
    Measurements.of(design).firstWhere(where);

void main() {
  group('nothing is written until it is given', () {
    test('a design just read knows none of its sizes', () {
      final d = read(door());
      expect(d.frame, isNotNull);
      expect(Measurements.complete(d), isFalse);
      for (final m in Measurements.of(d)) {
        expect(Measurements.knows(d, m), isFalse, reason: m.key);
      }
      expect(Measurements.figure(123, known: false), '? cm');
      expect(Measurements.overallOf(d), '? × ? cm');
    });

    test('everything is asked: the border, the bars, the size, each light '
        'and what follows from them', () {
      final d = read(door());
      final keys = [for (final m in Measurements.of(d)) m.key];
      expect(keys.take(4), [
        Measurements.profileKey,
        Measurements.barsKey,
        Measurements.widthKey,
        Measurements.heightKey,
      ]);
      // Two lights, each a width and a height.
      expect(
        Measurements.of(d).where((m) => m.sectionId != null),
        hasLength(4),
      );
      // The line across the door is the one thing a light's height can
      // move, so it is asked once; the other height follows.
      final heights = Measurements.of(d)
          .where((m) => m.axis == MeasureAxis.down)
          .toList();
      expect(heights.where((m) => m.asked), hasLength(1));
      expect(heights.where((m) => m.follows), hasLength(1));
    });

    test('a design kept before sizes were asked for shows every figure', () {
      final d = read(door().copyWith()).copyWith();
      final legacy = Design.fromJson({...d.toJson()}..remove('measured'));
      expect(legacy.measured, isNull);
      expect(Measurements.complete(legacy), isTrue);
      expect(Measurements.knowsOverall(legacy, MeasureAxis.across), isTrue);
    });
  });

  group('a size given is the size', () {
    test('the frame, the bars and a light, exactly', () {
      final d = read(door());
      final top = measureOf(d, (m) => m.asked && m.axis == MeasureAxis.down);
      final out = Measurements.apply(d, {
        Measurements.profileKey: 60,
        Measurements.barsKey: 50,
        Measurements.widthKey: 900,
        Measurements.heightKey: 2100,
        top.key: 500,
      });
      expect(out.problems, isEmpty);
      final m = out.design;
      expect(m.widthMm, closeTo(900, 0.01));
      expect(m.heightMm, closeTo(2100, 0.01));
      expect(m.frame!.profileMm, 60);
      expect(m.dividers.single.widthMm, 50);
      final lights = [...m.topLevelSections]
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      expect(lights.first.heightMm, closeTo(500, 0.01));
      // What follows is what is left: 2100 less the frame top and bottom,
      // the bar and the light above.
      expect(lights.last.heightMm, closeTo(2100 - 120 - 50 - 500, 0.01));
      expect(lights.first.widthMm, closeTo(900 - 120, 0.01));
      expect(Measurements.complete(m), isTrue);
      for (final measure in Measurements.of(m)) {
        expect(Measurements.knows(m, measure), isTrue, reason: measure.key);
      }
    });

    test('the width is the width alone, and the height the height alone', () {
      var d = Measurements.apply(read(door()), {
        Measurements.widthKey: 900,
        Measurements.heightKey: 2100,
      }).design;
      d = Measurements.apply(d, {Measurements.widthKey: 1200}).design;
      expect(d.widthMm, closeTo(1200, 0.01));
      expect(d.heightMm, closeTo(2100, 0.01), reason: 'the height stays');
      d = Measurements.apply(d, {Measurements.heightKey: 1950}).design;
      expect(d.heightMm, closeTo(1950, 0.01));
      expect(d.widthMm, closeTo(1200, 0.01), reason: 'the width stays');
    });

    test('a light given its width moves only the bar beside it', () {
      final d = read(window());
      final lights = Measurements.of(d)
          .where((m) => m.axis == MeasureAxis.across && m.sectionId != null);
      final asked = lights.where((m) => m.asked).toList();
      final follows = lights.where((m) => m.follows).toList();
      // Three lights across, two bars between them: two widths are free,
      // and the third is what is left.
      expect(asked, hasLength(2));
      expect(follows, hasLength(1));

      final out = Measurements.apply(d, {
        Measurements.profileKey: 50,
        Measurements.barsKey: 40,
        Measurements.widthKey: 3000,
        Measurements.heightKey: 1500,
        asked[0].key: 700,
        asked[1].key: 1300,
      });
      expect(out.problems, isEmpty);
      final widths = [
        for (final s in [
          ...out.design.topLevelSections,
        ]..sort((a, b) => a.outline.left.compareTo(b.outline.left)))
          s.widthMm,
      ];
      expect(widths[0], closeTo(700, 0.01));
      expect(widths[1], closeTo(1300, 0.01));
      expect(widths[2], closeTo(3000 - 100 - 80 - 700 - 1300, 0.01));
      // The mark is still in the light it was drawn in.
      final opening = out.design.openings.single;
      final marked = out.design.sectionById(opening.sectionId)!;
      expect(marked.widthMm, closeTo(1300, 0.01));
    });

    test('a size that cannot fit is refused and says why', () {
      final d = read(window());
      final first = measureOf(
        d,
        (m) => m.asked && m.axis == MeasureAxis.across && m.sectionId != null,
      );
      final out = Measurements.apply(d, {first.key: 5000});
      expect(out.problems.keys, [first.key]);
      expect(out.design.measured, isNot(contains(first.key)));
    });
  });

  group('a size outlasts the next reading', () {
    Design measured() {
      final d = read(door());
      final top = measureOf(d, (m) => m.asked && m.axis == MeasureAxis.down);
      return Measurements.apply(d, {
        Measurements.profileKey: 60,
        Measurements.barsKey: 50,
        Measurements.widthKey: 900,
        Measurements.heightKey: 2100,
        top.key: 500,
      }).design;
    }

    test('reading the sheet again builds the same sizes', () {
      final before = measured();
      final again = read(before);
      expect(again.widthMm, closeTo(before.widthMm, 0.01));
      expect(again.heightMm, closeTo(before.heightMm, 0.01));
      expect(again.measured, before.measured);
      final sizes = [
        for (final s in before.topLevelSections) (s.widthMm, s.heightMm),
      ];
      final sizesAgain = [
        for (final s in again.topLevelSections) (s.widthMm, s.heightMm),
      ];
      for (var i = 0; i < sizes.length; i++) {
        expect(sizesAgain[i].$1, closeTo(sizes[i].$1, 0.01));
        expect(sizesAgain[i].$2, closeTo(sizes[i].$2, 0.01));
      }
    });

    test('because the ink moved with the lines it made', () {
      final before = measured();
      // Read with nothing kept at all: the ink alone gives the sizes back.
      final raw = SketchInterpreter.interpret(before).design;
      expect(raw.widthMm, closeTo(900, 1));
      expect(raw.heightMm, closeTo(2100, 1));
      final top = [...raw.topLevelSections]
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      expect(top.first.heightMm, closeTo(500, 1));
    });

    test('a line drawn afterwards asks only for its own new size', () {
      final before = measured();
      final opening = before.openings.single;
      final light = before.sectionById(opening.sectionId)!;
      final y = light.outline.top + light.heightMm * 0.4;
      final drawn = before.copyWith(
        sketch: Sketch(
          strokes: [
            ...before.sketch.strokes,
            pen('inside', [
              Vec2(light.outline.left - 20, y),
              Vec2(light.outline.right + 20, y),
            ]),
          ],
        ),
      );
      final after = read(drawn);
      // Everything given is still given…
      expect(after.measured, containsAll(before.measured!));
      expect(after.widthMm, closeTo(900, 0.01));
      // …and the one new size is asked for.
      final outstanding = [
        for (final m in Measurements.of(after))
          if (m.asked && !after.measured!.contains(m.key)) m,
      ];
      expect(outstanding, hasLength(1));
      expect(outstanding.single.axis, MeasureAxis.down);
      expect(Measurements.complete(after), isFalse);
    });
  });
}
