import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// **Inward is into the building, and which way that is on the screen depends
// on which side of the wall the drawing is of.** A design with a door in it
// is seen from outside, so an inward door swings *away* from the viewer, into
// the room — the door you walk up to and push. A window is seen from inside,
// so an inward sash swings towards the viewer, into the room you are
// standing in. Every inward leaf used to swing towards the viewer, which
// opened a front door out into the street.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

Design leaf(DesignKind kind, {OpeningDirection? direction}) {
  final time = DateTime(2026);
  var design = SketchInterpreter.interpret(Design(
    id: 'd',
    name: 'test',
    kind: kind,
    createdAt: time,
    updatedAt: time,
    sketch: Sketch(strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(1000, 0),
        Vec2(1000, 2100),
        Vec2(0, 2100),
        Vec2(0, 0),
      ]),
      pen('mark', const [Vec2(250, 700), Vec2(750, 1050), Vec2(250, 1400)]),
    ]),
  )).design;
  if (direction != null) {
    final opening = design.openings.single;
    design = design.withElement(opening.copyWith(direction: direction));
  }
  return design;
}

/// How far towards the viewer the leaf's glass comes, on average, at
/// [open] — positive towards, negative away.
double glassComesForward(Design design, double open) {
  double meanZ(double fraction) {
    var sum = 0.0;
    var n = 0;
    for (final facet
        in MeshBuilder.build(design, openFraction: fraction).facets) {
      if (!design.sections.any((s) => s.id == facet.elementId)) continue;
      for (final c in facet.corners) {
        sum += c.z;
        n++;
      }
    }
    return sum / n;
  }

  return meanZ(open) - meanZ(0);
}

void main() {
  test('a door opens away from you, into the room', () {
    final door = leaf(DesignKind.door);
    expect(door.seenFrom, Face.outside);
    expect(door.openings.single.direction, OpeningDirection.inward);
    expect(MeshBuilder.swingsTowardViewer(door, door.openings.single), isFalse);
    expect(glassComesForward(door, 0.6), lessThan(-100));
  });

  test('a window opens towards you, into the room you are in', () {
    final window = leaf(DesignKind.window);
    expect(window.seenFrom, Face.inside);
    expect(glassComesForward(window, 0.6), greaterThan(100));
  });

  test('a door made to open outward comes towards you', () {
    final door = leaf(DesignKind.door, direction: OpeningDirection.outward);
    expect(glassComesForward(door, 0.6), greaterThan(100));
  });

  test('a door leaf turns about its back face and keeps its shape', () {
    // It turns on the face its hinges are on, so its near face does not
    // cut back through the frame it hangs in.
    final door = leaf(DesignKind.door);
    final shut = MeshBuilder.build(door);
    final open = MeshBuilder.build(door, openFraction: 1);
    final frame = door.frame!;
    for (final facet in open.facets) {
      if (!door.sections.any((s) => s.id == facet.elementId)) continue;
      for (final c in facet.corners) {
        // Nothing of the swung leaf comes out in front of the frame.
        expect(c.z, lessThanOrEqualTo(0.01));
        expect(c.x, greaterThanOrEqualTo(frame.outline.left - 1));
      }
    }
    expect(open.facets.length, shut.facets.length);
  });
}
