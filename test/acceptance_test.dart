import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// THE ACCEPTANCE TEST
//
// A 200 × 160 cm window. A 40 cm light down the left, marked `<`. A
// horizontal line drawn 40 cm down that opening. Glass above it, panel
// below.
//
//   Window
//   │
//   ├── Main/Fix geometry
//   │
//   └── Left opening  <
//        ├── Glass
//        ├── Internal divider
//        ├── Panel
//        ├── Hinges
//        └── Handle
//
// and never either of these:
//
//   Window                        Window = Opening
//   ├── Opening
//   ├── Horizontal bar
//   └── Panel
//
// Every step is done the way the user does it: the window is *drawn*, the
// mark is *drawn*, and the design is read from the sheet.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// Step 1–3: the user draws a 200 × 160 window, a mullion down the left, and
/// a `<` in the light it makes. The sheet is then read.
Design drawnAndRead() => SketchInterpreter.interpret(Design(
      id: 'acceptance',
      name: 'Acceptance',
      kind: DesignKind.window,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(2000, 0),
          Vec2(2000, 1600),
          Vec2(0, 1600),
          Vec2(0, 0),
        ]),
        pen('mullion', const [Vec2(470, 0), Vec2(470, 1600)]),
        // A `<`: its point on the left, its arms opening to the right.
        pen('mark', const [Vec2(320, 700), Vec2(200, 800), Vec2(320, 900)]),
      ]),
    )).design;

/// Steps 4–6: the user types the opening's width, draws a line 40 cm down
/// it, and says the lower pane is a panel.
Design acceptance() {
  var design = drawnAndRead();
  final on = design.openings.single.sectionId;

  // 4. The opening is to be 40 cm wide, so they type 40 into its width.
  design = DesignEdits.setSectionWidth(design, on, 400);

  // 5. A horizontal line, 40 cm down that opening.
  final box = design.sectionById(design.openings.single.sectionId)!.outline;
  design = DesignEdits.addLineInside(
    design,
    design.openings.single.sectionId,
    id: 'divider',
    at: Vec2(box.centroid.x, box.top + 400),
    horizontal: true,
  );

  // 6. Glass above, panel below. The upper one is already glass.
  final low = design
      .childSectionsOf(design.openings.single.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return design.withElement(low.copyWith(finish: _panel));
}

String openingSection(Design d) => d.openings.single.sectionId;

List<SectionElement> panes(Design d) => d.childSectionsOf(openingSection(d))
  ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

List<HardwareElement> ironmongery(Design d) => [
      for (final piece in d.hardware)
        if (d.openingHolding(piece.parentId)?.id == d.openings.single.id) piece,
    ];

void main() {
  group('the window the user drew', () {
    test('it is 200 × 160 cm', () {
      final design = acceptance();
      expect(Units.format(design.frame!.widthMm), '200');
      expect(Units.format(design.frame!.heightMm), '160');
    });

    test('it has main geometry and one opening, and nothing else', () {
      final design = acceptance();
      final tree = DesignTree.of(design);

      expect(tree.sections, hasLength(2));
      expect(tree.fixedSections, hasLength(1));
      expect(tree.openings, hasLength(1));
      expect(tree.barIds, hasLength(1), reason: 'the mullion they drew');
    });

    test('the opening is the left one, and it is marked <', () {
      final design = acceptance();
      final opening = design.openings.single;
      final daylight = design.frame!.innerOutline;
      final box = design.sectionById(opening.sectionId)!.outline;

      expect(opening.markGlyph, '<');
      expect(opening.mechanism, OpeningMechanism.hingedRight);
      expect(box.centroid.x, lessThan(daylight.centroid.x));
      expect(Units.format(box.width), '40');
    });
  });

  group('the hierarchy is the one the acceptance test demands', () {
    test('the opening holds glass, a divider, a panel, hinges and a handle',
        () {
      final design = acceptance();
      final branch = DesignTree.of(design).openings.single;
      final two = panes(design);

      expect(branch.barIds, ['divider']);
      expect(two, hasLength(2));
      expect(two.first.finish.material.isGlazing, isTrue, reason: 'glass');
      expect(two.last.finish.material, MaterialKind.panel, reason: 'panel');

      final kinds = {for (final p in ironmongery(design)) p.kind};
      expect(kinds, contains(HardwareKind.hinge));
      expect(kinds, contains(HardwareKind.handle));
    });

    test('every one of them is a child of the opening, not of the window', () {
      final design = acceptance();
      final opening = design.openings.single;

      for (final id in [
        'divider',
        for (final pane in panes(design)) pane.id,
        for (final piece in ironmongery(design)) piece.id,
      ]) {
        final element = design.elementById(id);
        expect(element, isNotNull, reason: '$id is missing');
        final parent = switch (element!) {
          DividerElement(:final parentId) => parentId,
          SectionElement(:final parentId) => parentId,
          HardwareElement(:final parentId) => parentId,
          _ => null,
        };
        expect(parent, opening.id,
            reason: '$id is not a child of the opening');
        expect(design.openingHolding(parent)!.id, opening.id);
      }
    });

    test('the whole of it is the opening’s contents, and nothing else is', () {
      final design = acceptance();
      final opening = design.openings.single;
      final inside = {for (final e in design.contentsOf(opening)) e.id};

      expect(inside, contains('divider'));
      for (final pane in panes(design)) {
        expect(inside, contains(pane.id));
      }
      for (final piece in ironmongery(design)) {
        expect(inside, contains(piece.id));
      }

      // The fixed light, the mullion and the frame are not the opening's.
      expect(inside, isNot(contains(design.frame!.id)));
      expect(inside, isNot(contains(DesignTree.of(design)
          .fixedSections.single.sectionId)));
      for (final bar in design.topLevelDividers) {
        expect(inside, isNot(contains(bar.id)));
      }
    });
  });

  group('and never either of the two it forbids', () {
    test('NOT: window → opening, horizontal bar, panel', () {
      final design = acceptance();
      final tree = DesignTree.of(design);

      // The bar and the panel are not divisions of the window.
      expect(tree.barIds, isNot(contains('divider')));
      expect(design.topLevelDividers.map((b) => b.id),
          isNot(contains('divider')));
      for (final pane in panes(design)) {
        expect(design.topLevelSections.map((s) => s.id),
            isNot(contains(pane.id)));
        expect(pane.parentId, isNotNull);
      }
      // Drawing inside the opening added no main division at all.
      expect(design.topLevelSections,
          hasLength(DesignTree.of(drawnAndRead()).sections.length));
    });

    test('NOT: window = opening', () {
      final design = acceptance();
      final opening = design.openings.single;
      final daylight = design.frame!.innerOutline;
      final box = design.sectionById(opening.sectionId)!.outline;

      expect(opening.sectionId, isNot(design.id));
      expect(opening.sectionId, isNot(design.frame!.id));
      expect(design.sectionById(design.frame!.id), isNull);
      expect(box.area, lessThan(daylight.area * 0.3));
      expect(box.right, lessThan(daylight.right));

      // The light beside it is fixed, and carries no ironmongery.
      final fixed = DesignTree.of(design).fixedSections.single;
      expect(design.openingOf(fixed.sectionId), isNull);
      for (final piece in design.hardware) {
        expect(design.sectionHolding(piece.parentId),
            isNot(fixed.sectionId));
      }
    });
  });

  group('the figures, as a workshop would cut them', () {
    test('the opening is 40 cm wide and fills the height of the daylight',
        () {
      final design = acceptance();
      final box = design.sectionById(openingSection(design))!.outline;
      final daylight = design.frame!.innerOutline;

      expect(Units.format(box.width), '40');
      // 160 cm is the window over its frame. The light inside it is the
      // daylight — the frame's own section taken off head and sill — so the
      // opening is 148 cm, and 160 would be a figure nobody could cut to.
      expect(Units.format(box.height), Units.format(daylight.height));
      expect(Units.format(box.height), '148');
    });

    test('the divider is 40 cm down the opening, and is real material', () {
      final design = acceptance();
      expect(
        Units.format(
            DesignEdits.alongWithin(design, design.dividerById('divider'))!),
        '40',
      );
      expect(design.dividerById('divider')!.widthMm, greaterThan(0));
    });

    test('glass, divider and panel fill the opening exactly', () {
      final design = acceptance();
      final two = panes(design);
      final bar = design.dividerById('divider')!;
      final box = design.sectionById(openingSection(design))!.outline;

      expect(Units.format(two.first.widthMm), '40');
      expect(Units.format(two.last.widthMm), '40');

      // The phase writes 40 × 40 and 40 × 120: the arithmetic for a divider
      // of no thickness in a light of the window's full height. The divider
      // is real material and the glass stops at its faces, so the panes are
      // shorter than that — and the three together are the opening exactly,
      // which 40 + 120 in a 148 cm light would not be.
      expect(
        two.first.heightMm + bar.widthMm + two.last.heightMm,
        closeTo(box.height, 0.01),
      );
      expect(two.first.heightMm, lessThan(400));
      expect(two.last.heightMm, greaterThan(two.first.heightMm));
    });

    test('every figure the user sees is centimetres', () {
      final design = acceptance();
      expect(Units.symbol, 'cm');
      for (final mm in [
        design.frame!.widthMm,
        design.sectionById(openingSection(design))!.widthMm,
        design.dividerById('divider')!.lengthMm,
        for (final pane in panes(design)) pane.heightMm,
      ]) {
        expect(Units.label(mm), endsWith(' cm'));
      }
    });
  });

  group('the same design all the way through', () {
    test('the drawing and the solid hold the same parts', () {
      final design = acceptance();
      final tree = DesignTree.of(design);
      final cad = {
        tree.frameId!,
        ...tree.everyBar,
        for (final s in tree.everySection) if (s.isLeaf) s.sectionId,
        for (final o in tree.openings) o.sectionId,
        for (final h in design.hardware) h.id,
      };
      expect({
        for (final f in MeshBuilder.build(design).facets) f.elementId,
      }, cad);
    });

    test('the solid builds glass as glass and the panel as a panel', () {
      final design = acceptance();
      final two = panes(design);
      final roles = <String, Set<FacetRole>>{};
      for (final facet in MeshBuilder.build(design).facets) {
        roles.putIfAbsent(facet.elementId, () => {}).add(facet.role);
      }

      expect(roles[two.first.id], contains(FacetRole.glazing));
      expect(roles[two.last.id], contains(FacetRole.panel));
      expect(roles['divider'], {FacetRole.bar});
      expect(roles[openingSection(design)], contains(FacetRole.sash));
      expect(roles[DesignTree.of(design).fixedSections.single.sectionId],
          isNot(contains(FacetRole.sash)));
    });

    test('the drawing can be painted, and painting changes nothing', () {
      final design = acceptance();
      final before = design.toJson().toString();
      final recorder = ui.PictureRecorder();
      CadPainter(
        design: design,
        view: ViewTransform.fit(design.frame!.outline, const Size(900, 640),
            padding: const EdgeInsets.all(40)),
        layers: const CadLayers(),
      ).paint(Canvas(recorder), const Size(900, 640));
      recorder.endRecording();
      expect(design.toJson().toString(), before);
    });

    test('only the opening swings, and it takes its own with it', () {
      final design = acceptance();
      final mine = {
        openingSection(design),
        'divider',
        for (final pane in panes(design)) pane.id,
        for (final piece in ironmongery(design)) piece.id,
      };
      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 1);

      String where(Mesh m, String id) => [
            for (final f in m.facets)
              if (f.elementId == id)
                for (final c in f.corners)
                  '${c.x.toStringAsFixed(4)},${c.y.toStringAsFixed(4)},'
                      '${c.z.toStringAsFixed(4)}',
          ].join('|');

      for (final id in {for (final f in shut.facets) f.elementId}) {
        if (mine.contains(id)) {
          expect(where(ajar, id), isNot(where(shut, id)),
              reason: '$id did not go with the opening');
        } else {
          expect(where(ajar, id), where(shut, id),
              reason: '$id moved though it is not the opening’s');
        }
      }
    });

    test('it survives a save and a reload as the same hierarchy', () {
      final design = acceptance();
      final back = Design.fromJson(design.toJson());

      String shape(Design d) {
        final tree = DesignTree.of(d);
        return [
          tree.frameId,
          tree.barIds.join('+'),
          for (final branch in tree.everySection)
            '${branch.sectionId}:${branch.openingId}:'
                '${branch.barIds.join("&")}:${branch.panes.length}',
          for (final piece in d.hardware)
            '${piece.id}@${d.sectionHolding(piece.parentId)}',
        ].join('|');
      }

      expect(shape(back), shape(design));
      expect(back.openings.single.markGlyph, '<');
      expect(panes(back).last.finish.material, MaterialKind.panel);
    });
  });
}
