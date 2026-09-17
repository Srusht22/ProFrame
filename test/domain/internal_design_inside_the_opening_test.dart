import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The phase's own example.
//
//   Overall window   200 cm x 160 cm of daylight
//   The opening       40 cm x 160 cm, the left light, marked `<`
//   Inside it         a horizontal line 40 cm down
//
//   ┌──────────┐
//   │  GLASS   │   40 cm
//   ├──────────┤
//   │          │
//   │  PANEL   │  the rest
//   │          │
//   └──────────┘
//
// The line is inside the opening, so it is the opening's: it divides the
// sash, not the window, and the window itself is not an opening.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

/// The window as geometry, with a mullion putting a 40 cm light down the left.
Design window() {
  final at = DateTime(2026);
  return SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 2100, 1700),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(
          id: 'mull', a: Vec2(470, 0), b: Vec2(470, 1700), widthMm: 40),
    ],
  ));
}

SectionElement leftLight(Design design) => design.topLevelSections
    .reduce((a, b) => a.outline.left < b.outline.left ? a : b);

SectionElement rightLight(Design design) => design.topLevelSections
    .reduce((a, b) => a.outline.left > b.outline.left ? a : b);

/// The left light marked `<`.
Design marked(Design design) {
  final light = leftLight(design);
  return DesignEdits.setOpening(
    design,
    light.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedRight,
    markGlyph: '<',
    markAt: light.outline.centroid,
  );
}

/// The horizontal line the user draws inside the opening, 40 cm down it.
Design divided(Design design, {double downMm = 400}) {
  final openingId = design.openings.single.sectionId;
  final box = design.sectionById(openingId)!.outline;
  return DesignEdits.addLineInside(
    design,
    openingId,
    id: 'inner',
    at: Vec2(box.centroid.x, box.top + downMm),
    horizontal: true,
  );
}

/// Glass in the upper pane, a solid panel in the lower one, as the user says.
Design glassOverPanel(Design design) {
  final openingId = design.openings.single.sectionId;
  return design.withElement(lower(design, openingId).copyWith(finish: _panel));
}

SectionElement upper(Design design, String openingId) => design
    .childSectionsOf(openingId)
    .reduce((a, b) => a.outline.top < b.outline.top ? a : b);

SectionElement lower(Design design, String openingId) => design
    .childSectionsOf(openingId)
    .reduce((a, b) => a.outline.top > b.outline.top ? a : b);

/// The design as the phase's example leaves it.
Design example() => glassOverPanel(divided(marked(window())));

Stroke straight(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// The same window, drawn rather than built, so it can be read again.
Design drawnWindow() {
  final at = DateTime(2026);
  return SketchInterpreter.interpret(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    sketch: Sketch(strokes: [
      straight('s-frame', const [
        Vec2(0, 0),
        Vec2(2100, 0),
        Vec2(2100, 1700),
        Vec2(0, 1700),
        Vec2(0, 0),
      ]),
      straight('s-mull', const [Vec2(470, 0), Vec2(470, 1700)]),
      straight('s-mark', const [
        Vec2(300, 700),
        Vec2(180, 850),
        Vec2(300, 1000),
      ]),
    ]),
  )).design;
}

void main() {
  group('the opening gets its own internal design', () {
    test('the line inside makes glass over panel, in the opening', () {
      final design = example();
      final openingId = design.openings.single.sectionId;

      // Opening
      // ├── Glass section
      // ├── Internal divider
      // └── Panel section
      final bar = design.childDividersOf(openingId).single;
      final panes = design.childSectionsOf(openingId);
      expect(panes, hasLength(2));
      expect(bar.parentId, openingId);
      for (final pane in panes) {
        expect(pane.parentId, openingId);
      }

      final glass = upper(design, openingId);
      final panel = lower(design, openingId);
      expect(glass.finish.material.isGlazing, isTrue);
      expect(panel.finish.material, MaterialKind.panel);

      // Glass above and panel below, both the full width of the sash.
      final opening = design.sectionById(openingId)!;
      expect(Units.format(opening.widthMm), '40');
      expect(Units.format(opening.heightMm), '160');
      expect(Units.format(glass.widthMm), '40');
      expect(Units.format(panel.widthMm), '40');

      // The line is 40 cm down the opening, where the user put it. The bar
      // there is real material, so it takes its own width out of the two
      // panes rather than being a drawn line between them: the glass above
      // is 40 cm less half the bar, and the three add up to the sash.
      expect(bar.segment.midpoint.y - opening.outline.top, closeTo(400, 0.01));
      expect(glass.heightMm, closeTo(400 - bar.widthMm / 2, 0.01));
      expect(
        glass.heightMm + bar.widthMm + panel.heightMm,
        closeTo(opening.heightMm, 0.01),
      );
    });

    test('typing 40 into the glass gives exactly 40 cm of glass', () {
      var design = example();
      final openingId = design.openings.single.sectionId;
      final glassId = upper(design, openingId).id;

      design = DesignEdits.setSectionHeight(design, glassId, 400);

      final glass = design.sectionById(glassId)!;
      final panel = lower(design, openingId);
      final bar = design.childDividersOf(openingId).single;
      final opening = design.sectionById(openingId)!;

      expect(Units.format(glass.heightMm), '40');
      expect(glass.finish.material.isGlazing, isTrue);
      expect(panel.finish.material, MaterialKind.panel);
      // The panel is the rest of the sash, and the sash did not change size.
      expect(
        glass.heightMm + bar.widthMm + panel.heightMm,
        closeTo(opening.heightMm, 0.01),
      );
      expect(Units.format(opening.heightMm), '160');
    });

    test('the window itself is not an opening, and nothing outside moved', () {
      final before = marked(window());
      final wasRight = rightLight(before).outline.corners.toString();
      final wasFrame = before.frame!.outline.corners.toString();
      final wasTop = before.topLevelSections.length;

      final design = example();

      expect(design.openings, hasLength(1));
      expect(design.openings.single.sectionId, leftLight(design).id);
      // The line inside the opening made no new main division.
      expect(design.topLevelSections, hasLength(wasTop));
      expect(design.topLevelDividers, hasLength(1));
      expect(rightLight(design).outline.corners.toString(), wasRight);
      expect(design.frame!.outline.corners.toString(), wasFrame);
      // The fixed light beside it has no opening and no children.
      expect(design.openingOf(rightLight(design).id), isNull);
      expect(design.childSectionsOf(rightLight(design).id), isEmpty);
    });

    test('the internal bar is the opening’s, not the design’s', () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final bar = design.childDividersOf(openingId).single;

      expect(design.topLevelDividers.map((d) => d.id), ['mull']);
      expect(design.sectionById(openingId)!.outline.holds(bar.segment),
          isTrue);
      // And the mullion, which is the design's, is not the opening's.
      expect(design.childDividersOf(openingId).map((d) => d.id), ['inner']);
    });
  });

  group('the internal design stays inside the opening', () {
    test('the opening moves, and its glass, panel and bar move with it', () {
      var design = example();
      final openingId = design.openings.single.sectionId;
      final was = design.sectionById(openingId)!.outline;
      final wasBar = design.childDividersOf(openingId).single;
      final downTheOpening = (wasBar.a.y - was.top) / was.height;

      // The mullion moves right, so the left light — the opening — widens.
      design = DesignEdits.moveDividerAcross(design, 'mull', const Vec2(870, 0));

      final now = design.sectionById(openingId)!.outline;
      expect(now.width, greaterThan(was.width));

      final bar = design.childDividersOf(openingId).single;
      expect(bar.id, wasBar.id);
      expect(bar.parentId, openingId);
      expect(now.holds(bar.segment), isTrue);
      // It is still the same distance down the sash, and still runs across it.
      expect((bar.a.y - now.top) / now.height, closeTo(downTheOpening, 0.001));
      expect(bar.a.x, closeTo(now.left, 0.5));
      expect(bar.b.x, closeTo(now.right, 0.5));

      // And the panes are still glass over panel.
      expect(upper(design, openingId).finish.material.isGlazing, isTrue);
      expect(lower(design, openingId).finish.material, MaterialKind.panel);
    });

    test('the opening is resized, and the bar stays inside it', () {
      var design = example();
      final openingId = design.openings.single.sectionId;

      design = DesignEdits.setSectionWidth(design, openingId, 700);
      final now = design.sectionById(openingId)!.outline;
      expect(Units.format(now.width), '70');

      final bar = design.childDividersOf(openingId).single;
      expect(bar.parentId, openingId);
      expect(now.holds(bar.segment), isTrue);
      expect(design.childSectionsOf(openingId), hasLength(2));
      expect(lower(design, openingId).finish.material, MaterialKind.panel);
    });

    test('typing the glass height moves the internal bar and only that', () {
      var design = example();
      final openingId = design.openings.single.sectionId;
      final wasOpening = design.sectionById(openingId)!.outline;
      final wasRight = rightLight(design).outline.corners.toString();
      final glassId = upper(design, openingId).id;

      design = DesignEdits.setSectionHeight(design, glassId, 600);

      expect(Units.format(design.sectionById(glassId)!.heightMm), '60');
      // The opening itself did not change size, and neither did the window.
      expect(design.sectionById(openingId)!.outline.corners.toString(),
          wasOpening.corners.toString());
      expect(rightLight(design).outline.corners.toString(), wasRight);
      expect(lower(design, openingId).finish.material, MaterialKind.panel);
    });
  });

  group('reading the sheet again leaves the internal design alone', () {
    test('a line drawn inside the opening survives a re-reading', () {
      var design = drawnWindow();
      expect(design.openings, hasLength(1));

      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      design = DesignEdits.addLineInside(
        design,
        openingId,
        id: 'inner',
        at: Vec2(box.centroid.x, box.top + 400),
        horizontal: true,
      );
      design = design.withElement(
          lower(design, openingId).copyWith(finish: _panel));
      expect(design.childSectionsOf(openingId), hasLength(2));

      // The user draws one more line on the sheet — a transom in the fixed
      // light — and the drawing is read again.
      design = design.copyWith(
        sketch: design.sketch
            .add(straight('s-transom', const [Vec2(470, 900), Vec2(2100, 900)])),
      );
      design = SketchInterpreter.interpret(design).design;

      // The new line divided the design, as every drawn line does.
      expect(design.topLevelDividers, hasLength(2));

      // The opening kept its own line, its two panes, and their materials.
      final now = design.openings.single.sectionId;
      expect(design.sectionById(now)!.outline.width, closeTo(box.width, 0.01));
      expect(design.sectionById(now)!.outline.height, closeTo(box.height, 0.01));
      final bar = design.childDividersOf(now).single;
      expect(bar.id, 'inner');
      expect(bar.fromStrokeId, isNull);
      expect(design.childSectionsOf(now), hasLength(2));
      expect(upper(design, now).finish.material.isGlazing, isTrue);
      expect(lower(design, now).finish.material, MaterialKind.panel);
    });

    test('reading again twice over changes nothing further', () {
      var design = drawnWindow();
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      design = DesignEdits.addLineInside(design, openingId,
          id: 'inner',
          at: Vec2(box.centroid.x, box.top + 400),
          horizontal: true);

      final once = SketchInterpreter.interpret(design).design;
      final twice = SketchInterpreter.interpret(once).design;

      expect(twice.dividers.length, once.dividers.length);
      expect(twice.sections.length, once.sections.length);
      expect(twice.dividers.map((d) => d.id).toSet(),
          once.dividers.map((d) => d.id).toSet());
    });

    test('a bar made inside the design is never given a stroke’s id', () {
      var design = drawnWindow();
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      design = DesignEdits.addLineInside(design, openingId,
          id: 'divider-d-0',
          at: Vec2(box.centroid.x, box.top + 400),
          horizontal: true);

      design = SketchInterpreter.interpret(design).design;
      final ids = design.dividers.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(design.childDividersOf(design.openings.single.sectionId),
          hasLength(1));
    });
  });

  group('the model and the solid follow the hierarchy', () {
    test('saving and reloading keeps the opening’s internal design', () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final back = Design.fromJson(design.toJson());

      expect(back.childDividersOf(openingId).single.id, 'inner');
      expect(back.childSectionsOf(openingId), hasLength(2));
      expect(upper(back, openingId).finish.material.isGlazing, isTrue);
      expect(lower(back, openingId).finish.material, MaterialKind.panel);
      expect(back.topLevelDividers.map((d) => d.id), ['mull']);
    });

    test('the solid has glass above, a panel below and a bar between', () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final glass = upper(design, openingId);
      final panel = lower(design, openingId);
      final mesh = MeshBuilder.build(design);

      bool anyIn(Polygon box, FacetRole role) => mesh.facets.any((facet) =>
          facet.role == role &&
          box.contains(Vec2(facet.centre.x, facet.centre.y)));

      expect(anyIn(glass.outline, FacetRole.glazing), isTrue);
      expect(anyIn(panel.outline, FacetRole.panel), isTrue);
      expect(anyIn(glass.outline, FacetRole.panel), isFalse);
      expect(anyIn(panel.outline, FacetRole.glazing), isFalse);

      // The bar between them is real material in the solid, not a drawn line.
      final bar = design.childDividersOf(openingId).single;
      final between = Polygon.rect(
        bar.segment.midpoint.x - 10,
        bar.segment.midpoint.y - bar.widthMm / 4,
        bar.segment.midpoint.x + 10,
        bar.segment.midpoint.y + bar.widthMm / 4,
      );
      expect(anyIn(between, FacetRole.bar) || anyIn(between, FacetRole.sash),
          isTrue);
    });
  });
}
