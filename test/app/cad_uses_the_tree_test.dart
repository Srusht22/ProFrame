import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
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

// The drawing the phase asks the CAD renderer to show:
//
//   Door/Window
//   ├── Fixed geometry        the frame, and the bars that divide the design
//   ├── Fixed sections        the lights that do not open
//   └── Opening               the one section the user marked
//        ├── its boundary
//        ├── its internal lines
//        ├── glass
//        └── panel
//
// The window itself is never the opening.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

/// A window 200 x 160 cm of daylight, a transom across it and a mullion under
/// the transom: three main divisions — an upper light, and two below it.
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
      outline: Polygon.rect(0, 0, 2100, 1700),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(
          id: 'transom', a: Vec2(0, 600), b: Vec2(2100, 600), widthMm: 40),
      DividerElement(
          id: 'mull', a: Vec2(900, 600), b: Vec2(900, 1700), widthMm: 40),
    ],
  ));
}

SectionElement lowerLeft(Design design) {
  final below = [
    for (final s in design.topLevelSections)
      if (s.outline.top > 400) s,
  ];
  return below.reduce((a, b) => a.outline.left < b.outline.left ? a : b);
}

/// The lower left light marked `<`, then divided into glass over panel.
Design marked(Design design) {
  final light = lowerLeft(design);
  return DesignEdits.setOpening(
    design,
    light.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedRight,
    markGlyph: '<',
    markAt: light.outline.centroid,
  );
}

Design divided(Design design) {
  final openingId = design.openings.single.sectionId;
  final box = design.sectionById(openingId)!.outline;
  final out = DesignEdits.addLineInside(
    design,
    openingId,
    id: 'inner',
    at: Vec2(box.centroid.x, box.top + 300),
    horizontal: true,
  );
  final panes = out.childSectionsOf(openingId);
  final low = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return out.withElement(low.copyWith(finish: _panel));
}

Design example() => divided(marked(window()));

TreeSection openingBranch(DesignTree tree) => tree.openings.single;

void main() {
  group('the drawing is the design’s own tree', () {
    test('the frame is not a branch, and nothing is inside it', () {
      final design = example();
      final tree = DesignTree.of(design);

      expect(tree.frameId, 'f');
      expect(
        tree.everySection.map((s) => s.sectionId),
        isNot(contains('f')),
      );
      // The frame is not a section, so it can never be a section's parent.
      for (final section in design.sections) {
        expect(section.parentId, isNot('f'));
      }
      for (final bar in design.dividers) {
        expect(bar.parentId, isNot('f'));
      }
    });

    test('the main divisions are the design’s, and the opening is one', () {
      final design = example();
      final tree = DesignTree.of(design);

      expect(tree.sections, hasLength(3));
      expect(tree.barIds, ['transom', 'mull']);
      expect(tree.openings, hasLength(1));
      expect(openingBranch(tree).sectionId, lowerLeft(design).id);

      // Two of the three do not open, and neither holds anything.
      expect(tree.fixedSections, hasLength(2));
      for (final fixed in tree.fixedSections) {
        expect(fixed.opens, isFalse);
        expect(fixed.barIds, isEmpty);
        expect(fixed.panes, isEmpty);
      }
    });

    test('the whole window is never the opening', () {
      final design = example();
      final tree = DesignTree.of(design);
      final opening = openingBranch(tree);
      final box = design.sectionById(opening.sectionId)!.outline;
      final daylight = design.frame!.innerOutline;

      expect(box.width, lessThan(daylight.width * 0.6));
      expect(box.height, lessThan(daylight.height * 0.8));
      // And the opening is a branch, not the root: every other main division
      // is outside it and stays fixed.
      for (final other in tree.sections) {
        if (other.sectionId == opening.sectionId) continue;
        expect(other.opens, isFalse);
      }
    });

    test('the opening holds its boundary, its lines and its panes', () {
      final design = example();
      final opening = openingBranch(DesignTree.of(design));

      expect(opening.barIds, ['inner']);
      expect(opening.panes, hasLength(2));
      expect(opening.isLeaf, isFalse);

      final materials = [
        for (final pane in opening.panes)
          design.sectionById(pane.sectionId)!.finish.material,
      ];
      expect(materials.where((m) => m.isGlazing), hasLength(1));
      expect(materials.where((m) => m == MaterialKind.panel), hasLength(1));

      // Its boundary is its section's, and nothing wider.
      final section = design.sectionById(opening.sectionId)!;
      expect(section.outline, isNot(design.frame!.outline));
      expect(section.outline.area, lessThan(design.frame!.innerOutline.area));
    });

    test('nothing outside the opening is in it', () {
      final design = example();
      final opening = openingBranch(DesignTree.of(design));
      final inside = {
        opening.sectionId,
        ...opening.barIds,
        for (final pane in opening.panes) pane.sectionId,
      };

      expect(inside, isNot(contains('transom')));
      expect(inside, isNot(contains('mull')));
      for (final fixed in DesignTree.of(design).fixedSections) {
        expect(inside, isNot(contains(fixed.sectionId)));
      }
    });

    test('every part of the design is in the tree exactly once', () {
      final design = example();
      final tree = DesignTree.of(design);

      final sections = [for (final s in tree.everySection) s.sectionId];
      expect(sections.toSet(), hasLength(sections.length));
      expect(sections.toSet(), {for (final s in design.sections) s.id});

      final bars = tree.everyBar.toList();
      expect(bars.toSet(), hasLength(bars.length));
      expect(bars.toSet(), {for (final b in design.dividers) b.id});
    });
  });

  group('one interpretation, not two', () {
    test('the solid is built from the same tree the drawing walks', () {
      final design = example();
      final tree = DesignTree.of(design);
      // What the tree says there is to build: the frame, every bar at every
      // level, every pane that was not divided again, and a sash for each
      // opening. A section that holds panes is built as its panes, not as a
      // pane of its own.
      final drawn = {
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
      expect(built, drawn);
    });

    test('an opening deep in the tree is still only that section', () {
      var design = example();
      final openingId = design.openings.single.sectionId;
      final pane = design.childSectionsOf(openingId).first;

      // The user marks a pane of the sash as well. It opens; the sash around
      // it still opens; nothing else does.
      design = DesignEdits.setOpening(
        design,
        pane.id,
        openingId: 'o2',
        mechanism: OpeningMechanism.hingedLeft,
        markGlyph: '>',
        markAt: pane.outline.centroid,
      );

      final tree = DesignTree.of(design);
      expect(tree.openings.map((o) => o.sectionId).toSet(),
          {openingId, pane.id});
      expect(tree.sections.where((s) => s.opens), hasLength(1));
      expect(tree.fixedSections, hasLength(2));
    });
  });

  group('the figures outside the drawing measure the design', () {
    test('a diagonal drawn inside a sash does not strike them off', () {
      final design = example();
      expect(DimensionChains.isRectilinear(design), isTrue);
      expect(DimensionChains.of(design), isNotEmpty);

      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      final slanted = design.copyWith(dividers: [
        ...design.dividers,
        DividerElement(
          id: 'slant',
          a: Vec2(box.left, box.top),
          b: Vec2(box.right, box.bottom),
          widthMm: 20,
          parentId: openingId,
        ),
      ]);

      // The design's own bars are still square, so its bands still mean
      // something and its figures are still written.
      expect(DimensionChains.isRectilinear(slanted), isTrue);
      expect(
        DimensionChains.of(slanted).length,
        DimensionChains.of(design).length,
      );
    });

    test('a diagonal that divides the design does strike them off', () {
      final design = example();
      final slanted = design.copyWith(dividers: [
        ...design.dividers,
        const DividerElement(
          id: 'slant',
          a: Vec2(100, 100),
          b: Vec2(1900, 1500),
          widthMm: 20,
        ),
      ]);
      expect(DimensionChains.isRectilinear(slanted), isFalse);
    });
  });
}
