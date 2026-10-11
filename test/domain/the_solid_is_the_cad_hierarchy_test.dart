import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The phase's source:
//
//   Design
//   ├── Fixed Section
//   └── Opening
//        ├── Glass
//        ├── Internal Divider
//        ├── Panel
//        ├── Handle
//        └── Hinges
//
// The solid must hold exactly those parts — the same set the drawing puts on
// the sheet, because both read the one hierarchy — and everything inside the
// opening must move, swing and resize with it.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

Design built({int lines = 1}) {
  final at = DateTime(2026);
  var design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
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
  design = DesignEdits.setOpening(
    design,
    sash.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedLeft,
    markGlyph: '>',
    markAt: sash.outline.centroid,
  );

  final box = design.sectionById(design.openings.single.sectionId)!.outline;
  for (var i = 1; i <= lines; i++) {
    design = DesignEdits.addLineInside(
      design,
      design.openings.single.sectionId,
      id: 'inner-$i',
      at: Vec2(box.centroid.x, box.top + box.height * i / (lines + 1)),
      horizontal: true,
    );
  }
  final low = design
      .childSectionsOf(design.openings.single.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return design.withElement(low.copyWith(finish: _panel));
}

/// Everything the drawing puts on the sheet, named by id, read from the one
/// hierarchy — the same walk `CadPainter` makes.
Set<String> cadParts(Design design) {
  final tree = DesignTree.of(design);
  return {
    if (tree.frameId != null) tree.frameId!,
    ...tree.everyBar,
    for (final section in tree.everySection)
      if (section.isLeaf) section.sectionId,
    for (final opening in tree.openings) opening.sectionId,
    for (final piece in design.hardware) piece.id,
  };
}

Set<String> solidParts(Mesh mesh) =>
    {for (final facet in mesh.facets) facet.elementId};

/// The geometry inside the opening: its bars and the panes they make. Not
/// its ironmongery — a handle stands proud of the leaf, as a handle does,
/// so it is the one thing inside an opening that reaches past it.
Set<String> geometryInside(Design design) {
  final branch = DesignTree.of(design).openings.single;
  return {
    ...branch.barIds,
    for (final pane in branch.panes) pane.sectionId,
  };
}

/// Everything inside the opening: its bars, its panes and its ironmongery.
Set<String> insideTheOpening(Design design) {
  final branch = DesignTree.of(design).openings.single;
  return {
    ...branch.barIds,
    for (final pane in branch.panes) pane.sectionId,
    for (final piece in design.hardware)
      if (design.sectionHolding(piece.parentId) == branch.sectionId) piece.id,
  };
}

/// How far towards the viewer anything with one of [ids] reaches.
double reachOf(Mesh mesh, Set<String> ids) {
  var most = -1e9;
  for (final facet in mesh.facets) {
    if (!ids.contains(facet.elementId)) continue;
    for (final corner in facet.corners) {
      if (corner.z > most) most = corner.z;
    }
  }
  return most;
}

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
  group('the solid is the drawing’s hierarchy, part for part', () {
    test('the source is the tree the phase names', () {
      final design = built();
      final tree = DesignTree.of(design);
      final branch = tree.openings.single;

      expect(tree.fixedSections, hasLength(1));
      expect(tree.openings, hasLength(1));
      expect(branch.barIds, ['inner-1']);
      expect(branch.panes, hasLength(2));

      final kinds = {
        for (final piece in design.hardware)
          if (design.sectionHolding(piece.parentId) == branch.sectionId)
            piece.kind,
      };
      expect(kinds, containsAll([HardwareKind.hinge, HardwareKind.handle]));
    });

    test('the drawing and the solid hold the same set of parts', () {
      for (final lines in [1, 2, 5]) {
        final design = built(lines: lines);
        final cad = cadParts(design);
        final solid = solidParts(MeshBuilder.build(design));

        expect(solid, cad,
            reason: 'with $lines internal line(s) the two views disagree '
                'about what the design is made of');
      }
    });

    test('every part of the solid is a part of the design', () {
      final design = built(lines: 2);
      final known = {
        design.frame!.id,
        for (final s in design.sections) s.id,
        for (final b in design.dividers) b.id,
        for (final h in design.hardware) h.id,
      };
      for (final facet in MeshBuilder.build(design).facets) {
        expect(known, contains(facet.elementId),
            reason: 'the solid built something the design does not have');
        expect(facet.corners.length, greaterThanOrEqualTo(3));
      }
    });

    test('the solid is a function of the design and keeps nothing', () {
      final design = built();
      final before = design.toJson().toString();
      final once = MeshBuilder.build(design, openFraction: 0.4);
      final twice = MeshBuilder.build(design, openFraction: 0.4);

      expect(design.toJson().toString(), before);
      expect(once.facets.length, twice.facets.length);
      for (var i = 0; i < once.facets.length; i++) {
        expect(twice.facets[i].elementId, once.facets[i].elementId);
        expect(twice.facets[i].corners.length, once.facets[i].corners.length);
      }
    });
  });

  group('what is inside the opening in the drawing is inside it in 3D', () {
    test('the divider and the panes never reach past the leaf', () {
      final design = built(lines: 2);
      final branch = DesignTree.of(design).openings.single;

      for (final open in [0.0, 0.25, 0.6, 1.0]) {
        final mesh = MeshBuilder.build(design, openFraction: open);
        expect(
          reachOf(mesh, geometryInside(design)),
          lessThanOrEqualTo(reachOf(mesh, {branch.sectionId}) + 1),
          reason: 'at $open the inside of the leaf was outside it',
        );
      }
    });

    test('the divider turns with the opening, as the sash does', () {
      final design = built();
      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 0.6);
      final branch = DesignTree.of(design).openings.single;

      final sash = travelled(shut, ajar, branch.sectionId);
      expect(sash, greaterThan(50));
      for (final id in insideTheOpening(design)) {
        // The hinges turn on the hinge line itself, so they move least;
        // everything else goes with the leaf.
        expect(travelled(shut, ajar, id), greaterThan(1),
            reason: '$id stayed behind when the opening swung');
      }
    });

    test('nothing outside the opening moves when it swings', () {
      final design = built(lines: 2);
      final moving = {
        ...insideTheOpening(design),
        DesignTree.of(design).openings.single.sectionId,
      };
      final shut = MeshBuilder.build(design);

      for (final open in [0.3, 1.0]) {
        final ajar = MeshBuilder.build(design, openFraction: open);
        for (final id in solidParts(shut)) {
          if (moving.contains(id)) continue;
          expect(travelled(shut, ajar, id), lessThan(0.001),
              reason: '$id moved when the opening was swung to $open');
        }
      }
    });
  });

  group('moved and resized, the inside stays inside', () {
    test('the opening moved to another light takes its parts with it', () {
      final before = built();
      final wide = before.topLevelSections
          .reduce((a, b) => a.areaMmSq > b.areaMmSq ? a : b);
      final after = DesignEdits.moveOpeningToSection(before, 'o', wide.id);

      expect(solidParts(MeshBuilder.build(after)), cadParts(after));

      final branch = DesignTree.of(after).openings.single;
      expect(branch.barIds, hasLength(1));
      expect(branch.panes, hasLength(2));

      final box = after.sectionById(branch.sectionId)!.outline;
      final bar = after.dividerById(branch.barIds.single)!;
      expect(box.holds(bar.segment, reach: bar.widthMm), isTrue,
          reason: 'the divider was left behind in the light it came from');
    });

    test('the opening resized keeps its geometry inside it', () {
      final before = built(lines: 2);
      final on = before.openings.single.sectionId;

      for (final after in [
        DesignEdits.setSectionWidth(before, on, 600),
        DesignEdits.setSectionHeight(before, on, 900),
        DesignEdits.moveDivider(before, 'mull', const Vec2(300, 0)),
      ]) {
        expect(solidParts(MeshBuilder.build(after)), cadParts(after));

        final branch = DesignTree.of(after).openings.single;
        final box = after.sectionById(branch.sectionId)!.outline;
        for (final id in branch.barIds) {
          final bar = after.dividerById(id)!;
          expect(box.holds(bar.segment, reach: bar.widthMm), isTrue,
              reason: '$id left the opening when it was resized');
        }
        for (final pane in branch.panes) {
          final outline = after.sectionById(pane.sectionId)!.outline;
          expect(box.contains(outline.centroid), isTrue,
              reason: 'a pane left the opening when it was resized');
        }
        final mesh = MeshBuilder.build(after, openFraction: 0.5);
        expect(reachOf(mesh, geometryInside(after)),
            lessThanOrEqualTo(reachOf(mesh, {branch.sectionId}) + 1));
      }
    });

    test('the hinges and handle are the leaf’s however it is stored', () {
      // Asked of the model, not compared by hand: the solid finds a leaf's
      // ironmongery through sectionHolding, so it keeps it whether the
      // hardware names the section or the opening on it.
      final design = built();
      final ours = insideTheOpening(design);

      final hinges = {
        for (final piece in design.hardware)
          if (piece.kind == HardwareKind.hinge) piece.id,
      };
      expect(hinges, isNotEmpty);
      expect(ours, containsAll(hinges));

      final parts = solidParts(MeshBuilder.build(design));
      expect(parts, containsAll(hinges));
      expect(parts, contains('o-handle'));
    });
  });
}
