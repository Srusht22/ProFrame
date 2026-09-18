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

// The rule this phase holds:
//
//   Door/Window
//   ├── Fixed section
//   ├── Fixed section
//   └── Opening
//        ├── Glass
//        ├── Divider
//        └── Panel
//
// The solid has that structure because the drawing has it, and when the
// opening opens, ONLY the opening moves. The frame stays, the fixed sections
// stay, the bars that divide the design stay, and everything inside the
// opening — its glass, its panel, its divider, its hinges and its handle —
// goes with it.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

/// A window with a transom across it and a mullion under the transom: an
/// upper light, and two lights below.
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

SectionElement lowerRight(Design design) {
  final below = [
    for (final s in design.topLevelSections)
      if (s.outline.top > 400) s,
  ];
  return below.reduce((a, b) => a.outline.left > b.outline.left ? a : b);
}

Design marked(Design design) => DesignEdits.setOpening(
      design,
      lowerLeft(design).id,
      openingId: 'o',
      mechanism: OpeningMechanism.hingedRight,
      markGlyph: '<',
      markAt: lowerLeft(design).outline.centroid,
    );

/// The opening divided into glass over panel by a line drawn inside it.
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
  final low = out
      .childSectionsOf(openingId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return out.withElement(low.copyWith(finish: _panel));
}

Design example() => divided(marked(window()));

/// Every part of the opening: its sash, its bars, its panes, its hardware.
Set<String> opensWith(Design design, String openingSectionId) {
  final tree = DesignTree.of(design);
  final branch =
      tree.everySection.firstWhere((s) => s.sectionId == openingSectionId);
  return {
    for (final section in branch.andItsPanes) section.sectionId,
    for (final section in branch.andItsPanes) ...section.barIds,
    for (final piece in design.hardware)
      if (branch.andItsPanes.any((s) => s.sectionId == piece.parentId))
        piece.id,
  };
}

/// Every facet of one element, written out so two builds can be compared
/// exactly rather than approximately.
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

/// The corners of one element, for measuring how far it travelled.
List<Vec3> cornersOf(Mesh mesh, String elementId) => [
      for (final facet in mesh.facets)
        if (facet.elementId == elementId) ...facet.corners,
    ];

/// The middle of one element's glazing, which both a plain pane and a pane
/// with a sash around it have, so the two can be compared.
Vec3 glassMiddleOf(Mesh mesh, String elementId) {
  var x = 0.0, y = 0.0, z = 0.0, n = 0;
  for (final facet in mesh.facets) {
    if (facet.elementId != elementId) continue;
    if (facet.role != FacetRole.glazing) continue;
    for (final c in facet.corners) {
      x += c.x;
      y += c.y;
      z += c.z;
      n++;
    }
  }
  expect(n, greaterThan(0));
  return Vec3(x / n, y / n, z / n);
}

double apart(Vec3 a, Vec3 b) => math.sqrt(math.pow(a.x - b.x, 2) +
    math.pow(a.y - b.y, 2) +
    math.pow(a.z - b.z, 2));

double movedBy(Mesh shut, Mesh ajar, String elementId) {
  final a = cornersOf(shut, elementId);
  final b = cornersOf(ajar, elementId);
  expect(a, hasLength(b.length));
  var most = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = math.sqrt(math.pow(a[i].x - b[i].x, 2) +
        math.pow(a[i].y - b[i].y, 2) +
        math.pow(a[i].z - b[i].z, 2));
    if (d > most) most = d;
  }
  return most;
}

void main() {
  group('the solid has the drawing’s structure', () {
    test('the same parts, from the same tree', () {
      final design = example();
      final tree = DesignTree.of(design);
      final built = {
        for (final facet in MeshBuilder.build(design).facets)
          if (facet.role != FacetRole.hardware) facet.elementId,
      };

      expect(built, {
        tree.frameId!,
        ...tree.everyBar,
        for (final section in tree.everySection)
          if (section.isLeaf) section.sectionId,
        for (final opening in tree.openings) opening.sectionId,
      });
    });

    test('one sash, and it is the marked section', () {
      final design = example();
      final sashes = {
        for (final facet in MeshBuilder.build(design).facets)
          if (facet.role == FacetRole.sash) facet.elementId,
      };
      expect(sashes, {design.openings.single.sectionId});

      // The frame is not a sash, and neither is any fixed section.
      expect(sashes, isNot(contains('f')));
      expect(sashes, isNot(contains(lowerRight(design).id)));
    });

    test('glass above, a divider between, a panel below — inside the leaf',
        () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final roles = <String, Set<FacetRole>>{};
      for (final facet in MeshBuilder.build(design).facets) {
        roles.putIfAbsent(facet.elementId, () => {}).add(facet.role);
      }

      final panes = design.childSectionsOf(openingId);
      final glass = panes.reduce((a, b) => a.outline.top < b.outline.top ? a : b);
      final panel = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);

      expect(roles[glass.id], {FacetRole.glazing});
      expect(roles[panel.id], {FacetRole.panel});
      expect(roles['inner'], {FacetRole.bar});
      expect(roles[openingId], {FacetRole.sash});
    });
  });

  group('only the opening moves', () {
    test('the frame and everything outside stays exactly where it is', () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final moving = opensWith(design, openingId);

      final shut = MeshBuilder.build(design);
      for (final open in [0.15, 0.4, 0.75, 1.0]) {
        final ajar = MeshBuilder.build(design, openFraction: open);
        for (final id in {
          for (final facet in shut.facets) facet.elementId,
        }) {
          if (moving.contains(id)) continue;
          expect(
            fingerprint(ajar, id),
            fingerprint(shut, id),
            reason: '$id moved when the opening was swung to $open',
          );
        }
      }
    });

    test('the fixed sections, the frame and the design’s bars are named', () {
      final design = example();
      final moving = opensWith(design, design.openings.single.sectionId);

      // Everything the phase forbids moving, by name.
      expect(moving, isNot(contains('f')));
      expect(moving, isNot(contains('transom')));
      expect(moving, isNot(contains('mull')));
      for (final fixed in DesignTree.of(design).fixedSections) {
        expect(moving, isNot(contains(fixed.sectionId)));
      }
    });

    test('the whole design does not become the opening', () {
      final design = example();
      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 1);

      final still = <String>{};
      final swung = <String>{};
      for (final id in {for (final f in shut.facets) f.elementId}) {
        (movedBy(shut, ajar, id) > 1 ? swung : still).add(id);
      }

      // More stays than moves: the window is not the leaf.
      expect(still, isNotEmpty);
      expect(still, contains('f'));
      expect(swung, contains(design.openings.single.sectionId));
      expect(
        swung,
        opensWith(design, design.openings.single.sectionId),
      );
    });
  });

  group('the opening carries its contents through the swing', () {
    test('its glass, its panel, its divider and its hardware all travel', () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 0.6);

      final hinges = {
        for (final piece in design.hardware)
          if (piece.parentId == openingId &&
              piece.kind == HardwareKind.hinge)
            piece.id,
      };
      expect(hinges, isNotEmpty);

      for (final id in opensWith(design, openingId)) {
        // Every part of the opening moves. The hinges sit on the hinged edge
        // itself, so they turn on the spot rather than travelling across the
        // window — but they turn, which is what says they are the leaf's.
        expect(
          movedBy(shut, ajar, id),
          greaterThan(hinges.contains(id) ? 1 : 50),
          reason: '$id stayed behind when the opening swung',
        );
      }
    });

    test('the leaf turns rigidly: nothing inside it is stretched', () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final inside = opensWith(design, openingId);

      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 0.5);

      final before = <Vec3>[];
      final after = <Vec3>[];
      for (final id in inside) {
        before.addAll(cornersOf(shut, id));
        after.addAll(cornersOf(ajar, id));
      }
      expect(before, hasLength(after.length));
      expect(before.length, greaterThan(20));

      double gap(Vec3 a, Vec3 b) => math.sqrt(math.pow(a.x - b.x, 2) +
          math.pow(a.y - b.y, 2) +
          math.pow(a.z - b.z, 2));

      // A rotation keeps every distance. Sampled across the whole leaf, so a
      // pane left behind or a bar carried the wrong way would show up as the
      // leaf being torn rather than turned.
      for (var i = 0; i < before.length; i += 7) {
        for (var j = i + 11; j < before.length; j += 29) {
          expect(
            gap(after[i], after[j]),
            closeTo(gap(before[i], before[j]), 0.5),
          );
        }
      }
    });

    test('swinging it changes nothing about the design', () {
      final design = example();
      final before = design.toJson().toString();
      MeshBuilder.build(design, openFraction: 0.9);
      expect(design.toJson().toString(), before);
    });
  });

  group('two openings, and one inside another', () {
    test('each swings about its own edge and neither drags the other', () {
      var design = example();
      design = DesignEdits.setOpening(
        design,
        lowerRight(design).id,
        openingId: 'o-right',
        mechanism: OpeningMechanism.hingedLeft,
        markGlyph: '>',
        markAt: lowerRight(design).outline.centroid,
      );

      final left = design.openings.firstWhere((o) => o.id == 'o').sectionId;
      final right =
          design.openings.firstWhere((o) => o.id == 'o-right').sectionId;

      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 0.5);

      expect(movedBy(shut, ajar, left), greaterThan(50));
      expect(movedBy(shut, ajar, right), greaterThan(50));
      // The upper light between and above them is untouched by either.
      for (final fixed in DesignTree.of(design).fixedSections) {
        expect(fingerprint(ajar, fixed.sectionId),
            fingerprint(shut, fixed.sectionId));
      }
      expect(fingerprint(ajar, 'transom'), fingerprint(shut, 'transom'));
      expect(fingerprint(ajar, 'mull'), fingerprint(shut, 'mull'));
    });

    test('a pane of a sash that opens too is a leaf inside a leaf', () {
      var design = example();
      final openingId = design.openings.single.sectionId;
      final pane = design
          .childSectionsOf(openingId)
          .reduce((a, b) => a.outline.top < b.outline.top ? a : b);
      design = DesignEdits.setOpening(
        design,
        pane.id,
        openingId: 'o2',
        mechanism: OpeningMechanism.hingedLeft,
        markGlyph: '>',
        markAt: pane.outline.centroid,
      );

      final roles = <String, Set<FacetRole>>{};
      for (final facet in MeshBuilder.build(design).facets) {
        roles.putIfAbsent(facet.elementId, () => {}).add(facet.role);
      }

      // The drawing gives it a leaf, so the solid does too.
      expect(roles[pane.id], contains(FacetRole.sash));
      expect(roles[openingId], contains(FacetRole.sash));

      // Its own hinges and handle are built, where before they were nowhere.
      final its = [
        for (final piece in design.hardware)
          if (piece.parentId == pane.id) piece.id,
      ];
      expect(its, isNotEmpty);
      for (final id in its) {
        expect(roles[id], {FacetRole.hardware});
      }

      // It swings within its parent: its own turn on top of the one it
      // hangs in. The same pane in the same design, unmarked, is carried by
      // the parent alone and ends up somewhere else entirely.
      final shut = MeshBuilder.build(design);
      final ajar = MeshBuilder.build(design, openFraction: 0.5);
      final carried = MeshBuilder.build(example(), openFraction: 0.5);

      expect(
        apart(glassMiddleOf(shut, pane.id), glassMiddleOf(ajar, pane.id)),
        greaterThan(50),
      );
      expect(
        apart(glassMiddleOf(carried, pane.id), glassMiddleOf(ajar, pane.id)),
        greaterThan(50),
        reason: 'the pane swung only with its parent, not on its own hinge',
      );

      // And still nothing outside either of them moves.
      expect(fingerprint(ajar, 'f'), fingerprint(shut, 'f'));
      expect(fingerprint(ajar, 'transom'), fingerprint(shut, 'transom'));
      for (final fixed in DesignTree.of(design).fixedSections) {
        expect(fingerprint(ajar, fixed.sectionId),
            fingerprint(shut, fixed.sectionId));
      }
    });
  });
}
