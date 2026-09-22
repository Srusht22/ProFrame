import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// What a leaf *is* says nothing about what is inside it.
//
//   Opening                       Opening
//   ├── Glass                     ├── Glass
//   ├── Internal divider          ├── Internal divider
//   ├── Panel                     ├── Panel
//   ├── Handle   (lever)          ├── Handle   (espagnolette)
//   ├── Lock                      └── Hinges
//   └── Hinges
//       a door                        a window
//
// The kind chooses the ironmongery and nothing else. A line drawn inside an
// opening is that opening's whichever kind it is, it never becomes a
// division of the design, and changing the answer from door to window and
// back leaves every line where it was drawn and every pane what it was
// made.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

List<Vec2> chevron(Vec2 at, {double size = 100}) => [
      Vec2(at.x - size / 2, at.y - size),
      Vec2(at.x + size / 2, at.y),
      Vec2(at.x - size / 2, at.y + size),
    ];

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

/// Fixed · Opening · Fixed · Opening, each opening divided into glass over
/// panel by one line drawn inside it.
Design screen({
  DesignKind first = DesignKind.door,
  DesignKind second = DesignKind.window,
}) {
  final read = SketchInterpreter.interpret(Design(
    id: 'd',
    name: 'Screen',
    kind: DesignKind.window,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sketch: Sketch(strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(4800, 0),
        Vec2(4800, 2200),
        Vec2(0, 2200),
        Vec2(0, 0),
      ]),
      for (var i = 1; i < 4; i++)
        pen('m$i', [Vec2(i * 1200, 0), Vec2(i * 1200, 2200)]),
      pen('k1', chevron(const Vec2(1800, 1100))),
      pen('k2', chevron(const Vec2(4200, 1100))),
    ]),
  )).design;

  final order = read.openingsInOrder;
  var design = OpeningHardware.settle(read.copyWith(openings: [
    order[0].copyWith(kind: first),
    order[1].copyWith(kind: second),
  ]));

  // One line inside each, and the lower pane of each made a panel.
  for (final opening in [...design.openingsInOrder]) {
    final box = design.sectionById(opening.sectionId)!.outline;
    design = DesignEdits.addLineInside(
      design,
      opening.sectionId,
      id: 'in-${opening.id}',
      at: Vec2(box.centroid.x, box.top + box.height * 0.42),
      horizontal: true,
    );
    final panes = design.childSectionsOf(opening.sectionId);
    final low = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);
    design = design.withElement(low.copyWith(finish: _panel));
  }
  return design;
}

/// Everything about what is inside an opening, so a change elsewhere can be
/// required to leave it alone.
String inside(Design design, String openingId) {
  final opening = design.openingById(openingId)!;
  return [
    for (final bar in design.childDividersOf(opening.sectionId))
      '${bar.id}:${bar.a}|${bar.b}|${bar.widthMm}',
    for (final pane in design.childSectionsOf(opening.sectionId))
      '${pane.id}:${pane.outline.corners}:${pane.finish.material}'
          ':${pane.finish.colour}',
  ].join('|');
}

void main() {
  group('the inside of a leaf is the same whichever kind it is', () {
    for (final kind in DesignKind.values) {
      test('a ${kind.label.toLowerCase()} holds its own line and panes', () {
        final design = screen(first: kind, second: kind);

        for (final opening in design.openingsInOrder) {
          expect(design.kindOf(opening), kind);

          final bars = design.childDividersOf(opening.sectionId);
          expect(bars, hasLength(1), reason: 'the line drawn inside it');
          expect(design.openingHolding(bars.single.parentId)?.id, opening.id);

          final panes = design.childSectionsOf(opening.sectionId);
          expect(panes, hasLength(2), reason: 'glass over panel');
          for (final pane in panes) {
            expect(design.openingHolding(pane.parentId)?.id, opening.id);
          }
          expect({for (final p in panes) p.finish.material}, hasLength(2));
        }
      });
    }

    test('the tree the phase names, for a door and for a window', () {
      final design = screen();
      final tree = DesignTree.of(design);
      expect(tree.openings, hasLength(2));

      for (final branch in tree.openings) {
        expect(branch.barIds, hasLength(1));
        expect(branch.panes, hasLength(2));
      }

      // And the ironmongery under each: a door locks, a window fastens.
      final door = design.openingsInOrder[0];
      final window = design.openingsInOrder[1];
      Set<HardwareKind> kindsOn(OpeningElement opening) => {
            for (final piece in design.hardware)
              if (design.openingHolding(piece.parentId)?.id == opening.id)
                piece.kind,
          };
      expect(kindsOn(door),
          {HardwareKind.hinge, HardwareKind.lever, HardwareKind.lock});
      expect(kindsOn(window), {HardwareKind.hinge, HardwareKind.handle});
    });

    test('no internal line is ever a division of the design', () {
      final design = screen();

      expect(design.topLevelSections, hasLength(4),
          reason: 'the four lights the user drew, and no more');
      expect(design.topLevelDividers, hasLength(3),
          reason: 'the three mullions, and no more');
      for (final bar in design.topLevelDividers) {
        expect(bar.id, isNot(startsWith('in-')));
      }
    });

    test('and no internal line lies outside the leaf it is in', () {
      final design = screen();

      for (final opening in design.openingsInOrder) {
        final box = design.sectionById(opening.sectionId)!.outline;
        for (final bar in design.childDividersOf(opening.sectionId)) {
          expect(box.holds(bar.segment, reach: DesignEdits.reachFor(bar)),
              isTrue,
              reason: '${bar.id} must lie within ${design.nameOf(opening)}');
        }
      }
    });
  });

  group('changing what a leaf is leaves its inside alone', () {
    test('door to window keeps every line and every pane', () {
      final before = screen();
      final doorId = before.openingsInOrder[0].id;
      final was = inside(before, doorId);
      final othersWere = inside(before, before.openingsInOrder[1].id);

      final after = OpeningHardware.settle(before.copyWith(openings: [
        for (final opening in before.openings)
          if (opening.id == doorId)
            opening.copyWith(kind: DesignKind.window)
          else
            opening,
      ]));

      expect(after.kindOf(after.openingById(doorId)!), DesignKind.window);
      expect(inside(after, doorId), was);
      expect(inside(after, after.openingsInOrder[1].id), othersWere);
    });

    test('and window to door, and back again', () {
      final before = screen();
      final windowId = before.openingsInOrder[1].id;
      final was = inside(before, windowId);

      Design saying(Design design, DesignKind kind) =>
          OpeningHardware.settle(design.copyWith(openings: [
            for (final opening in design.openings)
              if (opening.id == windowId)
                opening.copyWith(kind: kind)
              else
                opening,
          ]));

      final asDoor = saying(before, DesignKind.door);
      expect(inside(asDoor, windowId), was);

      final backAgain = saying(asDoor, DesignKind.window);
      expect(inside(backAgain, windowId), was);
    });

    test('the ironmongery changes and nothing else does', () {
      final before = screen();
      final windowId = before.openingsInOrder[1].id;

      final asDoor = OpeningHardware.settle(before.copyWith(openings: [
        for (final opening in before.openings)
          if (opening.id == windowId)
            opening.copyWith(kind: DesignKind.door)
          else
            opening,
      ]));

      // The leaf gained a lock and its handle changed form.
      Set<HardwareKind> kindsOn(Design design) => {
            for (final piece in design.hardware)
              if (design.openingHolding(piece.parentId)?.id == windowId)
                piece.kind,
          };
      expect(kindsOn(before), isNot(kindsOn(asDoor)));
      expect(kindsOn(asDoor), contains(HardwareKind.lock));

      // And the geometry of the whole design is untouched by that.
      String geometry(Design design) => [
            for (final section in design.sections)
              '${section.id}:${section.outline.corners}',
            for (final bar in design.dividers)
              '${bar.id}:${bar.a}|${bar.b}|${bar.parentId}',
            '${design.frame!.outline.corners}',
          ].join('|');
      expect(geometry(asDoor), geometry(before));
    });

    test('a line drawn after the answer is the leaf’s just the same', () {
      var design = screen();
      final doorId = design.openingsInOrder[0].id;
      final section = design.openingById(doorId)!.sectionId;
      final box = design.sectionById(section)!.outline;

      design = DesignEdits.addLineInside(design, section,
          id: 'later',
          at: Vec2(box.centroid.x, box.top + box.height * 0.75),
          horizontal: true);

      final bars = design.childDividersOf(section);
      expect(bars, hasLength(2));
      expect(design.openingHolding(
              bars.firstWhere((b) => b.id == 'later').parentId)?.id,
          doorId);
      expect(design.childSectionsOf(section), hasLength(3));
      // Still not the design's.
      expect(design.topLevelDividers, hasLength(3));
      expect(design.topLevelSections, hasLength(4));
    });
  });

  group('the solid builds the same inside for either kind', () {
    test('the leaf’s line and panes are built, whichever it is', () {
      for (final kind in DesignKind.values) {
        final design = screen(first: kind, second: kind);
        final built = {
          for (final facet in MeshBuilder.build(design).facets)
            facet.elementId,
        };

        for (final opening in design.openingsInOrder) {
          for (final bar in design.childDividersOf(opening.sectionId)) {
            expect(built, contains(bar.id),
                reason: '${kind.label}: its line is in the model');
          }
          for (final pane in design.childSectionsOf(opening.sectionId)) {
            expect(built, contains(pane.id));
          }
        }
      }
    });

    test('and changing the kind changes only the ironmongery in it', () {
      final before = screen(first: DesignKind.door, second: DesignKind.door);
      final after = OpeningHardware.settle(before.copyWith(openings: [
        for (final opening in before.openings)
          opening.copyWith(kind: DesignKind.window),
      ]));

      final ironmongery = {
        for (final design in [before, after])
          for (final piece in design.hardware) piece.id,
      };
      String everythingElse(Design design) => [
            for (final facet in MeshBuilder.build(design).facets)
              if (!ironmongery.contains(facet.elementId))
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');

      expect(everythingElse(after), everythingElse(before),
          reason: 'the glass, the panel, the line and the leaf are the same');
      expect(everythingElse(before), isNotEmpty);
    });
  });

  group('and it all survives what an opening survives', () {
    test('a rebuild', () {
      final before = screen();
      final ids = [for (final o in before.openingsInOrder) o.id];
      final was = {for (final id in ids) id: inside(before, id)};

      final after = SectionBuilder.rebuild(before);
      for (final id in ids) {
        expect(inside(after, id), was[id]);
      }
    });

    test('a save and a reload', () {
      final before = screen();
      final ids = [for (final o in before.openingsInOrder) o.id];
      final was = {for (final id in ids) id: inside(before, id)};

      final after = Design.fromJson(before.toJson());
      for (final id in ids) {
        expect(inside(after, id), was[id]);
        expect(after.kindOf(after.openingById(id)!),
            before.kindOf(before.openingById(id)!));
      }
    });

    test('reading the sheet again', () {
      final before = screen();
      final ids = [for (final o in before.openingsInOrder) o.id];
      final was = {for (final id in ids) id: inside(before, id)};

      // The lines inside were made in the design, not on the sheet, so a
      // re-reading has nothing to make them from and must keep them.
      final again = SketchInterpreter.interpret(before).design;
      expect(again.openings, hasLength(2));
      for (final id in ids) {
        expect(again.openingById(id), isNotNull);
        expect(inside(again, id), was[id]);
        expect(again.kindOf(again.openingById(id)!),
            before.kindOf(before.openingById(id)!));
      }
    });

    test('the leaf being moved to another light', () {
      final before = screen();
      final windowId = before.openingsInOrder[1].id;
      final fixed = [
        for (final section in before.topLevelSections)
          if (before.openingOf(section.id) == null) section,
      ];

      final after = DesignEdits.moveOpeningToSection(
          before, windowId, fixed.first.id);
      final moved = after.openingById(windowId)!;

      // Its line and its panes came with it, and are still its own.
      expect(after.childDividersOf(moved.sectionId), hasLength(1));
      expect(after.childSectionsOf(moved.sectionId), hasLength(2));
      final box = after.sectionById(moved.sectionId)!.outline;
      for (final bar in after.childDividersOf(moved.sectionId)) {
        expect(box.holds(bar.segment, reach: DesignEdits.reachFor(bar)),
            isTrue);
      }
      // And the materials the user set are still what they set.
      expect({
        for (final pane in after.childSectionsOf(moved.sectionId))
          pane.finish.material,
      }, hasLength(2));
    });
  });
}
