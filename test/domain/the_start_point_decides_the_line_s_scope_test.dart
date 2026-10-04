import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The user's words: *before completing any line, determine where the user
// started it. If the start point is inside Opening #1, the line is Opening
// #1's; inside the main design but outside every opening, it is the main
// design's. Not the nearest line, not the largest rectangle, not the overall
// drawing bounds — the starting point determines the scope.*
//
// ┌────────┬────────┬────────┐
// │   >    │        │   >    │
// │ Open 1 │  MAIN  │ Open 2 │
// │ ───    │  ───   │   ───  │
// └────────┴────────┴────────┘

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

List<Vec2> chevron(Vec2 at) => [
  Vec2(at.x - 150, at.y - 220),
  Vec2(at.x + 150, at.y),
  Vec2(at.x - 150, at.y + 220),
];

/// A main design of three lights, the outer two marked `>` and read — two
/// openings that exist before any line is drawn, as they do for the user.
Design twoOpenings() => SketchInterpreter.interpret(
  Design(
    id: 'd',
    name: 'Design',
    kind: DesignKind.door,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sketch: Sketch(
      strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(2400, 0),
          Vec2(2400, 2100),
          Vec2(0, 2100),
          Vec2(0, 0),
        ]),
        pen('left', const [Vec2(800, 0), Vec2(800, 2100)]),
        pen('right', const [Vec2(1600, 0), Vec2(1600, 2100)]),
        pen('one', chevron(const Vec2(400, 700))),
        pen('two', chevron(const Vec2(2000, 700))),
      ],
    ),
  ),
).design;

Design drawn(Design design, List<Stroke> lines) => SketchInterpreter.interpret(
  design.copyWith(
    sketch: Sketch(strokes: [...design.sketch.strokes, ...lines]),
  ),
).design;

DividerElement line(Design d, String strokeId) =>
    d.dividers.firstWhere((b) => b.fromStrokeId == strokeId);

List<double> xs(DividerElement b) => [b.a.x, b.b.x]..sort();

String openingsOf(Design d) => jsonEncode([
  for (final o in d.openings)
    {'opening': o.toJson(), 'outline': d.sectionById(o.sectionId)!.outline},
]);

void main() {
  late Design before;
  late OpeningElement one;
  late OpeningElement two;
  setUp(() {
    before = twoOpenings();
    expect(before.openings, hasLength(2));
    one = before.openings.firstWhere((o) => o.id == 'opening-one');
    two = before.openings.firstWhere((o) => o.id == 'opening-two');
  });

  test('the user\'s test: a line started in Opening #1 is Opening #1\'s, one '
      'started in Opening #2 is Opening #2\'s, and one started outside both '
      'is the main design\'s', () {
    final after = drawn(before, [
      pen('in-one', const [Vec2(300, 1300), Vec2(600, 1300)]),
      pen('in-two', const [Vec2(1900, 1300), Vec2(2200, 1300)]),
      pen('in-main', const [Vec2(1100, 1300), Vec2(1300, 1300)]),
    ]);

    expect(line(after, 'in-one').parentId, one.id);
    expect(line(after, 'in-two').parentId, two.id);
    expect(line(after, 'in-main').parentId, isNull);

    // Each is completed inside its own area and no further.
    final regionOne = before.sectionById(one.sectionId)!.outline;
    final regionTwo = before.sectionById(two.sectionId)!.outline;
    expect(xs(line(after, 'in-one')).first, closeTo(regionOne.left, 1));
    expect(xs(line(after, 'in-one')).last, closeTo(regionOne.right, 1));
    expect(xs(line(after, 'in-two')).first, closeTo(regionTwo.left, 1));
    expect(xs(line(after, 'in-two')).last, closeTo(regionTwo.right, 1));
    // The main design's line, to the main design's first lines: the two
    // mullions either side of the light it was started in.
    expect(xs(line(after, 'in-main')).first, closeTo(800, 1));
    expect(xs(line(after, 'in-main')).last, closeTo(1600, 1));

    // Neither opening moved or changed size.
    expect(openingsOf(after), openingsOf(before));
    // Each opening holds its own two panes, and the main design one more
    // light than it had.
    expect(after.childSectionsOf(one.sectionId), hasLength(2));
    expect(after.childSectionsOf(two.sectionId), hasLength(2));
    expect(
      after.topLevelSections,
      hasLength(before.topLevelSections.length + 1),
    );
  });

  group('the start decides, not what the line does afterwards', () {
    test('started in Opening #1 and run across the mullion, it is still '
        'Opening #1\'s — and stays inside Opening #1', () {
      final after = drawn(before, [
        pen('over', const [Vec2(300, 1300), Vec2(1200, 1300)]),
      ]);
      final over = line(after, 'over');
      expect(over.parentId, one.id);
      final region = before.sectionById(one.sectionId)!.outline;
      expect(xs(over).first, closeTo(region.left, 1));
      expect(xs(over).last, closeTo(region.right, 1));
      expect(openingsOf(after), openingsOf(before));
    });

    test('started in the main design and run into Opening #2, it is the '
        'main design\'s', () {
      final after = drawn(before, [
        pen('into', const [Vec2(1100, 1300), Vec2(1800, 1300)]),
      ]);
      expect(line(after, 'into').parentId, isNull);
    });

    test('started in Opening #2 right beside the mullion it shares with the '
        'main design — not the nearest line\'s area, the start\'s', () {
      final after = drawn(before, [
        pen('beside', const [Vec2(1690, 1300), Vec2(1900, 1300)]),
      ]);
      expect(line(after, 'beside').parentId, two.id);
    });

    test('drawn the other way — from the far end back towards the start — '
        'the start is still what decides', () {
      final after = drawn(before, [
        pen('back', const [Vec2(1300, 1500), Vec2(900, 1500)]),
      ]);
      expect(line(after, 'back').parentId, isNull);
      final after2 = drawn(before, [
        pen('back', const [Vec2(600, 1500), Vec2(250, 1500)]),
      ]);
      expect(line(after2, 'back').parentId, one.id);
    });
  });

  group('a start on an edge', () {
    test('from the frame into Opening #1, stopped short inside it: Opening '
        '#1\'s', () {
      final after = drawn(before, [
        pen('rail', const [Vec2(0, 1300), Vec2(500, 1300)]),
      ]);
      expect(line(after, 'rail').parentId, one.id);
      expect(openingsOf(after), openingsOf(before));
    });

    test('from the frame right across the design: the main design\'s', () {
      final after = drawn(before, [
        pen('across', const [Vec2(0, 1300), Vec2(2400, 1300)]),
      ]);
      expect(line(after, 'across').parentId, isNull);
    });
  });

  test('on a first reading there are no openings, so every line is the main '
      'design\'s', () {
    final first = SketchInterpreter.interpret(
      Design(
        id: 'd',
        name: 'Design',
        kind: DesignKind.door,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        sketch: Sketch(
          strokes: [
            ...before.sketch.strokes,
            pen('in-one', const [Vec2(300, 1300), Vec2(600, 1300)]),
          ],
        ),
      ),
    ).design;
    expect(line(first, 'in-one').parentId, isNull);
  });

  test('the scopes outlast a second reading of the sheet', () {
    final once = drawn(before, [
      pen('in-one', const [Vec2(300, 1300), Vec2(600, 1300)]),
      pen('in-two', const [Vec2(1900, 1300), Vec2(2200, 1300)]),
      pen('in-main', const [Vec2(1100, 1300), Vec2(1300, 1300)]),
    ]);
    final twice = SketchInterpreter.interpret(once).design;
    for (final id in ['in-one', 'in-two', 'in-main']) {
      expect(
        jsonEncode(line(twice, id).toJson()),
        jsonEncode(line(once, id).toJson()),
      );
    }
    expect(openingsOf(twice), openingsOf(before));
  });
}
