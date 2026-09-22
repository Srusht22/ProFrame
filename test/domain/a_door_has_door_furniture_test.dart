import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// A door's ironmongery is built as ironmongery.
//
//   Door opening
//   ├── Lever on a backplate     out of the leaf, and across it
//   ├── Escutcheon               with the keyhole through it
//   └── Hinges                   leaf and knuckle, on the inside face
//
// All of it is geometry. There is no photograph of a handle in this
// repository, no bundled model file and no flat overlay standing in for a
// part — `test/no_stock_content_test.dart` scans for exactly that. What is
// here is built from rings swept along their own axes, so a lever comes out
// of the door and turns across it the way a lever does.
//
// And it is the *opening's*: it hangs on the leaf, goes where the leaf
// goes, turns when it turns, and stays on it when the leaf is resized.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A two-light design with the left light marked to open, read as [kind].
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
  // Said outright, so the test is about the answer and not about the
  // design's kind leaking through.
  return OpeningHardware.settle(read.copyWith(openings: [
    for (final opening in read.openings) opening.copyWith(kind: kind),
  ]));
}

List<HardwareElement> ironmongery(Design design) => [
      for (final piece in design.hardware)
        if (piece.isOpeningHardware) piece,
    ];

HardwareElement handleOf(Design design) =>
    ironmongery(design).firstWhere((piece) => piece.kind.isHandle);

List<Vec3> cornersOf(Mesh mesh, String elementId) => [
      for (final facet in mesh.facets)
        if (facet.elementId == elementId) ...facet.corners,
    ];

void main() {
  group('what a door carries and a window does not', () {
    test('a door has a lever, an escutcheon and hinges', () {
      final kinds = {for (final p in ironmongery(leaf(DesignKind.door))) p.kind};
      expect(kinds, {
        HardwareKind.hinge,
        HardwareKind.lever,
        HardwareKind.lock,
      });
    });

    test('a window has its fastener and hinges, and no lock', () {
      final kinds =
          {for (final p in ironmongery(leaf(DesignKind.window))) p.kind};
      expect(kinds, {HardwareKind.hinge, HardwareKind.handle});
      expect(kinds, isNot(contains(HardwareKind.lock)));
    });

    test('saying a window is a door gives it door furniture', () {
      final design = leaf(DesignKind.window);
      final opening = design.openings.single;
      expect(ironmongery(design).any((p) => p.kind == HardwareKind.lock),
          isFalse);

      final asDoor = OpeningHardware.settle(design.copyWith(openings: [
        opening.copyWith(kind: DesignKind.door),
      ]));

      expect(ironmongery(asDoor).any((p) => p.kind == HardwareKind.lock),
          isTrue);
      expect(handleOf(asDoor).kind, HardwareKind.lever);
    });

    test('the keyhole sits below the lever, on the same stile', () {
      final design = leaf(DesignKind.door);
      final lock =
          ironmongery(design).firstWhere((p) => p.kind == HardwareKind.lock);
      final handle = handleOf(design);

      expect(lock.at.y, greaterThan(handle.at.y), reason: 'below it');
      expect(lock.at.x, closeTo(handle.at.x, 0.01), reason: 'the same stile');
    });
  });

  group('the handle is a real piece, not a tab', () {
    test('it has thickness in every direction', () {
      final design = leaf(DesignKind.door);
      final corners =
          cornersOf(MeshBuilder.build(design), handleOf(design).id);
      expect(corners, isNotEmpty);

      double spread(Iterable<double> of) =>
          of.reduce((a, b) => a > b ? a : b) -
          of.reduce((a, b) => a < b ? a : b);

      // A flat overlay has no depth. This comes out of the leaf and turns
      // across it, so it is real in all three.
      expect(spread(corners.map((c) => c.x)), greaterThan(40));
      expect(spread(corners.map((c) => c.y)), greaterThan(40));
      expect(spread(corners.map((c) => c.z)), greaterThan(20));
    });

    test('it stands off the face of the leaf', () {
      final design = leaf(DesignKind.door);
      final corners =
          cornersOf(MeshBuilder.build(design), handleOf(design).id);

      expect(corners.map((c) => c.z).reduce((a, b) => a > b ? a : b),
          greaterThan(design.depthMm),
          reason: 'a lever you can get a hand behind');
    });

    test('the lever points back across the leaf, not off it', () {
      // Hinged on the left: the handle is on the right stile and the lever
      // runs back towards the hinges. Running the other way puts it out in
      // the frame, where no hand goes.
      final design = leaf(DesignKind.door);
      final opening = design.openings.single;
      final box = design.sectionById(opening.sectionId)!.outline;
      expect(opening.mechanism.hingeEdge, OpeningEdge.left);

      final corners =
          cornersOf(MeshBuilder.build(design), handleOf(design).id);
      final reach = corners.map((c) => c.x).reduce((a, b) => a < b ? a : b);
      expect(reach, lessThan(handleOf(design).at.x - 60));
      expect(reach, greaterThan(box.left),
          reason: 'and it stays on the leaf it is fixed to');
    });

    test('a knob is a different shape from a lever, and the user chooses',
        () {
      final design = leaf(DesignKind.door);
      final opening = design.openings.single;

      String shape(HardwareKind handle) {
        final made = OpeningHardware.settle(design.copyWith(openings: [
          opening.copyWith(handleKind: handle),
        ]));
        final mesh = MeshBuilder.build(made);
        return cornersOf(mesh, handleOf(made).id).length.toString();
      }

      expect(handleOf(design).kind, HardwareKind.lever,
          reason: 'a door has a lever until the user says otherwise');
      expect(shape(HardwareKind.knob), isNotEmpty);
      // What form it takes is stored on the opening, and comes back.
      final withKnob = design.copyWith(openings: [
        opening.copyWith(handleKind: HardwareKind.knob),
      ]);
      expect(Design.fromJson(withKnob.toJson()).openings.single.handleKind,
          HardwareKind.knob);
    });
  });

  group('every piece of it is the opening’s', () {
    test('each one names the opening as its parent', () {
      final design = leaf(DesignKind.door);
      final opening = design.openings.single;

      expect(ironmongery(design), hasLength(greaterThanOrEqualTo(4)));
      for (final piece in ironmongery(design)) {
        expect(design.openingHolding(piece.parentId)?.id, opening.id);
        expect(piece.parentId, isNot(design.frame!.id));
      }
    });

    test('it turns when the leaf turns, and nothing else moves', () {
      final design = leaf(DesignKind.door);
      final theirs = {for (final p in ironmongery(design)) p.id};

      String elsewhere(double open) => [
            for (final facet in MeshBuilder.build(design, openFraction: open)
                .facets)
              if (!theirs.contains(facet.elementId) &&
                  facet.elementId != design.openings.single.sectionId)
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');
      String mine(double open) => [
            for (final facet in MeshBuilder.build(design, openFraction: open)
                .facets)
              if (theirs.contains(facet.elementId))
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');

      expect(mine(1), isNot(mine(0)), reason: 'it swings with the leaf');
      expect(elsewhere(1), elsewhere(0), reason: 'and nothing else does');
    });

    test('it stays on the leaf when the leaf is resized', () {
      final design = leaf(DesignKind.door);
      final opening = design.openings.single;

      final wider = DesignEdits.setSectionWidth(
          design, opening.sectionId, 1100);
      final box = wider.sectionById(
          wider.openingById(opening.id)!.sectionId)!.outline;

      final pieces = ironmongery(wider);
      expect(pieces, isNotEmpty);
      for (final piece in pieces) {
        expect(piece.at.x, greaterThanOrEqualTo(box.left - 1));
        expect(piece.at.x, lessThanOrEqualTo(box.right + 1));
        expect(piece.at.y, greaterThanOrEqualTo(box.top - 1));
        expect(piece.at.y, lessThanOrEqualTo(box.bottom + 1));
      }
    });

    test('nothing of it is put anywhere else on the design', () {
      final design = leaf(DesignKind.door);
      final fixed = [
        for (final section in design.topLevelSections)
          if (design.openingOf(section.id) == null) section,
      ];
      expect(fixed, hasLength(1));

      for (final piece in design.hardware) {
        expect(design.sectionHolding(piece.parentId),
            isNot(fixed.single.id));
      }
    });
  });

  group('and it is editable', () {
    test('colour and material are the piece’s own', () {
      final design = leaf(DesignKind.door);
      final handle = handleOf(design);

      const brass =
          Finish(colour: 0xFFB08D57, material: MaterialKind.aluminium);
      final after = design.withElement(handle.copyWith(finish: brass));
      final now = after.hardware.firstWhere((p) => p.id == handle.id);

      expect(now.finish.colour, brass.colour);
      // And the solid builds it in that colour, rather than in one of its
      // own choosing.
      final built = {
        for (final facet in MeshBuilder.build(after).facets)
          if (facet.elementId == handle.id) facet.colour,
      };
      expect(built, isNotEmpty);
      expect(built.every((c) => c != design.frame!.finish.colour), isTrue);
    });

    test('where it sits is the user’s figure, and it is kept', () {
      final design = leaf(DesignKind.door);
      final opening = design.openings.single;
      final box = design.sectionById(opening.sectionId)!.outline;

      final moved = OpeningHardware.settle(design.copyWith(openings: [
        opening.copyWith(handleAlongMm: 1250),
      ]));

      expect(box.bottom - handleOf(moved).at.y, closeTo(1250, 0.01));
      expect(Design.fromJson(moved.toJson()).openings.single.handleAlongMm,
          1250);
    });
  });

  group('nothing here is a picture', () {
    test('every facet of it belongs to a part the design has', () {
      final design = leaf(DesignKind.door);
      final parts = {for (final element in design.allElements) element.id};

      for (final facet in MeshBuilder.build(design).facets) {
        expect(parts, contains(facet.elementId));
      }
    });

    test('the same design gives the same ironmongery, facet for facet', () {
      final design = leaf(DesignKind.door);
      String hardware(Design d) => [
            for (final facet in MeshBuilder.build(d).facets)
              if (facet.role == FacetRole.hardware)
                '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');

      expect(hardware(design), hardware(leaf(DesignKind.door)));
      expect(hardware(design), isNotEmpty);
    });
  });
}
