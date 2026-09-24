import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/camera.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// **A design with a door in it is seen from outside, so its hinges are not
// seen.** They are round the back of the leaf, and the solid put them there
// — but the model painted them on the front all the same, because it
// ordered its faces by their average distance and a stile's face is as long
// as the door: a hinge near the foot came out "nearer" than the stile it was
// behind. The user saw hinges on the outside of their door.
//
// Held here on what is actually painted last at each point of every hinge,
// from the front and from the angles the view opens at; and from behind,
// where the same hinges must be what you see.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A window light on the left and a door on the right, both marked `>`.
Design windowAndDoor({
  DesignKind? right = DesignKind.door,
  DesignKind begunAs = DesignKind.both,
}) {
  final time = DateTime(2026);
  final design = SketchInterpreter.interpret(
    Design(
      id: 'd',
      name: 'test',
      kind: begunAs,
      createdAt: time,
      updatedAt: time,
      sketch: Sketch(
        strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(2400, 0),
            Vec2(2400, 2100),
            Vec2(0, 2100),
            Vec2(0, 0),
          ]),
          pen('mullion', const [Vec2(1200, 0), Vec2(1200, 2100)]),
          pen('left', const [Vec2(545, 940), Vec2(655, 1050), Vec2(545, 1160)]),
          pen('right', const [
            Vec2(1745, 940),
            Vec2(1855, 1050),
            Vec2(1745, 1160),
          ]),
        ],
      ),
    ),
  ).design;
  final order = design.openingsInOrder;
  // Said the way the opening's panel says it.
  final said = {order[0].id: DesignKind.window, order[1].id: ?right};
  return OpeningHardware.settle(
    design.copyWith(
      openings: [for (final o in design.openings) o.copyWith(kind: said[o.id])],
    ),
  );
}

bool inside(List<Vec2> polygon, Vec2 p) {
  var hit = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[i], b = polygon[j];
    if ((a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      hit = !hit;
    }
  }
  return hit;
}

/// What the painter leaves on top at [p]: the last face painted over it.
String? onTop(List<ProjectedFacet> painted, Vec2 p) {
  for (final face in painted.reversed) {
    if (inside(face.corners, p)) return face.elementId;
  }
  return null;
}

Vec2 middleOf(List<Vec2> corners) {
  var x = 0.0, y = 0.0;
  for (final c in corners) {
    x += c.x;
    y += c.y;
  }
  return Vec2(x / corners.length, y / corners.length);
}

/// How many points of the hinges show at the end of painting.
int hingesShowing(Design design, Camera camera) {
  final painted = camera.project(MeshBuilder.build(design));
  final hinges = {
    for (final piece in design.hardware)
      if (piece.kind == HardwareKind.hinge) piece.id,
  };
  var showing = 0;
  for (final face in painted) {
    if (!hinges.contains(face.elementId)) continue;
    if (hinges.contains(onTop(painted, middleOf(face.corners)))) showing++;
  }
  return showing;
}

void main() {
  test('a door in the design puts its hinges round the back', () {
    final design = windowAndDoor();
    expect(design.seenFrom, Face.outside);
    final hinges = design.hardware
        .where((p) => p.kind == HardwareKind.hinge)
        .toList();
    expect(hinges, isNotEmpty);
    expect(hinges.every(design.isConcealed), isTrue);
  });

  group('from outside, no hinge is seen', () {
    for (final (name, camera) in const [
      ('as the view opens', Camera()),
      ('square on', Camera.front),
      ('from the left', Camera(yawDegrees: -35, pitchDegrees: 12)),
      ('from below', Camera(yawDegrees: 20, pitchDegrees: -15)),
      ('in parallel', Camera(projection: Projection.parallel)),
    ]) {
      test(name, () {
        expect(hingesShowing(windowAndDoor(), camera), 0);
      });
    }
  });

  test('from inside, the same hinges are what you see', () {
    // Walk round the back and they are there: hidden by where they are,
    // not by the renderer leaving them out.
    const behind = Camera(yawDegrees: 180 + 30, pitchDegrees: 17);
    expect(hingesShowing(windowAndDoor(), behind), greaterThan(0));
  });

  test('a design with no door is seen from inside, hinges and all', () {
    final design = windowAndDoor(
      right: DesignKind.window,
      begunAs: DesignKind.window,
    );
    expect(design.seenFrom, Face.inside);
    expect(hingesShowing(design, const Camera()), greaterThan(0));
  });

  test('the handles are still on the face you are at', () {
    final design = windowAndDoor();
    final painted = const Camera().project(MeshBuilder.build(design));
    final handles = {
      for (final piece in design.hardware)
        if (piece.kind.isHandle) piece.id,
    };
    expect(handles, isNotEmpty);
    for (final id in handles) {
      final showing = painted.where(
        (f) => f.elementId == id && onTop(painted, middleOf(f.corners)) == id,
      );
      expect(showing, isNotEmpty, reason: '$id is on the near face');
    }
  });

  test('putting things in order leaves every face in the picture', () {
    final design = windowAndDoor();
    final mesh = MeshBuilder.build(design);
    final painted = const Camera().project(mesh);
    expect(painted.length, mesh.facets.length);
    expect({for (final f in painted) f.source}, {...mesh.facets});
  });
}
