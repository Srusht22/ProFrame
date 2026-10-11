import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The phase's source:
//
//   Opening
//   ├── Hinges
//   └── Handle
//
// The ironmongery is the opening's — a child of it, not of the door. It goes
// where the opening goes, turns when it turns, and a section nobody marked
// carries none of it.

/// A window of two lights, the left one marked.
Design marked({OpeningMechanism mechanism = OpeningMechanism.hingedLeft}) {
  final design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 2400, 1800),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(id: 'mull', a: Vec2(1000, 0), b: Vec2(1000, 1800),
          widthMm: 40),
    ],
  ));
  final sash = design.topLevelSections
      .reduce((a, b) => a.outline.left < b.outline.left ? a : b);
  return DesignEdits.setOpening(
    design,
    sash.id,
    openingId: 'o',
    mechanism: mechanism,
    markGlyph: '>',
    markAt: sash.outline.centroid,
  );
}

/// The ironmongery this opening carries, asked of the model.
List<HardwareElement> hardwareOf(Design design, OpeningElement opening) => [
      for (final piece in design.hardware)
        if (design.openingHolding(piece.parentId)?.id == opening.id) piece,
    ];

double travelled(Mesh shut, Mesh ajar, String id) {
  final a = [for (final f in shut.facets) if (f.elementId == id) ...f.corners];
  final b = [for (final f in ajar.facets) if (f.elementId == id) ...f.corners];
  expect(a, hasLength(b.length));
  var most = 0.0;
  for (var i = 0; i < a.length; i++) {
    final gap = math.sqrt(math.pow(a[i].x - b[i].x, 2) +
        math.pow(a[i].y - b[i].y, 2) +
        math.pow(a[i].z - b[i].z, 2));
    if (gap > most) most = gap;
  }
  return most;
}

void main() {
  group('an opening carries hinges and a handle', () {
    test('it has both, and they are its own', () {
      final design = marked();
      final opening = design.openings.single;
      final mine = hardwareOf(design, opening);

      expect(mine.where((p) => p.kind == HardwareKind.hinge), isNotEmpty);
      expect(mine.where((p) => p.kind == HardwareKind.handle), hasLength(1));
      for (final piece in mine) {
        expect(design.openingHolding(piece.parentId)!.id, opening.id);
      }
      expect({for (final e in design.contentsOf(opening)) e.id},
          containsAll([for (final p in mine) p.id]));
    });

    test('the parent it names is the opening, not the door', () {
      final design = marked();
      final opening = design.openings.single;

      for (final piece in hardwareOf(design, opening)) {
        // A child of the opening — not of the frame, not of the design, and
        // not loose on the root with no parent at all.
        expect(piece.parentId, opening.id);
        expect(piece.parentId, isNot(design.id));
        expect(piece.parentId, isNot(design.frame!.id));
        expect(piece.parentId, isNotNull);
        expect(piece.isOpeningHardware, isTrue);
      }
    });

    test('a section nobody marked carries none', () {
      final design = marked();
      final fixed = DesignTree.of(design).fixedSections;

      expect(fixed, isNotEmpty);
      for (final section in fixed) {
        expect(design.openingOf(section.sectionId), isNull);
        for (final piece in design.hardware) {
          expect(design.sectionHolding(piece.parentId),
              isNot(section.sectionId),
              reason: '${piece.id} was put on a section nobody marked');
        }
      }
    });

    test('a design with no opening has no ironmongery at all', () {
      final plain = SectionBuilder.rebuild(Design(
        id: 'p',
        name: 'test',
        kind: DesignKind.door,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        frame: FrameElement(
          id: 'f',
          outline: Polygon.rect(0, 0, 1000, 2100),
          profileMm: 50,
        ),
      ));

      expect(plain.openings, isEmpty);
      expect(plain.hardware, isEmpty,
          reason: 'a door-shaped section is not an opening');
    });

    test('cancelling the opening takes its ironmongery with it', () {
      final design = marked();
      expect(design.hardware, isNotEmpty);

      final shut = DesignEdits.setOpening(
        design,
        design.openings.single.sectionId,
        openingId: 'o',
        mechanism: OpeningMechanism.fixed,
      );
      expect(shut.openings, isEmpty);
      expect(shut.hardware, isEmpty);
    });
  });

  group('it goes where the opening goes', () {
    test('the opening moved to another light takes its hardware along', () {
      final before = marked();
      final was = {for (final p in before.hardware) p.id};
      final wide = before.topLevelSections
          .reduce((a, b) => a.areaMmSq > b.areaMmSq ? a : b);

      final after = DesignEdits.moveOpeningToSection(before, 'o', wide.id);
      final opening = after.openings.single;
      final mine = hardwareOf(after, opening);

      expect(mine, isNotEmpty);
      expect({for (final p in mine) p.id}, was,
          reason: 'the ironmongery was rebuilt as somebody else’s');

      final box = after.sectionById(opening.sectionId)!.outline;
      for (final piece in mine) {
        expect(box.awayFrom(piece.at), lessThan(60),
            reason: '${piece.id} was left behind in the light it came from');
      }
    });

    test('the opening resized keeps its hardware on its edges', () {
      final before = marked();
      for (final after in [
        DesignEdits.setSectionWidth(
            before, before.openings.single.sectionId, 600),
        DesignEdits.setSectionHeight(
            before, before.openings.single.sectionId, 900),
        DesignEdits.moveDivider(before, 'mull', const Vec2(300, 0)),
      ]) {
        final opening = after.openings.single;
        final box = after.sectionById(opening.sectionId)!.outline;
        final mine = hardwareOf(after, opening);

        expect(mine, isNotEmpty);
        for (final piece in mine) {
          expect(box.awayFrom(piece.at), lessThan(60),
              reason: '${piece.id} is off the leaf it hangs on');
        }
      }
    });

    test('the hinges change sides when the opening does', () {
      final left = marked();
      final right = marked(mechanism: OpeningMechanism.hingedRight);
      final box = left.sectionById(left.openings.single.sectionId)!.outline;

      double hingeX(Design d) {
        final hinges = [
          for (final p in hardwareOf(d, d.openings.single))
            if (p.kind == HardwareKind.hinge) p.at.x,
        ];
        expect(hinges, isNotEmpty);
        return hinges.reduce((a, b) => a + b) / hinges.length;
      }

      expect(hingeX(left), closeTo(box.left, 60));
      expect(hingeX(right), closeTo(box.right, 60));
    });
  });

  group('it turns when the opening turns', () {
    test('every piece swings with the leaf', () {
      final design = marked();
      final opening = design.openings.single;
      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 0.7);

      final mine = hardwareOf(design, opening);
      expect(mine, isNotEmpty);
      for (final piece in mine) {
        // The hinges turn on the hinge line itself, so they move least; the
        // handle is at the far stile and travels furthest. All of it moves.
        expect(travelled(shut, ajar, piece.id), greaterThan(1),
            reason: '${piece.id} stayed on the frame while the leaf swung');
      }

      final handle = mine.firstWhere((p) => p.kind == HardwareKind.handle);
      final hinge = mine.firstWhere((p) => p.kind == HardwareKind.hinge);
      expect(travelled(shut, ajar, handle.id),
          greaterThan(travelled(shut, ajar, hinge.id)));
    });

    test('nothing the opening does not own moves at all', () {
      final design = marked();
      final mine = {for (final p in hardwareOf(design, design.openings.single))
        p.id};
      final sash = design.openings.single.sectionId;
      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 1);

      for (final id in {for (final f in shut.facets) f.elementId}) {
        if (mine.contains(id) || id == sash) continue;
        expect(travelled(shut, ajar, id), lessThan(0.001),
            reason: '$id moved when the opening swung');
      }
    });

    test('the solid builds the hardware the model says the opening has', () {
      final design = marked();
      final mine = {for (final p in hardwareOf(design, design.openings.single))
        p.id};
      final built = {
        for (final facet in MeshBuilder.build(design).facets)
          if (facet.role == FacetRole.hardware) facet.elementId,
      };
      expect(built, mine);
    });
  });

  group('the ironmongery is worked out, never remembered', () {
    test('it is rebuilt from the opening, so it cannot drift', () {
      final design = marked();
      final before = [for (final p in design.hardware) '${p.id}@${p.at}'];

      // An edit that changes nothing about the opening leaves it identical.
      final again = SectionBuilder.rebuild(design);
      expect([for (final p in again.hardware) '${p.id}@${p.at}'], before);
    });

    test('hardware the user placed themselves is never regenerated', () {
      final design = marked();
      final mine = design.copyWith(hardware: [
        ...design.hardware,
        const HardwareElement(
          id: 'my-knocker',
          kind: HardwareKind.knob,
          at: Vec2(300, 300),
        ),
      ]);

      final after = SectionBuilder.rebuild(mine);
      final kept = after.hardware.where((p) => p.id == 'my-knocker');
      expect(kept, hasLength(1));
      expect(kept.single.at, const Vec2(300, 300));
      expect(kept.single.parentId, isNull,
          reason: 'what the user placed is theirs, not the opening’s');
      expect(kept.single.isOpeningHardware, isFalse);
    });
  });
}
