import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';

// INTERNAL LINES DO NOT CHANGE THE PARENT OPENING.
//
// A line drawn inside an opening may make child sections inside it. It must
// not turn the opening into separate top-level sections, and the opening
// itself must not disappear:
//
//   Opening 40 x 160            Opening            ← still the parent
//   ┌──────────┐                ├── Upper child
//   │          │                ├── Internal divider
//   ├──────────┤        →       └── Lower child
//   │          │
//   └──────────┘

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
      outline: Polygon.rect(0, 0, 2100, 1700),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(
          id: 'mull', a: Vec2(470, 0), b: Vec2(470, 1700), widthMm: 40),
    ],
  ));
}

/// A 40 x 160 cm opening down the left, marked `<`.
Design marked() {
  final design = window();
  final left = design.topLevelSections
      .reduce((a, b) => a.outline.left < b.outline.left ? a : b);
  return DesignEdits.setOpening(
    design,
    left.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedRight,
    markGlyph: '<',
    markAt: left.outline.centroid,
  );
}

Design lineInside(Design design, String id, double downMm) {
  final openingId = design.openings.single.sectionId;
  final box = design.sectionById(openingId)!.outline;
  return DesignEdits.addLineInside(
    design,
    openingId,
    id: id,
    at: Vec2(box.centroid.x, box.top + downMm),
    horizontal: true,
  );
}

void main() {
  group('an internal line does not destroy the opening', () {
    test('the opening is still there, the same size, the same opening', () {
      final before = marked();
      final openingId = before.openings.single.sectionId;
      final was = before.sectionById(openingId)!.outline;
      final mechanism = before.openings.single.mechanism;

      final after = lineInside(before, 'internal-divider', 400);

      expect(after.sectionById(openingId), isNotNull);
      expect(after.sectionById(openingId)!.outline, was);
      expect(after.openings, hasLength(1));
      expect(after.openings.single.sectionId, openingId);
      expect(after.openings.single.mechanism, mechanism);
      expect(after.openings.single.markGlyph, '<');
    });

    test('it makes child sections, not separate top-level ones', () {
      final before = marked();
      final after = lineInside(before, 'internal-divider', 400);
      final branch = DesignTree.of(after).openings.single;

      expect(after.topLevelSections, hasLength(before.topLevelSections.length));
      expect(branch.barIds, ['internal-divider']);
      expect(branch.panes, hasLength(2));
      for (final pane in branch.panes) {
        expect(after.sectionById(pane.sectionId)!.parentId, branch.sectionId);
        expect(after.topLevelSections.map((s) => s.id),
            isNot(contains(pane.sectionId)));
      }
    });

    test('the hierarchy is upper child, divider, lower child', () {
      final design = lineInside(marked(), 'internal-divider', 400);
      final openingId = design.openings.single.sectionId;
      final panes = design.childSectionsOf(openingId)
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      final bar = design.dividerById('internal-divider')!;

      expect(panes, hasLength(2));
      expect(panes.first.outline.bottom, lessThanOrEqualTo(bar.a.y + 1));
      expect(panes.last.outline.top, greaterThanOrEqualTo(bar.a.y - 1));
      expect(bar.parentId, openingId);
    });

    test('setting glass and panel leaves the opening the parent', () {
      var design = lineInside(marked(), 'internal-divider', 400);
      final openingId = design.openings.single.sectionId;
      final low = design
          .childSectionsOf(openingId)
          .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
      design = design.withElement(low.copyWith(finish: _panel));

      final branch = DesignTree.of(design).openings.single;
      expect(branch.sectionId, openingId);
      expect(branch.panes, hasLength(2));

      final materials = [
        for (final pane in branch.panes)
          design.sectionById(pane.sectionId)!.finish.material,
      ];
      expect(materials.where((m) => m.isGlazing), hasLength(1));
      expect(materials.where((m) => m == MaterialKind.panel), hasLength(1));

      // The opening did not disappear into its own panes.
      expect(design.openings, hasLength(1));
      expect(design.sectionById(openingId)!.parentId, isNull);
    });

    test('line after line, the parent opening is untouched', () {
      var design = marked();
      final openingId = design.openings.single.sectionId;
      final was = design.sectionById(openingId)!.outline;
      final tops = design.topLevelSections.length;

      for (final n in [1, 2, 3]) {
        design = lineInside(design, 'in-$n', 300.0 * n);
        final branch = DesignTree.of(design).openings.single;

        expect(design.sectionById(openingId)!.outline, was,
            reason: 'the opening changed shape after $n line(s)');
        expect(design.topLevelSections, hasLength(tops));
        expect(design.openings, hasLength(1));
        expect(branch.sectionId, openingId);
        expect(branch.barIds, hasLength(n));
        expect(branch.panes, hasLength(n + 1));
      }

      // A vertical one as well: a grid inside the sash, still one opening.
      design = DesignEdits.addLineInside(
        design,
        openingId,
        id: 'upright',
        at: Vec2(was.left + 150, was.centroid.y),
        horizontal: false,
      );
      final branch = DesignTree.of(design).openings.single;
      expect(design.sectionById(openingId)!.outline, was);
      expect(design.topLevelSections, hasLength(tops));
      expect(design.openings, hasLength(1));
      expect(branch.barIds, hasLength(4));
      expect(branch.panes, hasLength(8));
      expect(design.openings.single.markGlyph, '<');
    });

    test('deleting the line leaves the opening one undivided pane', () {
      final divided = lineInside(marked(), 'internal-divider', 400);
      final openingId = divided.openings.single.sectionId;
      final was = divided.sectionById(openingId)!.outline;

      final after = DesignEdits.delete(divided, 'internal-divider');

      expect(after.openings, hasLength(1));
      expect(after.openings.single.sectionId, openingId);
      expect(after.sectionById(openingId)!.outline, was);
      expect(after.childSectionsOf(openingId), isEmpty);
      expect(DesignTree.of(after).openings.single.isLeaf, isTrue);
    });
  });
}
