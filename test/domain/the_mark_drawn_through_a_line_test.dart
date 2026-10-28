import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// A door with a rail across it and a `>` drawn over the whole leaf.
//
//   ┌─────────────────┐
//   │ ╲               │
//   ├───╲─────────────┤   ← the rail
//   │     ╲     ╱     │
//   │       ╳         │   ← the `>`, drawn over the whole leaf
//   │     ╱     ╲     │
//   └─────────────────┘
//
// One leaf with a rail in it. Not two lights with only the lower one
// opening — the user drew the mark straight through the line, which says
// the line is inside the thing being marked.
//
// **Through, not into.** A mark whose point pokes a few millimetres past a
// mullion and stops there has strayed over it, not crossed it, and
// `the_mark_picks_one_face_test.dart` holds that case the other way. The
// difference is whether the arm carries on out of whatever is on the far
// side or ends inside it — a relationship, not a size.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

Design door({required List<Vec2> mark, List<Vec2>? rail}) =>
    SketchInterpreter.interpret(Design(
      id: 'd',
      name: 'Door',
      kind: DesignKind.door,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1030, 0),
          Vec2(1030, 1264),
          Vec2(0, 1264),
          Vec2(0, 0),
        ]),
        if (rail != null) pen('rail', rail),
        pen('mark', mark),
      ]),
    )).design;

/// The `>` the user drew: over the whole leaf, corner to corner.
const overTheWholeLeaf = [
  Vec2(20, 20),
  Vec2(1010, 640),
  Vec2(20, 1244),
];

const railRightAcross = [Vec2(0, 570), Vec2(1030, 570)];

void main() {
  test('the door is one leaf, and the rail is in it', () {
    final design = door(mark: overTheWholeLeaf, rail: railRightAcross);

    expect(design.topLevelSections, hasLength(1),
        reason: 'one leaf, not two lights');
    expect(design.topLevelDividers, isEmpty,
        reason: 'the rail is not a bar of the door');
    expect(design.openings, hasLength(1));

    final opening = design.openings.single;
    expect(opening.markGlyph, '>');

    final bar = design.dividers.single;
    expect(design.openingHolding(bar.parentId)?.id, opening.id,
        reason: 'the rail is the leaf’s');
    expect(DesignTree.of(design).openings.single.barIds, [bar.id]);
    expect(design.childSectionsOf(opening.sectionId), hasLength(2),
        reason: 'the rail divides the leaf into two');
  });

  test('the leaf is the whole daylight, and the frame is not the opening',
      () {
    final design = door(mark: overTheWholeLeaf, rail: railRightAcross);
    final leaf = design.sectionById(design.openings.single.sectionId)!;
    final daylight = design.frame!.innerOutline;

    expect(leaf.outline.width, closeTo(daylight.width, 0.01));
    expect(leaf.outline.height, closeTo(daylight.height, 0.01));
    // The root is never the opening: it is a section that opens, and the
    // frame is not a section.
    expect(design.openings.single.sectionId, isNot(design.frame!.id));
    expect(design.sectionById(design.frame!.id), isNull);
  });

  test('the same door without the rail reads the same way', () {
    final design = door(mark: overTheWholeLeaf);
    expect(design.topLevelSections, hasLength(1));
    expect(design.openings, hasLength(1));
    expect(design.dividers, isEmpty);
  });

  group('into is not through', () {
    test('a mark that stops inside the far light leaves the bar alone', () {
      // The arms run over the rail, but the point stops well inside the
      // lower half rather than carrying on out of it.
      final design = door(
        rail: railRightAcross,
        mark: const [Vec2(300, 300), Vec2(600, 700), Vec2(300, 1100)],
      );

      expect(design.topLevelDividers, hasLength(1),
          reason: 'the rail still divides the door');
      expect(design.topLevelSections, hasLength(2));
      expect(design.dividers.single.parentId, isNull);
    });

    test('a mark drawn clear of the rail leaves it alone', () {
      final design = door(
        rail: railRightAcross,
        mark: const [Vec2(300, 800), Vec2(500, 950), Vec2(300, 1100)],
      );

      expect(design.topLevelDividers, hasLength(1));
      expect(design.dividers.single.parentId, isNull);
      expect(design.topLevelSections, hasLength(2));
      // And it opened the half it was drawn in.
      final opened =
          design.sectionById(design.openings.single.sectionId)!.outline;
      expect(opened.contains(const Vec2(500, 950)), isTrue);
    });
  });

  test('it reads the same way every time, and survives a reading again', () {
    var design = door(mark: overTheWholeLeaf, rail: railRightAcross);
    final openingId = design.openings.single.id;
    final barId = design.dividers.single.id;

    for (var i = 0; i < 3; i++) {
      design = SketchInterpreter.interpret(design).design;
      expect(design.openings.single.id, openingId, reason: 'reading ${i + 1}');
      expect(design.topLevelSections, hasLength(1), reason: 'reading ${i + 1}');
      expect(design.dividerById(barId), isNotNull, reason: 'reading ${i + 1}');
      expect(design.openingHolding(design.dividerById(barId)!.parentId)?.id,
          openingId,
          reason: 'reading ${i + 1}');
    }
  });
}
