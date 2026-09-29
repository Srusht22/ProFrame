import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/frame_profile.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/opening_leaf.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import 'rendering_geometry_baseline_test.dart' as base;

// Phase 4 of the CAD and 3D work: the frame is a real frame.
//
// It used to be a flat ring pushed back to the design's depth — square
// everywhere, the same slab whatever it was made of. Now it is its profile
// ([FrameProfile]) swept round the outline: a front face, the arrises and
// the sightline its material is made with, a reveal facing into the
// opening, an outside and a back. A PVC chamber profile falls away to its
// glass in a curve; an aluminium extrusion has square arrises and a shadow
// step; timber is moulded.
//
// And none of it is allowed to touch the design. The profile lives wholly
// inside the ring the plain frame occupied — the outline, the daylight and
// the depth are exactly what they were — and its figures are shares of the
// frame's own profile width and depth, never of the size of the design. So
// this sweeps sizes from a small hatch to a shop front, three materials,
// two profile widths and depths, a five-sided frame and a door with no
// sill, and requires the design back as drawn from every one.

Design drawn(
  double w,
  double h, {
  MaterialKind material = MaterialKind.upvc,
  double? profileMm,
  double? depthMm,
  bool divided = false,
}) {
  final read = base.read(
    Design.empty(
      id: 'frame-${w.round()}x${h.round()}',
      kind: DesignKind.window,
      name: 'Frame',
      now: base.at,
    ),
    [
      base.pen('outline', base.rectangle(w, h)),
      if (divided) base.pen('mullion', [Vec2(w * 0.4, 0), Vec2(w * 0.4, h)]),
      if (divided) base.pen('mark', base.chevron(Vec2(w * 0.2, h / 2))),
    ],
  );
  // Through the rebuild an edit goes through, so the sections are the
  // daylight of the profile they were given.
  return SectionBuilder.rebuild(
    read.copyWith(
      depthMm: depthMm,
      frame: read.frame!.copyWith(
        profileMm: profileMm,
        finish: read.frame!.finish.copyWith(material: material),
      ),
    ),
  );
}

/// A gable window: five sides.
Design gable() => base.read(
  Design.empty(id: 'gable', kind: DesignKind.window, name: 'G', now: base.at),
  [
    base.pen('outline', const [
      Vec2(0, 400),
      Vec2(600, 0),
      Vec2(1200, 400),
      Vec2(1200, 1400),
      Vec2(0, 1400),
      Vec2(0, 400),
    ]),
  ],
);

/// A door frame with no sill: the bottom side left open.
Design noSill() {
  final d = drawn(1000, 2100);
  final corners = d.frame!.outline.corners;
  final bottom = [
    for (var i = 0; i < corners.length; i++)
      if (corners[i].y > 2000 && corners[(i + 1) % corners.length].y > 2000) i,
  ];
  return d.copyWith(frame: d.frame!.copyWith(openEdges: bottom.toSet()));
}

/// Strictly inside [shape]: by the winding rule, with no allowance for
/// being near an edge — `Polygon.contains` counts a point within half a
/// millimetre of an edge as inside, which is right for a tap and wrong for
/// asking whether material has crossed a line.
bool strictlyInside(Polygon shape, Vec2 p) {
  if (shape.awayFrom(p) <= 1e-6) return false;
  var inside = false;
  final c = shape.corners;
  for (var i = 0; i < c.length; i++) {
    final a = c[i], b = c[(i + 1) % c.length];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)) {
      inside = !inside;
    }
  }
  return inside;
}

Iterable<Facet> frameOf(Mesh mesh) =>
    mesh.facets.where((f) => f.role == FacetRole.frame);

Set<String> keys(Iterable<(double, double)> points) => {
  for (final (a, b) in points)
    '${(a + 0).toStringAsFixed(3)},${(b + 0).toStringAsFixed(3)}',
};

void main() {
  final sizes = [
    (450.0, 350.0),
    (600.0, 600.0),
    (1000.0, 2000.0),
    (2400.0, 1200.0),
    (3000.0, 2400.0),
  ];
  final materials = [
    MaterialKind.upvc,
    MaterialKind.aluminium,
    MaterialKind.wood,
  ];

  final cases = <String, Design>{
    for (final (w, h) in sizes)
      for (final m in materials)
        '${w.round()} × ${h.round()} mm, ${m.label}': drawn(w, h, material: m),
    '1200 × 1500 mm, a 40 mm profile 90 mm deep': drawn(
      1200,
      1500,
      profileMm: 40,
      depthMm: 90,
    ),
    '1800 × 1200 mm, divided with a leaf': drawn(1800, 1200, divided: true),
    'a gable window': gable(),
    'a door with no sill': noSill(),
  };

  for (final MapEntry(key: name, value: design) in cases.entries) {
    group(name, () {
      final frame = design.frame!;
      final outline = frame.outline;
      final daylight = frame.innerOutline;
      final depth = design.depthMm;

      test('the design is exactly what was drawn, before and after it is '
          'built', () {
        final before = base.designGeometry(design);
        MeshBuilder.build(design);
        MeshBuilder.build(design, openFraction: 1);
        DesignGeometry.of(design).frameSightlines;
        expect(base.designGeometry(design), before);
      });

      test('the frame stands on the outline, to the millimetre, and exactly '
          'the design\'s depth', () {
        final corners = [
          for (final f in frameOf(MeshBuilder.build(design))) ...f.corners,
        ];
        double lo(Iterable<double> v) => v.reduce((a, b) => a < b ? a : b);
        double hi(Iterable<double> v) => v.reduce((a, b) => a > b ? a : b);
        expect(lo(corners.map((c) => c.x)), closeTo(outline.left, 1e-9));
        expect(hi(corners.map((c) => c.x)), closeTo(outline.right, 1e-9));
        expect(lo(corners.map((c) => c.y)), closeTo(outline.top, 1e-9));
        expect(hi(corners.map((c) => c.y)), closeTo(outline.bottom, 1e-9));
        expect(hi(corners.map((c) => c.z)), closeTo(0, 1e-9));
        expect(lo(corners.map((c) => c.z)), closeTo(-depth, 1e-9));
      });

      test('none of it reaches into the daylight or out past the outline', () {
        for (final f in frameOf(MeshBuilder.build(design))) {
          for (final c in f.corners) {
            final p = Vec2(c.x, c.y);
            expect(
              strictlyInside(outline, p) || outline.awayFrom(p) <= 1e-6,
              isTrue,
              reason: '$p outside',
            );
            expect(
              strictlyInside(daylight, p),
              isFalse,
              reason: '$p in the daylight',
            );
          }
        }
      });

      test('the daylight is still the daylight: the reveal stands on it', () {
        final onIt = [
          for (final f in frameOf(MeshBuilder.build(design)))
            for (final c in f.corners)
              if (daylight.awayFrom(Vec2(c.x, c.y)) < 1e-6) Vec2(c.x, c.y),
        ];
        expect(onIt, isNotEmpty);
        double lo(Iterable<double> v) => v.reduce((a, b) => a < b ? a : b);
        double hi(Iterable<double> v) => v.reduce((a, b) => a > b ? a : b);
        expect(lo(onIt.map((p) => p.x)), closeTo(daylight.left, 1e-6));
        expect(hi(onIt.map((p) => p.x)), closeTo(daylight.right, 1e-6));
        expect(lo(onIt.map((p) => p.y)), closeTo(daylight.top, 1e-6));
        // A door with no sill has no member along its foot, and its
        // daylight runs down to the floor.
        expect(hi(onIt.map((p) => p.y)), closeTo(daylight.bottom, 1e-6));
      });

      test('it has a front, an outside, a reveal, a back and the arrises '
          'between them', () {
        final facets = frameOf(MeshBuilder.build(design)).toList();
        bool all(Facet f, bool Function(Vec3) test) => f.corners.every(test);
        final front = facets.where((f) => all(f, (c) => c.z.abs() < 1e-9));
        final back = facets.where(
          (f) => all(f, (c) => (c.z + depth).abs() < 1e-9),
        );
        final outside = facets.where(
          (f) =>
              !f.isSide &&
              all(f, (c) => outline.awayFrom(Vec2(c.x, c.y)) < 1e-6) &&
              f.normal.z.abs() < 1e-6,
        );
        final reveal = facets.where(
          (f) =>
              all(f, (c) => daylight.awayFrom(Vec2(c.x, c.y)) < 1e-6) &&
              f.normal.z.abs() < 1e-6,
        );
        // Neither square to the viewer nor square across: an arris, a
        // bevel, a sightline.
        final shaped = facets.where(
          (f) => f.normal.z.abs() > 1e-3 && f.normal.z.abs() < 1 - 1e-3,
        );
        expect(front, isNotEmpty, reason: 'front face');
        expect(back, isNotEmpty, reason: 'back face');
        expect(outside, isNotEmpty, reason: 'outer edge');
        expect(reveal, isNotEmpty, reason: 'inner edge');
        expect(shaped, isNotEmpty, reason: 'arrises and sightline');
      });
    });
  }

  group(
    'the profile comes from the frame, never from the size of the design',
    () {
      /// The section as the solid has it at the top left mitre: how far down
      /// from the head each corner is, and how far back.
      Set<String> sectionAtTheHead(Design design) {
        final outline = design.frame!.outline;
        return keys([
          for (final f in frameOf(MeshBuilder.build(design)))
            for (final c in f.corners)
              if (((c.x - outline.left) - (c.y - outline.top)).abs() < 1e-6 &&
                  c.y - outline.top <= design.frame!.profileMm + 1e-6)
                (c.y - outline.top, c.z),
        ]);
      }

      test('the same section on a hatch and on a shop front', () {
        for (final m in materials) {
          final sections = {
            for (final (w, h) in sizes)
              sectionAtTheHead(drawn(w, h, material: m, profileMm: 60))
                  .join(';'),
          };
          expect(sections, hasLength(1), reason: m.label);
        }
      });

      test('a wider or deeper profile is a wider or deeper section', () {
        final narrow = drawn(1200, 1500, profileMm: 40);
        final wide = drawn(1200, 1500, profileMm: 80);
        final deep = drawn(1200, 1500, depthMm: 120);
        double reach(Design d, double Function((double, double)) of) => [
          for (final k in sectionAtTheHead(d))
            of((double.parse(k.split(',')[0]), double.parse(k.split(',')[1]))),
        ].reduce((a, b) => a > b ? a : b);
        expect(reach(narrow, (p) => p.$1), closeTo(40, 1e-6));
        expect(reach(wide, (p) => p.$1), closeTo(80, 1e-6));
        expect(reach(deep, (p) => -p.$2), closeTo(120, 1e-6));
      });

      test('each material its own section', () {
        final sections = {
          for (final m in materials)
            sectionAtTheHead(drawn(1200, 1500, material: m)).join(';'),
        };
        expect(sections, hasLength(3));

        final pvc = FrameProfile.of(MaterialKind.upvc, width: 60, depth: 70);
        final alu = FrameProfile.of(
          MaterialKind.aluminium,
          width: 60,
          depth: 70,
        );
        // An extrusion's arris is all but square; a PVC profile's is round.
        expect(alu.section.first.back, lessThanOrEqualTo(1 + 1e-9));
        expect(pvc.section.first.back, greaterThan(alu.section.first.back));
        // The extrusion's shadow step: a run straight back from the face.
        final step = [
          for (var i = 0; i + 1 < alu.section.length; i++)
            if (alu.section[i].across == alu.section[i + 1].across &&
                alu.section[i].back == 0)
              i,
        ];
        expect(step, isNotEmpty);
      });

      test('a colour is not a profile', () {
        final white = drawn(1200, 1500);
        final black = white.copyWith(
          frame: white.frame!.copyWith(
            finish: white.frame!.finish.copyWith(colour: 0xFF1E1F1F),
          ),
        );
        expect(
          base.meshGeometry(MeshBuilder.build(black)),
          base.meshGeometry(MeshBuilder.build(white)),
        );
      });

      test('every section reaches both edges and both faces, and stays '
          'inside them', () {
        for (final m in MaterialKind.values) {
          for (final (w, d) in [(60.0, 70.0), (40.0, 90.0), (90.0, 50.0)]) {
            final p = FrameProfile.of(m, width: w, depth: d);
            final across = p.section.map((q) => q.across);
            final back = p.section.map((q) => q.back);
            expect(across.reduce((a, b) => a < b ? a : b), closeTo(0, 1e-9));
            expect(across.reduce((a, b) => a > b ? a : b), closeTo(w, 1e-9));
            expect(back.reduce((a, b) => a < b ? a : b), closeTo(0, 1e-9));
            expect(back.reduce((a, b) => a > b ? a : b), closeTo(d, 1e-9));
            for (final s in p.sightlines) {
              expect(s, inExclusiveRange(0, w), reason: m.label);
            }
          }
        }
      });
    },
  );

  test('the sash is its own profile, between the leaf\'s outside and its '
      'daylight', () {
    final design = drawn(1800, 1200, divided: true);
    final opening = design.openings.single;
    final section = design.sectionById(opening.sectionId)!;
    final geometry = DesignGeometry.of(design);
    final outer = geometry.leafOuter(section);
    final inner = geometry.leafInner(section)!;
    final sash = MeshBuilder.build(design).facets
        .where((f) => f.role == FacetRole.sash)
        .toList();
    expect(sash, isNotEmpty);
    for (final f in sash) {
      for (final c in f.corners) {
        final p = Vec2(c.x, c.y);
        expect(outer.contains(p), isTrue);
        expect(strictlyInside(inner, p), isFalse);
      }
    }
    // Shaped as the frame is, at the sash's own width.
    expect(
      sash.where((f) => f.normal.z.abs() > 1e-3 && f.normal.z.abs() < 1 - 1e-3),
      isNotEmpty,
    );
    expect(OpeningLeaf.profileFor(design.frame!), greaterThan(0));
  });

  test('the elevation\'s sightline is the solid\'s: the same line across '
      'every member', () {
    final design = drawn(1200, 1500);
    final geometry = DesignGeometry.of(design);
    final profile = geometry.frameProfile!;
    final lines = geometry.frameSightlines;
    expect(lines, hasLength(4 * profile.sightlines.length));
    final head = lines.first;
    expect(head.a.y, closeTo(profile.sightlines.single, 1e-9));
    // On the solid, a front-face corner stands on that line.
    final onIt = [
      for (final f in frameOf(MeshBuilder.build(design)))
        for (final c in f.corners)
          if (c.z.abs() < 1e-9 &&
              (c.y - profile.sightlines.single).abs() < 1e-9)
            c,
    ];
    expect(onIt, isNotEmpty);
    // No sill, no line along the foot.
    expect(
      DesignGeometry.of(noSill()).frameSightlines,
      hasLength(3 * profile.sightlines.length),
    );
  });
}
