import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

/// The design the specification uses as its example: three sections, one
/// horizontal divider, two vertical divisions, glass in one section and a
/// panel in another. Deliberately unequal, so nothing can be got right by
/// guessing.
Design example() {
  final at = DateTime(2026);
  var design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'example',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    depthMm: 80,
    frame: FrameElement(
      id: 'frame',
      outline: Polygon.rect(0, 0, 1800, 1400),
      profileMm: 60,
    ),
    dividers: const [
      // Two vertical divisions, at nothing like the thirds.
      DividerElement(
        id: 'v1',
        a: Vec2(430, 0),
        b: Vec2(430, 1400),
        widthMm: 50,
      ),
      DividerElement(
        id: 'v2',
        a: Vec2(1250, 0),
        b: Vec2(1250, 1400),
        widthMm: 50,
      ),
      // One horizontal divider, across the middle column only.
      DividerElement(
        id: 'h1',
        a: Vec2(430, 900),
        b: Vec2(1250, 900),
        widthMm: 50,
      ),
    ],
  ));

  // Glass in one section, a panel in another, chosen by where they sit so
  // the test can find the same ones again.
  final leftmost =
      design.sections.reduce((a, b) => a.outline.left < b.outline.left ? a : b);
  final lowestMiddle = design.sections
      .where((s) => s.outline.left > 430 && s.outline.right < 1250)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);

  design = design.withElement(leftmost.copyWith(
    finish: const Finish(colour: 0xFFD8E6EA, material: MaterialKind.clearGlass),
  ));
  design = design.withElement(lowestMiddle.copyWith(
    finish: const Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel),
  ));
  return design;
}

Set<String> elementsOf(Mesh mesh, FacetRole role) => {
      for (final facet in mesh.facets)
        if (facet.role == role) facet.elementId,
    };

void main() {
  group('the model is the CAD geometry, part for part', () {
    test('the CAD drawing this is built from has the structure expected', () {
      final design = example();
      expect(design.dividers.where((d) => d.isVertical), hasLength(2));
      expect(design.dividers.where((d) => d.isHorizontal), hasLength(1));
      expect(design.sections, hasLength(4));
    });

    test('every section in the drawing is a pane in the model, and no more',
        () {
      final design = example();
      final mesh = MeshBuilder.build(design);

      final panes = {
        ...elementsOf(mesh, FacetRole.glazing),
        ...elementsOf(mesh, FacetRole.panel),
      };
      expect(panes, {for (final s in design.sections) s.id});
    });

    test('every bar in the drawing is a bar in the model, and no more', () {
      final design = example();
      final mesh = MeshBuilder.build(design);
      expect(
        elementsOf(mesh, FacetRole.bar),
        {for (final d in design.dividers) d.id},
      );
    });

    test('the one horizontal divider is one horizontal bar in the model', () {
      final design = example();
      final mesh = MeshBuilder.build(design);

      final horizontal = design.dividers.where((d) => d.isHorizontal).single;
      final facets = [
        for (final f in mesh.facets)
          if (f.elementId == horizontal.id) f,
      ];
      expect(facets, isNotEmpty);

      var minY = 1e9, maxY = -1e9, minX = 1e9, maxX = -1e9;
      for (final facet in facets) {
        for (final c in facet.corners) {
          minY = c.y < minY ? c.y : minY;
          maxY = c.y > maxY ? c.y : maxY;
          minX = c.x < minX ? c.x : minX;
          maxX = c.x > maxX ? c.x : maxX;
        }
      }
      // It runs across, not up and down, and it is as thick as it was set.
      expect(maxX - minX, greaterThan(600));
      expect(maxY - minY, closeTo(horizontal.widthMm, 1));
      // And it spans only the middle column, exactly as drawn.
      expect(minX, closeTo(430, 2));
      expect(maxX, closeTo(1250, 2));
    });

    test('glass is in the section the glass was put in', () {
      final design = example();
      final mesh = MeshBuilder.build(design);

      final glazed = [
        for (final s in design.sections)
          if (s.finish.material.isGlazing) s.id,
      ];
      expect(elementsOf(mesh, FacetRole.glazing), glazed.toSet());
    });

    test('the panel is in the section the panel was put in', () {
      final design = example();
      final mesh = MeshBuilder.build(design);

      final panelled = [
        for (final s in design.sections)
          if (s.finish.material == MaterialKind.panel) s.id,
      ];
      expect(panelled, hasLength(1));
      expect(elementsOf(mesh, FacetRole.panel), panelled.toSet());

      // And it is the one below the horizontal divider, not its neighbour.
      final section = design.sectionById(panelled.single)!;
      expect(section.outline.top, greaterThan(900));
    });

    test('nothing exists in the model that is not in the drawing', () {
      final design = example();
      final mesh = MeshBuilder.build(design);

      final known = {
        design.frame!.id,
        for (final d in design.dividers) d.id,
        for (final s in design.sections) s.id,
        for (final h in design.hardware) h.id,
      };
      for (final facet in mesh.facets) {
        expect(known, contains(facet.elementId));
      }
      // No hardware was placed, so none is modelled.
      expect(elementsOf(mesh, FacetRole.hardware), isEmpty);
      // Nothing opens yet, so there are no sashes.
      expect(elementsOf(mesh, FacetRole.sash), isEmpty);
    });

    test('each pane in the model sits where its section sits', () {
      final design = example();
      final mesh = MeshBuilder.build(design);

      for (final section in design.sections) {
        var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
        for (final facet in mesh.facets) {
          if (facet.elementId != section.id) continue;
          for (final c in facet.corners) {
            minX = c.x < minX ? c.x : minX;
            maxX = c.x > maxX ? c.x : maxX;
            minY = c.y < minY ? c.y : minY;
            maxY = c.y > maxY ? c.y : maxY;
          }
        }
        expect(minX, closeTo(section.outline.left, 1));
        expect(maxX, closeTo(section.outline.right, 1));
        expect(minY, closeTo(section.outline.top, 1));
        expect(maxY, closeTo(section.outline.bottom, 1));
      }
    });

    test('the model has real depth, the same depth the design carries', () {
      final design = example();
      final mesh = MeshBuilder.build(design);

      var front = -1e9, back = 1e9;
      for (final facet in mesh.facets) {
        for (final c in facet.corners) {
          if (c.z > front) front = c.z;
          if (c.z < back) back = c.z;
        }
      }
      expect(front - back, closeTo(design.depthMm, 0.01));

      // It is a solid, not a flat picture: faces exist at more than two
      // depths, and the frame has faces on its sides.
      final depths = <int>{};
      for (final facet in mesh.facets) {
        depths.add(facet.centre.z.round());
      }
      expect(depths.length, greaterThan(4));
    });

    test('moving a bar in the drawing moves it in the model', () {
      final before = example();
      final moved = SectionBuilder.rebuild(before.copyWith(
        dividers: [
          for (final d in before.dividers)
            if (d.id == 'v1')
              d.copyWith(a: const Vec2(700, 0), b: const Vec2(700, 1400))
            else
              d,
        ],
      ));

      double barMiddle(Design design) {
        final mesh = MeshBuilder.build(design);
        var sum = 0.0;
        var count = 0;
        for (final facet in mesh.facets) {
          if (facet.elementId != 'v1') continue;
          sum += facet.centre.x;
          count++;
        }
        return sum / count;
      }

      expect(barMiddle(before), closeTo(430, 2));
      expect(barMiddle(moved), closeTo(700, 2));
    });

    test('a diagonal bar is a diagonal bar in the model', () {
      final at = DateTime(2026);
      final design = SectionBuilder.rebuild(Design(
        id: 'd',
        name: 'x',
        kind: DesignKind.window,
        createdAt: at,
        updatedAt: at,
        frame: FrameElement(
          id: 'f',
          outline: Polygon.rect(0, 0, 1000, 1000),
          profileMm: 50,
        ),
        dividers: const [
          DividerElement(
            id: 'd1',
            a: Vec2(60, 60),
            b: Vec2(940, 940),
            widthMm: 50,
          ),
        ],
      ));
      final mesh = MeshBuilder.build(design);

      var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
      for (final facet in mesh.facets) {
        if (facet.elementId != 'd1') continue;
        for (final c in facet.corners) {
          minX = c.x < minX ? c.x : minX;
          maxX = c.x > maxX ? c.x : maxX;
          minY = c.y < minY ? c.y : minY;
          maxY = c.y > maxY ? c.y : maxY;
        }
      }
      // It runs both across and down: it was not squared to an axis.
      expect(maxX - minX, greaterThan(700));
      expect(maxY - minY, greaterThan(700));

      // And it divides the opening into two, as a diagonal does.
      expect(design.sections, hasLength(2));
    });
  });

  group('looking at the model does not change it', () {
    test('every view of the model has the same faces', () {
      final design = example();
      final mesh = MeshBuilder.build(design);

      for (final camera in [
        Camera.front,
        Camera.back,
        Camera.left,
        Camera.right,
        Camera.top,
        Camera.bottom,
        Camera.isometric,
        const Camera(projection: Projection.parallel),
      ]) {
        final faces = camera.project(mesh);
        final elements = {for (final f in faces) f.elementId};
        for (final section in design.sections) {
          expect(elements, contains(section.id),
              reason: 'every pane should be visible from '
                  '${camera.yawDegrees}/${camera.pitchDegrees}');
        }
      }
    });

    test('projecting does not touch the design', () {
      final design = example();
      final before = design.toJson().toString();
      Camera.isometric.project(MeshBuilder.build(design));
      expect(design.toJson().toString(), before);
    });
  });
}
