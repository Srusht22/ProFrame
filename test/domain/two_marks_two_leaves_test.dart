import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The drawing the user made, and what it must read as.
//
//   ┌──────┬──────────┐
//   │      │    >     │   a window
//   │FIXED ├──────────┤
//   │      │    >     │   a door
//   └──────┴──────────┘
//
// A full-height mullion, a transom across the right only, and a `>` in each
// of the two lights the transom makes. **Two marks, two leaves.**
//
// It read as *one* leaf with the transom swallowed into it, and so asked
// once where it should have asked twice. The cause was in
// `_barsTheMarkRunsThrough`: picking which end of an arm is the one past
// the bar, it fell back to the **apex** — a point on the near side, the
// mark's own middle end of the arm — whenever neither end was strictly
// beyond the bar. Everything after that was measured from the wrong end of
// the line and came out as "through" every time.
//
// That is not a rare shape. A chevron drawn to fill its light ends on the
// bar bounding that light, which is how anybody draws one: the upper mark's
// tail comes to rest on the transom, and the lower mark's on the sill.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 40; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 40)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// The sheet, with each mark's tail stopping [tail] past the transom.
///
/// Zero is the drawing as it is actually made: the tail comes to rest on
/// the line bounding its own light.
Design read(
  double tail, {
  DesignKind kind = DesignKind.both,
}) {
  final at = DateTime(2026);
  return SketchInterpreter.interpret(Design(
    id: 'd',
    name: 'test',
    kind: kind,
    createdAt: at,
    updatedAt: at,
    sketch: Sketch(strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(1000, 0),
        Vec2(1000, 1400),
        Vec2(0, 1400),
        Vec2(0, 0),
      ]),
      pen('mull', const [Vec2(450, 0), Vec2(450, 1400)]),
      pen('transom', const [Vec2(450, 700), Vec2(1000, 700)]),
      pen('upper', [
        const Vec2(480, 70),
        const Vec2(950, 390),
        Vec2(470, 700 + tail),
      ]),
      pen('lower', [
        Vec2(470, 700 + 30 - tail),
        const Vec2(950, 1050),
        const Vec2(490, 1370),
      ]),
    ]),
  )).design;
}

SectionElement upperOf(Design design) => design.topLevelSections
    .where((s) => s.outline.left > 200)
    .reduce((a, b) => a.outline.top < b.outline.top ? a : b);

void main() {
  group('two marks in two lights are two leaves', () {
    test('the drawing reads as three lights and two openings', () {
      final design = read(0);

      expect(design.topLevelSections, hasLength(3));
      expect(design.topLevelDividers, hasLength(2),
          reason: 'the mullion and the transom both divide the design');
      expect(design.openings, hasLength(2),
          reason: 'a mark in each light is a leaf in each light');
    });

    test('the transom is not swallowed into a leaf', () {
      final design = read(0);
      for (final bar in design.dividers) {
        expect(bar.parentId, isNull,
            reason: 'neither mark was drawn through it');
      }
      // And so neither leaf is the whole right-hand column.
      final column = design.frame!.innerOutline.height;
      for (final opening in design.openings) {
        final leaf = design.sectionById(opening.sectionId)!;
        expect(leaf.outline.height, lessThan(column * 0.75));
      }
    });

    test('each leaf holds its own mark, and they are different leaves', () {
      final design = read(0);
      final order = design.openingsInOrder;
      expect(order, hasLength(2));
      expect(order[0].sectionId, isNot(order[1].sectionId));

      for (final opening in order) {
        final leaf = design.sectionById(opening.sectionId)!;
        expect(leaf.outline.contains(opening.markAt!), isTrue,
            reason: 'the leaf is the region the mark is in');
      }
      // Read down the drawing: the upper light first.
      final upper = design.sectionById(order[0].sectionId)!;
      final lower = design.sectionById(order[1].sectionId)!;
      expect(upper.outline.top, lessThan(lower.outline.top));
    });

    test('and each is asked about separately, so each can be its own kind',
        () {
      var design = read(0);
      final order = design.openingsInOrder;

      design = design.copyWith(openings: [
        for (final o in design.openings)
          if (o.id == order[0].id)
            o.copyWith(kind: DesignKind.window)
          else
            o.copyWith(kind: DesignKind.door),
      ]);

      expect(design.kindOf(design.openingsInOrder[0]), DesignKind.window);
      expect(design.kindOf(design.openingsInOrder[1]), DesignKind.door);
    });

    test('a tail that stops short of the bar is the same reading', () {
      // The drawing does not have to be neat about it: a mark that stops a
      // little short of the line bounding its light reads exactly as one
      // that comes to rest on it.
      for (final tail in [-60.0, -20.0, 0.0, 20.0]) {
        final design = read(tail);
        expect(design.openings, hasLength(2), reason: 'tail $tail');
        expect(design.topLevelDividers, hasLength(2), reason: 'tail $tail');
      }
    });

    test('a mark genuinely drawn across the transom still takes it', () {
      // The rule it was breaking is still the rule. An arm that crosses the
      // transom and carries on well across the light beyond was drawn
      // through it, and that line is the leaf's.
      final design = read(500);
      expect(design.openings, hasLength(1));
      expect(design.dividers.where((b) => b.parentId != null), hasLength(1));
    });
  });

  group('a door in the assembly means you are looking at it from outside',
      () {
    test('one window leaf and one door leaf: outside', () {
      var design = read(0, kind: DesignKind.window);
      expect(design.kind, DesignKind.window);
      expect(design.seenFrom, Face.inside,
          reason: 'every leaf follows the design, and they are windows');

      final door = design.openingsInOrder[1];
      design = design.copyWith(openings: [
        for (final o in design.openings)
          if (o.id == door.id) o.copyWith(kind: DesignKind.door) else o,
      ]);

      // One door among the windows, and the whole assembly is now met from
      // outside — because a door is what you walk up to.
      expect(design.kind, DesignKind.window,
          reason: 'the assembly is still what the user began');
      expect(design.seenFrom, Face.outside);
    });

    test('so that door’s hinges are round the back, and so are the sash’s',
        () {
      var design = read(0, kind: DesignKind.window);
      final door = design.openingsInOrder[1];
      design = design.copyWith(openings: [
        for (final o in design.openings)
          if (o.id == door.id) o.copyWith(kind: DesignKind.door) else o,
      ]);

      final hinges =
          design.hardware.where((p) => p.kind == HardwareKind.hinge);
      expect(hinges, isNotEmpty);
      for (final hinge in hinges) {
        expect(design.isConcealed(hinge), isTrue,
            reason: 'one face for the whole assembly, not one per leaf');
      }
      // And the handles are still on the face you are at, either way.
      for (final piece in design.hardware.where((p) => p.kind.isHandle)) {
        expect(design.isConcealed(piece), isFalse);
      }
    });

    test('no door anywhere leaves a window assembly seen from inside', () {
      final design = read(0, kind: DesignKind.window);
      for (final hinge
          in design.hardware.where((p) => p.kind == HardwareKind.hinge)) {
        expect(design.isConcealed(hinge), isFalse);
      }
    });

    test('a door assembly is seen from outside however many windows it has',
        () {
      var design = read(0, kind: DesignKind.door);
      expect(design.seenFrom, Face.outside);

      // Say both leaves are windows and the assembly is a door set still —
      // that is the kind the user began the drawing as, and nothing in it
      // is a door leaf any more, so it follows what they said.
      design = design.copyWith(openings: [
        for (final o in design.openings) o.copyWith(kind: DesignKind.window),
      ]);
      expect(design.seenFrom, Face.outside,
          reason: 'a door set is met from outside');
    });

    test('a door-and-window assembly is met from outside', () {
      final design = read(0);
      expect(design.kind, DesignKind.both);
      expect(design.seenFrom, Face.outside,
          reason: 'a set the user says holds both holds a door');
    });

    test('it is one answer for the whole design, not one per leaf', () {
      var design = read(0, kind: DesignKind.window);
      final door = design.openingsInOrder[1];
      design = design.copyWith(openings: [
        for (final o in design.openings)
          if (o.id == door.id) o.copyWith(kind: DesignKind.door) else o,
      ]);

      // Every hinge in the assembly is on the same side as every other.
      // A window light in a door set does not put you indoors for that one
      // leaf, so the two leaves must not disagree.
      final concealed = {
        for (final hinge
            in design.hardware.where((p) => p.kind == HardwareKind.hinge))
          design.isConcealed(hinge),
      };
      expect(concealed, hasLength(1));
    });
  });
}
