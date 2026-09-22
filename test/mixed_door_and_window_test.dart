import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The whole system, on one design that holds both kinds of leaf.
//
//   Design
//   ├── Fixed area
//   ├── Window opening  <
//   │    ├── Glass
//   │    ├── Internal divider
//   │    ├── Panel
//   │    └── Window handle  (and the hinges it hangs on)
//   ├── Fixed area
//   └── Door opening  >
//        ├── Glass
//        ├── Internal divider
//        ├── Panel
//        ├── Door handle
//        ├── Lock
//        └── Hinges
//
// Drawn the way the user draws it: an outline, three mullions and two
// marks, all strokes on the sheet. Then each leaf is said to be a door or a
// window, and each is divided into glass over panel with a line drawn
// inside it.
//
// **A window sash hangs on hinges too.** The brief's list shows them only
// under the door, but a leaf that opens hangs on something, and a window
// that carried none would be a drawing nobody could build. They are the
// leaf's, exactly as the door's are.

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

/// The design above, built the way the user builds it.
Design theScreen() {
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
      // The second light is the window; the fourth is the door.
      pen('k-window', chevron(const Vec2(1800, 1100))),
      pen('k-door', chevron(const Vec2(4200, 1100))),
    ]),
  )).design;

  final order = read.openingsInOrder;
  var design = OpeningHardware.settle(read.copyWith(openings: [
    order[0].copyWith(kind: DesignKind.window),
    order[1].copyWith(kind: DesignKind.door),
  ]));

  for (final opening in [...design.openingsInOrder]) {
    final box = design.sectionById(opening.sectionId)!.outline;
    design = DesignEdits.addLineInside(
      design,
      opening.sectionId,
      id: 'in-${opening.id}',
      at: Vec2(box.centroid.x, box.top + box.height * 0.45),
      horizontal: true,
    );
    final panes = design.childSectionsOf(opening.sectionId);
    final low = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);
    design = design.withElement(low.copyWith(finish: _panel));
  }
  return design;
}

OpeningElement windowLeaf(Design design) => design.openingsInOrder[0];
OpeningElement doorLeaf(Design design) => design.openingsInOrder[1];

List<HardwareElement> hardwareOf(Design design, String openingId) => [
      for (final piece in design.hardware)
        if (design.openingHolding(piece.parentId)?.id == openingId) piece,
    ];

Set<String> facetIds(Mesh mesh) =>
    {for (final facet in mesh.facets) facet.elementId};

void main() {
  group('the design is the hierarchy the brief names', () {
    test('four lights: fixed, window opening, fixed, door opening', () {
      final design = theScreen();

      expect(design.topLevelSections, hasLength(4));
      expect(design.topLevelDividers, hasLength(3));
      expect(design.openings, hasLength(2));

      final opens = [
        for (final section in design.topLevelSections)
          design.openingOf(section.id) != null,
      ];
      expect(opens, [false, true, false, true],
          reason: 'fixed, window, fixed, door — in reading order');

      expect(design.kindOf(windowLeaf(design)), DesignKind.window);
      expect(design.kindOf(doorLeaf(design)), DesignKind.door);
      expect(design.nameOf(windowLeaf(design)), startsWith('Opening 1'));
      expect(design.nameOf(doorLeaf(design)), startsWith('Opening 2'));
    });

    test('each opening holds glass, a divider and a panel', () {
      final design = theScreen();

      for (final opening in design.openingsInOrder) {
        expect(design.childDividersOf(opening.sectionId), hasLength(1));

        final panes = design.childSectionsOf(opening.sectionId);
        expect(panes, hasLength(2));
        final materials = {for (final pane in panes) pane.finish.material};
        expect(materials, contains(MaterialKind.panel));
        expect(materials.any((m) => m.isGlazing), isTrue);
      }
    });

    test('and the tree both views walk says exactly that', () {
      final tree = DesignTree.of(theScreen());

      expect(tree.fixedSections, hasLength(2));
      expect(tree.openings, hasLength(2));
      expect(tree.barIds, hasLength(3));
      for (final branch in tree.openings) {
        expect(branch.barIds, hasLength(1));
        expect(branch.panes, hasLength(2));
      }
    });

    test('the root is never an opening, and the frame never a section', () {
      final design = theScreen();
      for (final opening in design.openings) {
        expect(opening.sectionId, isNot(design.frame!.id));
        expect(opening.sectionId, isNot(design.id));
      }
      expect(design.sectionById(design.frame!.id), isNull);
    });
  });

  group('a door behaves as a door, a window as a window', () {
    test('the door has a lever and a lock; the window has neither', () {
      final design = theScreen();

      final onDoor = {
        for (final p in hardwareOf(design, doorLeaf(design).id)) p.kind,
      };
      final onWindow = {
        for (final p in hardwareOf(design, windowLeaf(design).id)) p.kind,
      };

      expect(onDoor,
          {HardwareKind.hinge, HardwareKind.lever, HardwareKind.lock});
      expect(onWindow, {HardwareKind.hinge, HardwareKind.handle});
    });

    test('both leaves hang on hinges, because both open', () {
      final design = theScreen();
      for (final opening in design.openingsInOrder) {
        final hinges = [
          for (final p in hardwareOf(design, opening.id))
            if (p.kind == HardwareKind.hinge) p,
        ];
        expect(hinges, isNotEmpty,
            reason: '${design.nameOf(opening)} has to hang on something');
      }
    });

    test('the door’s hinges are hidden and the window’s are not', () {
      // The assembly is drawn from the design's own side; a leaf's kind
      // decides which face its hinges are screwed to.
      final design = theScreen();
      for (final piece in design.hardware) {
        expect(design.isConcealed(piece),
            piece.kind.onTheInsideFace &&
                design.kind.seenFrom == Face.outside);
      }
      // This design is a window assembly, so nothing is concealed.
      expect(design.kind.seenFrom, Face.inside);
    });

    test('their handles are different objects, built differently', () {
      final design = theScreen();
      final mesh = MeshBuilder.build(design);

      final doorHandle = hardwareOf(design, doorLeaf(design).id)
          .firstWhere((p) => p.kind.isHandle);
      final windowHandle = hardwareOf(design, windowLeaf(design).id)
          .firstWhere((p) => p.kind.isHandle);

      expect(doorHandle.kind, HardwareKind.lever);
      expect(windowHandle.kind, HardwareKind.handle);

      int facesOf(String id) => [
            for (final facet in mesh.facets)
              if (facet.elementId == id) facet,
          ].length;
      expect(facesOf(doorHandle.id), isNot(facesOf(windowHandle.id)));
      expect(facesOf(doorHandle.id), greaterThan(0));
      expect(facesOf(windowHandle.id), greaterThan(0));
    });
  });

  group('only the designated openings open', () {
    test('a fixed light carries no sash, no hardware and no children', () {
      final design = theScreen();
      final fixed = [
        for (final section in design.topLevelSections)
          if (design.openingOf(section.id) == null) section,
      ];
      expect(fixed, hasLength(2));

      for (final section in fixed) {
        expect(design.openingOf(section.id), isNull,
            reason: 'a light nobody marked does not open');
        expect(design.hasChildren(section.id), isFalse);
        for (final piece in design.hardware) {
          expect(design.sectionHolding(piece.parentId), isNot(section.id));
        }
      }
    });

    test('nothing outside the leaves moves at any angle', () {
      final design = theScreen();
      final theirs = {
        for (final opening in design.openings) ...{
          opening.sectionId,
          for (final element in design.contentsOf(opening)) element.id,
        },
      };

      String elsewhere(double open) => [
            for (final facet
                in MeshBuilder.build(design, openFraction: open).facets)
              if (!theirs.contains(facet.elementId))
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');

      final shut = elsewhere(0);
      expect(shut, isNotEmpty);
      for (final angle in [0.25, 0.5, 0.75, 1.0]) {
        expect(elsewhere(angle), shut, reason: 'at $angle');
      }
    });

    test('and everything inside a leaf does move with it', () {
      final design = theScreen();

      for (final opening in design.openingsInOrder) {
        final mine = {
          opening.sectionId,
          for (final element in design.contentsOf(opening)) element.id,
        };
        String facets(double open) => [
              for (final facet
                  in MeshBuilder.build(design, openFraction: open).facets)
                if (mine.contains(facet.elementId))
                  '${facet.elementId}:${facet.corners.join(',')}',
            ].join('|');

        expect(facets(1), isNot(facets(0)),
            reason: '${design.nameOf(opening)} swings');
      }
    });
  });

  group('internal geometry stays inside its own leaf', () {
    test('every line and pane names the opening it is in', () {
      final design = theScreen();

      for (final opening in design.openingsInOrder) {
        for (final bar in design.childDividersOf(opening.sectionId)) {
          expect(design.openingHolding(bar.parentId)?.id, opening.id);
        }
        for (final pane in design.childSectionsOf(opening.sectionId)) {
          expect(design.openingHolding(pane.parentId)?.id, opening.id);
        }
      }
      // And nothing of one leaf's is in the other's.
      final first = {
        for (final e in design.contentsOf(windowLeaf(design))) e.id,
      };
      final second = {
        for (final e in design.contentsOf(doorLeaf(design))) e.id,
      };
      expect(first.intersection(second), isEmpty);
    });

    test('what is inside a leaf never reaches past it, at any angle', () {
      final design = theScreen();

      for (final opening in design.openingsInOrder) {
        // The bars and the panes, which must stay within the sash. The
        // ironmongery is the one thing that reaches past it, as a handle
        // does, so it is not among them.
        final within = {
          for (final bar in design.childDividersOf(opening.sectionId)) bar.id,
          for (final pane in design.childSectionsOf(opening.sectionId))
            pane.id,
        };
        final leafId = opening.sectionId;

        for (final angle in [0.0, 0.5, 1.0]) {
          final mesh = MeshBuilder.build(design, openFraction: angle);
          final sash = [
            for (final facet in mesh.facets)
              if (facet.elementId == leafId) ...facet.corners,
          ];
          expect(sash, isNotEmpty);
          double lo(Iterable<double> of) => of.reduce((a, b) => a < b ? a : b);
          double hi(Iterable<double> of) => of.reduce((a, b) => a > b ? a : b);

          for (final facet in mesh.facets) {
            if (!within.contains(facet.elementId)) continue;
            for (final corner in facet.corners) {
              expect(corner.x, greaterThanOrEqualTo(lo(sash.map((c) => c.x)) - 1));
              expect(corner.x, lessThanOrEqualTo(hi(sash.map((c) => c.x)) + 1));
              expect(corner.y, greaterThanOrEqualTo(lo(sash.map((c) => c.y)) - 1));
              expect(corner.y, lessThanOrEqualTo(hi(sash.map((c) => c.y)) + 1));
            }
          }
        }
      }
    });

    test('no internal line is ever a division of the design', () {
      final design = theScreen();
      for (final bar in design.topLevelDividers) {
        expect(bar.id, isNot(startsWith('in-')));
        expect(bar.parentId, isNull);
      }
      expect(design.topLevelDividers, hasLength(3));
    });
  });

  group('nothing is randomly added', () {
    test('every facet belongs to a part the design actually has', () {
      final design = theScreen();
      final parts = {for (final element in design.allElements) element.id};

      final mesh = MeshBuilder.build(design);
      expect(mesh.facets, isNotEmpty);
      for (final facet in mesh.facets) {
        expect(parts, contains(facet.elementId));
      }
    });

    test('the parts are exactly what the drawing and the edits made', () {
      final design = theScreen();

      // Three mullions and two internal lines. No more.
      expect(design.dividers, hasLength(5));
      // Four lights and two panes in each opening.
      expect(design.sections, hasLength(8));
      // Two leaves' worth of ironmongery, and nothing loose.
      expect(design.hardware.where((p) => p.parentId == null), isEmpty);
      expect(
        design.hardware.length,
        hardwareOf(design, windowLeaf(design).id).length +
            hardwareOf(design, doorLeaf(design).id).length,
      );
    });

    test('the same design gives the same model, facet for facet', () {
      String fingerprint(Design design) => [
            for (final facet in MeshBuilder.build(design).facets)
              '${facet.elementId}:${facet.role.name}:'
                  '${facet.corners.join(',')}',
          ].join('|');

      expect(fingerprint(theScreen()), fingerprint(theScreen()));
    });
  });

  group('the drawing and the solid are the same design', () {
    test('both views build the same set of parts', () {
      final design = theScreen();
      final tree = DesignTree.of(design);

      final onTheSheet = <String>{
        design.frame!.id,
        ...tree.barIds,
        for (final section in tree.fixedSections) section.sectionId,
        for (final branch in tree.openings) ...{
          branch.sectionId,
          ...branch.barIds,
          for (final pane in branch.panes) pane.sectionId,
        },
        for (final piece in design.hardware) piece.id,
      };

      final inTheModel = facetIds(MeshBuilder.build(design));
      // Everything the solid builds is on the sheet. The frame members are
      // drawn from the frame and carry its id, so the two sets meet there.
      expect(inTheModel.difference(onTheSheet), isEmpty);
      for (final branch in tree.openings) {
        expect(inTheModel, contains(branch.sectionId));
        for (final pane in branch.panes) {
          expect(inTheModel, contains(pane.sectionId));
        }
      }
    });
  });

  group('and the whole of it survives', () {
    String everything(Design design) => [
          for (final opening in design.openingsInOrder)
            '${design.kindOf(opening).name}'
                ':${design.childDividersOf(opening.sectionId).length}'
                ':${design.childSectionsOf(opening.sectionId).length}'
                ':${hardwareOf(design, opening.id).length}',
          '${design.topLevelSections.length}',
          '${design.topLevelDividers.length}',
        ].join('|');

    test('a save and a reload', () {
      final before = theScreen();
      expect(everything(Design.fromJson(before.toJson())), everything(before));
    });

    test('reading the sheet again', () {
      final before = theScreen();
      final again = SketchInterpreter.interpret(before).design;
      expect(everything(again), everything(before));
    });

    test('and an edit to one leaf leaves the other exactly as it was', () {
      final before = theScreen();
      final windowId = windowLeaf(before).id;
      final doorId = doorLeaf(before).id;

      String leaf(Design design, String openingId) {
        final opening = design.openingById(openingId)!;
        return [
          design.sectionById(opening.sectionId)!.outline.corners.toString(),
          for (final bar in design.childDividersOf(opening.sectionId))
            '${bar.id}:${bar.a}|${bar.b}',
          for (final pane in design.childSectionsOf(opening.sectionId))
            '${pane.id}:${pane.finish.material}',
          for (final piece in hardwareOf(design, openingId))
            '${piece.id}:${piece.at}:${piece.kind.name}',
        ].join('|');
      }

      final doorWas = leaf(before, doorId);
      final after = DesignEdits.setOpeningMechanism(
          before, windowId, OpeningMechanism.topHung);

      expect(after.openingById(windowId)!.mechanism,
          OpeningMechanism.topHung);
      expect(leaf(after, doorId), doorWas,
          reason: 'the door is untouched by what the window was told');
    });
  });
}
