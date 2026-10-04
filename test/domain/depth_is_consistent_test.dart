import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/opening_leaf.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/depth_layout.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import 'rendering_geometry_baseline_test.dart' as base;

// Phase 8 of the CAD and 3D work: consistent physical depth.
//
// The solid is built in one coordinate system — X across and Y down the
// elevation, exactly the drawing's own, and Z out of the face the drawing is
// of, the frame's face at Z = 0 and the design running back to Z = -depth —
// and where along Z every part stands is said in one place, [DepthLayout],
// as a share of whatever holds it.
//
// Held here: the front-facing design is the drawing's to the millimetre and
// depth never moves it; every part stands in its own band, at every level of
// the tree — the bars and panes inside a sash in the sash, not against the
// frame, which is where they used to be measured from; glass is a sealed
// unit of two sheets with a cavity, held by a bead on the room side; the
// ironmongery stands out of the face it is fixed to; and turned, the model
// shows its depth, as deep as it is.

final door = base.door();
final window = base.window();
final sliding = base.sliding();

Iterable<Facet> _of(Mesh mesh, String id, {FacetRole? role}) => mesh.facets
    .where((f) => f.elementId == id && (role == null || f.role == role));

({double lo, double hi}) _z(Iterable<Facet> facets) {
  var lo = double.infinity, hi = -double.infinity;
  for (final f in facets) {
    for (final c in f.corners) {
      lo = math.min(lo, c.z);
      hi = math.max(hi, c.z);
    }
  }
  return (lo: lo, hi: hi);
}

void _within(Iterable<Facet> facets, DepthBand band, String what) {
  expect(facets, isNotEmpty, reason: what);
  final z = _z(facets);
  expect(z.hi, lessThanOrEqualTo(band.front + 1e-6), reason: '$what: $z');
  expect(z.lo, greaterThanOrEqualTo(band.back - 1e-6), reason: '$what: $z');
}

Design _deepened(Design d, double depth) => d.copyWith(depthMm: depth);

void main() {
  group('one coordinate system', () {
    for (final (name, d) in [
      ('door', door),
      ('window', window),
      ('sliding', sliding),
    ]) {
      test('$name: X and Y are the drawing\'s, Z is the depth', () {
        final outline = d.frame!.outline;
        final mesh = MeshBuilder.build(d);
        for (final f in mesh.facets) {
          for (final c in f.corners) {
            expect(
              c.x >= outline.left - 1e-6 && c.x <= outline.right + 1e-6,
              isTrue,
              reason: '${f.role.name} across',
            );
            expect(
              c.y >= outline.top - 1e-6 && c.y <= outline.bottom + 1e-6,
              isTrue,
              reason: '${f.role.name} down',
            );
          }
          // Only the ironmongery stands out of the frame's depth — out of
          // the faces it is fixed to.
          if (f.role == FacetRole.hardware) continue;
          for (final c in f.corners) {
            expect(c.z, lessThanOrEqualTo(1e-6), reason: f.role.name);
            expect(
              c.z,
              greaterThanOrEqualTo(-d.depthMm - 1e-6),
              reason: f.role.name,
            );
          }
        }
        // The frame is the whole depth, from its face at zero.
        final frame = _z(_of(mesh, d.frame!.id));
        expect(frame.hi, closeTo(0, 1e-6));
        expect(frame.lo, closeTo(-d.depthMm, 1e-6));
      });
    }
  });

  group('depth is a property of its own: it moves nothing on the face', () {
    for (final (name, d) in [
      ('door', door),
      ('window', window),
      ('sliding', sliding),
    ]) {
      test(name, () {
        final at = <double, List<Facet>>{
          for (final depth in [60.0, 70.0, 110.0])
            depth: MeshBuilder.build(_deepened(d, depth)).facets,
        };
        final reference = at[70.0]!;
        for (final depth in at.keys) {
          final design = _deepened(d, depth);
          // The front-facing design — the frame, its daylight, every
          // section and every bar — is the drawing's, whatever the depth.
          String face(Design x) => [
            x.frame!.outline.toJson(),
            x.frame!.innerOutline.toJson(),
            for (final s in x.sections) s.outline.toJson(),
            for (final b in x.dividers) '${b.a} ${b.b} ${b.widthMm}',
          ].join('|');
          expect(face(design), face(d), reason: 'the design at $depth mm');
          // Every point of the solid on the face is where it was: the
          // same points, whatever the depth. (A sliding panel's glass may
          // be one sheet rather than two where its track is too thin for a
          // cavity — construction, in depth — and it adds no point.)
          Set<String> onTheFace(List<Facet> facets) => {
            for (final f in facets)
              for (final c in f.corners)
                '${c.x.toStringAsFixed(6)},${c.y.toStringAsFixed(6)}',
          };
          expect(onTheFace(at[depth]!), onTheFace(reference));
        }
        // And the depth is the depth asked for.
        for (final depth in at.keys) {
          final frame = _z(at[depth]!.where((f) => f.role == FacetRole.frame));
          expect(frame.hi - frame.lo, closeTo(depth, 1e-6));
        }
      });
    }
  });

  group('every part stands in its own band', () {
    final layout = DepthLayout.of(door);
    final mesh = MeshBuilder.build(door);
    final opening = door.openings.single;
    final leaf = layout.leaf;
    final panes = door.childSectionsOf(opening.sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

    test('the design\'s own bars in the frame', () {
      for (final bar in door.topLevelDividers) {
        _within(_of(mesh, bar.id), layout.barsIn(layout.frame), bar.id);
        final z = _z(_of(mesh, bar.id));
        expect(z.hi, closeTo(layout.barsIn(layout.frame).front, 1e-6));
        expect(z.lo, closeTo(layout.barsIn(layout.frame).back, 1e-6));
      }
    });

    test('the sash in the frame, a little back from its face', () {
      final sash = _of(mesh, opening.sectionId, role: FacetRole.sash);
      final z = _z(sash);
      expect(z.hi, closeTo(leaf.front, 1e-6));
      expect(z.lo, closeTo(leaf.back, 1e-6));
      expect(leaf.front, lessThan(0));
      expect(leaf.back, greaterThan(-door.depthMm));
    });

    test('a bar drawn inside the sash stands in the sash, as the design\'s '
        'bars stand in the frame', () {
      final inner = door.dividers.where((d) => d.parentId != null).single;
      final z = _z(_of(mesh, inner.id));
      final band = layout.barsIn(leaf);
      expect(z.hi, closeTo(band.front, 1e-6), reason: 'not proud of the sash');
      expect(z.lo, closeTo(band.back, 1e-6));
      _within(_of(mesh, inner.id), leaf, 'inside the leaf');
    });

    test('the panes of the sash are centred in the sash', () {
      for (final pane in panes) {
        final body = _of(mesh, pane.id).where(
          (f) => f.role == FacetRole.glazing || f.role == FacetRole.panel,
        );
        final z = _z(body);
        expect((z.hi + z.lo) / 2, closeTo(leaf.middle, 1e-6), reason: pane.id);
        _within(body, leaf, pane.id);
      }
    });

    test('a fixed light\'s glass is centred in the frame', () {
      final fixed = door.topLevelSections.where(
        (s) => door.openingOf(s.id) == null,
      );
      for (final s in fixed) {
        final unit = _of(mesh, s.id, role: FacetRole.glazing);
        final z = _z(unit);
        expect((z.hi + z.lo) / 2, closeTo(layout.frame.middle, 1e-6));
        expect(
          z.hi - z.lo,
          closeTo(layout.glazingIn(layout.frame).depth, 1e-6),
        );
      }
    });

    test('a sliding panel stands on its own track, inside the frame', () {
      final mesh = MeshBuilder.build(sliding);
      final frame = DepthLayout.of(sliding).frame;
      final bands = <({double lo, double hi})>[];
      for (final s in sliding.topLevelSections) {
        final z = _z(_of(mesh, s.id));
        _within(_of(mesh, s.id), frame, s.id);
        bands.add(z);
      }
      // The slider and the fixed panel are on two tracks: their depths do
      // not overlap.
      expect(bands, hasLength(2));
      expect(
        bands[0].hi <= bands[1].lo + 1e-6 || bands[1].hi <= bands[0].lo + 1e-6,
        isTrue,
        reason: '$bands',
      );
    });
  });

  group('glass is as thick as glass is', () {
    for (final (name, d) in [('door', door), ('window', window)]) {
      test('$name: a sealed unit of two sheets, a cavity and a seal', () {
        final mesh = MeshBuilder.build(d);
        final glazed = d.sections.where(
          (s) =>
              s.finish.material.surface.isTransparent &&
              _of(mesh, s.id, role: FacetRole.glazing).isNotEmpty,
        );
        expect(glazed, isNotEmpty);
        for (final s in glazed) {
          final faces = _of(
            mesh,
            s.id,
            role: FacetRole.glazing,
          ).where((f) => !f.isSide).toList();
          expect(faces, hasLength(4), reason: s.id);
          final zs = [for (final f in faces) f.corners.first.z]..sort();
          expect(zs[1] - zs[0], closeTo(DepthLayout.lite, 1e-6));
          expect(zs[3] - zs[2], closeTo(DepthLayout.lite, 1e-6));
          expect(
            zs[2] - zs[1],
            greaterThanOrEqualTo(DepthLayout.narrowestCavity),
          );
          // Seen through, the four faces are one glass.
          for (final f in faces) {
            expect(f.glassFaces, 4);
          }
          // The cavity is closed round its edge by the seal, and the sheets'
          // edges are glass.
          final sides = _of(
            mesh,
            s.id,
            role: FacetRole.glazing,
          ).where((f) => f.isSide);
          expect(sides.where((f) => !f.surface.isTransparent), isNotEmpty);
          expect(sides.where((f) => f.surface.isTransparent), isNotEmpty);
        }
      });
    }

    test('and a unit too thin for a cavity is one sheet', () {
      const layout = DepthLayout(70);
      expect(layout.litesOf(const DepthBand(0, -8)), hasLength(1));
      expect(layout.litesOf(const DepthBand(0, -24)), hasLength(2));
    });
  });

  group('the glazing bead holds the glass from the room', () {
    for (final (name, d, roomInFront) in [
      ('door, drawn from outside', door, false),
      ('window, drawn from inside', window, true),
    ]) {
      test(name, () {
        final layout = DepthLayout.of(d);
        expect(layout.roomInFront, roomInFront);
        final mesh = MeshBuilder.build(d);
        final geometry = DesignGeometry.of(d);
        var seen = 0;
        for (final s in d.sections) {
          final bead = _of(mesh, s.id, role: FacetRole.bead);
          if (bead.isEmpty) continue;
          seen++;
          final unit = _z(_of(mesh, s.id, role: FacetRole.glazing));
          final z = _z(bead);
          if (roomInFront) {
            expect(z.lo, closeTo(unit.hi, 1e-6), reason: 'on the glass');
          } else {
            expect(z.hi, closeTo(unit.lo, 1e-6), reason: 'on the glass');
          }
          // On the face, from the edge of the glass to the bead's line.
          final glass = OpeningLeaf.fillOf(d, s);
          final line = geometry.beadAround(glass)!;
          for (final f in bead) {
            for (final c in f.corners) {
              final p = c.flat;
              expect(
                (glass.contains(p) ||
                        glass.edges.any((e) => e.distanceTo(p) < 1e-6)) &&
                    !(line.contains(p) &&
                        line.edges.every((e) => e.distanceTo(p) > 1e-6)),
                isTrue,
                reason: 'between the glass\'s edge and the bead line',
              );
            }
          }
        }
        expect(seen, greaterThan(0));
        // And the drawing shows the bead exactly where it is on the face
        // the drawing is of.
        expect(geometry.beadsSeen, roomInFront);
      });
    }
  });

  group('the ironmongery stands out of the face it is fixed to', () {
    test('a door\'s lever out of both faces; its hinges behind', () {
      final leaf = DepthLayout.of(door).leaf;
      final mesh = MeshBuilder.build(door);
      final lever = door.hardware.firstWhere(
        (p) => p.kind == HardwareKind.lever,
      );
      final near = _z(_of(mesh, lever.id).where((f) => f.part == null));
      final far = _z(_of(mesh, lever.id).where((f) => f.part != null));
      expect(near.lo, closeTo(leaf.front, 1e-6), reason: 'on the near face');
      expect(near.hi, greaterThan(leaf.front + 30), reason: 'out of it');
      expect(far.hi, closeTo(leaf.back, 1e-6), reason: 'on the far face');
      expect(far.lo, lessThan(leaf.back - 30), reason: 'out of it');
      for (final hinge in door.hardware.where(
        (p) => p.kind == HardwareKind.hinge,
      )) {
        final z = _z(_of(mesh, hinge.id));
        expect(z.hi, lessThan(leaf.back + 10), reason: 'round the back');
      }
    });

    test('a window\'s handle out of the face you stand at, and only it', () {
      final leaf = DepthLayout.of(window).leaf;
      final mesh = MeshBuilder.build(window);
      final handle = window.hardware.firstWhere(
        (p) => p.kind == HardwareKind.handle,
      );
      final z = _z(_of(mesh, handle.id));
      expect(z.lo, closeTo(leaf.front, 1e-6));
      expect(z.hi, greaterThan(leaf.front + 20));
    });
  });

  group('turned, the model shows its depth', () {
    /// How wide the outside of the frame's right jamb is on the screen,
    /// seen from [camera].
    double side(Design d, Camera camera) {
      final outline = d.frame!.outline;
      var lo = double.infinity, hi = -double.infinity;
      for (final f in camera.project(MeshBuilder.build(d))) {
        if (f.source.role != FacetRole.frame) continue;
        if (!f.source.corners.every(
          (c) => (c.x - outline.right).abs() < 1e-6,
        )) {
          continue;
        }
        for (final c in f.corners) {
          lo = math.min(lo, c.x);
          hi = math.max(hi, c.x);
        }
      }
      return hi - lo;
    }

    const turned = Camera(yawDegrees: -60, pitchDegrees: 10);
    const front = Camera(yawDegrees: 0, pitchDegrees: 0);

    test('square on, the frame\'s side is edge on; turned, it is seen as '
        'deep as the frame is', () {
      final flat = side(window, front);
      final seen = side(window, turned);
      expect(seen, greaterThan(flat + 20));
      // Twice as deep, about twice as wide on the screen, and never the
      // width or the height of the design that changes it.
      final deeper = side(_deepened(window, window.depthMm * 2), turned);
      expect(deeper / seen, closeTo(2, 0.35));
    });
  });
}
