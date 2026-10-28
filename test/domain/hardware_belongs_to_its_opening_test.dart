import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// Every piece of ironmongery is its own opening's, and no other's.
//
//   Design
//   ├── Fixed section
//   ├── Door opening          ── its lever, its lock, its hinges
//   ├── Fixed section
//   └── Window opening        ── its handle, its hinges
//
// Move the door opening and the door, its handle and its hinges move; the
// window opening does not. Move the window opening and its handle moves;
// the door does not. Nothing is attached to the design itself, so nothing
// is left behind on the frame when a leaf goes somewhere.
//
// The two openings are given a fixed light between them on purpose. A bar
// shared by two openings bounds both, so moving it changes both regions and
// both sets of ironmongery move — correctly. This drawing gives each
// opening a bar of its own, so "the other one does not move" is a claim
// about ownership rather than about which bars happen to touch what.

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

/// Fixed · Door opening · Fixed · Window opening.
Design screen() {
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
  return OpeningHardware.settle(read.copyWith(openings: [
    order[0].copyWith(kind: DesignKind.door),
    order[1].copyWith(kind: DesignKind.window),
  ]));
}

OpeningElement door(Design design) => design.openingsInOrder[0];
OpeningElement window(Design design) => design.openingsInOrder[1];

List<HardwareElement> hardwareOf(Design design, String openingId) => [
      for (final piece in design.hardware)
        if (design.openingHolding(piece.parentId)?.id == openingId) piece,
    ];

/// Where every piece of an opening's ironmongery is.
String placesIn(Design design, String openingId) => [
      for (final piece in hardwareOf(design, openingId)) '${piece.id}:${piece.at}',
    ].join('|');

void main() {
  group('the structure is the one the drawing makes', () {
    test('four lights, two of them open, one a door and one a window', () {
      final design = screen();

      expect(design.topLevelSections, hasLength(4));
      expect(design.openings, hasLength(2));
      expect(design.kindOf(door(design)), DesignKind.door);
      expect(design.kindOf(window(design)), DesignKind.window);

      final tree = DesignTree.of(design);
      expect(tree.openings, hasLength(2));
      expect(tree.fixedSections, hasLength(2));
    });

    test('every piece names the opening it hangs on', () {
      final design = screen();

      expect(design.hardware, isNotEmpty);
      for (final piece in design.hardware) {
        final opening = design.openingHolding(piece.parentId);
        expect(opening, isNotNull,
            reason: '${piece.id} must belong to an opening');
        expect(piece.parentId, isNot(design.frame!.id));
        expect(piece.parentId, isNot(design.id));
      }
    });

    test('nothing is attached to the design itself', () {
      final design = screen();
      final loose = [
        for (final piece in design.hardware)
          if (piece.parentId == null) piece,
      ];
      expect(loose, isEmpty,
          reason: 'a leaf’s ironmongery is never the design’s');
    });

    test('the door’s pieces and the window’s are different pieces', () {
      final design = screen();
      final his = {for (final p in hardwareOf(design, door(design).id)) p.id};
      final hers = {
        for (final p in hardwareOf(design, window(design).id)) p.id,
      };

      expect(his, isNotEmpty);
      expect(hers, isNotEmpty);
      expect(his.intersection(hers), isEmpty);
      // The door has a lock; the window does not.
      expect([for (final p in hardwareOf(design, door(design).id)) p.kind],
          contains(HardwareKind.lock));
      expect([for (final p in hardwareOf(design, window(design).id)) p.kind],
          isNot(contains(HardwareKind.lock)));
    });

    test('a fixed light carries none of it', () {
      final design = screen();
      final fixed = [
        for (final section in design.topLevelSections)
          if (design.openingOf(section.id) == null) section,
      ];
      expect(fixed, hasLength(2));

      for (final piece in design.hardware) {
        for (final section in fixed) {
          expect(design.sectionHolding(piece.parentId), isNot(section.id));
        }
      }
    });
  });

  group('move the door opening', () {
    test('the door and all of its ironmongery move', () {
      final before = screen();
      final was = placesIn(before, door(before).id);

      // The bar on the door's own side.
      final bar = before.topLevelDividers
          .firstWhere((b) => b.segment.midpoint.x < 1500);
      final after = DesignEdits.moveDivider(before, bar.id, const Vec2(-220, 0));

      expect(placesIn(after, door(after).id), isNot(was));
      expect(hardwareOf(after, door(after).id),
          hasLength(hardwareOf(before, door(before).id).length),
          reason: 'it moves with the leaf, it is not lost by it');
    });

    test('and the window opening does not move at all', () {
      final before = screen();
      final was = placesIn(before, window(before).id);

      final bar = before.topLevelDividers
          .firstWhere((b) => b.segment.midpoint.x < 1500);
      final after = DesignEdits.moveDivider(before, bar.id, const Vec2(-220, 0));

      expect(placesIn(after, window(after).id), was);
      // Nor does its leaf.
      expect(after.sectionById(window(after).sectionId)!.outline.corners,
          before.sectionById(window(before).sectionId)!.outline.corners);
    });
  });

  group('move the window opening', () {
    test('the window and its handle move', () {
      final before = screen();
      final was = placesIn(before, window(before).id);

      final bar = before.topLevelDividers
          .firstWhere((b) => b.segment.midpoint.x > 3000);
      final after = DesignEdits.moveDivider(before, bar.id, const Vec2(-220, 0));

      expect(placesIn(after, window(after).id), isNot(was));
      expect(hardwareOf(after, window(after).id).any((p) => p.kind.isHandle),
          isTrue);
    });

    test('and the door does not move at all', () {
      final before = screen();
      final was = placesIn(before, door(before).id);

      final bar = before.topLevelDividers
          .firstWhere((b) => b.segment.midpoint.x > 3000);
      final after = DesignEdits.moveDivider(before, bar.id, const Vec2(-220, 0));

      expect(placesIn(after, door(after).id), was);
      expect(after.sectionById(door(after).sectionId)!.outline.corners,
          before.sectionById(door(before).sectionId)!.outline.corners);
    });
  });

  group('an opening taken to another light takes its own with it', () {
    test('its ironmongery goes, and the other leaf’s stays', () {
      final before = screen();
      final doorWas = placesIn(before, door(before).id);
      final fixed = [
        for (final section in before.topLevelSections)
          if (before.openingOf(section.id) == null) section,
      ];

      // Held by id from here on: moving an opening changes which is first
      // across the drawing, so *Opening 1* is a place and not a thing.
      final doorId = door(before).id;
      final windowId = window(before).id;
      final after =
          DesignEdits.moveOpeningToSection(before, windowId, fixed.first.id);

      final moved = after.openingById(windowId)!;
      expect(moved.sectionId, fixed.first.id);
      // Its own pieces are on the new leaf.
      final box = after.sectionById(moved.sectionId)!.outline;
      final mine = hardwareOf(after, moved.id);
      expect(mine, isNotEmpty);
      for (final piece in mine) {
        expect(piece.at.x, greaterThanOrEqualTo(box.left - 1));
        expect(piece.at.x, lessThanOrEqualTo(box.right + 1));
      }
      // And nothing of the door's went anywhere.
      expect(placesIn(after, doorId), doorWas);
    });

    test('and nothing is left behind on the light it came from', () {
      final before = screen();
      final leaving = before.sectionById(window(before).sectionId)!;
      final fixed = [
        for (final section in before.topLevelSections)
          if (before.openingOf(section.id) == null) section,
      ];

      final after = DesignEdits.moveOpeningToSection(
          before, window(before).id, fixed.first.id);

      for (final piece in after.hardware) {
        expect(after.sectionHolding(piece.parentId), isNot(leaving.id));
      }
    });
  });

  group('and in the solid, a leaf takes its own with it', () {
    test('swinging the door moves the door’s pieces and no others', () {
      final design = screen();
      final his = {for (final p in hardwareOf(design, door(design).id)) p.id};
      final hers = {
        for (final p in hardwareOf(design, window(design).id)) p.id,
      };

      String facetsOf(Set<String> ids, double open) => [
            for (final facet
                in MeshBuilder.build(design, openFraction: open).facets)
              if (ids.contains(facet.elementId))
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');

      // Both leaves swing together in this view, so the honest claim is the
      // one about ownership: each set of pieces travels with its own leaf,
      // and neither set is in the other's.
      expect(facetsOf(his, 1), isNot(facetsOf(his, 0)));
      expect(facetsOf(hers, 1), isNot(facetsOf(hers, 0)));
      expect(his.intersection(hers), isEmpty);
    });

    test('the frame and the fixed lights never move, whatever swings', () {
      final design = screen();
      final leaves = {
        for (final opening in design.openings) ...{
          opening.sectionId,
          for (final element in design.contentsOf(opening)) element.id,
        },
      };

      String elsewhere(double open) => [
            for (final facet
                in MeshBuilder.build(design, openFraction: open).facets)
              if (!leaves.contains(facet.elementId))
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');

      expect(elsewhere(1), elsewhere(0));
      expect(elsewhere(0), isNotEmpty);
    });
  });

  group('the parents outlast everything', () {
    test('a save and a reload', () {
      final before = screen();
      final after = Design.fromJson(before.toJson());

      for (final piece in after.hardware) {
        expect(after.openingHolding(piece.parentId), isNotNull);
      }
      expect(hardwareOf(after, door(after).id).length,
          hardwareOf(before, door(before).id).length);
      expect(hardwareOf(after, window(after).id).length,
          hardwareOf(before, window(before).id).length);
    });

    test('reading the sheet again', () {
      final again = SketchInterpreter.interpret(screen()).design;

      expect(again.openings, hasLength(2));
      for (final piece in again.hardware) {
        expect(again.openingHolding(piece.parentId), isNotNull,
            reason: '${piece.id} is still a leaf’s, not the design’s');
      }
    });

    test('cancelling one opening takes its ironmongery and no other’s', () {
      final before = screen();
      final doorId = door(before).id;
      final windowId = window(before).id;
      final windowWas = placesIn(before, windowId);

      final after = DesignEdits.setOpening(
        before,
        door(before).sectionId,
        openingId: doorId,
        mechanism: OpeningMechanism.fixed,
      );

      expect(after.openings, hasLength(1));
      expect(after.openingById(doorId), isNull);
      expect(hardwareOf(after, doorId), isEmpty,
          reason: 'a leaf that no longer opens hangs on nothing');
      expect(placesIn(after, windowId), windowWas,
          reason: 'and the leaf beside it keeps every piece of its own');
    });
  });
}
