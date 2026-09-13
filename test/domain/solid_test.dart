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

Design build({
  List<Vec2>? outline,
  List<DividerElement> dividers = const [],
  List<HardwareElement> hardware = const [],
}) {
  final at = DateTime(2026);
  return SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: outline == null ? Polygon.rect(0, 0, 1000, 2000) : Polygon(outline),
      profileMm: 60,
    ),
    dividers: dividers,
    hardware: hardware,
  ));
}

void main() {
  test('an empty design has no model — nothing is invented', () {
    final at = DateTime(2026);
    final mesh = MeshBuilder.build(Design(
      id: 'd',
      name: 'x',
      kind: DesignKind.door,
      createdAt: at,
      updatedAt: at,
    ));
    expect(mesh.isEmpty, isTrue);
  });

  test('the model is as deep as the design says and no deeper', () {
    final mesh = MeshBuilder.build(build());
    var front = -1e9, back = 1e9;
    for (final facet in mesh.facets) {
      for (final c in facet.corners) {
        if (c.z > front) front = c.z;
        if (c.z < back) back = c.z;
      }
    }
    expect(front, closeTo(0, 0.01));
    expect(back, closeTo(-70, 0.01));
  });

  test('a five-sided frame gives a five-sided model', () {
    final design = build(outline: const [
      Vec2(0, 400),
      Vec2(500, 0),
      Vec2(1000, 400),
      Vec2(1000, 2000),
      Vec2(0, 2000),
    ]);
    final mesh = MeshBuilder.build(design);
    // Five edges, four faces each: the shape is followed, not squared off.
    final frameFacets =
        mesh.facets.where((f) => f.role == FacetRole.frame).length;
    expect(frameFacets, 20);
  });

  test('a diagonal bar is modelled at its own angle', () {
    final design = build(dividers: [
      const DividerElement(
        id: 'v',
        a: Vec2(100, 100),
        b: Vec2(900, 1900),
        widthMm: 50,
      ),
    ]);
    final mesh = MeshBuilder.build(design);
    final bar = mesh.facets.firstWhere((f) => f.role == FacetRole.bar);
    final xs = [for (final c in bar.corners) c.x];
    final ys = [for (final c in bar.corners) c.y];
    // It genuinely runs across and down, rather than being squared to an axis.
    expect(xs.reduce((a, b) => a > b ? a : b) -
        xs.reduce((a, b) => a < b ? a : b), greaterThan(500));
    expect(ys.reduce((a, b) => a > b ? a : b) -
        ys.reduce((a, b) => a < b ? a : b), greaterThan(1000));
  });

  test('no hardware is drawn where the user drew none', () {
    final mesh = MeshBuilder.build(build());
    expect(mesh.facets.any((f) => f.role == FacetRole.hardware), isFalse);
  });

  test('one handle gives one handle', () {
    final mesh = MeshBuilder.build(build(hardware: [
      const HardwareElement(
        id: 'h',
        kind: HardwareKind.lever,
        at: Vec2(880, 1000),
      ),
    ]));
    final ids = {
      for (final f in mesh.facets)
        if (f.role == FacetRole.hardware) f.elementId,
    };
    expect(ids, {'h'});
  });

  test('a section that does not open has no sash', () {
    final mesh = MeshBuilder.build(build());
    expect(mesh.facets.any((f) => f.role == FacetRole.sash), isFalse);
    expect(mesh.facets.any((f) => f.role == FacetRole.glazing), isTrue);
  });

  test('an opening leaf swings about the edge it hinges on', () {
    var design = build();
    final section = design.sections.single;
    design = design.copyWith(openings: [
      OpeningElement(
        id: 'o',
        sectionId: section.id,
        mechanism: OpeningMechanism.hingedLeft,
        confirmed: true,
      ),
    ]);

    final shut = MeshBuilder.build(design);
    final open = MeshBuilder.build(design, openFraction: 1);

    double furthest(Mesh mesh) {
      var z = 0.0;
      for (final f in mesh.facets) {
        if (f.role != FacetRole.sash && f.role != FacetRole.glazing) continue;
        for (final c in f.corners) {
          if (c.z.abs() > z.abs()) z = c.z;
        }
      }
      return z;
    }

    expect(furthest(open).abs(), greaterThan(furthest(shut).abs() * 4));

    // The hinge edge itself did not move.
    double leftmost(Mesh mesh) {
      var x = 1e9;
      for (final f in mesh.facets) {
        if (f.role != FacetRole.sash) continue;
        for (final c in f.corners) {
          if (c.x < x) x = c.x;
        }
      }
      return x;
    }

    expect(leftmost(open), closeTo(leftmost(shut), 0.01));
  });

  test('every face knows which part of the design it belongs to', () {
    final design = build(dividers: [
      const DividerElement(
        id: 'v',
        a: Vec2(400, 0),
        b: Vec2(400, 2000),
        widthMm: 50,
      ),
    ]);
    final mesh = MeshBuilder.build(design);
    final ids = {for (final f in mesh.facets) f.elementId};
    expect(ids, contains('f'));
    expect(ids, contains('v'));
    for (final section in design.sections) {
      expect(ids, contains(section.id));
    }
  });

  test('a colour set on a section reaches the model', () {
    var design = build();
    design = design.withElement(design.sections.single.copyWith(
      finish: const Finish(colour: 0xFF224466, material: MaterialKind.panel),
    ));
    final mesh = MeshBuilder.build(design);
    final panel = mesh.facets.firstWhere((f) => f.role == FacetRole.panel);
    expect(panel.colour, 0xFF224466);
  });

  group('camera', () {
    test('turning brings one side forward and takes the other back', () {
      final mesh = MeshBuilder.build(build());
      const camera = Camera(turnDegrees: 35, tiltDegrees: 0);
      final faces = camera.project(mesh);
      expect(faces, isNotEmpty);

      // The nearest face and the furthest are at genuinely different depths:
      // a flat projection would put them at the same one.
      final depths = [for (final f in faces) f.depth];
      final near = depths.reduce((a, b) => a < b ? a : b);
      final far = depths.reduce((a, b) => a > b ? a : b);
      expect(far - near, greaterThan(mesh.span * 0.05));
    });

    test('faces are painted far to near', () {
      final mesh = MeshBuilder.build(build());
      final faces = const Camera().project(mesh);
      for (var i = 1; i < faces.length; i++) {
        expect(faces[i].depth, lessThanOrEqualTo(faces[i - 1].depth));
      }
    });

    test('turning the model moves the light with it, not against it', () {
      final mesh = MeshBuilder.build(build());
      double lightOn(double turn) {
        final faces = Camera(turnDegrees: turn).project(mesh);
        return faces
                .where((f) => f.source.role == FacetRole.frame)
                .map((f) => f.light)
                .reduce((a, b) => a + b) /
            faces.where((f) => f.source.role == FacetRole.frame).length;
      }

      expect(lightOn(0), isNot(closeTo(lightOn(50), 0.001)));
    });

    test('a straight-on view is wider than a near one', () {
      final mesh = MeshBuilder.build(build());
      double width(Camera camera) {
        final faces = camera.project(mesh);
        var left = 1e9, right = -1e9;
        for (final f in faces) {
          for (final c in f.corners) {
            if (c.x < left) left = c.x;
            if (c.x > right) right = c.x;
          }
        }
        return right - left;
      }

      // Standing closer with the same model makes it loom larger.
      expect(width(const Camera(distanceInSpans: 1.8)),
          greaterThan(width(const Camera(distanceInSpans: 6))));
    });
  });
}
