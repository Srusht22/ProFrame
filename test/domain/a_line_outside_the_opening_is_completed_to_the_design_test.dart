import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The user's words: *if the user starts a line outside an opening but inside
// the overall design, complete it to the boundary of that surrounding design
// area. Do not extend the line through the opening, and do not use the
// opening's boundary for it: the line belongs to the surrounding design.*
//
// ┌────────────────────────────┐        ┌────────────────────────────┐
// │      ┌──────────┐          │        │      ┌──────────┐          │
// │      │ ──── >   │          │        │      │──────────│          │
// │      └──────────┘          │   →    │      └──────────┘          │
// │──────                      │        │────────────────────────────│
// └────────────────────────────┘        └────────────────────────────┘

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// The user's picture: a 200 × 210 cm design with a box drawn in it, the box
/// marked `>` and read — so the opening is there before anything else is
/// drawn, as it is for the user.
Design withOpening() => SketchInterpreter.interpret(
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
          Vec2(2000, 0),
          Vec2(2000, 2100),
          Vec2(0, 2100),
          Vec2(0, 0),
        ]),
        pen('box', const [
          Vec2(500, 300),
          Vec2(1300, 300),
          Vec2(1300, 900),
          Vec2(500, 900),
          Vec2(500, 300),
        ]),
        pen('mark', const [Vec2(900, 450), Vec2(1150, 600), Vec2(900, 750)]),
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
List<double> ys(DividerElement b) => [b.a.y, b.b.y]..sort();

String openingOf(Design d) {
  final opening = d.openings.single;
  return jsonEncode({
    'opening': opening.toJson(),
    'outline': d.sectionById(opening.sectionId)!.outline.toJson(),
  });
}

void main() {
  test('the user\'s test: one line inside the opening completes inside it, '
      'one outside completes to the design', () {
    final before = withOpening();
    final opening = before.openings.single;
    final region = before.sectionById(opening.sectionId)!.outline;

    final after = drawn(before, [
      pen('inside', const [Vec2(500, 600), Vec2(800, 600)]),
      pen('outside', const [Vec2(0, 1400), Vec2(700, 1400)]),
    ]);

    // Inside line → completes inside the opening: the opening's own line,
    // from its edge to its edge, and no further.
    final inside = line(after, 'inside');
    expect(inside.parentId, opening.id);
    expect(xs(inside).first, closeTo(region.left, 1));
    expect(xs(inside).last, closeTo(region.right, 1));
    expect(inside.a.y, closeTo(600, 1));

    // Outside line → completes inside the surrounding design: a line of the
    // design, from the frame to the frame.
    final outside = line(after, 'outside');
    expect(outside.parentId, isNull);
    expect(xs(outside).first, closeTo(0, 1));
    expect(xs(outside).last, closeTo(2000, 1));
    expect(outside.a.y, closeTo(1400, 1));
    expect(outside.b.y, closeTo(1400, 1));
    // It does not touch the opening at all.
    for (final edge in region.edges) {
      expect(Segment(outside.a, outside.b).crossing(edge), isNull);
    }

    // The opening is exactly as it was.
    expect(openingOf(after), openingOf(before));
  });

  test('a line of the design heading for the opening stops at its edge and '
      'is not carried through it', () {
    final before = withOpening();
    final after = drawn(before, [
      // Up from the sill, straight at the underside of the opening.
      pen('upright', const [Vec2(900, 2100), Vec2(900, 1500)]),
    ]);
    final upright = line(after, 'upright');
    expect(upright.parentId, isNull);
    expect(ys(upright).last, closeTo(2100, 1));
    expect(
      ys(upright).first,
      closeTo(900, 1),
      reason: 'the edge of the surrounding design in that direction',
    );
    expect(openingOf(after), openingOf(before));
  });

  test('from the left jamb towards the opening, it stops where the opening '
      'begins', () {
    final before = withOpening();
    final after = drawn(before, [
      pen('rail', const [Vec2(0, 1000), Vec2(300, 1000)]),
      pen('level', const [Vec2(0, 600), Vec2(250, 600)]),
    ]);
    // Below the opening: nothing in the way, so frame to frame.
    final rail = line(after, 'rail');
    expect(xs(rail).first, closeTo(0, 1));
    expect(xs(rail).last, closeTo(2000, 1));
    // Level with the opening: the opening is in the way, so to its edge.
    final level = line(after, 'level');
    expect(level.parentId, isNull);
    expect(xs(level).first, closeTo(0, 1));
    expect(xs(level).last, closeTo(500, 1));
    expect(openingOf(after), openingOf(before));
  });

  test('an end the hand carried into the opening is left where it was '
      'drawn, not run on across the opening', () {
    final before = withOpening();
    final after = drawn(before, [
      pen('into', const [Vec2(0, 820), Vec2(700, 820)]),
    ]);
    final into = line(after, 'into');
    expect(into.parentId, isNull, reason: 'started outside: the design\'s');
    expect(xs(into).first, closeTo(0, 1));
    expect(xs(into).last, closeTo(700, 1), reason: 'where the hand stopped');
  });

  test('the lines outlast a second reading of the sheet', () {
    final before = withOpening();
    final once = drawn(before, [
      pen('inside', const [Vec2(500, 600), Vec2(800, 600)]),
      pen('outside', const [Vec2(0, 1400), Vec2(700, 1400)]),
    ]);
    final twice = SketchInterpreter.interpret(once).design;
    for (final id in ['inside', 'outside']) {
      expect(
        jsonEncode(line(twice, id).toJson()),
        jsonEncode(line(once, id).toJson()),
      );
    }
    expect(openingOf(twice), openingOf(before));
  });
}
