import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The user's words: *if the user starts a line inside an opening and stops
// early, complete it to the opening's boundary. Do not expand, move or
// resize the opening — only extend the line. The completed line must remain
// inside the opening.*
//
// ┌──────────┬───────┐        ┌──────────┬───────┐
// │    >     │       │        │    >     │       │
// │──────    │ FIXED │   →    │──────────│ FIXED │
// │          │       │        │          │       │
// └──────────┴───────┘        └──────────┴───────┘

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

/// A window with a mullion, the left light marked `>` and read — the
/// opening exists before the line is drawn, as it does for the user.
Design withOpening({bool mullion = true}) => SketchInterpreter.interpret(
  Design(
    id: 'w',
    name: 'Window',
    kind: DesignKind.door,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sketch: Sketch(
      strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1600, 0),
          Vec2(1600, 2100),
          Vec2(0, 2100),
          Vec2(0, 0),
        ]),
        if (mullion) pen('mullion', const [Vec2(1000, 0), Vec2(1000, 2100)]),
        pen('mark', chevron(const Vec2(450, 700))),
      ],
    ),
  ),
).design;

/// [design] with [line] drawn on the sheet, and the sheet read again.
Design drawn(Design design, Stroke line) => SketchInterpreter.interpret(
  design.copyWith(sketch: Sketch(strokes: [...design.sketch.strokes, line])),
).design;

String openingOf(Design d) {
  final opening = d.openings.single;
  return jsonEncode({
    'opening': opening.toJson(),
    'outline': d.sectionById(opening.sectionId)!.outline.toJson(),
  });
}

String topLevelOf(Design d) => jsonEncode({
  'frame': d.frame!.toJson(),
  'bars': [for (final b in d.topLevelDividers) b.toJson()],
  'sections': [for (final s in d.topLevelSections) s.outline.toJson()],
});

void main() {
  test('a horizontal line started at the opening\'s jamb and stopped early '
      'reaches the opening\'s own boundary, and the opening is unchanged', () {
    final before = withOpening();
    final opening = before.openings.single;
    final region = before.sectionById(opening.sectionId)!.outline;

    final after = drawn(
      before,
      pen('rail', const [Vec2(0, 1300), Vec2(550, 1300)]),
    );

    final rail = after.dividers.firstWhere((d) => d.fromStrokeId == 'rail');
    // The opening's line, not the design's.
    expect(rail.parentId, opening.id);
    // Completed to the opening's boundary on both sides, and no further.
    final left = rail.a.x < rail.b.x ? rail.a : rail.b;
    final right = rail.a.x < rail.b.x ? rail.b : rail.a;
    expect(left.x, closeTo(region.left, 1));
    expect(right.x, closeTo(region.right, 1));
    expect(left.y, closeTo(1300, 1));
    expect(right.y, closeTo(1300, 1), reason: 'along its own line');
    // It remains inside the opening.
    expect(region.holds(Segment(rail.a, rail.b), reach: 1), isTrue);

    // The opening is not expanded, moved or resized.
    expect(openingOf(after), openingOf(before));
    // Nothing outside it changes: the frame, the mullion, the main parts.
    expect(topLevelOf(after), topLevelOf(before));
    // And inside it, the two panes the line makes.
    expect(after.childSectionsOf(opening.sectionId), hasLength(2));
  });

  test('drawn from the other side, it reaches the far jamb', () {
    final before = withOpening();
    final region = before
        .sectionById(before.openings.single.sectionId)!
        .outline;
    final after = drawn(
      before,
      pen('rail', const [Vec2(1000, 1300), Vec2(420, 1300)]),
    );
    final rail = after.dividers.firstWhere((d) => d.fromStrokeId == 'rail');
    expect(rail.parentId, before.openings.single.id);
    final xs = [rail.a.x, rail.b.x]..sort();
    expect(xs.first, closeTo(region.left, 1));
    expect(xs.last, closeTo(region.right, 1));
    expect(openingOf(after), openingOf(before));
  });

  test('a line started well inside and stopped short at both ends reaches '
      'both sides of the opening', () {
    final before = withOpening();
    final region = before
        .sectionById(before.openings.single.sectionId)!
        .outline;
    final after = drawn(
      before,
      pen('rail', const [Vec2(250, 1500), Vec2(700, 1500)]),
    );
    final rail = after.dividers.firstWhere((d) => d.fromStrokeId == 'rail');
    final xs = [rail.a.x, rail.b.x]..sort();
    expect(xs.first, closeTo(region.left, 1));
    expect(xs.last, closeTo(region.right, 1));
    expect(openingOf(after), openingOf(before));
  });

  test('a vertical line started inside the opening reaches its head and '
      'sill, not the frame beyond', () {
    final before = withOpening();
    final region = before
        .sectionById(before.openings.single.sectionId)!
        .outline;
    final after = drawn(
      before,
      pen('upright', const [Vec2(500, 2100), Vec2(500, 1200)]),
    );
    final upright = after.dividers.firstWhere(
      (d) => d.fromStrokeId == 'upright',
    );
    expect(upright.parentId, before.openings.single.id);
    final ys = [upright.a.y, upright.b.y]..sort();
    expect(ys.first, closeTo(region.top, 1));
    expect(ys.last, closeTo(region.bottom, 1));
    expect(openingOf(after), openingOf(before));
  });

  test('when the whole door is the one light, the line stops at the '
      'opening\'s edge — inside the frame, not on it', () {
    final before = withOpening(mullion: false);
    final region = before
        .sectionById(before.openings.single.sectionId)!
        .outline;
    final after = drawn(
      before,
      pen('rail', const [Vec2(0, 1300), Vec2(700, 1300)]),
    );
    final rail = after.dividers.firstWhere((d) => d.fromStrokeId == 'rail');
    expect(rail.parentId, before.openings.single.id);
    final xs = [rail.a.x, rail.b.x]..sort();
    expect(xs.first, closeTo(region.left, 1));
    expect(xs.last, closeTo(region.right, 1));
    expect(openingOf(after), openingOf(before));
    expect(topLevelOf(after), topLevelOf(before));
  });

  group('what does not join the opening stays as it was', () {
    test('a line started in the fixed light is completed there, and does '
        'not reach into the opening', () {
      final before = withOpening();
      final after = drawn(
        before,
        pen('fixed', const [Vec2(1600, 1300), Vec2(1300, 1300)]),
      );
      final line = after.dividers.firstWhere((d) => d.fromStrokeId == 'fixed');
      expect(line.parentId, isNull);
      final xs = [line.a.x, line.b.x]..sort();
      expect(xs.first, closeTo(1000, 1), reason: 'stops at the mullion');
      expect(openingOf(after), openingOf(before));
    });

    test('a line along the opening\'s jamb does not join it', () {
      final before = withOpening();
      final after = drawn(
        before,
        pen('along', const [Vec2(10, 300), Vec2(10, 1800)]),
      );
      final line = after.dividers.where((d) => d.fromStrokeId == 'along');
      for (final l in line) {
        expect(l.parentId, isNull);
      }
      expect(openingOf(after), openingOf(before));
    });

    test('the line outlasts a second reading, still inside the opening', () {
      final before = withOpening();
      final once = drawn(
        before,
        pen('rail', const [Vec2(0, 1300), Vec2(550, 1300)]),
      );
      final twice = SketchInterpreter.interpret(once).design;
      final a = once.dividers.firstWhere((d) => d.fromStrokeId == 'rail');
      final b = twice.dividers.firstWhere((d) => d.fromStrokeId == 'rail');
      expect(jsonEncode(b.toJson()), jsonEncode(a.toJson()));
      expect(openingOf(twice), openingOf(before));
    });
  });
}
