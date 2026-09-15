import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/scale.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';

Design build({
  double width = 1000,
  double height = 2000,
  List<DividerElement> dividers = const [],
  List<HardwareElement> hardware = const [],
}) {
  final at = DateTime(2026);
  return SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, width, height),
      profileMm: 60,
    ),
    dividers: dividers,
    hardware: hardware,
  ));
}

DividerElement vertical(String id, double x, double height) =>
    DividerElement(id: id, a: Vec2(x, 0), b: Vec2(x, height), widthMm: 40);

DividerElement horizontal(String id, double y, double width) =>
    DividerElement(id: id, a: Vec2(0, y), b: Vec2(width, y), widthMm: 40);

void main() {
  group('scaling to a real size', () {
    test('a 48/52 split is still 48/52 afterwards', () {
      var design = build(dividers: [vertical('m', 480, 2000)]);
      final before = [for (final s in design.sections) s.widthMm]..sort();

      design = DesignScale.toWidth(design, 2400);

      expect(design.widthMm, closeTo(2400, 0.01));
      final after = [for (final s in design.sections) s.widthMm]..sort();
      expect(after[0] / after[1], closeTo(before[0] / before[1], 1e-9));
    });

    test('scaling never makes unequal sections equal', () {
      var design = build(dividers: [
        vertical('a', 200, 2000),
        vertical('b', 500, 2000),
      ]);
      design = DesignScale.toWidth(design, 3000);
      final widths = [for (final s in design.sections) s.widthMm.round()]
        ..sort();
      expect(widths.toSet(), hasLength(3));
    });

    test('the frame profile scales with the design', () {
      var design = build();
      design = DesignScale.toWidth(design, 2000);
      expect(design.frame!.profileMm, closeTo(120, 0.01));
    });

    test('scaling from one dimension carries the rest with it', () {
      var design = build(dividers: [vertical('m', 400, 2000)]);
      design = design.copyWith(dimensions: [
        const DimensionElement(
          id: 'dim',
          a: Vec2(0, 2000),
          b: Vec2(400, 2000),
        ),
      ]);
      final dimension = design.dimensions.single;

      design = DesignScale.toDimension(design, dimension, 800);

      expect(design.dimensions.single.measuredMm, closeTo(800, 0.01));
      expect(design.dimensions.single.statedMm, closeTo(800, 0.01));
      expect(design.widthMm, closeTo(2000, 0.01));
    });

    test('a stated size that the geometry no longer matches is reported', () {
      var design = build();
      design = design.copyWith(dimensions: [
        const DimensionElement(
          id: 'dim',
          a: Vec2(0, 0),
          b: Vec2(1000, 0),
          statedMm: 1200,
        ),
      ]);
      final conflicts = DesignScale.conflicts(design);
      expect(conflicts, hasLength(1));
      expect(conflicts.single.measuredMm, closeTo(1000, 0.01));
      expect(conflicts.single.statedMm, 1200);
    });

    test('the sketch scales with the geometry it produced', () {
      var design = build();
      design = design.copyWith(
        sketch: const Sketch(strokes: [
          Stroke(
            id: 's',
            samples: [
              StrokeSample(Vec2(0, 0)),
              StrokeSample(Vec2(1000, 2000)),
            ],
          ),
        ]),
      );
      design = DesignScale.toWidth(design, 2000);
      expect(design.sketch.strokes.single.end.x, closeTo(2000, 0.01));
      expect(design.sketch.strokes.single.end.y, closeTo(4000, 0.01));
    });
  });

  group('editing by hand', () {
    test('moving a bar moves that bar and nothing else', () {
      var design = build(dividers: [
        vertical('a', 300, 2000),
        vertical('b', 700, 2000),
      ]);
      design = DesignEdits.moveDivider(design, 'a', const Vec2(-120, 0));

      final moved = design.dividers.firstWhere((d) => d.id == 'a');
      final stayed = design.dividers.firstWhere((d) => d.id == 'b');
      expect(moved.a.x, closeTo(180, 0.01));
      expect(stayed.a.x, closeTo(700, 0.01));
      expect(design.sections, hasLength(3));
    });

    test('setting a section width moves the bar beside it', () {
      var design = build(dividers: [vertical('m', 300, 2000)]);
      final left = design.sections
          .reduce((a, b) => a.outline.left < b.outline.left ? a : b);

      design = DesignEdits.setSectionWidth(design, left.id, 500);

      final again = design.sections
          .reduce((a, b) => a.outline.left < b.outline.left ? a : b);
      expect(again.widthMm, closeTo(500, 1));
      // The frame did not move to make room.
      expect(design.frame!.widthMm, closeTo(1000, 0.01));
    });

    test('a section with no bar beside it moves the jamb, and only that', () {
      var design = build();
      final leftJamb = design.frame!.outline.left;
      final height = design.frame!.heightMm;

      design =
          DesignEdits.setSectionWidth(design, design.sections.single.id, 600);

      // The figure the user typed is the figure the pane now is.
      expect(design.sections.single.widthMm, closeTo(600, 0.5));
      // The right jamb is what moved, because it is the only thing that
      // could. Nothing else did.
      expect(design.frame!.outline.left, closeTo(leftJamb, 0.01));
      expect(design.frame!.heightMm, closeTo(height, 0.01));
    });

    test('resizing the frame keeps the bars where they were in proportion', () {
      var design = build(dividers: [vertical('m', 300, 2000)]);
      design = DesignEdits.resizeFrame(design, widthMm: 2000);

      expect(design.frame!.widthMm, closeTo(2000, 0.01));
      expect(design.dividers.single.a.x, closeTo(600, 0.01));
      // A bar is a real piece of material: it does not get wider because the
      // window did.
      expect(design.dividers.single.widthMm, closeTo(40, 0.01));
      expect(design.frame!.profileMm, closeTo(60, 0.01));
    });

    test('deleting a bar leaves one section, not a template', () {
      var design = build(dividers: [vertical('m', 300, 2000)]);
      expect(design.sections, hasLength(2));
      design = DesignEdits.delete(design, 'm');
      expect(design.dividers, isEmpty);
      expect(design.sections, hasLength(1));
    });

    test('an opening is only ever created by saying so', () {
      var design = build(dividers: [vertical('m', 300, 2000)]);
      expect(design.openings, isEmpty);

      final right = design.sections
          .reduce((a, b) => a.outline.left > b.outline.left ? a : b);
      design = DesignEdits.setOpening(
        design,
        right.id,
        openingId: 'o',
        mechanism: OpeningMechanism.hingedRight,
      );

      expect(design.openings, hasLength(1));
      expect(design.openings.single.confirmed, isTrue);
      expect(design.openings.single.mechanism, OpeningMechanism.hingedRight);
    });

    test('a handle stays exactly where it was put', () {
      var design = build(hardware: [
        const HardwareElement(
          id: 'h',
          kind: HardwareKind.lever,
          at: Vec2(880, 1150),
        ),
      ]);
      design = SectionBuilder.rebuild(design);
      expect(design.hardware.single.at.x, 880);
      expect(design.hardware.single.at.y, 1150);

      // Resizing carries it along in proportion, and nothing else appears.
      design = DesignEdits.resizeFrame(design, widthMm: 2000);
      expect(design.hardware, hasLength(1));
      expect(design.hardware.single.at.x, closeTo(1760, 0.01));
    });

    test('tapping finds the bar over the section behind it', () {
      final design = build(dividers: [vertical('m', 300, 2000)]);
      final onBar = DesignEdits.hitTest(design, const Vec2(300, 900), slopMm: 30);
      expect(onBar, isA<DividerElement>());

      final inGlass =
          DesignEdits.hitTest(design, const Vec2(700, 900), slopMm: 30);
      expect(inGlass, isA<SectionElement>());
    });

    test('dragging the frame takes the whole design with it', () {
      var design = build(dividers: [vertical('m', 300, 2000)]);
      design = DesignEdits.dragElement(design, 'f', const Vec2(100, 50));
      expect(design.frame!.outline.left, closeTo(100, 0.01));
      expect(design.dividers.single.a.x, closeTo(400, 0.01));
      expect(design.sections, hasLength(2));
    });
  });
}
