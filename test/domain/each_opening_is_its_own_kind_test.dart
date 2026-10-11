import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// One design, several openings, each its own kind.
//
//   Overall design
//   ├── Fixed section
//   ├── Window opening
//   ├── Fixed section
//   ├── Door opening
//   └── Window opening
//
// The openings were already independent of each other — a design has held
// as many as the user marked for a long time. What is new is that each one
// is a door or a window in its own right, and that the user says which.
//
// **Null is the whole of "they have not said."** It is not a door and it is
// not a window: `Design.kindOf` answers with the design's own kind, which is
// what the user chose when they started the drawing. Writing a default into
// the opening would record a decision they never made.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

List<Vec2> chevron(Vec2 at, {double size = 90}) => [
      Vec2(at.x - size / 2, at.y - size),
      Vec2(at.x + size / 2, at.y),
      Vec2(at.x - size / 2, at.y + size),
    ];

/// Five lights in a row; the 2nd, 4th and 5th marked to open.
Design run({DesignKind kind = DesignKind.window}) =>
    SketchInterpreter.interpret(Design(
      id: 'd',
      name: 'Run',
      kind: kind,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(5000, 0),
          Vec2(5000, 2100),
          Vec2(0, 2100),
          Vec2(0, 0),
        ]),
        for (var i = 1; i < 5; i++)
          pen('m$i', [Vec2(i * 1000, 0), Vec2(i * 1000, 2100)]),
        pen('k1', chevron(const Vec2(1500, 1050))),
        pen('k2', chevron(const Vec2(3500, 1050))),
        pen('k3', chevron(const Vec2(4500, 1050))),
      ]),
    )).design;

/// The openings in reading order across the design.
List<OpeningElement> acrossThe(Design design) {
  final out = [...design.openings];
  out.sort((a, b) => design
      .sectionById(a.sectionId)!
      .outline
      .left
      .compareTo(design.sectionById(b.sectionId)!.outline.left));
  return out;
}

Design saying(Design design, Map<int, DesignKind?> said) {
  final order = acrossThe(design);
  return design.copyWith(openings: [
    for (final opening in design.openings)
      if (said.containsKey(order.indexOf(opening)))
        opening.copyWith(
          kind: said[order.indexOf(opening)],
          clearKind: said[order.indexOf(opening)] == null,
        )
      else
        opening,
  ]);
}

void main() {
  group('a design already holds as many openings as were marked', () {
    test('five lights, three of them marked, three openings', () {
      final design = run();
      expect(design.topLevelSections, hasLength(5));
      expect(design.openings, hasLength(3));

      // Each opening is on its own section, and no section carries two.
      final sections = {for (final o in design.openings) o.sectionId};
      expect(sections, hasLength(3));
      // And the two nobody marked stay fixed.
      final fixed = [
        for (final section in design.topLevelSections)
          if (design.openingOf(section.id) == null) section,
      ];
      expect(fixed, hasLength(2));
    });
  });

  group('each opening is a door or a window in its own right', () {
    test('until the user says, an opening has not been asked about', () {
      for (final opening in run().openings) {
        expect(opening.kind, isNull,
            reason: 'nothing may write down a decision the user did not make');
      }
    });

    test('and follows the design, which is a kind they did choose', () {
      for (final kind in DesignKind.leafKinds) {
        final design = run(kind: kind);
        for (final opening in design.openings) {
          expect(design.kindOf(opening), kind);
        }
      }
    });

    test('unless the design does not say either, and then nothing does', () {
      // A design begun as a door and window set says its assembly holds
      // both, which is not a statement about any one leaf. So there is
      // nothing for an unanswered leaf to follow, and the application does
      // not pick one for it.
      final design = run(kind: DesignKind.both);
      for (final opening in design.openings) {
        expect(opening.kind, isNull);
        expect(design.kindOf(opening), isNull);
      }

      // It still opens, so it still hangs on its hinges — that is what the
      // mark said. It has no handle, because which handle is exactly what
      // has not been said.
      final leaf = design.openings.first;
      final mine = [
        for (final piece in design.hardware)
          if (design.openingHolding(piece.parentId)?.id == leaf.id) piece,
      ];
      expect(mine, isNotEmpty);
      expect({for (final p in mine) p.kind}, {HardwareKind.hinge});

      // And saying puts the handle on.
      final said = OpeningHardware.settle(design.copyWith(openings: [
        for (final o in design.openings)
          if (o.id == leaf.id) o.copyWith(kind: DesignKind.door) else o,
      ]));
      expect({
        for (final piece in said.hardware)
          if (said.openingHolding(piece.parentId)?.id == leaf.id) piece.kind,
      }, {HardwareKind.hinge, HardwareKind.lever, HardwareKind.lock});
    });

    test('the user’s own example: window, door, window in one design', () {
      // Fixed · Window opening · Fixed · Door opening · Window opening
      final design = saying(run(), {
        0: DesignKind.window,
        1: DesignKind.door,
        2: DesignKind.window,
      });

      final order = acrossThe(design);
      expect([for (final o in order) design.kindOf(o)], [
        DesignKind.window,
        DesignKind.door,
        DesignKind.window,
      ]);
      // Said, not inherited: each one carries its own answer.
      expect([for (final o in order) o.kind], isNot(contains(isNull)));
    });

    test('saying what one opening is leaves every other one alone', () {
      final before = run();
      final after = saying(before, {1: DesignKind.door});
      final order = acrossThe(after);

      expect(order[1].kind, DesignKind.door);
      expect(order[0].kind, isNull, reason: 'nobody has said about this one');
      expect(order[2].kind, isNull, reason: 'nor this one');
      expect(after.kindOf(order[0]), before.kind);
      expect(after.kindOf(order[2]), before.kind);
    });

    test('an opening can be put back to following the design', () {
      var design = saying(run(), {0: DesignKind.door});
      expect(acrossThe(design)[0].kind, DesignKind.door);

      design = saying(design, {0: null});
      expect(acrossThe(design)[0].kind, isNull);
      expect(design.kindOf(acrossThe(design)[0]), design.kind);
    });

    test('a door opening in a window design stays a door', () {
      // The design's kind is not imposed on an opening that has an answer.
      final design = saying(run(kind: DesignKind.window),
          {1: DesignKind.door});
      expect(design.kind, DesignKind.window);
      expect(design.kindOf(acrossThe(design)[1]), DesignKind.door);
    });
  });

  group('it survives everything an opening survives', () {
    test('a save and a reload', () {
      final design = saying(run(), {
        0: DesignKind.window,
        1: DesignKind.door,
        2: DesignKind.window,
      });
      final back = Design.fromJson(design.toJson());

      expect([for (final o in acrossThe(back)) o.kind],
          [for (final o in acrossThe(design)) o.kind]);
    });

    test('a design saved before openings had a kind loads as “not said”', () {
      final json = run().toJson();
      final openings = json['openings']! as List;
      for (final opening in openings) {
        expect((opening as Map)['kind'], isNull,
            reason: 'nothing unasked-for is written to the file');
      }
      for (final opening in Design.fromJson(json).openings) {
        expect(opening.kind, isNull);
      }
    });

    test('a rebuild, which throws every section away and makes them again',
        () {
      final design = saying(run(), {1: DesignKind.door});
      final after = SectionBuilder.rebuild(design);

      expect(after.openings, hasLength(3));
      expect(acrossThe(after)[1].kind, DesignKind.door);
      expect(acrossThe(after)[0].kind, isNull);
    });
  });

  group('and nothing else has changed', () {
    test('which face the drawing is of is still the design’s', () {
      // You stand on one side of the wall and look at the whole assembly,
      // so the side you are on belongs to the design. A window opening in a
      // door set does not put you indoors for that one leaf.
      final design = saying(run(kind: DesignKind.door), {1: DesignKind.window});
      expect(design.kind.seenFrom, Face.outside);

      for (final piece in design.hardware) {
        expect(design.isConcealed(piece),
            piece.kind.onTheInsideFace,
            reason: 'the assembly is drawn from outside, all of it');
      }
    });

    test('saying what an opening is moves no geometry at all', () {
      final before = run();
      final after = saying(before, {
        0: DesignKind.door,
        1: DesignKind.window,
        2: DesignKind.door,
      });

      String shape(Design design) => [
            for (final s in design.sections) '${s.id}:${s.outline.corners}',
            for (final b in design.dividers) '${b.id}:${b.a}|${b.b}',
            '${design.frame!.outline.corners}',
          ].join('|');

      expect(shape(after), shape(before));
      expect(after.hardware.length, before.hardware.length);
    });
  });
}
