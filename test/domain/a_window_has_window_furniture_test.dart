import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// A window's handle is its own object, not the door's made smaller.
//
//   Window opening
//   ├── Sash and glass
//   ├── Espagnolette handle   short base, boss, an arm that hangs down
//   └── Hinges                leaf and knuckle, on the face you are at
//
// A window handle is a different manufactured thing from a door lever: a
// short base on the stile rather than a long backplate, and a cast arm that
// curves away from the face and hangs, because that is where the handle of
// a shut window sits. The door's lever is still there for a leaf the user
// puts one on, and only then.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

Design leaf(DesignKind kind) {
  final read = SketchInterpreter.interpret(Design(
    id: 'd',
    name: kind.label,
    kind: kind,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sketch: Sketch(strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(1900, 0),
        Vec2(1900, 2100),
        Vec2(0, 2100),
        Vec2(0, 0),
      ]),
      pen('mullion', const [Vec2(950, 0), Vec2(950, 2100)]),
      pen('mark', const [Vec2(560, 950), Vec2(700, 1050), Vec2(560, 1150)]),
    ]),
  )).design;
  return OpeningHardware.settle(read.copyWith(openings: [
    for (final opening in read.openings) opening.copyWith(kind: kind),
  ]));
}

Design saying(Design design, HardwareKind handleKind) =>
    OpeningHardware.settle(design.copyWith(openings: [
      for (final opening in design.openings)
        opening.copyWith(handleKind: handleKind),
    ]));

HardwareElement handleOf(Design design) => design.hardware
    .firstWhere((piece) => piece.isOpeningHardware && piece.kind.isHandle);

List<Vec3> cornersOf(Design design, String elementId) => [
      for (final facet in MeshBuilder.build(design).facets)
        if (facet.elementId == elementId) ...facet.corners,
    ];

double spread(Iterable<double> of) =>
    of.reduce((a, b) => a > b ? a : b) - of.reduce((a, b) => a < b ? a : b);

void main() {
  group('a window gets a window handle', () {
    test('and it is not the door’s lever', () {
      final window = leaf(DesignKind.window);
      final door = leaf(DesignKind.door);

      expect(handleOf(window).kind, HardwareKind.handle);
      expect(handleOf(door).kind, HardwareKind.lever);

      // Different objects, not the same one scaled: their built shapes do
      // not have the same number of faces, nor the same extent.
      final made = <String, int>{};
      for (final design in [window, door]) {
        made[design.name] = [
          for (final facet in MeshBuilder.build(design).facets)
            if (facet.elementId == handleOf(design).id) facet,
        ].length;
      }
      expect(made['Window'], isNot(made['Door']));
    });

    test('it is a real piece with thickness in every direction', () {
      final design = leaf(DesignKind.window);
      final corners = cornersOf(design, handleOf(design).id);
      expect(corners, isNotEmpty);

      expect(spread(corners.map((c) => c.x)), greaterThan(10));
      expect(spread(corners.map((c) => c.y)), greaterThan(40));
      expect(spread(corners.map((c) => c.z)), greaterThan(20));
    });

    test('it stands off the face of the sash', () {
      final design = leaf(DesignKind.window);
      final corners = cornersOf(design, handleOf(design).id);

      expect(corners.map((c) => c.z).reduce((a, b) => a > b ? a : b),
          greaterThan(MeshBuilder.leafFront(design.depthMm)),
          reason: 'a handle you can get a hand round');
    });

    test('its arm hangs down the sash, where a shut handle rests', () {
      final design = leaf(DesignKind.window);
      final handle = handleOf(design);
      final corners = cornersOf(design, handle.id);

      final lowest = corners.map((c) => c.y).reduce((a, b) => a > b ? a : b);
      final highest = corners.map((c) => c.y).reduce((a, b) => a < b ? a : b);
      expect(lowest - handle.at.y, greaterThan(60),
          reason: 'it reaches well below the boss');
      expect(handle.at.y - highest, lessThan(lowest - handle.at.y),
          reason: 'and further down than up');
    });

    test('its base is short, not a mortice lock’s long plate', () {
      // The one number that tells the two objects apart at a glance: a door
      // needs a plate long enough to cover a lock case, a window does not.
      final window = leaf(DesignKind.window);
      final door = leaf(DesignKind.door);

      double plateRun(Design design) {
        final corners = cornersOf(design, handleOf(design).id);
        // The plate lies on the face; the arm is what stands off it.
        final onFace = [
          for (final c in corners)
            if (c.z <= MeshBuilder.leafFront(design.depthMm) + 9) c,
        ];
        return spread(onFace.map((c) => c.y));
      }

      expect(plateRun(window), lessThan(plateRun(door)));
    });
  });

  group('the door’s lever is only ever there because it was chosen', () {
    test('a window given a lever gets the door’s lever', () {
      final design = saying(leaf(DesignKind.window), HardwareKind.lever);
      expect(handleOf(design).kind, HardwareKind.lever);

      // And it is the lever's shape: it reaches across the sash rather than
      // hanging down it.
      final handle = handleOf(design);
      final corners = cornersOf(design, handle.id);
      expect(spread(corners.map((c) => c.x)), greaterThan(80));
    });

    test('a door given a window handle gets the window handle', () {
      final design = saying(leaf(DesignKind.door), HardwareKind.handle);
      expect(handleOf(design).kind, HardwareKind.handle);
      final corners = cornersOf(design, handleOf(design).id);
      expect(spread(corners.map((c) => c.y)),
          greaterThan(spread(corners.map((c) => c.x))),
          reason: 'it hangs rather than reaches');
    });

    test('a knob is a turned ball on a rose, on either kind', () {
      for (final kind in DesignKind.values) {
        final design = saying(leaf(kind), HardwareKind.knob);
        final corners = cornersOf(design, handleOf(design).id);
        expect(corners, isNotEmpty);
        // Round: as wide as it is tall, and standing off the leaf.
        expect(spread(corners.map((c) => c.x)),
            closeTo(spread(corners.map((c) => c.y)), 20));
        expect(corners.map((c) => c.z).reduce((a, b) => a > b ? a : b),
            greaterThan(MeshBuilder.leafFront(design.depthMm)));
      }
    });

    test('the choice is the opening’s, and it is kept', () {
      final design = saying(leaf(DesignKind.window), HardwareKind.lever);
      final back = Design.fromJson(design.toJson());
      expect(back.openings.single.handleKind, HardwareKind.lever);
      expect(handleOf(OpeningHardware.settle(back)).kind, HardwareKind.lever);
    });
  });

  group('and it is the opening’s, like everything else on the leaf', () {
    test('it names the opening as its parent', () {
      final design = leaf(DesignKind.window);
      expect(design.openingHolding(handleOf(design).parentId)?.id,
          design.openings.single.id);
    });

    test('it turns with the sash, and nothing else moves', () {
      final design = leaf(DesignKind.window);
      final theirs = {
        for (final piece in design.hardware)
          if (piece.isOpeningHardware) piece.id,
      };

      String mine(double open) => [
            for (final facet
                in MeshBuilder.build(design, openFraction: open).facets)
              if (theirs.contains(facet.elementId))
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');
      String elsewhere(double open) => [
            for (final facet
                in MeshBuilder.build(design, openFraction: open).facets)
              if (!theirs.contains(facet.elementId) &&
                  facet.elementId != design.openings.single.sectionId)
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');

      expect(mine(1), isNot(mine(0)));
      expect(elsewhere(1), elsewhere(0));
    });

    test('a window’s hinges are on the face you are standing at', () {
      final design = leaf(DesignKind.window);
      final hinge = design.hardware
          .firstWhere((piece) => piece.kind == HardwareKind.hinge);
      final corners = cornersOf(design, hinge.id);

      expect(corners, isNotEmpty);
      final middle = corners.map((c) => c.z).reduce((a, b) => a + b) /
          corners.length;
      expect(middle, greaterThan(MeshBuilder.leafFront(design.depthMm)),
          reason: 'a window is met from inside, where its hinges are');
    });

    test('a window still carries no lock', () {
      final kinds = {
        for (final piece in leaf(DesignKind.window).hardware)
          if (piece.isOpeningHardware) piece.kind,
      };
      expect(kinds, {HardwareKind.hinge, HardwareKind.handle});
    });
  });

  group('nothing here is a picture either', () {
    test('every facet belongs to a part the design has', () {
      final design = leaf(DesignKind.window);
      final parts = {for (final element in design.allElements) element.id};
      for (final facet in MeshBuilder.build(design).facets) {
        expect(parts, contains(facet.elementId));
      }
    });

    test('the same window gives the same handle, facet for facet', () {
      String hardware(Design d) => [
            for (final facet in MeshBuilder.build(d).facets)
              if (facet.role == FacetRole.hardware)
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');
      expect(hardware(leaf(DesignKind.window)),
          hardware(leaf(DesignKind.window)));
      expect(hardware(leaf(DesignKind.window)), isNotEmpty);
    });
  });
}
