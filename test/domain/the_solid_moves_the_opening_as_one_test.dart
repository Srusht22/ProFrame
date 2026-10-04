import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The phase: *3D is generated from the same geometry hierarchy as Draw and
// CAD, not a separate interpretation of it.*
//
// Design
// ├── Fixed geometry
// └── Opening
//     ├── Glass
//     ├── Internal divider
//     ├── Panel
//     ├── Handle
//     └── Hinges
//
// If the divider is inside the opening in Draw and CAD it is inside it in 3D;
// if the opening moves, everything in it moves with it; if it turns,
// everything in it turns with it — by the one transform the leaf is placed
// by, not by an offset.
//
// ┌──────────────────────────────────┐
// │              FIXED               │
// ├──────────┬──────────┬────────────┤
// │  >       │          │            │
// │ ─────    │  FIXED   │ same size  │
// │          │          │ as the opening
// └──────────┴──────────┴────────────┘

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// Drawn on the sheet and read: a band across the head and three lights
/// beneath it, the two outer ones the same size and the left one marked; then
/// an incomplete line drawn inside the opening, and the part above it made
/// glass and the part below it a panel.
Design built() {
  final marked = SketchInterpreter.interpret(
    Design(
      id: 'w',
      name: 'Window',
      kind: DesignKind.window,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(
        strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(2400, 0),
            Vec2(2400, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
          pen('transom', const [Vec2(0, 600), Vec2(2400, 600)]),
          pen('left', const [Vec2(800, 600), Vec2(800, 2000)]),
          pen('right', const [Vec2(1600, 600), Vec2(1600, 2000)]),
          pen('mark', const [
            Vec2(250, 1000),
            Vec2(550, 1300),
            Vec2(250, 1600),
          ]),
        ],
      ),
    ),
  ).design;
  final divided = SketchInterpreter.interpret(
    marked.copyWith(
      sketch: Sketch(
        strokes: [
          ...marked.sketch.strokes,
          pen('line', const [Vec2(200, 1200), Vec2(600, 1200)]),
        ],
      ),
    ),
  ).design;
  final panes = panesOf(divided);
  return Infill.fill(divided, {
    panes.first.id: GlassLook.clear.finish,
    panes.last.id: PanelColour.white.finish,
  });
}

OpeningElement openingOf(Design d) => d.openings.single;

List<SectionElement> panesOf(Design d) =>
    d.childSectionsOf(openingOf(d).sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

/// Every id that is the opening's: the opening, the region it is on, and
/// everything it holds.
Set<String> ownedBy(Design d) => {
  openingOf(d).id,
  openingOf(d).sectionId,
  for (final e in d.contentsOf(openingOf(d))) e.id,
};

/// The top level light the same size as the opening, on the far side.
SectionElement twin(Design d) {
  final lower = [
    for (final s in d.topLevelSections)
      if (s.outline.top > d.frame!.outline.top + 300) s,
  ]..sort((a, b) => a.outline.left.compareTo(b.outline.left));
  return lower.last;
}

String keyOf(Facet f, [Vec3 by = Vec3.zero]) => [
  f.role.name,
  for (final c in f.corners) ...[
    (c.x + by.x).toStringAsFixed(3),
    (c.y + by.y).toStringAsFixed(3),
    (c.z + by.z).toStringAsFixed(3),
  ],
].join(',');

List<Facet> ofOpening(Design d, Mesh m) => [
  for (final f in m.facets)
    if (ownedBy(d).contains(f.elementId)) f,
];

List<Facet> notOfOpening(Design d, Mesh m) => [
  for (final f in m.facets)
    if (!ownedBy(d).contains(f.elementId)) f,
];

void main() {
  late Design design;
  setUp(() => design = built());

  test('the hierarchy the phase names, in the model', () {
    final opening = openingOf(design);
    final branch = DesignTree.of(design).openings.single;
    expect(branch.openingId, opening.id);
    expect(branch.barIds, hasLength(1));
    expect(branch.panes, hasLength(2));
    final panes = panesOf(design);
    expect(Infill.isGlass(panes.first.finish), isTrue);
    expect(Infill.isPanel(panes.last.finish), isTrue);
    final hardware = [
      for (final h in design.hardware)
        if (design.openingHolding(h.parentId)?.id == opening.id) h.kind,
    ];
    expect(hardware.where((k) => k.isHandle), isNotEmpty);
    expect(hardware.where((k) => k == HardwareKind.hinge), isNotEmpty);
  });

  test('the solid builds exactly that: every part of the opening, and each '
      'inside the opening', () {
    final mesh = MeshBuilder.build(design);
    final opening = openingOf(design);
    final box = design.sectionById(opening.sectionId)!.outline;
    final divider = design.dividers.singleWhere((d) => d.parentId != null);
    final panes = panesOf(design);

    Iterable<Facet> of(String id) =>
        mesh.facets.where((f) => f.elementId == id);

    // The divider, the glass and the panel are each built, as what they are.
    expect(of(divider.id).map((f) => f.role).toSet(), {FacetRole.bar});
    expect(
      of(panes.first.id).map((f) => f.role).toSet(),
      contains(FacetRole.glazing),
    );
    expect(
      of(panes.last.id).map((f) => f.role).toSet(),
      contains(FacetRole.panel),
    );
    // And the handle and the hinges, as the opening's.
    for (final piece in design.hardware) {
      if (design.openingHolding(piece.parentId)?.id != opening.id) continue;
      expect(of(piece.id), isNotEmpty, reason: '${piece.kind} is built');
    }

    // Shut, the divider, the glass and the panel lie inside the opening's
    // region, as they do on the drawing.
    for (final id in [divider.id, panes.first.id, panes.last.id]) {
      for (final facet in of(id)) {
        for (final corner in facet.corners) {
          expect(
            box.contains(corner.flat),
            isTrue,
            reason: '$id reaches $corner, outside the opening',
          );
        }
      }
    }

    // Every part the tree puts in the opening, the solid builds in it, and
    // it builds nothing in it that the tree does not have.
    final built = {
      for (final f in mesh.facets)
        if (ownedBy(design).contains(f.elementId)) f.elementId,
    };
    expect(built, containsAll([divider.id, for (final p in panes) p.id]));
    expect(built.difference(ownedBy(design)), isEmpty);
  });

  test('the phase\'s test: moved, everything inside the opening moves '
      'together — by the same translation, facet for facet', () {
    final before = design;
    final to = twin(before);
    final from = before.sectionById(openingOf(before).sectionId)!.outline;
    expect(to.outline.width, closeTo(from.width, 1e-6), reason: 'same size');
    expect(to.outline.height, closeTo(from.height, 1e-6));
    final by = Vec3(to.outline.left - from.left, to.outline.top - from.top, 0);
    expect(by.x, greaterThan(1000), reason: 'a real move');

    final after = DesignEdits.moveOpeningToSection(
      before,
      openingOf(before).id,
      to.id,
    );
    expect(openingOf(after).sectionId, to.id);

    // Every facet of the opening — sash, divider, glass, panel, handle and
    // hinges — is where it was, carried across by exactly the move.
    final moved = ofOpening(after, MeshBuilder.build(after));
    final expected = ofOpening(before, MeshBuilder.build(before));
    expect(moved, hasLength(expected.length));
    expect(
      [for (final f in moved) keyOf(f)]..sort(),
      [for (final f in expected) keyOf(f, by)]..sort(),
    );

    // Nothing else moved: the frame, the band, the bars and the fixed light
    // between them are built exactly as they were.
    Set<String> fixed(Design d) => {
      for (final f in notOfOpening(d, MeshBuilder.build(d)))
        if (f.role == FacetRole.frame || f.role == FacetRole.bar) keyOf(f),
    };
    expect(fixed(after), fixed(before));
  });

  test('turned, everything inside the opening turns with it: one rigid '
      'movement for sash, divider, glass, panel, handle and hinges', () {
    for (final d in [
      design,
      DesignEdits.moveOpeningToSection(
        design,
        openingOf(design).id,
        twin(design).id,
      ),
    ]) {
      final shut = ofOpening(d, MeshBuilder.build(d));
      for (final fraction in [0.35, 1.0]) {
        final open = ofOpening(d, MeshBuilder.build(d, openFraction: fraction));
        expect(open, hasLength(shut.length));

        final a = [for (final f in shut) ...f.corners];
        final b = [for (final f in open) ...f.corners];
        expect(b, hasLength(a.length));

        // It moved.
        var furthest = 0.0;
        for (var i = 0; i < a.length; i++) {
          furthest = math.max(furthest, (b[i] - a[i]).length);
        }
        expect(furthest, greaterThan(100));

        // And it moved rigidly, all of it together: every point keeps its
        // distance from three points of the sash, which a separate movement
        // of any child would break.
        final anchors = [0, a.length ~/ 3, (2 * a.length) ~/ 3];
        for (var i = 0; i < a.length; i++) {
          for (final j in anchors) {
            expect((b[i] - b[j]).length, closeTo((a[i] - a[j]).length, 1e-6));
          }
        }
      }

      // Nothing outside the opening moves at all.
      String outside(Mesh m) =>
          ([for (final f in notOfOpening(d, m)) keyOf(f)]..sort()).join('|');
      expect(
        outside(MeshBuilder.build(d, openFraction: 1)),
        outside(MeshBuilder.build(d)),
      );
    }
  });
}
