import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import 'hinges_round_the_back_test.dart' as leaves;

// A door is opened from the room as well as from the street, so its lever is
// on both faces of the leaf — and so is a window's handle, a knob and a
// lock's escutcheon. Each is built on the face the drawing is of and again
// on the other, the same piece turned through the leaf. A hinge is screwed
// to one face only, and is not doubled.

Design design() => leaves.windowAndDoor();

List<Facet> facetsOf(Mesh mesh, String id) => [
  for (final f in mesh.facets)
    if (f.elementId == id) f,
];

/// How much of [id] shows, from [camera]: facets on top at their middles.
int showing(Design design, String id, Camera camera) {
  final painted = camera.project(MeshBuilder.build(design));
  return painted
      .where(
        (f) =>
            f.elementId == id &&
            leaves.onTop(painted, leaves.middleOf(f.corners)) == id,
      )
      .length;
}

void main() {
  final door = design();
  final handles = [
    for (final piece in door.hardware)
      if (!piece.kind.onTheInsideFace) piece,
  ];
  final front = MeshBuilder.leafFront(door.depthMm);
  final back = MeshBuilder.leafBack(door.depthMm);

  test('every handle and lock is built on both faces of its leaf', () {
    expect(handles, isNotEmpty);
    final mesh = MeshBuilder.build(door);
    for (final piece in handles) {
      final zs = [
        for (final f in facetsOf(mesh, piece.id))
          for (final c in f.corners) c.z,
      ];
      expect(
        zs.any((z) => z > front),
        isTrue,
        reason: '${piece.kind.name} stands off the near face',
      );
      expect(
        zs.any((z) => z < back),
        isTrue,
        reason: '${piece.kind.name} stands off the far face too',
      );
    }
  });

  test('the two are the same piece, turned through the leaf', () {
    final mesh = MeshBuilder.build(door);
    for (final piece in handles) {
      final near = [
        for (final f in facetsOf(mesh, piece.id))
          if (f.part == null) f,
      ];
      final far = [
        for (final f in facetsOf(mesh, piece.id))
          if (f.part != null) f,
      ];
      expect(far.length, near.length);
      // Same place across and up the leaf, mirrored through its middle.
      for (var i = 0; i < near.length; i++) {
        for (var j = 0; j < near[i].corners.length; j++) {
          final a = near[i].corners[j], b = far[i].corners[j];
          expect(b.x, closeTo(a.x, 1e-6));
          expect(b.y, closeTo(a.y, 1e-6));
          expect(b.z, closeTo(front + back - a.z, 1e-6));
        }
      }
    }
  });

  test('a hinge is on one face only', () {
    final mesh = MeshBuilder.build(door);
    for (final piece in door.hardware) {
      if (!piece.kind.onTheInsideFace) continue;
      expect(facetsOf(mesh, piece.id).every((f) => f.part == null), isTrue);
    }
  });

  test('seen from the street and from the room, the lever is there', () {
    final lever = door.hardware.firstWhere((p) => p.kind == HardwareKind.lever);
    expect(showing(door, lever.id, const Camera()), greaterThan(0));
    expect(
      showing(door, lever.id, const Camera(yawDegrees: 210, pitchDegrees: 12)),
      greaterThan(0),
    );
  });

  test('both of them swing with the leaf', () {
    final lever = door.hardware.firstWhere((p) => p.kind == HardwareKind.lever);
    final shut = facetsOf(MeshBuilder.build(door), lever.id);
    final open = facetsOf(MeshBuilder.build(door, openFraction: 0.7), lever.id);
    for (final part in [null, 'the other face']) {
      final a = shut.where((f) => f.part == part).first.corners.first;
      final b = open.where((f) => f.part == part).first.corners.first;
      expect((a - b).length, greaterThan(50), reason: 'part $part moved');
    }
  });
}
