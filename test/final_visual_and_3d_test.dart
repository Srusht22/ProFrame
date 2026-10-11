import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/opening_leaf.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// THE FINAL TEST
//
// The drawing the user gave, drawn the way they draw it:
//
//   ┌───────────────────────────────┐
//   │             FIXED             │
//   ├───────┬───────────────────────┤
//   │ GLASS │                       │
//   ├───────┤          FIXED        │
//   │ PANEL │                       │
//   └───────┴───────────────────────┘
//
// A band across the head, and beneath it a narrow left column and a wide
// right one. The left column is the opening. The line between GLASS and
// PANEL is *inside that opening*: it must not appear above the opening, it
// must not become a bar of the window, and it must not move outside the
// opening.
//
// And the solid must be the same thing:
//
//   Fixed frame + fixed sections + Opening
//                                  ├── Glass
//                                  ├── Divider
//                                  ├── Panel
//                                  ├── Hinges
//                                  └── Handle
//
// Only the opening opens. The rest of the window stays exactly where it is.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);
const _size = Size(900, 640);

/// The window, over its frame.
const _widthMm = 2000.0;
const _heightMm = 1600.0;

/// The transom, and the mullion that hangs from it down to the sill.
const _transomMm = 500.0;
const _mullionMm = 500.0;

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// The sheet: the outline, the transom across the whole width, the mullion
/// below it, and a `>` drawn in the lower left light.
Design sheet() => SketchInterpreter.interpret(Design(
      id: 'final',
      name: 'Final',
      kind: DesignKind.window,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(_widthMm, 0),
          Vec2(_widthMm, _heightMm),
          Vec2(0, _heightMm),
          Vec2(0, 0),
        ]),
        pen('transom', const [Vec2(0, _transomMm), Vec2(_widthMm, _transomMm)]),
        pen('mullion',
            const [Vec2(_mullionMm, _transomMm), Vec2(_mullionMm, _heightMm)]),
        // A `>`: its point on the right, its arms opening to the left.
        pen('mark', const [
          Vec2(230, 950),
          Vec2(350, 1050),
          Vec2(230, 1150),
        ]),
      ]),
    )).design;

/// The sheet, with the line the user then draws *inside* the opening, and
/// the lower pane made a panel.
Design drawn() {
  var design = sheet();
  final on = design.openings.single.sectionId;
  final box = design.sectionById(on)!.outline;

  design = DesignEdits.addLineInside(
    design,
    on,
    id: 'divider',
    at: Vec2(box.centroid.x, box.top + box.height * 0.4),
    horizontal: true,
  );

  final low = design
      .childSectionsOf(design.openings.single.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return design.withElement(low.copyWith(finish: _panel));
}

/// The same line drawn on the *sheet* instead — a bar of the window. This is
/// the thing the drawing must not look like.
Design asGlobalBar() {
  final design = sheet();
  final box = design.sectionById(design.openings.single.sectionId)!.outline;
  return DesignEdits.addDivider(
    design,
    id: 'divider',
    a: Vec2(0, box.top + box.height * 0.4),
    b: Vec2(_widthMm, box.top + box.height * 0.4),
  );
}

SectionElement sashOf(Design d) => d.sectionById(d.openings.single.sectionId)!;

/// The light across the head, and the wide light beside the opening.
List<SectionElement> fixedLights(Design d) => [
      for (final branch in DesignTree.of(d).fixedSections)
        d.sectionById(branch.sectionId)!,
    ];

SectionElement upperBand(Design d) =>
    fixedLights(d).reduce((a, b) => a.outline.top < b.outline.top ? a : b);

SectionElement rightLight(Design d) =>
    fixedLights(d).reduce((a, b) => a.outline.left > b.outline.left ? a : b);

List<SectionElement> panes(Design d) =>
    d.childSectionsOf(d.openings.single.sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

List<HardwareElement> ironmongery(Design d) => [
      for (final piece in d.hardware)
        if (d.openingHolding(piece.parentId)?.id == d.openings.single.id) piece,
    ];

/// What the painter actually lays down for the bar: its body, clipped to the
/// leaf's own daylight, exactly as `_barBody` clips it.
Polygon drawnBodyOf(Design design, String barId) {
  final bar = design.dividerById(barId)!;
  final side = bar.segment.unit.perpendicular * (bar.widthMm / 2);
  final body = Polygon([bar.a + side, bar.b + side, bar.b - side, bar.a - side]);
  final daylight = OpeningLeaf.daylightAround(design, bar.parentId);
  return daylight == null ? body : body.clippedTo(daylight);
}

ViewTransform viewFor(Design design) => ViewTransform.fit(
      design.frame!.outline,
      _size,
      padding: const EdgeInsets.all(40),
    );

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

String placeOf(Mesh mesh, String id) => [
      for (final facet in mesh.facets)
        if (facet.elementId == id)
          for (final corner in facet.corners)
            '${corner.x.toStringAsFixed(4)},${corner.y.toStringAsFixed(4)},'
                '${corner.z.toStringAsFixed(4)}',
    ].join('|');

void main() {
  group('the drawing the user drew', () {
    test('a band across the head, a narrow left light and a wide right one',
        () {
      final design = drawn();
      final tree = DesignTree.of(design);

      expect(tree.sections, hasLength(3), reason: 'three main divisions');
      expect(tree.fixedSections, hasLength(2));
      expect(tree.openings, hasLength(1));
      expect(tree.barIds.toSet(),
          {for (final bar in design.topLevelDividers) bar.id});
      expect(tree.barIds, hasLength(2), reason: 'the transom and the mullion');

      final head = upperBand(design);
      final right = rightLight(design);
      final sash = sashOf(design);

      // The band runs the whole width; the two below it share what is left.
      expect(head.outline.width,
          closeTo(design.frame!.innerOutline.width, 0.01));
      expect(head.outline.bottom, lessThanOrEqualTo(sash.outline.top + 0.01));
      expect(head.outline.bottom, lessThanOrEqualTo(right.outline.top + 0.01));

      // Narrow on the left, wide on the right.
      expect(sash.outline.width, lessThan(right.outline.width));
      expect(sash.outline.left, lessThan(right.outline.left));

      // The narrow light is the daylight from the jamb to the mullion: the
      // mullion's own material taken off, as a workshop would cut it. The
      // figure is derived rather than quoted, because quoting one would be
      // a second opinion about where the user drew the line.
      final mullion = design.topLevelDividers
          .reduce((a, b) => a.segment.unit.y.abs() > b.segment.unit.y.abs()
              ? a
              : b);
      expect(
        sash.outline.width,
        closeTo(
          _mullionMm -
              mullion.widthMm / 2 -
              design.frame!.innerOutline.left,
          0.01,
        ),
      );
      expect(Units.label(sash.outline.width), endsWith(' cm'));
    });

    test('the left light is the opening, and the other two are fixed', () {
      final design = drawn();
      final opening = design.openings.single;

      expect(opening.markGlyph, '>');
      expect(opening.sectionId, sashOf(design).id);
      for (final fixed in fixedLights(design)) {
        expect(design.openingOf(fixed.id), isNull,
            reason: '${fixed.id} opens, and nobody marked it');
      }

      // And never the window itself.
      expect(opening.sectionId, isNot(design.id));
      expect(opening.sectionId, isNot(design.frame!.id));
      expect(sashOf(design).outline.area,
          lessThan(design.frame!.innerOutline.area * 0.25));
    });

    test('GLASS over PANEL, both the opening’s', () {
      final design = drawn();
      final two = panes(design);

      expect(two, hasLength(2));
      expect(two.first.finish.material.isGlazing, isTrue);
      expect(two.last.finish.material, MaterialKind.panel);
      for (final pane in two) {
        expect(pane.parentId, design.openings.single.id);
        expect(design.topLevelSections.map((s) => s.id),
            isNot(contains(pane.id)));
      }
    });
  });

  group('the divider is inside the opening', () {
    test('it is the opening’s child, and not a bar of the window', () {
      final design = drawn();
      final bar = design.dividerById('divider')!;

      expect(bar.parentId, design.openings.single.id);
      expect(design.openingHolding(bar.parentId)?.id,
          design.openings.single.id);
      expect(design.topLevelDividers.map((b) => b.id),
          isNot(contains('divider')));
      expect(DesignTree.of(design).barIds, isNot(contains('divider')));
      expect(DesignTree.of(design).openings.single.barIds, ['divider']);
    });

    test('every part of it lies within the opening', () {
      final design = drawn();
      final bar = design.dividerById('divider')!;
      final sash = sashOf(design).outline;

      expect(sash.holds(bar.segment, reach: bar.widthMm), isTrue);

      final body = drawnBodyOf(design, 'divider');
      expect(body.isEmpty, isFalse);
      for (final corner in body.corners) {
        expect(sash.contains(corner), isTrue,
            reason: 'the drawn divider reaches outside its opening');
      }
    });

    test('it does not appear above the opening', () {
      final design = drawn();
      final sash = sashOf(design).outline;
      final head = upperBand(design).outline;
      final body = drawnBodyOf(design, 'divider');

      expect(body.top, greaterThan(sash.top));
      expect(body.bottom, lessThan(sash.bottom));
      for (final corner in body.corners) {
        expect(head.contains(corner), isFalse,
            reason: 'the divider is drawn in the band across the head');
      }
      expect(upperBand(design).outline.bottom, lessThanOrEqualTo(body.top));
    });

    test('it does not move outside the opening, into the light beside it',
        () {
      final design = drawn();
      final right = rightLight(design).outline;
      final body = drawnBodyOf(design, 'divider');

      for (final corner in body.corners) {
        expect(right.contains(corner), isFalse,
            reason: 'the divider crosses into the fixed light');
      }
      expect(body.right, lessThanOrEqualTo(right.left + 0.01));

      // Neither fixed light is given a bar of the opening's.
      for (final fixed in DesignTree.of(design).fixedSections) {
        expect(fixed.barIds, isEmpty);
        expect(design.childDividersOf(fixed.sectionId), isEmpty);
      }
    });

    test('the picture says so too', () async {
      final design = drawn();

      // The same design draws the same picture, so the comparisons below
      // are about the design and not about the painter.
      expect(await pixels(design), await pixels(design));

      // A line inside the opening and the same line drawn on the sheet are
      // different pictures: the drawing is not quietly promoting it to a
      // bar of the window.
      expect(await pixels(design), isNot(await pixels(asGlobalBar())));

      // And it is not simply being left out: the opening with its line and
      // the opening without it are different pictures.
      expect(await pixels(design), isNot(await pixels(sheet())));
    });

    test('the opening is still one opening, with its boundary where it was',
        () {
      final before = sheet();
      final after = drawn();

      expect(after.openings, hasLength(1));
      expect(after.openings.single.id, before.openings.single.id);
      expect(sashOf(after).outline.corners.length,
          sashOf(before).outline.corners.length);
      for (final (i, corner) in sashOf(after).outline.corners.indexed) {
        final was = sashOf(before).outline.corners[i];
        expect(corner.x, closeTo(was.x, 0.01));
        expect(corner.y, closeTo(was.y, 0.01));
      }
      // And the window's own divisions are exactly what they were.
      expect([for (final s in after.topLevelSections) s.id].length,
          [for (final s in before.topLevelSections) s.id].length);
      expect([for (final b in after.topLevelDividers) b.id],
          [for (final b in before.topLevelDividers) b.id]);
    });
  });

  group('the solid is that same drawing', () {
    test('it builds a frame, two fixed lights and one opening', () {
      final design = drawn();
      final roles = <String, Set<FacetRole>>{};
      for (final facet in MeshBuilder.build(design).facets) {
        roles.putIfAbsent(facet.elementId, () => {}).add(facet.role);
      }

      expect(roles, contains(design.frame!.id));
      expect(roles[sashOf(design).id], contains(FacetRole.sash));
      for (final fixed in fixedLights(design)) {
        expect(roles[fixed.id], isNot(contains(FacetRole.sash)),
            reason: '${fixed.id} was given a leaf nobody marked');
      }
    });

    test('the opening holds glass, a divider, a panel, hinges and a handle',
        () {
      final design = drawn();
      final roles = <String, Set<FacetRole>>{};
      for (final facet in MeshBuilder.build(design).facets) {
        roles.putIfAbsent(facet.elementId, () => {}).add(facet.role);
      }
      final two = panes(design);

      expect(roles[two.first.id], contains(FacetRole.glazing));
      expect(roles[two.last.id], contains(FacetRole.panel));
      expect(roles['divider'], {FacetRole.bar});

      final kinds = {for (final piece in ironmongery(design)) piece.kind};
      expect(kinds, contains(HardwareKind.hinge));
      expect(kinds, contains(HardwareKind.handle));
      for (final piece in ironmongery(design)) {
        expect(piece.parentId, design.openings.single.id);
        expect(roles, contains(piece.id));
      }
    });

    test('the drawing and the solid are the same set of parts', () {
      final design = drawn();
      final tree = DesignTree.of(design);
      final cad = {
        tree.frameId!,
        ...tree.everyBar,
        for (final branch in tree.everySection)
          if (branch.isLeaf) branch.sectionId,
        for (final branch in tree.openings) branch.sectionId,
        for (final piece in design.hardware) piece.id,
      };
      expect({
        for (final facet in MeshBuilder.build(design).facets) facet.elementId,
      }, cad);
    });

    test('only the opening opens; the rest of the window stays fixed', () {
      final design = drawn();
      final mine = {
        sashOf(design).id,
        'divider',
        for (final pane in panes(design)) pane.id,
        for (final piece in ironmongery(design)) piece.id,
      };
      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 1);

      for (final id in {for (final facet in shut.facets) facet.elementId}) {
        if (mine.contains(id)) {
          expect(placeOf(ajar, id), isNot(placeOf(shut, id)),
              reason: '$id did not go with the opening');
        } else {
          expect(placeOf(ajar, id), placeOf(shut, id),
              reason: '$id moved though it is not the opening’s');
        }
      }

      // Named outright, because this is the claim: the frame, the band
      // across the head, the light beside it and the window's own bars.
      for (final id in [
        design.frame!.id,
        for (final fixed in fixedLights(design)) fixed.id,
        for (final bar in design.topLevelDividers) bar.id,
      ]) {
        expect(placeOf(ajar, id), placeOf(shut, id));
        expect(mine, isNot(contains(id)));
      }
    });

    test('what is inside the leaf stays inside it as it swings', () {
      final design = drawn();
      final inside = {'divider', for (final pane in panes(design)) pane.id};

      for (final at in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final mesh = MeshBuilder.build(design, openFraction: at);
        final leaf = [
          for (final facet in mesh.facets)
            if (facet.elementId == sashOf(design).id) ...facet.corners,
        ];
        expect(leaf, isNotEmpty);
        final low = leaf.map((c) => c.z).reduce((a, b) => a < b ? a : b);
        final high = leaf.map((c) => c.z).reduce((a, b) => a > b ? a : b);

        for (final facet in mesh.facets) {
          if (!inside.contains(facet.elementId)) continue;
          for (final corner in facet.corners) {
            expect(corner.z, greaterThanOrEqualTo(low - 1));
            expect(corner.z, lessThanOrEqualTo(high + 1));
          }
        }
      }
    });
  });

  test('and it is all still there after a save and a reload', () {
    final design = drawn();
    final back = Design.fromJson(design.toJson());

    String shape(Design d) {
      final tree = DesignTree.of(d);
      return [
        tree.frameId,
        tree.barIds.join('+'),
        for (final branch in tree.everySection)
          '${branch.sectionId}:${branch.openingId}:'
              '${branch.barIds.join("&")}:${branch.panes.length}',
      ].join('/');
    }

    expect(shape(back), shape(design));
    expect(back.dividerById('divider')!.parentId,
        design.openings.single.id);
  });
}
