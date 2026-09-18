import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';

var _n = 0;

Stroke drawn(List<Vec2> through, {double wobble = 7}) {
  final random = math.Random(_n + 3);
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 16; i++) {
      final at = through[leg].lerp(through[leg + 1], i / 16);
      samples.add(StrokeSample(Vec2(
        at.x + (random.nextDouble() - 0.5) * wobble * 2,
        at.y + (random.nextDouble() - 0.5) * wobble * 2,
      )));
    }
  }
  samples.add(StrokeSample(through.last));
  return Stroke(id: 'stroke-${_n++}', samples: samples);
}

Design read(List<List<Vec2>> strokes) {
  _n = 0;
  final at = DateTime(2026);
  return SketchInterpreter.interpret(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    sketch: Sketch(strokes: [for (final v in strokes) drawn(v)]),
  )).design;
}

SectionElement openingOf(Design design) =>
    design.sectionById(design.openings.single.sectionId)!;

// The phase's design: an outer frame, three sections, one opening, three
// lines outside the opening and two inside it.
//
//   ┌─────────────────────────────┐
//   │            FIXED            │   ← two lines divide this one
//   ├──────────────┬──────────────┤
//   │      >       │              │
//   │   OPENING    │    FIXED     │   ← one line divides this one
//   │──────────────│              │
//   └──────────────┴──────────────┘
const frame = [
  Vec2(0, 0),
  Vec2(2400, 0),
  Vec2(2400, 1800),
  Vec2(0, 1800),
  Vec2(0, 0),
];
const transom = [Vec2(0, 700), Vec2(2400, 700)];
const mullion = [Vec2(1000, 700), Vec2(1000, 1800)];
const mark = [Vec2(560, 1050), Vec2(720, 1150), Vec2(560, 1250)];

// The three lines outside the opening: two dividing the fixed light above,
// one dividing the fixed light beside it.
const outsideA = [Vec2(800, 0), Vec2(800, 700)];
const outsideB = [Vec2(1600, 0), Vec2(1600, 700)];
const outsideC = [Vec2(1000, 1300), Vec2(2400, 1300)];

/// The drawing, with the two internal bars put in the opening by hand.
Design built() {
  final sheet =
      read([frame, transom, mullion, mark, outsideA, outsideB, outsideC]);

  final opening = sheet.openings.single.sectionId;
  final box = sheet.sectionById(opening)!.outline;
  final once = DesignEdits.addLineInside(sheet, opening,
      id: 'in-1',
      at: Vec2(box.centroid.x, box.top + box.height * 0.33),
      horizontal: true);
  return DesignEdits.addLineInside(once, opening,
      id: 'in-2',
      at: Vec2(box.centroid.x, box.top + box.height * 0.66),
      horizontal: true);
}

void main() {
  group('the phase’s own test', () {
    test('three lines outside, and the opening has none of them', () {
      final design = built();
      final opening = openingOf(design);

      // The three drawn lines plus the transom and the mullion all divide
      // the design. Not one of them is the opening's.
      expect(design.topLevelDividers, hasLength(5));
      for (final bar in design.topLevelDividers) {
        expect(bar.parentId, isNull);
      }

      final mine = design.childDividersOf(opening.id);
      expect(mine, hasLength(2), reason: 'only its own two');
      expect({for (final bar in mine) bar.id}, {'in-1', 'in-2'});
    });

    test('the two inside lines are inside, and lie within the opening', () {
      final design = built();
      final opening = openingOf(design);

      for (final bar in design.childDividersOf(opening.id)) {
        expect(design.sectionHolding(bar.parentId), opening.id);
        expect(
          opening.outline.holds(bar.segment, reach: DesignEdits.reachFor(bar)),
          isTrue,
          reason: '${bar.id} must lie within the opening it belongs to',
        );
      }
      expect(design.childSectionsOf(opening.id), hasLength(3));
    });

    test('the outside lines stay outside, doing their own work', () {
      final design = built();
      final opening = openingOf(design);

      // The fixed light above is cut into three by its two lines; the fixed
      // light beside the opening is cut into two by its one.
      expect(design.topLevelSections, hasLength(6));
      final fixed = [
        for (final section in design.topLevelSections)
          if (section.id != opening.id) section,
      ];
      expect(fixed, hasLength(5));
      for (final section in fixed) {
        expect(design.openingOf(section.id), isNull);
        expect(section.parentId, isNull);
        expect(design.hasChildren(section.id), isFalse);
      }
    });

    test('the opening is one section of the design, not the design', () {
      final design = built();
      final opening = openingOf(design);
      final daylight = design.frame!.innerOutline;

      expect(design.openings, hasLength(1));
      expect(opening.areaMmSq, lessThan(daylight.area * 0.3));
      expect(opening.outline.contains(const Vec2(620, 1150)), isTrue);

      // No line that divides the design runs through the inside of the
      // opening. The transom and the mullion lie along its edges — that is
      // what bounds it — but none of the five is within it.
      for (final bar in design.topLevelDividers) {
        expect(
          opening.outline.holds(bar.segment),
          isFalse,
          reason: '${bar.id} divides the design, not the opening',
        );
      }
      // And none of them is one of its children.
      final mine = {for (final bar in design.childDividersOf(opening.id)) bar.id};
      for (final bar in design.topLevelDividers) {
        expect(mine, isNot(contains(bar.id)));
      }
    });

    test('moving the opening moves its two lines and nothing else', () {
      final before = built();
      final opening = openingOf(before);
      final outside = {
        for (final bar in before.topLevelDividers)
          bar.id: '${bar.a}|${bar.b}',
      };

      // Widen the opening by moving the mullion beside it.
      final mullionId = before.topLevelDividers
          .firstWhere((b) => b.isVertical && b.segment.midpoint.y > 900)
          .id;
      final after = DesignEdits.moveDivider(before, mullionId, const Vec2(260, 0));

      // Its own two came with it, and still lie within it.
      final now = after.sectionById(opening.id)!;
      final mine = after.childDividersOf(opening.id);
      expect(mine, hasLength(2));
      for (final bar in mine) {
        expect(now.outline.holds(bar.segment, reach: DesignEdits.reachFor(bar)),
            isTrue);
      }

      // Every other line is where it was, except the one that was moved.
      for (final entry in outside.entries) {
        if (entry.key == mullionId) continue;
        final bar = after.dividers.firstWhere((b) => b.id == entry.key);
        expect('${bar.a}|${bar.b}', entry.value,
            reason: '${entry.key} is outside the opening');
      }
    });
  });

  group('what may be inside is judged by where it is, not by its middle', () {
    test('a bar reaching out of a section is not that section’s', () {
      final design = built();
      final opening = openingOf(design);
      final box = opening.outline;

      // Starting inside the opening and running well past its right edge.
      final crossing = DividerElement(
        id: 'crossing',
        a: Vec2(box.left + 20, box.centroid.y),
        b: Vec2(box.right + 600, box.centroid.y),
        widthMm: 40,
      );
      expect(
        box.holds(crossing.segment, reach: DesignEdits.reachFor(crossing)),
        isFalse,
      );
      // Its middle is inside all the same, which is why the middle is not
      // what is asked.
      expect(box.contains(crossing.segment.midpoint), isTrue);
    });

    test('a bar named by a section that has gone is not adopted by one it '
        'merely crosses', () {
      final design = built();
      final opening = openingOf(design);
      final box = opening.outline;

      final with_ = SectionBuilder.rebuild(design.copyWith(dividers: [
        ...design.dividers,
        DividerElement(
          id: 'orphan',
          a: Vec2(box.left + 20, box.centroid.y),
          b: Vec2(box.right + 600, box.centroid.y),
          widthMm: 40,
          parentId: 'a-section-that-is-gone',
        ),
      ]));

      final orphan = with_.dividers.firstWhere((b) => b.id == 'orphan');
      expect(orphan.parentId, isNull,
          reason: 'it crosses out of the opening, so it is not its');
      expect(with_.childDividersOf(opening.id), hasLength(2));
    });

    test('a line is never lost because the section holding it went away', () {
      final design = built();
      final opening = openingOf(design);
      final box = opening.outline;

      final with_ = SectionBuilder.rebuild(design.copyWith(dividers: [
        ...design.dividers,
        DividerElement(
          id: 'orphan',
          a: Vec2(box.left + 20, box.centroid.y),
          b: Vec2(box.right + 600, box.centroid.y),
          widthMm: 40,
          parentId: 'a-section-that-is-gone',
        ),
      ]));

      // It is still there, dividing the design, exactly where it was drawn.
      final orphan = with_.dividers.firstWhere((b) => b.id == 'orphan');
      expect(orphan.a.x, closeTo(box.left + 20, 0.01));
      expect(orphan.b.x, closeTo(box.right + 600, 0.01));
    });

    test('a bar along the opening’s own edge may still be put in it', () {
      final design = built();
      final opening = openingOf(design);
      final box = opening.outline;

      final onEdge = DividerElement(
        id: 'on-edge',
        a: Vec2(box.left, box.bottom),
        b: Vec2(box.right, box.bottom),
        widthMm: 40,
      );
      expect(
        box.holds(onEdge.segment, reach: DesignEdits.reachFor(onEdge)),
        isTrue,
        reason: 'a bar bounding a section is what the Divides control moves in',
      );
    });
  });

  group('nothing outside the opening is absorbed by it', () {
    test('a dimension outside it is neither owned nor moved', () {
      var design = built();
      design = design.copyWith(dimensions: const [
        DimensionElement(id: 'dim', a: Vec2(1200, 1600), b: Vec2(2300, 1600)),
      ]);
      final was = design.dimensions.single;

      final mullionId = design.topLevelDividers
          .firstWhere((b) => b.isVertical && b.segment.midpoint.y > 900)
          .id;
      final after =
          DesignEdits.moveDivider(design, mullionId, const Vec2(260, 0));

      final now = after.dimensions.single;
      expect(now.a, was.a);
      expect(now.b, was.b);
    });

    test('a note outside it is neither owned nor moved', () {
      var design = built();
      design = design.copyWith(texts: const [
        TextElement(id: 'note', text: 'Toughened', at: Vec2(1800, 1500)),
      ]);

      final mullionId = design.topLevelDividers
          .firstWhere((b) => b.isVertical && b.segment.midpoint.y > 900)
          .id;
      final after =
          DesignEdits.moveDivider(design, mullionId, const Vec2(260, 0));

      expect(after.texts.single.at, const Vec2(1800, 1500));
    });

    test('the frame is never a child of anything', () {
      final design = built();
      expect(design.sectionById(design.frame!.id), isNull);
      for (final section in design.sections) {
        expect(section.parentId, isNot(design.frame!.id));
      }
      for (final bar in design.dividers) {
        expect(bar.parentId, isNot(design.frame!.id));
      }
    });

    test('hardware in the opening stays in the opening', () {
      final design = built();
      final opening = openingOf(design);

      for (final piece in design.hardware) {
        expect(piece.parentId, opening.id);
        expect(opening.outline.awayFrom(piece.at), lessThan(50));
      }
    });
  });
}
