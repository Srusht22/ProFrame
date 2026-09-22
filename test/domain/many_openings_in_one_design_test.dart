import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The phase's own drawing, drawn the way the user draws it — outline,
// transom, two mullions and three marks, all strokes on the sheet.
//
//   ┌─────────────────────────────────────┐
//   │               FIXED                 │
//   ├───────────────┬──────────┬──────────┤
//   │    OPENING    │ OPENING  │ OPENING  │
//   │       >       │    >     │    >     │
//   └───────────────┴──────────┴──────────┘
//
//   Design
//   ├── Fixed geometry
//   ├── Opening 1
//   ├── Opening 2
//   └── Opening 3
//
// Three openings, each a separate object with its own identity, its own
// contents and its own edits. The whole design is never one opening, and
// no opening is ever the whole design.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

List<Vec2> chevron(Vec2 at, {double size = 110}) => [
      Vec2(at.x - size / 2, at.y - size),
      Vec2(at.x + size / 2, at.y),
      Vec2(at.x - size / 2, at.y + size),
    ];

Design drawn() => SketchInterpreter.interpret(Design(
      id: 'd',
      name: 'Screen',
      kind: DesignKind.window,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(4200, 0),
          Vec2(4200, 2400),
          Vec2(0, 2400),
          Vec2(0, 0),
        ]),
        pen('transom', const [Vec2(0, 700), Vec2(4200, 700)]),
        pen('mull1', const [Vec2(1800, 700), Vec2(1800, 2400)]),
        pen('mull2', const [Vec2(2900, 700), Vec2(2900, 2400)]),
        pen('k1', chevron(const Vec2(900, 1550))),
        pen('k2', chevron(const Vec2(2350, 1550))),
        pen('k3', chevron(const Vec2(3550, 1550))),
      ]),
    )).design;

/// The design with one line drawn inside each opening, and the lower pane
/// of each made a panel — so every opening has contents of its own.
Design fittedOut() {
  var design = drawn();
  for (final opening in [...design.openingsInOrder]) {
    final box = design.sectionById(opening.sectionId)!.outline;
    design = DesignEdits.addLineInside(
      design,
      opening.sectionId,
      id: 'in-${opening.id}',
      at: Vec2(box.centroid.x, box.top + box.height * 0.4),
      horizontal: true,
    );
    final panes = design.childSectionsOf(opening.sectionId);
    final low = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);
    design = design.withElement(low.copyWith(
      finish: const Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel),
    ));
  }
  return design;
}

void main() {
  group('one design, three openings', () {
    test('the drawing reads as a fixed head and three openings', () {
      final design = drawn();

      expect(design.topLevelSections, hasLength(4));
      expect(design.topLevelDividers, hasLength(3),
          reason: 'the transom and the two mullions divide the design');
      expect(design.openings, hasLength(3));

      // Three openings, three different sections, and one light left fixed.
      expect({for (final o in design.openings) o.sectionId}, hasLength(3));
      final fixed = [
        for (final section in design.topLevelSections)
          if (design.openingOf(section.id) == null) section,
      ];
      expect(fixed, hasLength(1));
      expect(fixed.single.outline.top, lessThan(700),
          reason: 'the fixed light is the band across the head');
    });

    test('the whole design is never one of them', () {
      final design = drawn();
      final daylight = design.frame!.innerOutline;

      for (final opening in design.openings) {
        final box = design.sectionById(opening.sectionId)!.outline;
        expect(box.area, lessThan(daylight.area * 0.45));
        expect(opening.sectionId, isNot(design.frame!.id));
      }
      // The frame is not a section, so it can never be the thing that opens.
      expect(design.sectionById(design.frame!.id), isNull);
    });

    test('each one has an identity of its own', () {
      final design = drawn();
      final order = design.openingsInOrder;

      expect(order, hasLength(3));
      expect([for (final o in order) design.numberOf(o)], [1, 2, 3]);
      expect([for (final o in order) design.nameOf(o)],
          ['Opening 1  >', 'Opening 2  >', 'Opening 3  >']);
      // Three different names for three different things.
      expect({for (final o in order) design.nameOf(o)}, hasLength(3));
      expect({for (final o in order) o.id}, hasLength(3));
    });

    test('and they are numbered across the drawing, not by chance', () {
      final design = drawn();
      final order = design.openingsInOrder;
      final lefts = [
        for (final o in order) design.sectionById(o.sectionId)!.outline.left,
      ];
      expect(lefts, orderedEquals([...lefts]..sort()));
    });

    test('both views show three openings and one fixed light', () {
      final tree = DesignTree.of(drawn());
      expect(tree.openings, hasLength(3));
      expect(tree.fixedSections, hasLength(1));
      expect(tree.barIds, hasLength(3));
    });
  });

  group('every opening keeps its own child geometry', () {
    test('a line drawn in one is that one’s, and makes its own panes', () {
      final design = fittedOut();

      expect(design.openings, hasLength(3));
      for (final opening in design.openingsInOrder) {
        final bars = design.childDividersOf(opening.sectionId);
        expect(bars, hasLength(1), reason: design.nameOf(opening));
        expect(bars.single.id, 'in-${opening.id}');
        expect(design.childSectionsOf(opening.sectionId), hasLength(2));
      }
      // And none of them became a division of the design.
      expect(design.topLevelSections, hasLength(4));
      expect(design.topLevelDividers, hasLength(3));
    });

    test('glass and panel are set per opening, not across the design', () {
      final design = fittedOut();

      for (final opening in design.openingsInOrder) {
        final panes = design.childSectionsOf(opening.sectionId);
        final materials = {for (final p in panes) p.finish.material};
        expect(materials, hasLength(2),
            reason: '${design.nameOf(opening)} is glass over panel');
      }
    });

    test('its contents name it, and nothing else’s', () {
      final design = fittedOut();

      for (final opening in design.openings) {
        final mine = {for (final e in design.contentsOf(opening)) e.id};
        expect(mine, isNotEmpty);
        for (final bar in design.childDividersOf(opening.sectionId)) {
          expect(design.openingHolding(bar.parentId)?.id, opening.id);
          expect(mine, contains(bar.id));
        }
        for (final pane in design.childSectionsOf(opening.sectionId)) {
          expect(design.openingHolding(pane.parentId)?.id, opening.id);
          expect(mine, contains(pane.id));
        }
        // And nothing of anyone else's is in it.
        for (final other in design.openings) {
          if (other.id == opening.id) continue;
          for (final bar in design.childDividersOf(other.sectionId)) {
            expect(mine, isNot(contains(bar.id)),
                reason: '${design.nameOf(other)} keeps its own');
          }
        }
      }
      // Every bar drawn inside an opening is inside exactly one of them.
      final inside = [
        for (final bar in design.dividers)
          if (bar.parentId != null) bar,
      ];
      expect(inside, hasLength(3));
      expect({for (final b in inside) design.openingHolding(b.parentId)!.id},
          hasLength(3));
    });
  });

  group('each opening is edited on its own', () {
    /// Everything about an opening that an edit elsewhere must not touch.
    String fingerprint(Design design, OpeningElement opening) => [
          opening.mechanism.name,
          opening.direction.name,
          design.sectionById(opening.sectionId)!.outline.corners,
          for (final bar in design.childDividersOf(opening.sectionId))
            '${bar.id}:${bar.a}|${bar.b}',
          for (final pane in design.childSectionsOf(opening.sectionId))
            '${pane.id}:${pane.finish.material}:${pane.outline.corners}',
        ].join('|');

    test('changing one opening’s direction leaves the others alone', () {
      final before = fittedOut();
      final order = before.openingsInOrder;
      final others = {
        for (final o in order)
          if (o.id != order[1].id) o.id: fingerprint(before, o),
      };

      final after = DesignEdits.setOpeningMechanism(
          before, order[1].id, OpeningMechanism.topHung);

      expect(after.openingById(order[1].id)!.mechanism,
          OpeningMechanism.topHung);
      for (final entry in others.entries) {
        expect(fingerprint(after, after.openingById(entry.key)!), entry.value,
            reason: '${entry.key} must be untouched');
      }
      expect(after.openings, hasLength(3));
    });

    test('drawing in one opening leaves the others alone', () {
      final before = fittedOut();
      final order = before.openingsInOrder;
      final others = {
        for (final o in order)
          if (o.id != order[2].id) o.id: fingerprint(before, o),
      };

      final box = before.sectionById(order[2].sectionId)!.outline;
      final after = DesignEdits.addLineInside(before, order[2].sectionId,
          id: 'another', at: Vec2(box.centroid.x, box.top + 120),
          horizontal: true);

      expect(after.childDividersOf(order[2].sectionId), hasLength(2));
      for (final entry in others.entries) {
        expect(fingerprint(after, after.openingById(entry.key)!), entry.value);
      }
    });

    test('cancelling one opening leaves the other two', () {
      final before = fittedOut();
      final order = before.openingsInOrder;

      // Cancelling is saying the section is fixed after all, which is the
      // one route the inspector offers.
      final after = DesignEdits.setOpening(
        before,
        order[0].sectionId,
        openingId: order[0].id,
        mechanism: OpeningMechanism.fixed,
      );

      expect(after.openings, hasLength(2));
      expect(after.openingById(order[0].id), isNull);
      // And the two that are left are renumbered by where they are, so the
      // names still say which is which.
      expect([for (final o in after.openingsInOrder) after.numberOf(o)],
          [1, 2]);
      for (final o in after.openingsInOrder) {
        expect(after.childDividersOf(o.sectionId), hasLength(1),
            reason: 'its own line is still its own');
      }
    });
  });

  group('the solid builds three leaves, and only what is there', () {
    test('every facet belongs to a part the design actually has', () {
      final design = fittedOut();
      final mesh = MeshBuilder.build(design);
      final parts = {for (final element in design.allElements) element.id};

      expect(mesh.facets, isNotEmpty);
      for (final facet in mesh.facets) {
        expect(parts, contains(facet.elementId),
            reason: 'the solid cannot build something out of nothing');
      }
    });

    test('each opening’s own contents are in the solid', () {
      final design = fittedOut();
      final built = {
        for (final facet in MeshBuilder.build(design).facets) facet.elementId,
      };

      for (final opening in design.openingsInOrder) {
        for (final bar in design.childDividersOf(opening.sectionId)) {
          expect(built, contains(bar.id),
              reason: '${design.nameOf(opening)} keeps its line in 3D');
        }
        for (final pane in design.childSectionsOf(opening.sectionId)) {
          expect(built, contains(pane.id));
        }
      }
    });

    test('swinging the leaves moves the leaves and nothing else', () {
      final design = fittedOut();

      String fingerprint(double open) {
        final mesh = MeshBuilder.build(design, openFraction: open);
        final theirs = <String>{
          for (final opening in design.openings)
            for (final element in design.contentsOf(opening)) element.id,
          for (final opening in design.openings) opening.sectionId,
        };
        return [
          for (final facet in mesh.facets)
            if (!theirs.contains(facet.elementId))
              '${facet.elementId}:${facet.corners.join(',')}',
        ].join('|');
      }

      // The frame, the transom, the mullions and the fixed head do not move,
      // however far the three leaves are swung.
      expect(fingerprint(1), fingerprint(0));
      expect(fingerprint(0.5), fingerprint(0));
    });
  });

  group('it all survives being put away and fetched back', () {
    test('a save and a reload keeps three openings and their contents', () {
      final before = fittedOut();
      final after = Design.fromJson(before.toJson());

      expect(after.openings, hasLength(3));
      expect([for (final o in after.openingsInOrder) after.nameOf(o)],
          [for (final o in before.openingsInOrder) before.nameOf(o)]);
      for (final opening in after.openingsInOrder) {
        expect(after.childDividersOf(opening.sectionId), hasLength(1));
        expect(after.childSectionsOf(opening.sectionId), hasLength(2));
      }
    });

    test('reading the sheet again keeps all three', () {
      final again = SketchInterpreter.interpret(fittedOut()).design;

      expect(again.openings, hasLength(3));
      for (final opening in again.openingsInOrder) {
        expect(again.childDividersOf(opening.sectionId), hasLength(1),
            reason: 'a line made in the design is not on the sheet to re-read');
      }
    });
  });
}
