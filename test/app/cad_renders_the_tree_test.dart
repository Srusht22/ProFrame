import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/dimension_handles.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/opening_leaf.dart';
import 'package:proframe/domain/sections/section_builder.dart';

// The source the phase names:
//
//   Door/Window
//   ├── Fixed Section
//   ├── Fixed Section
//   └── Opening
//        ├── Glass
//        ├── Internal Divider
//        └── Panel
//
// The CAD drawing must render exactly that — reading the structured geometry
// rather than working the hierarchy out again for itself.

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

/// Paints the design and reports what reached the canvas, by the ids the
/// painter asked the design for. Nothing about the structure is recomputed
/// here — the point is what the painter *reads*.
ViewTransform viewFor(Design design) => ViewTransform.fit(
      design.frame!.outline,
      const Size(1200, 900),
      padding: const EdgeInsets.all(40),
    );

void main() {
  group('the drawing renders the tree it is given', () {
    test('the source is the hierarchy the phase names', () {
      final design = example();
      final tree = DesignTree.of(design);

      expect(tree.fixedSections, hasLength(2));
      expect(tree.openings, hasLength(1));

      final opening = tree.openings.single;
      expect(opening.barIds, ['internal-divider']);
      expect(opening.panes, hasLength(2));

      final materials = [
        for (final pane in opening.panes)
          design.sectionById(pane.sectionId)!.finish.material,
      ];
      expect(materials.where((m) => m.isGlazing), hasLength(1));
      expect(materials.where((m) => m == MaterialKind.panel), hasLength(1));
    });

    test('painting reads the design and changes nothing in it', () {
      final design = example();
      final before = design.toJson().toString();

      final recorder = ui.PictureRecorder();
      CadPainter(
        design: design,
        view: viewFor(design),
        layers: const CadLayers(),
      ).paint(Canvas(recorder), const Size(1200, 900));
      recorder.endRecording();

      expect(design.toJson().toString(), before);
    });

    test('the same design paints the same picture, every time', () {
      final design = example();

      String paint() {
        final recorder = ui.PictureRecorder();
        CadPainter(
          design: design,
          view: viewFor(design),
          layers: const CadLayers(),
        ).paint(Canvas(recorder), const Size(1200, 900));
        final picture = recorder.endRecording();
        return picture.approximateBytesUsed.toString();
      }

      expect(paint(), paint());
    });

    test('a figure is written for every pane the tree calls a leaf', () {
      final design = example();
      final tree = DesignTree.of(design);
      final view = viewFor(design);

      final labelled = <String>{};
      for (final branch in tree.everySection) {
        final section = design.sectionById(branch.sectionId)!;
        if (CadDimensions.sectionSizeAt(design, view, section) != null) {
          labelled.add(branch.sectionId);
        }
      }

      // Only leaves carry their own figure: a branch is described by its
      // panes, so the opening itself is not labelled across them.
      for (final branch in tree.everySection) {
        if (!branch.isLeaf) {
          expect(labelled, isNot(contains(branch.sectionId)),
              reason: 'a branch was labelled over its own panes');
        }
      }
      expect(labelled, contains(tree.fixedSections.first.sectionId));
      for (final pane in tree.openings.single.panes) {
        expect(labelled, contains(pane.sectionId));
      }
    });
  });

  group('the opening stays where it is, and holds what is its', () {
    test('the leaf is drawn on the marked section and nowhere else', () {
      final design = example();
      final tree = DesignTree.of(design);
      final frame = design.frame!;

      // The leaf the painter draws is OpeningLeaf's, read from the section
      // the model says opens. Every other main division has no leaf.
      final opened = design.sectionById(tree.openings.single.sectionId)!;
      expect(OpeningLeaf.innerOf(opened, frame), isNotNull);
      expect(OpeningLeaf.outerOf(opened), opened.outline);

      for (final fixed in tree.fixedSections) {
        expect(design.openingOf(fixed.sectionId), isNull);
      }
      expect(opened.outline.area,
          lessThan(frame.innerOutline.area * 0.45));
    });

    test('the internal divider is drawn inside the opening', () {
      final design = example();
      final tree = DesignTree.of(design);
      final opening = tree.openings.single;
      final box = design.sectionById(opening.sectionId)!.outline;
      final bar = design.dividerById('internal-divider')!;

      expect(opening.barIds, contains('internal-divider'));
      expect(box.holds(bar.segment, reach: bar.widthMm), isTrue);

      // What the painter trims it to: the sash daylight, not the design.
      final daylight =
          OpeningLeaf.daylightAround(design, bar.parentId);
      expect(daylight, isNotNull);
      expect(daylight!.area, lessThan(box.area));
      expect(daylight.area, greaterThan(0));
    });

    test('the design’s own bars are not the opening’s', () {
      final design = example();
      final tree = DesignTree.of(design);

      expect(tree.barIds, ['transom', 'mull']);
      expect(tree.openings.single.barIds, ['internal-divider']);
      for (final id in ['transom', 'mull']) {
        expect(OpeningLeaf.daylightAround(design, design.dividerById(id)!
            .parentId), isNull);
      }
    });
  });

  group('no second interpretation', () {
    test('every part the drawing shows is in the tree exactly once', () {
      final design = example();
      final tree = DesignTree.of(design);

      final sections = [for (final s in tree.everySection) s.sectionId];
      expect(sections.toSet(), hasLength(sections.length));
      expect(sections.toSet(), {for (final s in design.sections) s.id});

      final bars = tree.everyBar.toList();
      expect(bars.toSet(), hasLength(bars.length));
      expect(bars.toSet(), {for (final b in design.dividers) b.id});
    });

    test('what the drawing shows follows the model, not a copy of it', () {
      var design = example();
      final openingId = design.openings.single.sectionId;

      // Move the mullion. The opening is a different size at once, and its
      // bar came with it — nothing in the drawing had to be told.
      design = DesignEdits.moveDivider(design, 'mull', const Vec2(400, 0));
      final tree = DesignTree.of(design);

      expect(tree.openings.single.sectionId, openingId);
      expect(tree.openings.single.barIds, ['internal-divider']);
      final box = design.sectionById(openingId)!.outline;
      final bar = design.dividerById('internal-divider')!;
      expect(box.holds(bar.segment, reach: bar.widthMm), isTrue);
      expect(bar.a.x, closeTo(box.left, 1));
      expect(bar.b.x, closeTo(box.right, 1));
    });

    test('the tree survives a save and a reload unchanged', () {
      final design = example();
      final before = DesignTree.of(design);
      final after = DesignTree.of(Design.fromJson(design.toJson()));

      String shape(DesignTree tree) => [
            tree.frameId,
            tree.barIds.join(','),
            for (final branch in tree.everySection)
              '${branch.sectionId}:${branch.openingId}:'
                  '${branch.barIds.join("+")}:${branch.panes.length}',
          ].join('|');

      expect(shape(after), shape(before));
    });
  });
}
