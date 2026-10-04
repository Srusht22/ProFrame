import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// A door drawn as one leaf, with a rail across it and an upright below —
// or above. The upright is the user's to put where they like, and where
// they put it cannot decide what their mark says about the rail.
//
//   ┌───────────────┐        ┌───────┬───────┐
//   │               │        │       │       │
//   ├───────────────┤        ├───────┴───────┤
//   │       │       │        │               │
//   └───────┴───────┘        └───────────────┘
//
// Both are one leaf holding two lines and three panes. They are the same
// drawing with one line moved, and they must read the same way.
//
// This is the failure the drawing showed. The mark's middle falls in one of
// the quarters the two lines cut the door into, so the reading opened a
// quarter and left the rail dividing the door — and the rail could not then
// be put inside that quarter by hand either, because it runs the width of
// the door. With the upright drawn in the upper half the door came back
// whole, with it in the lower half it came back in quarters, and nothing
// about the mark had changed.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// The door as drawn, with the upright wherever [upright] puts it.
Design door(List<Vec2> upright) => SketchInterpreter.interpret(Design(
      id: 'd',
      name: 'Door',
      kind: DesignKind.door,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1343, 0),
          Vec2(1343, 1720),
          Vec2(0, 1720),
          Vec2(0, 0),
        ]),
        pen('rail', const [Vec2(0, 713), Vec2(1343, 713)]),
        pen('upright', upright),
        // A `>` drawn over the whole door, corner to corner.
        pen('mark', const [Vec2(67, 59), Vec2(1208, 839), Vec2(42, 1670)]),
      ]),
    )).design;

const below = [Vec2(671, 713), Vec2(671, 1712)];
const above = [Vec2(671, 8), Vec2(671, 713)];

void main() {
  group('one leaf, both lines in it, wherever the upright is drawn', () {
    for (final (where, upright) in const [
      ('below the rail', below),
      ('above the rail', above),
    ]) {
      test('the upright $where: the door is one leaf', () {
        final design = door(upright);

        expect(design.openings, hasLength(1));
        expect(design.topLevelSections, hasLength(1),
            reason: 'the mark was drawn over the whole door');
        expect(design.topLevelDividers, isEmpty,
            reason: 'both lines are the leaf’s, not the door’s');
      });

      test('the upright $where: the leaf is the whole daylight', () {
        final design = door(upright);
        final leaf = design.sectionById(design.openings.single.sectionId)!;
        final daylight = design.frame!.innerOutline;

        expect(leaf.outline.width, closeTo(daylight.width, 0.01));
        expect(leaf.outline.height, closeTo(daylight.height, 0.01));
        // The root is never the opening: the frame is not a section.
        expect(design.sectionById(design.frame!.id), isNull);
      });

      test('the upright $where: the leaf holds both lines and three panes',
          () {
        final design = door(upright);
        final opening = design.openings.single;

        final mine = design.childDividersOf(opening.sectionId);
        expect(mine, hasLength(2));
        for (final bar in mine) {
          expect(design.openingHolding(bar.parentId)?.id, opening.id);
        }
        expect(design.childSectionsOf(opening.sectionId), hasLength(3),
            reason: 'a rail and an upright in half of it make three panes');
        expect(DesignTree.of(design).openings.single.barIds, hasLength(2));
      });
    }

    test('and the two readings are the same design, line for line', () {
      // The same drawing with one line moved. Everything that is not that
      // line must be identical: the same leaf, the same rail, the same
      // count of panes.
      final low = door(below);
      final high = door(above);

      // Its geometry, and whose it is — not the id of the section it sits
      // on, which is a fresh number from each reading and says nothing.
      String railOf(Design design) {
        final bar =
            design.dividers.firstWhere((b) => b.fromStrokeId == 'rail');
        final holder = design.openingHolding(bar.parentId);
        return '${bar.a}|${bar.b}|${holder?.markGlyph}|${holder?.markAt}';
      }

      expect(low.topLevelSections.single.outline.corners,
          high.topLevelSections.single.outline.corners);
      expect(railOf(low), railOf(high));
      expect(low.childSectionsOf(low.openings.single.sectionId).length,
          high.childSectionsOf(high.openings.single.sectionId).length);
    });
  });

  group('the lines stay where the user drew them', () {
    test('the upright is not stretched across the leaf', () {
      final design = door(below);
      final upright = design.dividers
          .firstWhere((bar) => bar.fromStrokeId == 'upright');

      // It was drawn from the rail down, so it runs from the rail down —
      // not from the head to the sill.
      expect(upright.segment.a.y, closeTo(713, 25));
      expect(upright.a.x, closeTo(671, 25));
      expect(upright.b.x, closeTo(671, 25));
    });

    test('nothing the user did not draw is added', () {
      final design = door(below);
      expect(design.dividers, hasLength(2));
      expect(design.sections, hasLength(4),
          reason: 'the leaf and its three panes, and nothing else');
    });
  });

  group('and it stays editable by hand', () {
    test('the rail can be taken back out of the leaf and put back in', () {
      var design = door(below);

      final rail = design.dividers
          .firstWhere((bar) => bar.fromStrokeId == 'rail');

      // Out: it divides the door again, and the leaf is one pane the
      // upright still divides.
      design = DesignEdits.setDividerParent(design, rail.id, null);
      expect(design.dividerById(rail.id)!.parentId, isNull);
      expect(design.topLevelSections.length, greaterThan(1));

      // And back in, by the same control, on the section it now bounds.
      final now = design.openings.single;
      expect(
        DesignEdits.containersFor(design, rail.id).map((s) => s.id),
        contains(now.sectionId),
        reason: 'the Divides control must offer the leaf the rail bounds',
      );
      design = DesignEdits.setDividerParent(design, rail.id, now.sectionId);
      expect(design.openingHolding(design.dividerById(rail.id)!.parentId)?.id,
          now.id);
    });
  });
}
