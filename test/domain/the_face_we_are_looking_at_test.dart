import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// A door is met from outside; a window is met from inside.
//
// So a door's hinges are round the back of it, and a window's are on the
// face you are standing at. The same drawing read as a door and as a window
// is the same design — same frame, same bars, same leaf, same hinges in the
// same places — and the only difference is which side of the leaf the
// hinges are on.
//
// This is not a rule about pictures. The hinge is *behind* the leaf in the
// solid, so it is out of sight because of where it is, not because anything
// declined to draw it.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A leaf on the left of a two-light design, marked to open.
Design leaf(DesignKind kind) => SketchInterpreter.interpret(Design(
      id: 'd',
      name: kind.label,
      kind: kind,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1800, 0),
          Vec2(1800, 2000),
          Vec2(0, 2000),
          Vec2(0, 0),
        ]),
        pen('mullion', const [Vec2(900, 0), Vec2(900, 2000)]),
        pen('mark', const [Vec2(560, 900), Vec2(700, 1000), Vec2(560, 1100)]),
      ]),
    )).design;

/// Every facet of [id]'s piece, by how far through the leaf it sits.
List<double> depthsOf(Mesh mesh, String elementId) => [
      for (final facet in mesh.facets)
        if (facet.elementId == elementId)
          for (final corner in facet.corners) corner.z,
    ];

void main() {
  test('a door is seen from outside and a window from inside', () {
    expect(DesignKind.door.seenFrom, Face.outside);
    expect(DesignKind.window.seenFrom, Face.inside);
  });

  test('a hinge is on the inside face; a handle is on neither in particular',
      () {
    expect(HardwareKind.hinge.onTheInsideFace, isTrue);
    for (final kind in const [
      HardwareKind.handle,
      HardwareKind.lever,
      HardwareKind.knob,
      HardwareKind.lock,
    ]) {
      expect(kind.onTheInsideFace, isFalse,
          reason: '${kind.label} is worked from either side');
    }
  });

  group('the same drawing, read as each kind', () {
    test('is the same design — the hinges are in the same places', () {
      final door = leaf(DesignKind.door);
      final window = leaf(DesignKind.window);

      String places(Design design) => [
            for (final piece in design.hardware)
              if (piece.kind == HardwareKind.hinge) '${piece.at}',
          ].join('|');

      expect(places(door), places(window));
      expect(places(door), isNotEmpty);
      // And the geometry itself is untouched by the kind.
      expect(door.topLevelSections.length, window.topLevelSections.length);
      expect(door.frame!.outline.corners, window.frame!.outline.corners);
    });

    test('only which side of the leaf they are on differs', () {
      final door = leaf(DesignKind.door);
      final window = leaf(DesignKind.window);

      for (final piece in door.hardware) {
        if (piece.kind != HardwareKind.hinge) continue;
        expect(door.isConcealed(piece), isTrue,
            reason: 'a door’s hinges are round the back');
      }
      for (final piece in window.hardware) {
        expect(window.isConcealed(piece), isFalse,
            reason: 'a window is met from inside, where its hinges are');
      }
    });

    test('a handle is on the face you are standing at, either way', () {
      for (final design in [leaf(DesignKind.door), leaf(DesignKind.window)]) {
        for (final piece in design.hardware) {
          if (piece.kind == HardwareKind.hinge) continue;
          expect(design.isConcealed(piece), isFalse);
        }
      }
    });
  });

  group('the solid puts the hinge where the rule says', () {
    test('a door’s hinge is behind the face you are looking at', () {
      final design = leaf(DesignKind.door);
      final hinge = design.hardware
          .firstWhere((piece) => piece.kind == HardwareKind.hinge);
      final depths = depthsOf(MeshBuilder.build(design), hinge.id);
      expect(depths, isNotEmpty);

      // Two things, and the second is not the first. It is fixed to the
      // **inside** face, so its body is behind the leaf; and nothing of it
      // reaches the face the drawing is of, so there is nothing to see
      // standing on the outside of the door.
      final middle = depths.reduce((a, b) => a + b) / depths.length;
      expect(middle, lessThan(MeshBuilder.leafBack(design.depthMm)),
          reason: 'fixed to the inside face');
      expect(depths.reduce((a, b) => a > b ? a : b),
          lessThan(MeshBuilder.leafFront(design.depthMm)),
          reason: 'nothing of it is on the face you are looking at');
    });

    test('but its knuckle breaks the inside face, as a real one does', () {
      // A butt hinge's barrel is centred on the line the leaf turns about,
      // so it stands a little proud of the face it is screwed to. A hinge
      // that lies entirely flat behind the door is a tab, not a hinge.
      final design = leaf(DesignKind.door);
      final hinge = design.hardware
          .firstWhere((piece) => piece.kind == HardwareKind.hinge);
      final depths = depthsOf(MeshBuilder.build(design), hinge.id);

      expect(depths.reduce((a, b) => a > b ? a : b),
          greaterThan(MeshBuilder.leafBack(design.depthMm)));
    });

    test('a window’s hinge is on the face you are looking at', () {
      final design = leaf(DesignKind.window);
      final hinge = design.hardware
          .firstWhere((piece) => piece.kind == HardwareKind.hinge);
      final depths = depthsOf(MeshBuilder.build(design), hinge.id);
      expect(depths, isNotEmpty);

      // On the near side of the leaf: you are standing indoors, which is
      // where a window's hinges are, and there they are.
      final middle = depths.reduce((a, b) => a + b) / depths.length;
      final near = MeshBuilder.leafFront(design.depthMm);
      expect(middle, greaterThan(near));
      expect(depths.reduce((a, b) => a > b ? a : b), greaterThan(near));
    });

    test('the handle stands on the near face for both kinds', () {
      // The leaf kinds. A door-and-window assembly says nothing about one
      // leaf, so a leaf in one carries no handle to ask this of.
      for (final kind in DesignKind.leafKinds) {
        final design = leaf(kind);
        final handle = design.hardware
            .firstWhere((piece) => piece.kind.isHandle);
        final depths = depthsOf(MeshBuilder.build(design), handle.id);
        expect(depths.reduce((a, b) => a > b ? a : b),
            greaterThan(MeshBuilder.leafFront(design.depthMm)),
            reason: 'a ${kind.label}’s handle is on the face you are at');
      }
    });

    test('no geometry of the design depends on the kind', () {
      // The ironmongery is what the kind decides — which side of the leaf
      // the hinges are on, and which pieces are there at all. Not where
      // they go: the handle is at the middle of its edge on every leaf. The
      // design itself is not the kind's business: the frame, the bars, the
      // sections and their panes are the same either way, facet for facet.
      String fingerprint(Design design) {
        final ironmongery = {for (final p in design.hardware) p.id};
        return [
          for (final facet in MeshBuilder.build(design).facets)
            if (!ironmongery.contains(facet.elementId))
              '${facet.elementId}:${facet.corners.join(',')}',
        ].join('|');
      }

      expect(fingerprint(leaf(DesignKind.door)),
          fingerprint(leaf(DesignKind.window)));
    });

    test('the handle is at the middle of the leaf, whatever the kind', () {
      // **Where the handle goes stopped being the kind's business.** It
      // used to be a metre up on a door and mid-stile on a window, so
      // answering *door* about a sash slid its fastener up a leaf whose
      // geometry had not moved at all. The middle is derived from the leaf,
      // and the same leaf answered either way puts it in the same place.
      double handleUp(DesignKind kind) {
        final design = leaf(kind);
        final handle =
            design.hardware.firstWhere((piece) => piece.kind.isHandle);
        final section =
            design.sectionById(design.sectionHolding(handle.parentId)!)!;
        return section.outline.bottom - handle.at.y;
      }

      final door = handleUp(DesignKind.door);
      final window = handleUp(DesignKind.window);
      expect(door, closeTo(window, 0.01),
          reason: 'the kind does not move the handle');

      final sash = leaf(DesignKind.window);
      final height = sash
          .sectionById(sash.openings.single.sectionId)!
          .outline
          .height;
      expect(door, closeTo(height / 2, 0.5), reason: 'the middle of the leaf');
    });

    test('what the kind does decide is which pieces are there', () {
      Set<HardwareKind> piecesOn(DesignKind kind) =>
          {for (final piece in leaf(kind).hardware) piece.kind};

      // A door locks and is worked by a lever; a window fastens and is
      // worked by an espagnolette. That is the whole of the difference.
      expect(piecesOn(DesignKind.door),
          {HardwareKind.hinge, HardwareKind.lever, HardwareKind.lock});
      expect(piecesOn(DesignKind.window),
          {HardwareKind.hinge, HardwareKind.handle});
    });
  });
}
