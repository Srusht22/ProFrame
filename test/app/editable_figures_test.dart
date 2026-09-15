import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/dimension_handles.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sections/section_builder.dart';

/// The specification's window: 105 cm by 140.1 cm, split by a transom.
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

ViewTransform viewOf(Design design) => ViewTransform.fit(
      design.bounds,
      const Size(1000, 800),
      marginFraction: 0.06,
      padding: const EdgeInsets.only(
        left: 118,
        right: 70,
        top: 20,
        bottom: 150,
      ),
    );

List<DimensionHandle> figuresOf(Design design) =>
    CadDimensions.of(design, viewOf(design), const CadLayers());

void main() {
  group('every figure on the drawing can be typed over', () {
    test('the overall width and height are both there', () {
      final design = twoUp();
      final kinds = {for (final f in figuresOf(design)) f.of};

      expect(kinds, contains(DimensionOf.overallWidth));
      expect(kinds, contains(DimensionOf.overallHeight));
    });

    test('every pane offers its own width and its own height', () {
      final design = twoUp();
      final figures = figuresOf(design);

      for (final section in design.sections) {
        final mine = [
          for (final f in figures)
            if (f.elementId == section.id) f.of,
        ];
        expect(mine, contains(DimensionOf.sectionWidth));
        expect(mine, contains(DimensionOf.sectionHeight));
      }
    });

    test('a measurement the user drew is one of them too', () {
      final design = twoUp().copyWith(dimensions: const [
        DimensionElement(id: 'dim', a: Vec2(0, 1401), b: Vec2(1050, 1401)),
      ]);

      expect(
        [for (final f in figuresOf(design)) f.of],
        contains(DimensionOf.drawn),
      );
    });

    test('a figure reads exactly what the geometry is', () {
      final design = twoUp();
      for (final figure in figuresOf(design)) {
        final actual = switch (figure.of) {
          DimensionOf.overallWidth => design.widthMm,
          DimensionOf.overallHeight => design.heightMm,
          DimensionOf.sectionWidth =>
            design.sectionById(figure.elementId!)!.widthMm,
          DimensionOf.sectionHeight =>
            design.sectionById(figure.elementId!)!.heightMm,
          DimensionOf.drawn => figure.valueMm,
        };
        // A daylight chain measures the pane it names, so either way the
        // figure and the geometry are the same number.
        expect(figure.valueMm, closeTo(actual, 0.5),
            reason: '${figure.label} must be the geometry, not a caption');
      }
    });

    test('a figure is tappable where it is written', () {
      final design = twoUp();
      final figures = figuresOf(design);

      for (final figure in figures) {
        expect(CadDimensions.at(figures, figure.rect.center), isNotNull);
      }
      expect(CadDimensions.at(figures, const Offset(-500, -500)), isNull);
    });

    test('with the dimension layer off there is nothing to tap', () {
      final design = twoUp();
      final figures = CadDimensions.of(
        design,
        viewOf(design),
        const CadLayers(dimensions: false),
      );
      expect(figures, isEmpty);
    });

    test('a section with children is not labelled over its own panes', () {
      var design = twoUp();
      final lower = design.topLevelSections
          .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
      design = SectionBuilder.rebuild(design.copyWith(dividers: [
        ...design.dividers,
        DividerElement(
          id: 'inner',
          a: Vec2(0, 900),
          b: Vec2(1050, 900),
          widthMm: 30,
          parentId: lower.id,
        ),
      ]));

      final named = {
        for (final f in figuresOf(design))
          if (f.of == DimensionOf.sectionWidth) f.elementId,
      };
      // The parent's own size label would print over its children's.
      expect(design.hasChildren(lower.id), isTrue);
      expect(named, isNot(contains(lower.id)));
    });
  });

  group('typing over a figure moves the geometry', () {
    test('the width the user types is the width the design becomes', () {
      final before = twoUp();
      final figure = figuresOf(before)
          .firstWhere((f) => f.of == DimensionOf.overallWidth);

      expect(Units.format(figure.valueMm), '105');
      final after =
          DesignEdits.resizeFrame(before, widthMm: Units.parse('90')!);

      expect(Units.format(after.widthMm), '90');
      expect(
        figuresOf(after)
            .firstWhere((f) => f.of == DimensionOf.overallWidth)
            .valueMm,
        closeTo(900, 0.5),
      );
    });

    test('a pane figure and the pane never disagree', () {
      var design = twoUp();
      final lower = design.topLevelSections
          .reduce((a, b) => a.outline.top > b.outline.top ? a : b);

      design = DesignEdits.setSectionHeight(
        design,
        lower.id,
        Units.parse('90')!,
      );

      final figure = figuresOf(design).firstWhere(
        (f) => f.elementId == lower.id && f.of == DimensionOf.sectionHeight,
      );
      expect(figure.valueMm, closeTo(design.sectionById(lower.id)!.heightMm, 0.01));
      expect(Units.format(figure.valueMm), '90');
    });
  });
}
