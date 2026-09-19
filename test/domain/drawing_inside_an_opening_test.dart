import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sections/section_builder.dart';

// Editing an opening: the same tools as the sheet, working on the opening.
//
//   Opening selected, a line drawn:
//
//     InternalLine { parentId: selectedOpening.id }     and never
//     GlobalLine   { ... }
//
// The selected opening is what says where the geometry belongs, so nothing
// is asked after a line is drawn.

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
      DividerElement(id: 'mull', a: Vec2(1000, 0), b: Vec2(1000, 1900),
          widthMm: 40),
    ],
  ));
  final sash = design.topLevelSections
      .firstWhere((s) => s.outline.contains(const Vec2(500, 900)));
  return DesignEdits.setOpening(
    design,
    sash.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedLeft,
    markGlyph: '>',
    markAt: sash.outline.centroid,
  );
}

SectionElement sashOf(Design d) =>
    d.sectionById(d.openings.single.sectionId)!;

List<DividerElement> newBars(Design before, Design after) => [
      for (final bar in after.dividers)
        if (!before.dividers.any((b) => b.id == bar.id)) bar,
    ];

/// The design's own structure, which drawing inside an opening never alters.
String designShape(Design d) => [
      d.topLevelSections.length,
      [for (final b in d.topLevelDividers) b.id].join('+'),
    ].join('|');

void main() {
  group('everything drawn inside the opening is the opening’s', () {
    final base = marked();
    final on = base.openings.single.sectionId;
    final box = base.sectionById(on)!.outline;

    final drawings = <String, Design>{
      'a straight line at an angle': DesignEdits.addShapeInside(
        base,
        on,
        idPrefix: 'line',
        corners: [
          Vec2(box.left + 10, box.centroid.y - 100),
          Vec2(box.right - 10, box.centroid.y + 100),
        ],
      ),
      'a rectangle': DesignEdits.addShapeInside(
        base,
        on,
        idPrefix: 'rect',
        closed: true,
        corners: [
          Vec2(box.left + 200, box.top + 300),
          Vec2(box.right - 200, box.top + 300),
          Vec2(box.right - 200, box.bottom - 300),
          Vec2(box.left + 200, box.bottom - 300),
        ],
      ),
      'a polyline': DesignEdits.addShapeInside(
        base,
        on,
        idPrefix: 'poly',
        corners: [
          Vec2(box.left, box.top + 400),
          Vec2(box.centroid.x, box.top + 700),
          Vec2(box.right, box.top + 400),
        ],
      ),
      'a horizontal line': DesignEdits.addLineInside(
        base,
        on,
        id: 'h',
        at: Vec2(box.centroid.x, box.top + 400),
        horizontal: true,
      ),
      'a vertical line': DesignEdits.addLineInside(
        base,
        on,
        id: 'v',
        at: Vec2(box.left + 300, box.centroid.y),
        horizontal: false,
      ),
    };

    drawings.forEach((what, after) {
      test('$what names the opening as its parent', () {
        final made = newBars(base, after);
        expect(made, isNotEmpty, reason: '$what drew nothing');
        for (final bar in made) {
          expect(bar.parentId, after.openings.single.id,
              reason: '${bar.id} was made a line of the design');
          expect(after.openingHolding(bar.parentId)!.id,
              after.openings.single.id);
        }
      });

      test('$what makes no global line and no global section', () {
        final made = {for (final bar in newBars(base, after)) bar.id};
        expect(designShape(after), designShape(base),
            reason: '$what re-cut the design itself');
        for (final id in made) {
          expect(after.topLevelDividers.map((b) => b.id), isNot(contains(id)));
        }
        expect(DesignTree.of(after).barIds, ['mull']);
      });

      test('$what leaves the opening one opening, its boundary unmoved', () {
        expect(after.openings, hasLength(1));
        expect(after.openings.single.id, 'o');
        expect(sashOf(after).outline, sashOf(base).outline);
      });

      test('$what is in the tree as the opening’s', () {
        final made = {for (final bar in newBars(base, after)) bar.id};
        final branch = DesignTree.of(after).openings.single;
        expect(branch.barIds.toSet(), containsAll(made));
      });
    });
  });

  group('a shape is the lines that enclose it, not a picture of one', () {
    test('a rectangle is four bars, and they divide the opening', () {
      final base = marked();
      final on = base.openings.single.sectionId;
      final box = base.sectionById(on)!.outline;
      final after = DesignEdits.addShapeInside(base, on,
          idPrefix: 'rect', closed: true, corners: [
            Vec2(box.left + 200, box.top + 300),
            Vec2(box.right - 200, box.top + 300),
            Vec2(box.right - 200, box.bottom - 300),
            Vec2(box.left + 200, box.bottom - 300),
          ]);

      expect(newBars(base, after), hasLength(4));
      expect(after.childSectionsOf(sashOf(after).id), hasLength(2),
          reason: 'the pane it encloses, and the rest of the sash round it');
    });

    test('a polyline is one bar for each leg, and closes when asked', () {
      final base = marked();
      final on = base.openings.single.sectionId;
      final box = base.sectionById(on)!.outline;
      final corners = [
        Vec2(box.left + 150, box.top + 300),
        Vec2(box.right - 150, box.top + 500),
        Vec2(box.centroid.x, box.bottom - 300),
      ];

      expect(newBars(base,
          DesignEdits.addShapeInside(base, on, idPrefix: 'p', corners: corners)),
          hasLength(2));
      expect(newBars(base, DesignEdits.addShapeInside(base, on,
              idPrefix: 'q', corners: corners, closed: true)),
          hasLength(3));
    });

    test('a leg drawn out past the sash is trimmed to it, not dropped', () {
      final base = marked();
      final on = base.openings.single.sectionId;
      final box = base.sectionById(on)!.outline;
      final after = DesignEdits.addShapeInside(base, on,
          idPrefix: 'over', closed: true, corners: [
            Vec2(box.left + 200, box.top + 300),
            Vec2(box.right + 900, box.top + 300),
            Vec2(box.right + 900, box.bottom - 300),
            Vec2(box.left + 200, box.bottom - 300),
          ]);

      final made = newBars(base, after);
      expect(made, isNotEmpty);
      for (final bar in made) {
        expect(box.holds(bar.segment, reach: bar.widthMm), isTrue,
            reason: '${bar.id} reaches out of the opening it belongs to');
        expect(bar.parentId, 'o');
      }
      // The fixed light across the design is untouched by any of it.
      expect(designShape(after), designShape(base));
    });

    test('a shape drawn entirely outside the opening adds nothing', () {
      final base = marked();
      final on = base.openings.single.sectionId;
      final far = base.topLevelSections
          .reduce((a, b) => a.areaMmSq > b.areaMmSq ? a : b)
          .outline;
      final after = DesignEdits.addShapeInside(base, on,
          idPrefix: 'away', closed: true, corners: [
            Vec2(far.left + 100, far.top + 100),
            Vec2(far.left + 400, far.top + 100),
            Vec2(far.left + 400, far.top + 400),
            Vec2(far.left + 100, far.top + 400),
          ]);

      expect(newBars(base, after), isEmpty);
      expect(identical(after, base), isTrue,
          reason: 'nothing was drawn, so nothing changed');
    });
  });

  group('a lone line is laid across; a shape’s legs are not', () {
    test('one straight line runs the full width of the opening', () {
      final base = marked();
      final on = base.openings.single.sectionId;
      final box = base.sectionById(on)!.outline;
      final after = DesignEdits.addShapeInside(base, on,
          idPrefix: 'one', corners: [
            Vec2(box.left + 200, box.centroid.y - 50),
            Vec2(box.right - 200, box.centroid.y + 50),
          ]);

      final bar = newBars(base, after).single;
      expect(bar.a.x, closeTo(box.left, 0.5));
      expect(bar.b.x, closeTo(box.right, 0.5));
      expect(after.childSectionsOf(sashOf(after).id), hasLength(2));
    });

    test('a rectangle’s legs stay where they were drawn', () {
      final base = marked();
      final on = base.openings.single.sectionId;
      final box = base.sectionById(on)!.outline;
      final after = DesignEdits.addShapeInside(base, on,
          idPrefix: 'rect', closed: true, corners: [
            Vec2(box.left + 200, box.top + 300),
            Vec2(box.right - 200, box.top + 300),
            Vec2(box.right - 200, box.bottom - 300),
            Vec2(box.left + 200, box.bottom - 300),
          ]);

      // Laid across, a rectangle would be a cross: every leg would run the
      // full width or height of the sash and enclose nothing.
      for (final bar in newBars(base, after)) {
        expect(bar.segment.length, lessThan(box.height - 100));
      }
    });
  });
}
