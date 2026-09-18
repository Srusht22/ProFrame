import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The phase's own figures:
//
//   Opening            x 100 cm, y 20 cm, 40 x 160 cm
//   Internal divider   parent = the opening
//                      localY = 40 cm   ── 40 cm from the top of THIS opening
//                      localWidth = 40 cm
//
// and the structure it must make:
//
//   Opening                 not:   Design
//   ├── Internal Divider           ├── Opening
//   ├── Upper Section              ├── Global Bar
//   └── Lower Section              └── Global Section

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A window with a 40 cm light standing 100 cm across it, marked `<`.
Design marked() {
  final at = DateTime(2026);
  final design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 2400, 1900),
      profileMm: 50,
    ),
    dividers: const [
      // A transom 20 cm down, so the opening below it does not start at the
      // head of the window — which is what makes the two figures differ.
      DividerElement(id: 'transom', a: Vec2(0, 200), b: Vec2(2400, 200),
          widthMm: 40),
      DividerElement(id: 'mull-a', a: Vec2(1000, 200), b: Vec2(1000, 1900),
          widthMm: 40),
      DividerElement(id: 'mull-b', a: Vec2(1440, 200), b: Vec2(1440, 1900),
          widthMm: 40),
    ],
  ));
  final sash = design.topLevelSections
      .firstWhere((s) => s.outline.contains(const Vec2(1220, 1000)));
  return DesignEdits.setOpening(
    design,
    sash.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedRight,
    markGlyph: '<',
    markAt: sash.outline.centroid,
  );
}

/// The user draws a line 40 cm down that opening.
Design example() {
  final design = marked();
  final on = design.openings.single.sectionId;
  final box = design.sectionById(on)!.outline;
  return DesignEdits.addLineInside(
    design,
    on,
    id: 'internal-divider',
    at: Vec2(box.centroid.x, box.top + 400),
    horizontal: true,
  );
}

SectionElement sashOf(Design d) =>
    d.sectionById(d.openings.single.sectionId)!;

void main() {
  group('a line inside an opening belongs to that opening', () {
    test('its parent is the opening, not the design', () {
      final design = example();
      final opening = design.openings.single;
      final bar = design.dividerById('internal-divider')!;

      expect(bar.parentId, opening.id);
      expect(design.openingHolding(bar.parentId)!.id, opening.id);
      expect(bar.parentId, isNot(design.id));
      expect(bar.parentId, isNot(design.frame!.id));
    });

    test('it is not a global bar and makes no global section', () {
      final before = marked();
      final design = example();

      expect(design.topLevelDividers.map((d) => d.id),
          ['transom', 'mull-a', 'mull-b']);
      expect(design.topLevelDividers.map((d) => d.id),
          before.topLevelDividers.map((d) => d.id));
      expect(design.topLevelSections,
          hasLength(before.topLevelSections.length));
      for (final section in design.topLevelSections) {
        expect(section.parentId, isNull);
      }
    });

    test('the structure is opening, divider, upper section, lower section',
        () {
      final design = example();
      final branch = DesignTree.of(design).openings.single;

      expect(branch.barIds, ['internal-divider']);
      expect(branch.panes, hasLength(2));

      final panes = [
        for (final pane in branch.panes) design.sectionById(pane.sectionId)!,
      ]..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      for (final pane in panes) {
        expect(pane.parentId, design.openings.single.id);
        expect(sashOf(design).outline.contains(pane.outline.centroid), isTrue);
      }
      expect(panes.first.outline.top, lessThan(panes.last.outline.top));

      // And the design's own branches are untouched by it.
      final tree = DesignTree.of(design);
      expect(tree.barIds, ['transom', 'mull-a', 'mull-b']);
      for (final fixed in tree.fixedSections) {
        expect(design.childDividersOf(fixed.sectionId), isEmpty);
      }
    });
  });

  group('its place is said in the opening’s terms', () {
    test('40 cm down THIS opening, not 40 cm down the window', () {
      final design = example();
      final along =
          DesignEdits.alongWithin(design, design.dividerById('internal-divider'));

      expect(along, isNotNull);
      expect(Units.format(along!), '40');

      // Down the window it is somewhere else entirely, and that number is
      // not what the panel shows.
      final bar = design.dividerById('internal-divider')!;
      final downTheWindow =
          bar.segment.midpoint.y - design.frame!.innerOutline.top;
      expect(downTheWindow, greaterThan(410),
          reason: 'the opening does not start at the head of the window');
      expect(Units.format(downTheWindow), isNot('40'));
    });

    test('the opening is a 40 cm light standing across the window', () {
      final design = example();
      final sash = sashOf(design);
      final daylight = design.frame!.innerOutline;

      expect(Units.format(sash.widthMm), '40');
      expect(sash.outline.left, greaterThan(daylight.left + 900));
      expect(sash.areaMmSq, lessThan(daylight.area * 0.25));
    });

    test('the divider runs the width of the opening and no further', () {
      final design = example();
      final sash = sashOf(design);
      final bar = design.dividerById('internal-divider')!;

      expect(Units.format(bar.segment.length), Units.format(sash.widthMm));
      expect(sash.outline.holds(bar.segment, reach: bar.widthMm), isTrue);
      for (final other in design.topLevelSections) {
        if (other.id == sash.id) continue;
        expect(other.outline.holds(bar.segment), isFalse);
      }
    });

    test('the figure means the same wherever the opening is put', () {
      final before = example();
      final wide = before.topLevelSections
          .reduce((a, b) => a.areaMmSq > b.areaMmSq ? a : b);
      final after = DesignEdits.moveOpeningToSection(before, 'o', wide.id);

      expect(sashOf(after).widthMm, greaterThan(sashOf(before).widthMm + 200),
          reason: 'a different-sized light');
      expect(
        Units.format(DesignEdits.alongWithin(
            after, after.dividerById('internal-divider'))!),
        '40',
      );
      expect(after.dividerById('internal-divider')!.parentId,
          after.openings.single.id);
    });
  });

  group('a line drawn on the sheet, put into the opening', () {
    // The sheet's own lines divide the design until the user says otherwise.
    // The **Divides** control is how they say otherwise, and the line must
    // end up where they drew it — not swept along by the sash growing back
    // to the size it was before that line cut it in two.
    Design drawn() {
      final at = DateTime(2026);
      return SketchInterpreter.interpret(Design(
        id: 'd',
        name: 'test',
        kind: DesignKind.window,
        createdAt: at,
        updatedAt: at,
        sketch: Sketch(strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(2400, 0),
            Vec2(2400, 1800),
            Vec2(0, 1800),
            Vec2(0, 0),
          ]),
          pen('mullion', const [Vec2(900, 0), Vec2(900, 1800)]),
          pen('mark', const [Vec2(380, 830), Vec2(500, 900), Vec2(380, 970)]),
          pen('inner', const [Vec2(30, 1300), Vec2(870, 1300)]),
        ]),
      )).design;
    }

    test('the sheet’s line divides the design until the user says otherwise',
        () {
      final design = drawn();
      expect(design.topLevelDividers, hasLength(2));
      for (final bar in design.dividers) {
        expect(bar.parentId, isNull);
      }
    });

    test('Divides makes it the opening’s, where it was drawn', () {
      final before = drawn();
      final bar = before.dividers
          .firstWhere((b) => b.isHorizontal && b.parentId == null);
      final was = bar.segment.midpoint;
      final opening = before.openings.single;

      // The control offers the opening, because the line lies along it.
      expect(DesignEdits.containersFor(before, bar.id).map((s) => s.id),
          contains(opening.sectionId));

      final after =
          DesignEdits.setDividerParent(before, bar.id, opening.sectionId);
      final moved = after.dividerById(bar.id)!;

      expect(moved.parentId, after.openings.single.id);
      expect(after.topLevelDividers.map((b) => b.id), [
        for (final b in before.topLevelDividers)
          if (b.id != bar.id) b.id,
      ]);

      // It is where the user drew it: the line has not shifted along the
      // sash. Only its two ends move, to reach the sash's own edges — a bar
      // that stopped short of them would divide nothing.
      expect(moved.segment.midpoint.y, closeTo(was.y, 1));
      final sash = sashOf(after).outline;
      expect(moved.a.x, closeTo(sash.left, 0.5));
      expect(moved.b.x, closeTo(sash.right, 0.5));
    });

    test('and it divides the opening into two panes', () {
      final before = drawn();
      final bar = before.dividers
          .firstWhere((b) => b.isHorizontal && b.parentId == null);
      final opening = before.openings.single;
      final cut = before.sectionById(opening.sectionId)!.heightMm;

      final after =
          DesignEdits.setDividerParent(before, bar.id, opening.sectionId);
      final branch = DesignTree.of(after).openings.single;

      // The sash is whole again — the line no longer cuts it short — and the
      // line divides it instead.
      expect(sashOf(after).heightMm, greaterThan(cut + 300));
      expect(branch.barIds, [bar.id]);
      expect(branch.panes, hasLength(2));
      expect(after.childSectionsOf(sashOf(after).id), hasLength(2));
    });
  });
}
