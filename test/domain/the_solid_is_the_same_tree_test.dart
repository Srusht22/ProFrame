import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/viewer/model_view.dart';
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

// Source and result are the same tree:
//
//   Door/Window
//   ├── Fixed Section
//   ├── Fixed Section
//   └── Opening
//        ├── Glass
//        ├── Internal Divider
//        └── Panel
//
// Only the opening opens. The frame, the fixed sections and the design's own
// bars stay exactly where they are; the glass, the panel, the internal
// divider, the hinges and the handle go with the opening.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

Design window() {
  final at = DateTime(2026);
  return SectionBuilder.rebuild(Design(
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
      DividerElement(
          id: 'transom', a: Vec2(0, 700), b: Vec2(2400, 700), widthMm: 40),
      DividerElement(
          id: 'mull', a: Vec2(1400, 700), b: Vec2(1400, 1800), widthMm: 40),
    ],
  ));
}

SectionElement lowerLeft(Design design) {
  final below = [
    for (final s in design.topLevelSections)
      if (s.outline.top > 500) s,
  ];
  return below.reduce((a, b) => a.outline.left < b.outline.left ? a : b);
}

Design example() {
  var design = window();
  design = DesignEdits.setOpening(
    design,
    lowerLeft(design).id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedLeft,
    markGlyph: '>',
    markAt: lowerLeft(design).outline.centroid,
  );

  final openingId = design.openings.single.sectionId;
  final box = design.sectionById(openingId)!.outline;
  design = DesignEdits.addLineInside(
    design,
    openingId,
    id: 'internal-divider',
    at: Vec2(box.centroid.x, box.top + 400),
    horizontal: true,
  );
  final low = design
      .childSectionsOf(openingId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return design.withElement(low.copyWith(finish: _panel));
}

/// Everything the opening owns, from the design's own hierarchy.
Set<String> openingParts(Design design) {
  final opening = design.openings.single;
  return {
    opening.parentId,
    for (final part in design.contentsOf(opening)) part.id,
  };
}

String fingerprint(Mesh mesh, String elementId) {
  final lines = <String>[];
  for (final facet in mesh.facets) {
    if (facet.elementId != elementId) continue;
    lines.add([
      facet.role.name,
      for (final c in facet.corners)
        '${c.x.toStringAsFixed(6)},'
            '${c.y.toStringAsFixed(6)},'
            '${c.z.toStringAsFixed(6)}',
    ].join('|'));
  }
  return lines.join('\n');
}

double travelled(Mesh shut, Mesh ajar, String elementId) {
  final a = [
    for (final f in shut.facets)
      if (f.elementId == elementId) ...f.corners,
  ];
  final b = [
    for (final f in ajar.facets)
      if (f.elementId == elementId) ...f.corners,
  ];
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
  group('the solid is built from the tree, part for part', () {
    test('the source and the result are the same set of parts', () {
      final design = example();
      final tree = DesignTree.of(design);

      final expected = {
        tree.frameId!,
        ...tree.everyBar,
        for (final section in tree.everySection)
          if (section.isLeaf) section.sectionId,
        for (final opening in tree.openings) opening.sectionId,
      };
      final built = {
        for (final facet in MeshBuilder.build(design).facets)
          if (facet.role != FacetRole.hardware) facet.elementId,
      };
      expect(built, expected);
    });

    test('two fixed sections, one opening holding three things', () {
      final design = example();
      final tree = DesignTree.of(design);
      final roles = <String, Set<FacetRole>>{};
      for (final facet in MeshBuilder.build(design).facets) {
        roles.putIfAbsent(facet.elementId, () => {}).add(facet.role);
      }

      expect(tree.fixedSections, hasLength(2));
      for (final fixed in tree.fixedSections) {
        expect(roles[fixed.sectionId], isNot(contains(FacetRole.sash)));
      }

      final opening = tree.openings.single;
      expect(roles[opening.sectionId], contains(FacetRole.sash));
      expect(roles['internal-divider'], {FacetRole.bar});

      final panes = [
        for (final pane in opening.panes)
          design.sectionById(pane.sectionId)!,
      ]..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      expect(roles[panes.first.id], {FacetRole.glazing});
      expect(roles[panes.last.id], {FacetRole.panel});
    });

    test('the solid is a function of the design and keeps nothing', () {
      final design = example();
      final before = design.toJson().toString();

      final once = MeshBuilder.build(design, openFraction: 0.4);
      final twice = MeshBuilder.build(design, openFraction: 0.4);

      expect(design.toJson().toString(), before);
      expect(once.facets.length, twice.facets.length);
      for (final id in {for (final f in once.facets) f.elementId}) {
        expect(fingerprint(twice, id), fingerprint(once, id));
      }
    });

    test('every face is a face of the design, not of a picture of it', () {
      final design = example();
      final known = {
        design.frame!.id,
        for (final s in design.sections) s.id,
        for (final d in design.dividers) d.id,
        for (final h in design.hardware) h.id,
      };
      for (final facet in MeshBuilder.build(design).facets) {
        expect(known, contains(facet.elementId));
        expect(facet.corners.length, greaterThanOrEqualTo(3));
      }
    });
  });

  group('only the opening is openable', () {
    test('the frame, the fixed sections and the design’s bars never move',
        () {
      final design = example();
      final moving = openingParts(design);
      final shut = MeshBuilder.build(design);

      for (final open in [0.2, 0.55, 1.0]) {
        final ajar = MeshBuilder.build(design, openFraction: open);
        for (final id in {for (final f in shut.facets) f.elementId}) {
          if (moving.contains(id)) continue;
          expect(fingerprint(ajar, id), fingerprint(shut, id),
              reason: '$id moved when the opening was swung to $open');
        }
      }

      expect(moving, isNot(contains('f')));
      expect(moving, isNot(contains('transom')));
      expect(moving, isNot(contains('mull')));
      for (final fixed in DesignTree.of(design).fixedSections) {
        expect(moving, isNot(contains(fixed.sectionId)));
      }
    });

    test('the divider, the glass, the panel and the hardware go with it', () {
      final design = example();
      final opening = design.openings.single;
      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 0.6);

      final hinges = {
        for (final piece in design.hardware)
          if (piece.parentId == opening.parentId &&
              piece.kind == HardwareKind.hinge)
            piece.id,
      };
      expect(hinges, isNotEmpty);

      for (final id in openingParts(design)) {
        // The hinges turn on the hinge line itself, so they move least;
        // everything else travels. All of it moves.
        expect(travelled(shut, ajar, id),
            greaterThan(hinges.contains(id) ? 1 : 50),
            reason: '$id stayed behind');
      }
    });

    test('the divider stays physically inside the opening as it swings', () {
      final design = example();
      final opening = design.openings.single;

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

      for (final open in [0.0, 0.3, 0.7, 1.0]) {
        final mesh = MeshBuilder.build(design, openFraction: open);
        final sash = reachOf(mesh, {opening.parentId});
        final inside = reachOf(mesh, {
          'internal-divider',
          for (final pane in design.childSectionsOf(opening.parentId))
            pane.id,
        });
        // What is inside the leaf never reaches past the leaf itself: it is
        // carried by it, not flung out of it.
        expect(inside, lessThanOrEqualTo(sash + 1),
            reason: 'at $open the inside of the leaf was outside it');
      }
    });
  });

  group('picking the opening picks all of it', () {
    test('its sash, its divider, its panes and its hardware light up', () {
      final design = example();
      final opening = design.openings.single;
      final lit = partsOfOpening(design, opening.id);

      expect(lit, contains(opening.parentId));
      expect(lit, contains('internal-divider'));
      for (final pane in design.childSectionsOf(opening.parentId)) {
        expect(lit, contains(pane.id));
      }
      for (final piece in design.hardware) {
        if (piece.parentId != opening.parentId) continue;
        expect(lit, contains(piece.id));
      }
    });

    test('nothing outside the opening lights up with it', () {
      final design = example();
      final lit = partsOfOpening(design, design.openings.single.id);

      expect(lit, isNot(contains('f')));
      expect(lit, isNot(contains('transom')));
      expect(lit, isNot(contains('mull')));
      for (final fixed in DesignTree.of(design).fixedSections) {
        expect(lit, isNot(contains(fixed.sectionId)));
      }
      // And what lights up is exactly what moves.
      expect(lit, openingParts(design));
    });

    test('picking one pane stays that one pane', () {
      final design = example();
      final pane =
          design.childSectionsOf(design.openings.single.parentId).first;
      expect(partsOfOpening(design, pane.id), isEmpty);
      expect(partsOfOpening(design, 'transom'), isEmpty);
      expect(partsOfOpening(design, null), isEmpty);
    });
  });
}
