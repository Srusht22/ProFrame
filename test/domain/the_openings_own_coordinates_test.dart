import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/local_space.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sections/section_builder.dart';

// The phase's own example:
//
//   Opening        x 40 cm, y 20 cm, 40 x 160 cm
//   Internal bar   40 cm down THIS OPENING — not 40 cm down the window
//
// A line drawn inside the opening is the opening's: not a root-level bar,
// not a new main division, not a line above or outside it. And where it is
// is said in the opening's own terms, so it means the same thing wherever
// the opening is.

/// A window with a mullion putting a 40 cm light down the left.
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

Design marked(Design design) => DesignEdits.setOpening(
      design,
      leftLight(design).id,
      openingId: 'o',
      mechanism: OpeningMechanism.hingedRight,
      markGlyph: '<',
      markAt: leftLight(design).outline.centroid,
    );

/// The user draws a horizontal line 40 cm down the opening.
Design divided(Design design, {double downMm = 400}) {
  final openingId = design.openings.single.sectionId;
  final box = design.sectionById(openingId)!.outline;
  return DesignEdits.addLineInside(
    design,
    openingId,
    id: 'internal-line',
    at: Vec2(box.centroid.x, box.top + downMm),
    horizontal: true,
  );
}

Design example() => divided(marked(window()));

double alongOf(Design design, String barId) =>
    DesignEdits.alongWithin(design, design.dividerById(barId))!;

void main() {
  group('a line drawn inside the opening is the opening’s', () {
    test('it is not a root-level bar', () {
      final design = example();
      final openingId = design.openings.single.sectionId;

      expect(design.dividerById('internal-line')!.parentId, openingId);
      expect(design.topLevelDividers.map((d) => d.id), ['mull']);
      expect(DesignTree.of(design).barIds, ['mull']);
      expect(DesignTree.of(design).openings.single.barIds,
          ['internal-line']);
    });

    test('it makes no new main division', () {
      final before = marked(window());
      final after = example();

      expect(after.topLevelSections, hasLength(before.topLevelSections.length));
      expect(after.topLevelSections, hasLength(2));
      for (final section in after.topLevelSections) {
        expect(section.parentId, isNull);
      }
    });

    test('it is inside the opening, not above it or outside it', () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      final bar = design.dividerById('internal-line')!;

      expect(box.holds(bar.segment, reach: bar.widthMm), isTrue);
      expect(bar.segment.midpoint.y, greaterThan(box.top));
      expect(bar.segment.midpoint.y, lessThan(box.bottom));
      // It runs right across the opening and no further.
      expect(bar.a.x, closeTo(box.left, 1));
      expect(bar.b.x, closeTo(box.right, 1));
      expect(rightLight(design).outline.holds(bar.segment), isFalse);
    });

    test('the hierarchy is opening → line, glass, panel', () {
      final design = example();
      final branch = DesignTree.of(design).openings.single;

      expect(branch.barIds, ['internal-line']);
      expect(branch.panes, hasLength(2));
      for (final pane in branch.panes) {
        expect(design.sectionById(pane.sectionId)!.parentId,
            branch.sectionId);
      }
      // And not: design → opening, global bar, panel.
      expect(DesignTree.of(design).sections, hasLength(2));
    });
  });

  group('said in the opening’s own terms', () {
    test('40 cm down the opening, not 40 cm down the window', () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      final bar = design.dividerById('internal-line')!;

      expect(Units.format(alongOf(design, 'internal-line')), '40');

      // Down the window it is somewhere else entirely, because the opening
      // does not start at the top of the window.
      final downTheWindow = bar.segment.midpoint.y -
          design.frame!.innerOutline.top;
      expect(downTheWindow, closeTo(400 + (box.top -
          design.frame!.innerOutline.top), 1));
    });

    test('the figure holds when the opening moves to another section', () {
      final before = example();
      final was = alongOf(before, 'internal-line');
      final after = DesignEdits.moveOpeningToSection(
        before,
        'o',
        rightLight(before).id,
      );

      final box = after.sectionById(after.openings.single.sectionId)!.outline;
      expect(box.width, greaterThan(1000), reason: 'a different-sized section');
      expect(alongOf(after, 'internal-line'), closeTo(was, 0.01));
      expect(Units.format(alongOf(after, 'internal-line')), '40');
    });

    test('the figure holds when the opening is made wider', () {
      final before = example();
      final was = alongOf(before, 'internal-line');
      final after = DesignEdits.moveDivider(before, 'mull', const Vec2(300, 0));

      final openingId = after.openings.single.sectionId;
      expect(after.sectionById(openingId)!.outline.width,
          greaterThan(before.sectionById(openingId)!.outline.width + 200));
      expect(alongOf(after, 'internal-line'), closeTo(was, 0.01));
    });

    test('typing the figure moves the bar and nothing else', () {
      final before = example();
      final openingId = before.openings.single.sectionId;
      final box = before.sectionById(openingId)!.outline;
      final fixed = rightLight(before).outline;

      final after =
          DesignEdits.moveDividerWithin(before, 'internal-line', 900);

      expect(Units.format(alongOf(after, 'internal-line')), '90');
      expect(after.sectionById(openingId)!.outline, box);
      expect(rightLight(after).outline, fixed);
      expect(after.topLevelDividers.map((d) => d.id), ['mull']);
    });

    test('a pane’s corner is given in the opening’s terms too', () {
      final design = example();
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      final panes = design.childSectionsOf(openingId)
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

      expect(LocalSpace.of(box, panes.first.outline.topLeft),
          const Vec2(0, 0));
      final lower = LocalSpace.of(box, panes.last.outline.topLeft);
      expect(lower.x, closeTo(0, 1));
      expect(lower.y, greaterThan(400));
    });
  });

  group('every bar has a place in its parent, at any angle', () {
    test('a bar up the opening is measured across it', () {
      var design = marked(window());
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;
      design = DesignEdits.addLineInside(
        design,
        openingId,
        id: 'upright',
        at: Vec2(box.left + 150, box.centroid.y),
        horizontal: false,
      );

      expect(Units.format(alongOf(design, 'upright')), '15');
      design = DesignEdits.moveDividerWithin(design, 'upright', 250);
      expect(Units.format(alongOf(design, 'upright')), '25');
    });

    test('a diagonal is measured square to itself, and can be typed over',
        () {
      var design = marked(window());
      final openingId = design.openings.single.sectionId;
      final box = design.sectionById(openingId)!.outline;

      design = SectionBuilder.rebuild(design.copyWith(dividers: [
        ...design.dividers,
        DividerElement(
          id: 'diagonal',
          a: Vec2(box.left + 20, box.top + 900),
          b: Vec2(box.right - 20, box.top + 1200),
          widthMm: 28,
          parentId: openingId,
        ),
      ]));

      final was = alongOf(design, 'diagonal');
      expect(was, greaterThan(0));
      expect(DesignEdits.reachWithin(design, design.dividerById('diagonal')),
          greaterThan(was));

      // Before this phase the figure on a diagonal's panel did nothing.
      final moved =
          DesignEdits.moveDividerWithin(design, 'diagonal', was + 200);
      expect(alongOf(moved, 'diagonal'), closeTo(was + 200, 0.5));

      // It moved square to itself, so its angle is untouched.
      final before = design.dividerById('diagonal')!.segment;
      final after = moved.dividerById('diagonal')!.segment;
      expect(after.unit.x, closeTo(before.unit.x, 1e-9));
      expect(after.unit.y, closeTo(before.unit.y, 1e-9));
      expect(after.length, closeTo(before.length, 1e-9));
      expect(moved.dividerById('diagonal')!.parentId, openingId);
    });

    test('a figure typed past the far side puts it on the far side', () {
      final design = example();
      final reach =
          DesignEdits.reachWithin(design, design.dividerById('internal-line'))!;

      final far =
          DesignEdits.moveDividerWithin(design, 'internal-line', reach + 5000);
      expect(alongOf(far, 'internal-line'), closeTo(reach, 0.01));

      final near = DesignEdits.moveDividerWithin(design, 'internal-line', -900);
      expect(alongOf(near, 'internal-line'), closeTo(0, 0.01));
    });

    test('the measurement does not change sign with the drawing direction',
        () {
      final box = Polygon.rect(100, 200, 500, 1000);
      const across = Segment(Vec2(100, 600), Vec2(500, 600));
      const backwards = Segment(Vec2(500, 600), Vec2(100, 600));
      expect(LocalSpace.alongIn(box, across), closeTo(400, 1e-9));
      expect(LocalSpace.alongIn(box, backwards), closeTo(400, 1e-9));

      const up = Segment(Vec2(300, 200), Vec2(300, 1000));
      const down = Segment(Vec2(300, 1000), Vec2(300, 200));
      expect(LocalSpace.alongIn(box, up), closeTo(200, 1e-9));
      expect(LocalSpace.alongIn(box, down), closeTo(200, 1e-9));
    });

    test('a bar that divides the design has no figure in a parent', () {
      final design = example();
      expect(
        DesignEdits.alongWithin(design, design.dividerById('mull')),
        isNull,
      );
      expect(
        DesignEdits.moveDividerWithin(design, 'mull', 700).dividerById('mull'),
        design.dividerById('mull'),
      );
    });
  });
}
