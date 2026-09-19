import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
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

// The phase's source:
//
//   Design
//   ├── Fixed Section
//   ├── Fixed Section
//   └── Opening
//        ├── Glass
//        ├── Internal Divider
//        └── Panel
//
// The drawing must be that, and only that: the divider inside the opening,
// the opening on the side the user marked, and as many internal lines as
// they drew. Not a second reading of the design, and not a picture nudged
// into place.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);
const _size = Size(900, 640);

/// A window of three lights; the far left or the far right is marked, and
/// divided by [internalLines] lines of its own.
Design built({required bool onLeft, int internalLines = 1}) {
  final at = DateTime(2026);
  var design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 3000, 1800),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(id: 'm1', a: Vec2(900, 0), b: Vec2(900, 1800),
          widthMm: 40),
      DividerElement(id: 'm2', a: Vec2(2100, 0), b: Vec2(2100, 1800),
          widthMm: 40),
    ],
  ));

  final lights = [...design.topLevelSections]
    ..sort((a, b) => a.outline.left.compareTo(b.outline.left));
  final sash = onLeft ? lights.first : lights.last;
  design = DesignEdits.setOpening(
    design,
    sash.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedLeft,
    markGlyph: '>',
    markAt: sash.outline.centroid,
  );

  final box = design.sectionById(design.openings.single.sectionId)!.outline;
  for (var i = 1; i <= internalLines; i++) {
    design = DesignEdits.addLineInside(
      design,
      design.openings.single.sectionId,
      id: 'inner-$i',
      at: Vec2(box.centroid.x, box.top + box.height * i / (internalLines + 1)),
      horizontal: true,
    );
  }

  // The lowest pane is the panel of the diagram.
  final panes = design.childSectionsOf(design.openings.single.sectionId);
  if (panes.isEmpty) return design;
  final low = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return design.withElement(low.copyWith(finish: _panel));
}

ViewTransform viewFor(Design design) => ViewTransform.fit(
      design.frame!.outline,
      _size,
      padding: const EdgeInsets.all(40),
    );

/// The drawing, rasterised, so two of them can actually be compared.
Future<Uint8List> pixels(Design design) async {
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: design,
    view: viewFor(design),
    layers: const CadLayers(),
  ).paint(Canvas(recorder), _size);
  final image = await recorder
      .endRecording()
      .toImage(_size.width.round(), _size.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

SectionElement sashOf(Design d) =>
    d.sectionById(d.openings.single.sectionId)!;

void main() {
  group('the drawing is the hierarchy, not a second reading of it', () {
    test('the source is the tree the phase names', () {
      final design = built(onLeft: false);
      final tree = DesignTree.of(design);

      expect(tree.barIds, ['m1', 'm2']);
      expect(tree.fixedSections, hasLength(2));
      expect(tree.openings, hasLength(1));

      final branch = tree.openings.single;
      expect(branch.barIds, ['inner-1']);
      expect(branch.panes, hasLength(2));
      final materials = [
        for (final pane in branch.panes)
          design.sectionById(pane.sectionId)!.finish.material,
      ];
      expect(materials.where((m) => m.isGlazing), hasLength(1));
      expect(materials.where((m) => m == MaterialKind.panel), hasLength(1));
    });

    test('painting reads the design and changes nothing in it', () async {
      final design = built(onLeft: false);
      final before = design.toJson().toString();
      await pixels(design);
      expect(design.toJson().toString(), before);
    });

    test('the same design draws the same picture, to the pixel', () async {
      final design = built(onLeft: false);
      expect(await pixels(design), await pixels(design));
    });

    test('every part drawn is in the tree exactly once', () {
      final design = built(onLeft: false, internalLines: 2);
      final tree = DesignTree.of(design);

      final bars = [...tree.barIds, for (final s in tree.everySection) ...s.barIds];
      expect(bars.toSet(), hasLength(bars.length),
          reason: 'a bar is drawn at two levels');
      expect(bars.toSet(), {for (final b in design.dividers) b.id});

      final sections = [for (final s in tree.everySection) s.sectionId];
      expect(sections.toSet(), hasLength(sections.length));
      expect(sections.toSet(), {for (final s in design.sections) s.id});

      // The design's own bars and the opening's are different bars.
      expect(tree.barIds.toSet()
          .intersection(tree.openings.single.barIds.toSet()), isEmpty);
    });
  });

  group('the divider appears inside the opening', () {
    test('it is within the sash, and trimmed to the sash’s daylight', () {
      final design = built(onLeft: false);
      final bar = design.dividerById('inner-1')!;
      final sash = sashOf(design).outline;

      expect(sash.holds(bar.segment, reach: bar.widthMm), isTrue);

      // What the painter draws it as: the bar's body, clipped to the leaf's
      // own daylight — the same trim the solid makes.
      final daylight = OpeningLeaf.daylightAround(design, bar.parentId);
      expect(daylight, isNotNull);
      final side = bar.segment.unit.perpendicular * (bar.widthMm / 2);
      final body = Polygon([
        bar.a + side,
        bar.b + side,
        bar.b - side,
        bar.a - side,
      ]).clippedTo(daylight!);

      expect(body.isEmpty, isFalse);
      for (final corner in body.corners) {
        expect(sash.contains(corner), isTrue,
            reason: 'the drawn divider reaches outside its opening');
      }
    });

    test('no fixed section is given a bar of the opening’s', () {
      final design = built(onLeft: false, internalLines: 2);
      for (final fixed in DesignTree.of(design).fixedSections) {
        expect(fixed.barIds, isEmpty);
        expect(design.childDividersOf(fixed.sectionId), isEmpty);
        expect(OpeningLeaf.daylightAround(design, fixed.sectionId), isNull);
      }
      for (final id in ['m1', 'm2']) {
        expect(OpeningLeaf.daylightAround(design, design.dividerById(id)!
            .parentId), isNull,
            reason: '$id was trimmed as though it were inside an opening');
      }
    });
  });

  group('the side the user marked is the side that is drawn', () {
    test('marked left it stays left; marked right it stays right', () {
      final left = built(onLeft: true);
      final right = built(onLeft: false);
      final daylight = left.frame!.innerOutline;

      expect(sashOf(left).outline.centroid.x,
          lessThan(daylight.centroid.x));
      expect(sashOf(right).outline.centroid.x,
          greaterThan(daylight.centroid.x));

      // And the divider went with it, rather than staying where it was.
      expect(left.dividerById('inner-1')!.segment.midpoint.x,
          lessThan(daylight.centroid.x));
      expect(right.dividerById('inner-1')!.segment.midpoint.x,
          greaterThan(daylight.centroid.x));
    });

    test('the two are different drawings', () async {
      // If the drawing normalised the opening to a side of its own choosing,
      // these would be the same picture.
      expect(await pixels(built(onLeft: true)),
          isNot(await pixels(built(onLeft: false))));
    });
  });

  group('as many internal lines as the user drew', () {
    test('two lines are two lines, and three panes', () {
      final design = built(onLeft: false, internalLines: 2);
      final branch = DesignTree.of(design).openings.single;

      expect(branch.barIds, ['inner-1', 'inner-2']);
      expect(branch.panes, hasLength(3));
      expect(DesignTree.of(design).barIds, ['m1', 'm2'],
          reason: 'an internal line was drawn as a division of the design');
    });

    test('one line and two lines are different drawings', () async {
      expect(await pixels(built(onLeft: false)),
          isNot(await pixels(built(onLeft: false, internalLines: 2))));
    });

    test('five lines still leave the design’s own drawing alone', () {
      final one = built(onLeft: false);
      final five = built(onLeft: false, internalLines: 5);

      expect(DesignTree.of(five).barIds, DesignTree.of(one).barIds);
      expect(DesignTree.of(five).sections, hasLength(3));
      expect(DesignTree.of(five).openings.single.barIds, hasLength(5));
      expect(DesignTree.of(five).openings.single.panes, hasLength(6));
      expect(sashOf(five).outline, sashOf(one).outline,
          reason: 'the opening’s boundary moved when it was divided');
    });
  });
}
