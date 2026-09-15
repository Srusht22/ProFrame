import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

var _n = 0;

Stroke drawn(List<Vec2> through, {double wobble = 4}) {
  final random = math.Random(_n + 11);
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 14; i++) {
      final at = through[leg].lerp(through[leg + 1], i / 14);
      samples.add(StrokeSample(Vec2(
        at.x + (random.nextDouble() - 0.5) * wobble * 2,
        at.y + (random.nextDouble() - 0.5) * wobble * 2,
      )));
    }
  }
  samples.add(StrokeSample(through.last));
  return Stroke(id: 'stroke-${_n++}', samples: samples);
}

/// A window 105 cm by 140 cm, split by a transom, exactly as the
/// specification's example: 26.8 cm of glass over a 96.4 cm lower section.
Design twoUp() {
  final at = DateTime(2026);
  return SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.door,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 1050, 1401),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(id: 't', a: Vec2(0, 388), b: Vec2(1050, 388), widthMm: 40),
    ],
  ));
}

SectionElement lowerOf(Design design) => design.topLevelSections
    .reduce((a, b) => a.outline.top > b.outline.top ? a : b);

SectionElement upperOf(Design design) => design.topLevelSections
    .reduce((a, b) => a.outline.top < b.outline.top ? a : b);

Design opened(Design design, OpeningMechanism mechanism) => DesignEdits
    .setOpening(
  design,
  lowerOf(design).id,
  openingId: 'o',
  mechanism: mechanism,
  markGlyph: mechanism.glyph,
  markAt: lowerOf(design).outline.centroid,
);

void main() {
  setUp(() => _n = 0);

  // ------------------------------------------------------------------ units

  group('the user works in centimetres', () {
    test('a figure typed in centimetres is exact in millimetres', () {
      expect(Units.parse('105'), 1050);
      expect(Units.parse('140.1'), closeTo(1401, 1e-9));
      expect(Units.parse('40.5'), closeTo(405, 1e-9));
      expect(Units.parse('72.25'), closeTo(722.5, 1e-9));
    });

    test('nothing is rounded away on the way back out', () {
      expect(Units.format(964), '96.4');
      expect(Units.format(1401), '140.1');
      expect(Units.label(964), '96.4 cm');
      // Written to the millimetre, which is what a workshop cuts to, and
      // never to something tidier than the design actually is.
      expect(Units.format(900), '90');
      expect(Units.format(897), '89.7');
    });

    test('a whole number of centimetres is written without a tail', () {
      expect(Units.format(1050), '105');
      expect(Units.format(400), '40');
      expect(Units.label(0), '0 cm');
    });

    test('what is typed comes back as what was typed', () {
      for (final typed in ['105', '96.4', '40.5', '8', '140.1']) {
        expect(Units.format(Units.parse(typed)!), typed);
      }
      // Finer than a millimetre is kept in the geometry exactly, and
      // written to the millimetre, as a drawing quotes it.
      expect(Units.parse('72.25'), closeTo(722.5, 1e-9));
      expect(Units.format(722.5), '72.3');
    });

    test('what is not a number changes nothing', () {
      expect(Units.parse('wide'), isNull);
      expect(Units.parse(''), isNull);
    });
  });

  // ------------------------------------------- the nine completion checks

  group('every figure on the drawing is the geometry it measures', () {
    test('1 — changing an overall dimension changes the geometry', () {
      final before = twoUp();
      final after = DesignEdits.resizeFrame(before, widthMm: Units.toMm(90));

      expect(after.widthMm, closeTo(900, 0.01));
      // In proportion, so the design is still the design.
      expect(after.heightMm, closeTo(before.heightMm, 0.01));
      expect(
        after.topLevelSections.length,
        before.topLevelSections.length,
      );
    });

    test('2 — changing an internal dimension moves only what it must', () {
      final before = twoUp();
      final lower = lowerOf(before);
      final upperWas = upperOf(before).outline.top;

      final after = DesignEdits.setSectionHeight(
        before,
        lower.id,
        Units.toMm(90),
      );

      expect(lowerOf(after).heightMm, closeTo(900, 1));
      // The overall size did not change to make room, and the head stayed
      // exactly where it was: the transom is what moved.
      expect(after.heightMm, closeTo(before.heightMm, 0.01));
      expect(upperOf(after).outline.top, closeTo(upperWas, 0.5));
    });

    test('3 — changing an opening dimension changes the opening', () {
      final before = opened(twoUp(), OpeningMechanism.hingedLeft);
      final opening = before.openings.single;
      final was = before.sectionById(opening.sectionId)!.heightMm;

      final after = DesignEdits.setSectionHeight(
        before,
        opening.sectionId,
        was - 200,
      );

      final now = after.sectionById(after.openings.single.sectionId)!;
      expect(now.heightMm, closeTo(was - 200, 1));
      expect(after.openings, hasLength(1),
          reason: 'resizing an opening does not cancel it');
    });

    test('4 — a < inside a section makes that section the opening', () {
      final before = twoUp();
      final after = opened(before, OpeningMechanism.hingedRight);

      expect(after.openings, hasLength(1));
      expect(after.openings.single.sectionId, lowerOf(before).id);
      expect(after.openings.single.mechanism.hingeEdge, OpeningEdge.right);
      expect(after.openings.single.markGlyph, '<');
    });

    test('5 — a > makes the opening the other way round', () {
      final after = opened(twoUp(), OpeningMechanism.hingedLeft);

      expect(after.openings.single.mechanism.hingeEdge, OpeningEdge.left);
      expect(after.openings.single.markGlyph, '>');

      final section = after.sectionById(after.openings.single.sectionId)!;
      for (final hinge in after.hardware) {
        if (hinge.kind != HardwareKind.hinge) continue;
        expect(hinge.at.x, closeTo(section.outline.left, 0.5));
      }
    });

    test('6 — lines inside an opening stay inside it', () {
      final design = fixedOverOpening();

      final opening = design.sectionById(design.openings.single.sectionId)!;
      expect(design.topLevelSections, hasLength(2));
      expect(design.childDividersOf(opening.id), hasLength(2));
      expect(design.childSectionsOf(opening.id), hasLength(3));
    });

    test('7 — an opening carries hinges and a handle', () {
      final design = opened(twoUp(), OpeningMechanism.hingedLeft);
      final opening = design.openings.single;

      final mine = [
        for (final piece in design.hardware)
          if (piece.parentId == opening.sectionId) piece,
      ];
      expect(mine.where((p) => p.kind == HardwareKind.hinge), isNotEmpty);
      expect(mine.where((p) => p.kind == HardwareKind.handle), hasLength(1));
      for (final piece in mine) {
        expect(piece.isOpeningHardware, isTrue);
      }
    });

    test('8 — 100 cm becomes 90 cm, in the model and not just the label', () {
      var design = twoUp();
      design = DesignEdits.setSectionHeight(
        design,
        lowerOf(design).id,
        Units.toMm(100),
      );
      expect(Units.format(lowerOf(design).heightMm), '100');

      design = DesignEdits.setSectionHeight(
        design,
        lowerOf(design).id,
        Units.toMm(90),
      );

      // The figure and the geometry are the same thing, so both moved.
      expect(lowerOf(design).heightMm, closeTo(900, 1));
      expect(Units.format(lowerOf(design).heightMm), '90');
    });

    test('9 — the design read back is the design that was typed', () {
      var design = twoUp();
      design = DesignEdits.resizeFrame(design, widthMm: Units.toMm(105));
      design = DesignEdits.resizeFrame(design, heightMm: Units.toMm(140));

      expect(Units.format(design.widthMm), '105');
      expect(Units.format(design.heightMm), '140');

      final again = Design.fromJson(design.toJson());
      expect(Units.format(again.widthMm), '105');
      expect(Units.format(again.heightMm), '140');
    });
  });

  // -------------------------------------------------------------- hardware

  group('the ironmongery belongs to the opening', () {
    test('a section nobody marked carries none of it', () {
      final design = opened(twoUp(), OpeningMechanism.hingedLeft);
      final fixed = upperOf(design);

      for (final piece in design.hardware) {
        expect(piece.parentId, isNot(fixed.id));
      }
    });

    test('a design with no opening at all carries none of it', () {
      final design = twoUp();
      expect(design.openings, isEmpty);
      expect(design.hardware, isEmpty);
    });

    test('nothing but hinges and a handle is added', () {
      final design = opened(twoUp(), OpeningMechanism.hingedLeft);
      final kinds = {
        for (final piece in design.hardware)
          if (piece.isOpeningHardware) piece.kind,
      };
      expect(kinds, {HardwareKind.hinge, HardwareKind.handle});
    });

    test('the hinges change sides when the direction changes', () {
      final left = opened(twoUp(), OpeningMechanism.hingedLeft);
      final section = left.sectionById(left.openings.single.sectionId)!;

      final right = DesignEdits.setOpeningMechanism(
        left,
        left.openings.single.id,
        OpeningMechanism.hingedRight,
      );

      double hingeX(Design design) => design.hardware
          .firstWhere((p) => p.kind == HardwareKind.hinge)
          .at
          .x;
      double handleX(Design design) => design.hardware
          .firstWhere((p) => p.kind == HardwareKind.handle)
          .at
          .x;

      expect(hingeX(left), closeTo(section.outline.left, 0.5));
      expect(hingeX(right), closeTo(section.outline.right, 0.5));
      // And the handle is always on the stile that moves.
      expect(handleX(left), closeTo(section.outline.right, 0.5));
      expect(handleX(right), closeTo(section.outline.left, 0.5));
    });

    test('the handle goes where a hand falls, and stays on the leaf', () {
      var tall = opened(twoUp(), OpeningMechanism.hingedLeft);
      tall = DesignEdits.resizeFrame(tall, heightMm: 2200);
      final leaf = tall.sectionById(tall.openings.single.sectionId)!;
      final handle =
          tall.hardware.firstWhere((p) => p.kind == HardwareKind.handle);

      // A metre up on a leaf with room for it.
      expect(leaf.heightMm, greaterThan(1150));
      expect(handle.at.y, closeTo(leaf.outline.bottom - 1000, 0.5));

      // On a short sash, the middle of the stile instead of jammed into the
      // top corner.
      final short = DesignEdits.setSectionHeight(
        tall,
        tall.openings.single.sectionId,
        900,
      );
      final small = short.sectionById(short.openings.single.sectionId)!;
      final low =
          short.hardware.firstWhere((p) => p.kind == HardwareKind.handle);
      expect(low.at.y, closeTo(small.outline.centroid.y, 1));
    });

    test('the handle stays on the leaf when the leaf is resized', () {
      final before = opened(twoUp(), OpeningMechanism.hingedLeft);
      final opening = before.openings.single;

      final after = DesignEdits.setSectionHeight(
        before,
        opening.sectionId,
        before.sectionById(opening.sectionId)!.heightMm - 150,
      );

      final section = after.sectionById(after.openings.single.sectionId)!;
      final handle =
          after.hardware.firstWhere((p) => p.kind == HardwareKind.handle);
      expect(handle.at.x, closeTo(section.outline.right, 0.5));
      expect(handle.at.y, greaterThanOrEqualTo(section.outline.top - 0.5));
      expect(handle.at.y, lessThanOrEqualTo(section.outline.bottom + 0.5));
    });

    test('the user can say how many hinges, and where', () {
      final before = opened(twoUp(), OpeningMechanism.hingedLeft);
      final opening = before.openings.single;
      final section = before.sectionById(opening.sectionId)!;

      final after = DesignEdits.setOpeningHardware(
        before,
        opening.id,
        hingeCount: 2,
        hingeFromStartMm: Units.toMm(20),
        hingeFromEndMm: Units.toMm(20),
      );

      final hinges = [
        for (final piece in after.hardware)
          if (piece.kind == HardwareKind.hinge) piece,
      ]..sort((a, b) => a.at.y.compareTo(b.at.y));

      expect(hinges, hasLength(2));
      expect(hinges.first.at.y, closeTo(section.outline.top + 200, 0.5));
      expect(hinges.last.at.y, closeTo(section.outline.bottom - 200, 0.5));
    });

    test('the user can say how high the handle is', () {
      final before = opened(twoUp(), OpeningMechanism.hingedLeft);
      final opening = before.openings.single;
      final section = before.sectionById(opening.sectionId)!;

      final after = DesignEdits.setOpeningHardware(
        before,
        opening.id,
        handleAlongMm: Units.toMm(40),
      );

      final handle =
          after.hardware.firstWhere((p) => p.kind == HardwareKind.handle);
      expect(handle.at.y, closeTo(section.outline.bottom - 400, 0.5));
    });

    test('the figures the user gave survive saving and loading', () {
      var design = opened(twoUp(), OpeningMechanism.hingedLeft);
      design = DesignEdits.setOpeningHardware(
        design,
        design.openings.single.id,
        hingeCount: 2,
        handleAlongMm: 850,
      );

      final again = Design.fromJson(design.toJson());
      expect(again.openings.single.hingeCount, 2);
      expect(again.openings.single.handleAlongMm, closeTo(850, 1e-9));
      expect(
        [for (final p in again.hardware) p.id],
        [for (final p in design.hardware) p.id],
      );
    });

    test('an opening that is cancelled takes its ironmongery with it', () {
      final opened_ = opened(twoUp(), OpeningMechanism.hingedLeft);
      expect(opened_.hardware, isNotEmpty);

      final shut = DesignEdits.setOpeningMechanism(
        opened_,
        opened_.openings.single.id,
        OpeningMechanism.fixed,
      );

      expect(shut.openings, isEmpty);
      expect(shut.hardware, isEmpty);
    });

    test('hardware the user placed themselves is never touched', () {
      var design = twoUp();
      design = design.copyWith(hardware: [
        const HardwareElement(
          id: 'mine',
          kind: HardwareKind.letterplate,
          at: Vec2(500, 900),
        ),
      ]);
      design = opened(design, OpeningMechanism.hingedLeft);

      final mine = design.hardware.firstWhere((p) => p.id == 'mine');
      expect(mine.at, const Vec2(500, 900));
      expect(mine.isOpeningHardware, isFalse);
      expect(OpeningHardware.placedByHand(design), hasLength(1));
    });

    test('the ironmongery swings with the leaf, not with the frame', () {
      final design = opened(twoUp(), OpeningMechanism.hingedLeft);

      double frontOf(double openFraction) {
        var front = -1e9;
        for (final facet
            in MeshBuilder.build(design, openFraction: openFraction).facets) {
          if (facet.elementId.contains('handle') != true) continue;
          for (final corner in facet.corners) {
            if (corner.z > front) front = corner.z;
          }
        }
        return front;
      }

      final shut = frontOf(0);
      final ajar = frontOf(0.4);
      expect(ajar, greaterThan(shut + 50),
          reason: 'the handle comes away from the frame with the leaf');
    });
  });
}

/// The specification's containment example, read from a drawing.
Design fixedOverOpening() {
  final at = DateTime(2026);
  final design = Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    sketch: Sketch(strokes: [
      drawn(const [
        Vec2(0, 0),
        Vec2(1600, 0),
        Vec2(1600, 2400),
        Vec2(0, 2400),
        Vec2(0, 0),
      ]),
      drawn(const [Vec2(0, 620), Vec2(1600, 620)]),
      drawn(const [Vec2(400, 900), Vec2(560, 1000), Vec2(400, 1100)]),
      drawn(const [Vec2(0, 1350), Vec2(1600, 1350)]),
      drawn(const [Vec2(0, 1900), Vec2(1600, 1900)]),
    ]),
  );
  return SketchInterpreter.interpret(design).design;
}
