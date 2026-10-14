import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../app/cad_is_the_canonical_geometry_test.dart' as cad;
import '../app/pause_and_take_it_back_test.dart' show chevron;
import 'an_under_stair_design_test.dart' as under;
import 'angled_dimensions_test.dart' as angled;
import 'geometry_normalizer_test.dart' show pen;
import 'the_solid_is_the_cad_hierarchy_test.dart' show cadParts, solidParts;

// The solid is built from the canonical geometry, and from nothing else:
//
//   standard:  drawing → normalisation → canonical geometry → 3D
//   angled:    drawing → canonical angled geometry          → 3D
//
// Four designs — a rectangular door and a standard window, each drawn by
// hand a little out of square; an angled window, its head sloping from a
// left side of 200 cm to a right side of 150; and the window under a stair —
// each with an opening divided into glass over a panel and furnished.
//
// For each, every face the solid builds is held to the geometry the
// drawings draw: the frame swept round the outline and the daylight, the
// leaf on the leaf, each bar on its body, the glass and the panel on what
// they fill, and nothing anywhere outside the outline — so a box round an
// angled shape, a slope built straight or a pane built to its region's box
// would each put a face where the shape is not. The solid builds exactly
// the parts the technical drawing draws. And a leaf turns about the line
// its hinges are on, which on a stile drawn leaning leans with it.

Design read(Design d) => cad.read(d);

/// The leaf of [d]'s only opening divided by a line [up] from its sill,
/// glass above and a white panel below.
Design divided(Design d, {double up = 400}) {
  final opening = d.openings.single;
  final region = d.sectionById(opening.sectionId)!.outline;
  d = DesignEdits.addLineInside(
    d,
    opening.sectionId,
    id: 'inside',
    at: Vec2(region.centroid.x, region.bottom - up),
    horizontal: true,
  );
  final lower = d
      .childSectionsOf(opening.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return d.withElement(lower.copyWith(finish: PanelColour.white.finish));
}

/// [d]'s openings said to be [kind], and furnished.
Design said(Design d, DesignKind kind) => OpeningHardware.settle(
  d.copyWith(openings: [for (final o in d.openings) o.copyWith(kind: kind)]),
);

/// A 100 × 210 cm door drawn by hand, every corner a little out: a
/// fanlight 45 cm deep across the head and the leaf below it marked `>`.
Design door() {
  final d = read(
    Design.empty(id: 'door', kind: DesignKind.door).copyWith(
      sketch: Sketch(
        strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(1000, 12),
            Vec2(1018, 2100),
            Vec2(-8, 2094),
            Vec2(0, 0),
          ]),
          pen('transom', const [Vec2(0, 450), Vec2(1000, 450)]),
          pen('mark', chevron(const Vec2(500, 1300))),
        ],
      ),
    ),
  );
  return divided(said(d, DesignKind.door), up: 900);
}

/// The 120 × 150 cm window drawn by hand, its opening divided.
Design window() => divided(said(cad.window(cad.byHand), DesignKind.window));

/// The sloped head: left side 200 cm, right side 150, its opening already
/// divided into glass over a white panel, here said to be a window.
Design angledWindow() => said(angled.drawn(), DesignKind.window);

final designs = <String, Design Function()>{
  'a rectangular door': door,
  'a standard window': window,
  'an angled window': angledWindow,
  'a window under a stair': under.built,
};

Vec2 face(Vec3 p) => Vec2(p.x, p.y);

/// Whether [p] is inside [shape], give or take [slack] millimetres.
bool within(Polygon shape, Vec2 p, {double slack = 0.5}) =>
    shape.contains(p) || shape.edges.any((e) => e.distanceTo(p) <= slack);

/// How far [p] is inside [shape]: 0 on or outside it.
double depthInside(Polygon shape, Vec2 p) => shape.contains(p)
    ? shape.edges.map((e) => e.distanceTo(p)).reduce(math.min)
    : 0;

/// Whether some face in [facets] has a corner at [p] on the face.
bool hasCornerAt(Iterable<Facet> facets, Vec2 p, {double slack = 0.5}) =>
    facets.any((f) => f.corners.any((c) => face(c).distanceTo(p) <= slack));

bool raked(Polygon p) =>
    p.edges.any((e) => (e.a.x - e.b.x).abs() > 1 && (e.a.y - e.b.y).abs() > 1);

void main() {
  for (final MapEntry(key: name, value: make) in designs.entries) {
    group(name, () {
      late Design d;
      late Mesh mesh;
      late DesignGeometry geometry;
      setUp(() {
        d = make();
        mesh = MeshBuilder.build(d);
        geometry = DesignGeometry.of(d);
      });

      Iterable<Facet> facetsOf(String id, [FacetRole? role]) => mesh.facets
          .where((f) => f.elementId == id && (role == null || f.role == role));

      test('the design is the canonical one: square where it was corrected, '
          'raked where it was drawn raked', () {
        final outline = d.frame!.outline;
        final isAngled = d.kind == DesignKind.angled;
        expect(raked(outline), isAngled, reason: '${outline.corners}');
        expect(d.openings, hasLength(1));
        expect(d.childSectionsOf(d.openings.single.sectionId), hasLength(2));
      });

      test('nothing is built outside the outline — no box round it, no '
          'slope built straight', () {
        final outline = d.frame!.outline;
        for (final facet in mesh.facets) {
          for (final c in facet.corners) {
            expect(
              within(outline, face(c)),
              isTrue,
              reason: '${facet.elementId} (${facet.role.name}) at $c',
            );
          }
        }
        // And the box's own corners, where the outline does not reach them,
        // have nothing at them.
        final box = Polygon.rect(
          outline.left,
          outline.top,
          outline.right,
          outline.bottom,
        );
        for (final corner in box.corners) {
          if (within(outline, corner)) continue;
          expect(
            hasCornerAt(mesh.facets, corner, slack: 20),
            isFalse,
            reason: 'something at the box corner $corner',
          );
        }
      });

      test('the frame is swept round the outline and the daylight, the '
          'whole depth', () {
        final frame = d.frame!;
        final faces = facetsOf(frame.id, FacetRole.frame).toList();
        expect(faces, isNotEmpty);
        for (final f in faces) {
          for (final c in f.corners) {
            final p = face(c);
            expect(within(frame.outline, p), isTrue, reason: '$c');
            expect(
              depthInside(frame.innerOutline, p),
              lessThan(0.5),
              reason: 'the frame in the daylight at $c',
            );
          }
        }
        for (final corner in [
          ...frame.outline.corners,
          ...frame.innerOutline.corners,
        ]) {
          expect(hasCornerAt(faces, corner), isTrue, reason: '$corner');
        }
        // Along every edge of the outline, the frame is there: the face of
        // each member reaches the outline at its middle, slope or not.
        for (final e in frame.outline.edges) {
          final middle = e.midpoint;
          expect(
            faces.any((f) => _onFace(f, middle)),
            isTrue,
            reason: 'no member along $e',
          );
        }
        final zs = [
          for (final f in faces)
            for (final c in f.corners) c.z,
        ];
        expect(zs.reduce(math.max), closeTo(0, 1e-6));
        expect(zs.reduce(math.min), closeTo(-d.depthMm, 1e-6));
      });

      test('the leaf is the leaf the drawings draw, raked where its region '
          'is raked', () {
        final section = d.sectionById(d.openings.single.sectionId)!;
        final outer = geometry.leafOuter(section);
        final inner = geometry.leafInner(section)!;
        final faces = facetsOf(section.id, FacetRole.sash).toList();
        expect(faces, isNotEmpty, reason: 'a sash');
        for (final f in faces) {
          for (final c in f.corners) {
            expect(within(outer, face(c)), isTrue, reason: '$c');
            expect(depthInside(inner, face(c)), lessThan(0.5), reason: '$c');
          }
        }
        for (final corner in [...outer.corners, ...inner.corners]) {
          expect(hasCornerAt(faces, corner), isTrue, reason: '$corner');
        }
        expect(raked(outer), raked(section.outline));
      });

      test('every bar is built on its body', () {
        for (final bar in d.dividers) {
          final body = geometry.barBody(bar);
          final faces = facetsOf(bar.id, FacetRole.bar).toList();
          expect(faces, isNotEmpty, reason: bar.id);
          for (final f in faces) {
            for (final c in f.corners) {
              expect(within(body, face(c)), isTrue, reason: '${bar.id} $c');
            }
          }
          for (final corner in body.corners) {
            expect(
              hasCornerAt(faces, corner),
              isTrue,
              reason: '${bar.id}: $corner',
            );
          }
        }
      });

      test('the glass and the panel fill what they fill, following the '
          'slope where there is one', () {
        var glass = 0, panels = 0;
        for (final section in d.sections) {
          if (d.childSectionsOf(section.id).isNotEmpty) continue;
          final fill = geometry.fillOf(section);
          final isGlass = section.finish.material.isGlazing;
          final role = isGlass ? FacetRole.glazing : FacetRole.panel;
          final faces = facetsOf(section.id, role).toList();
          expect(faces, isNotEmpty, reason: section.id);
          isGlass ? glass++ : panels++;
          for (final f in faces) {
            for (final c in f.corners) {
              expect(within(fill, face(c)), isTrue, reason: '${section.id} $c');
            }
          }
          // Each corner of what it fills — the slope's own included.
          for (final corner in fill.corners) {
            expect(
              hasCornerAt(faces, corner),
              isTrue,
              reason: '${section.id}: $corner of ${fill.corners}',
            );
          }
          // Opaque faces of a pane are never glass, and glass never panel.
          expect(
            facetsOf(section.id).where(
              (f) => f.role == (isGlass ? FacetRole.panel : FacetRole.glazing),
            ),
            isEmpty,
          );
        }
        expect(glass, greaterThanOrEqualTo(2));
        expect(panels, 1);
        // In the opening, the glass is above the panel.
        final panes = d.childSectionsOf(d.openings.single.sectionId);
        final upper = panes.reduce(
          (a, b) => a.outline.top < b.outline.top ? a : b,
        );
        expect(upper.finish.material.isGlazing, isTrue);
      });

      test('the ironmongery is on its leaf', () {
        final opening = d.openings.single;
        final leaf = d.sectionById(opening.sectionId)!.outline;
        final pieces = [
          for (final h in d.hardware)
            if (h.parentId == opening.id) h,
        ];
        expect(pieces.where((h) => h.kind == HardwareKind.hinge), isNotEmpty);
        expect(pieces.where((h) => h.kind.isHandle), isNotEmpty);
        for (final piece in pieces) {
          expect(within(leaf, piece.at), isTrue, reason: piece.id);
          expect(facetsOf(piece.id), isNotEmpty, reason: piece.id);
        }
      });

      test('the solid builds exactly the parts the technical drawing '
          'draws', () {
        expect(solidParts(mesh), cadParts(d));
        // And every edge the technical drawing inks for the frame is an
        // edge of the solid's frame.
        final faces = facetsOf(d.frame!.id).toList();
        for (final e in [
          ...d.frame!.lines.outside,
          ...d.frame!.lines.daylight,
        ]) {
          expect(hasCornerAt(faces, e.a), isTrue, reason: '$e');
          expect(hasCornerAt(faces, e.b), isTrue, reason: '$e');
        }
      });

      test('swung, the leaf turns about its hinges and nothing else moves; '
          'shut again, it is where it was', () {
        final open = MeshBuilder.build(d, openFraction: 0.6);
        expect(open.facets, hasLength(mesh.facets.length));
        final inside = {
          d.openings.single.sectionId,
          for (final s in d.childSectionsOf(d.openings.single.sectionId)) s.id,
          'inside',
          for (final h in d.hardware)
            if (h.parentId == d.openings.single.id) h.id,
        };
        var moved = 0;
        for (var i = 0; i < mesh.facets.length; i++) {
          final a = mesh.facets[i], b = open.facets[i];
          expect(b.elementId, a.elementId);
          final same = [
            for (var k = 0; k < a.corners.length; k++)
              _distance(a.corners[k], b.corners[k]) < 1e-6,
          ].every((s) => s);
          if (inside.contains(a.elementId)) {
            if (!same) moved++;
          } else {
            expect(same, isTrue, reason: '${a.elementId} moved');
          }
        }
        expect(moved, greaterThan(0));
        _expectTurnsAboutItsHinges(d, mesh, open);
      });
    });
  }

  group('a leaf turns about the line its hinges are on', () {
    // The right side drawn leaning out, 10 cm over its 150; a `<` in the
    // right light hangs its leaf on that side, its hinges down that leaning
    // stile.
    Design leaning() {
      final d = read(
        Design.empty(id: 'lean', kind: DesignKind.angled).copyWith(
          sketch: Sketch(
            strokes: [
              pen('outline', const [
                Vec2(0, 0),
                Vec2(1200, 500),
                Vec2(1300, 2000),
                Vec2(0, 2000),
                Vec2(0, 0),
              ]),
              pen('mullion', const [Vec2(600, 250), Vec2(600, 2000)]),
              pen('mark', [
                for (final p in chevron(const Vec2(900, 1300)))
                  Vec2(1800 - p.x, p.y),
              ]),
            ],
          ),
        ),
      );
      return said(d, DesignKind.window);
    }

    test('on a stile drawn leaning, its hinges stay on their line as it '
        'opens — the axis leans with the stile', () {
      final d = leaning();
      final opening = d.openings.single;
      expect(opening.mechanism.hingeEdge, OpeningEdge.right);
      final stile = OpeningHardware.stileOf(
        d.sectionById(opening.sectionId)!.outline,
        OpeningEdge.right,
      )!;
      expect(stile.offAxisDegrees, greaterThan(3), reason: 'it leans');
      final shut = MeshBuilder.build(d);
      for (final fraction in [0.25, 0.6, 1.0]) {
        _expectTurnsAboutItsHinges(
          d,
          shut,
          MeshBuilder.build(d, openFraction: fraction),
        );
      }
    });

    test('a rectangle turns as it always did, about its box\'s side', () {
      final d = window();
      final section = d.sectionById(d.openings.single.sectionId)!;
      final box = section.outline;
      final (a, b, _) = OpeningHardware.swingOf(
        box,
        d.openings.single.mechanism.hingeEdge!,
      );
      expect(a.x, closeTo(b.x, 1e-9));
      expect(
        a.x == box.left || a.x == box.right,
        isTrue,
        reason: 'the hinge line is the box\'s side',
      );
    });
  });
}

double _distance(Vec3 a, Vec3 b) =>
    math.sqrt(_sq(a.x - b.x) + _sq(a.y - b.y) + _sq(a.z - b.z));

double _sq(double v) => v * v;

/// Whether [p] lies on [facet] as it is seen from the front.
bool _onFace(Facet facet, Vec2 p) {
  final shape = Polygon([for (final c in facet.corners) face(c)]);
  if (shape.corners.length < 3) return false;
  return shape.edges.any((e) => e.distanceTo(p) <= 0.5) || shape.contains(p);
}

/// The leaf of [d]'s opening turns about its hinge line in [open]: every
/// point of it keeps its distance from that line, at the face it turns
/// about, and every point on the line stays where it was.
void _expectTurnsAboutItsHinges(Design d, Mesh shut, Mesh open) {
  final opening = d.openings.single;
  final section = d.sectionById(opening.sectionId)!;
  final edge = opening.mechanism.hingeEdge!;
  final (a, b, _) = OpeningHardware.swingOf(section.outline, edge);
  final layout = MeshBuilder.swingsTowardViewer(d, opening)
      ? MeshBuilder.leafFront(d.depthMm)
      : MeshBuilder.leafBack(d.depthMm);

  double fromAxis(Vec3 p) {
    // The distance from the line through the hinge line at the pivot's
    // depth, in three dimensions.
    final u = b - a;
    final length = u.length;
    final ux = u.x / length, uy = u.y / length;
    final vx = p.x - a.x, vy = p.y - a.y, vz = p.z - layout;
    final along = ux * vx + uy * vy;
    return math.sqrt(math.max(0, vx * vx + vy * vy + vz * vz - along * along));
  }

  var nearest = double.infinity;
  for (var i = 0; i < shut.facets.length; i++) {
    final f = shut.facets[i];
    if (f.elementId != section.id || f.role != FacetRole.sash) continue;
    for (var k = 0; k < f.corners.length; k++) {
      final before = f.corners[k], after = open.facets[i].corners[k];
      expect(
        fromAxis(after),
        closeTo(fromAxis(before), 1e-6),
        reason: 'a point of the sash changed its distance from the hinges',
      );
      nearest = math.min(nearest, fromAxis(before));
    }
  }
  // The sash hangs on that line: its hinge stile's own face lies along it,
  // a leaf's depth or less from it, all the way down.
  expect(
    nearest,
    lessThanOrEqualTo(d.depthMm),
    reason: 'the sash is not on its own hinge line',
  );
}
