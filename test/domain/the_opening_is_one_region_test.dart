import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/hierarchy.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';

// The hierarchy this phase makes structural:
//
//   Door/Window                  the root — never an opening
//   ├── Outer frame              not a section, so not a parent, not a child
//   ├── Section A                fixed
//   ├── Section B                fixed
//   ├── Section X                the opening
//   │    ├── Internal line
//   │    ├── Glass
//   │    ├── Panel
//   │    └── Hardware
//   └── Section C                fixed
//
// Not "opening = true" on the drawing. One section carries it, and only what
// names that section as its parent is inside it.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

/// A window cut into four main divisions: an upper light, and three below it.
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
      outline: Polygon.rect(0, 0, 3000, 1800),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(
          id: 'transom', a: Vec2(0, 600), b: Vec2(3000, 600), widthMm: 40),
      DividerElement(
          id: 'mull-a', a: Vec2(900, 600), b: Vec2(900, 1800), widthMm: 40),
      DividerElement(
          id: 'mull-b', a: Vec2(2000, 600), b: Vec2(2000, 1800), widthMm: 40),
    ],
  ));
}

List<SectionElement> lowerLights(Design design) {
  final below = [
    for (final s in design.topLevelSections)
      if (s.outline.top > 400) s,
  ];
  return below..sort((a, b) => a.outline.left.compareTo(b.outline.left));
}

/// The middle lower light marked `<` — Section X of the diagram.
Design marked(Design design) {
  final x = lowerLights(design)[1];
  return DesignEdits.setOpening(
    design,
    x.id,
    openingId: 'opening-x',
    mechanism: OpeningMechanism.hingedRight,
    markGlyph: '<',
    markAt: x.outline.centroid,
  );
}

/// A line drawn inside it, making glass over panel.
Design divided(Design design) {
  final openingId = design.openings.single.sectionId;
  final box = design.sectionById(openingId)!.outline;
  final out = DesignEdits.addLineInside(
    design,
    openingId,
    id: 'internal-line',
    at: Vec2(box.centroid.x, box.top + 400),
    horizontal: true,
  );
  final low = out
      .childSectionsOf(openingId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return out.withElement(low.copyWith(finish: _panel));
}

Design example() => divided(marked(window()));

void main() {
  group('the opening is one region, not the drawing', () {
    test('the root carries no opening state at all', () {
      final design = example();

      // There is no flag on the design and none on the frame. The only way
      // anything opens is a section saying so.
      expect(design.openings, hasLength(1));
      expect(design.openings.single.sectionId, isNot('f'));
      expect(design.openings.single.sectionId, isNot(design.id));
      expect(design.frame!.id, 'f');
      expect(design.sectionById('f'), isNull);
    });

    test('one of four main divisions opens and three stay fixed', () {
      final design = example();
      final tree = DesignTree.of(design);

      expect(tree.sections, hasLength(4));
      expect(tree.openings, hasLength(1));
      expect(tree.fixedSections, hasLength(3));

      final x = lowerLights(design)[1];
      expect(tree.openings.single.sectionId, x.id);
      for (final fixed in tree.fixedSections) {
        expect(fixed.opens, isFalse);
        expect(design.openingOf(fixed.sectionId), isNull);
      }
    });

    test('the opening has an id, a parent, a place, a size and a direction',
        () {
      final design = example();
      final opening = design.openings.single;
      final box = design.outlineOf(opening)!;

      expect(opening.id, 'opening-x');
      expect(opening.parentId, opening.sectionId);
      expect(design.sectionById(opening.parentId), isNotNull);
      expect(opening.markGlyph, '<');
      expect(opening.mechanism, OpeningMechanism.hingedRight);

      // Where it is and how big it is — its section's outline and nothing
      // wider. It is a fifth of the daylight, not the daylight.
      final daylight = design.frame!.innerOutline;
      expect(box.left, greaterThan(daylight.left));
      expect(box.right, lessThan(daylight.right));
      expect(box.top, greaterThan(daylight.top));
      expect(box.area, lessThan(daylight.area * 0.3));
    });

    test('its size is the section’s, never a second copy that can drift', () {
      var design = example();
      final opening = design.openings.single;
      final before = design.outlineOf(opening)!;

      // Move the mullion beside it. The opening's own figures follow,
      // because there are no figures of its own to fall behind.
      design = DesignEdits.moveDivider(design, 'mull-b', const Vec2(400, 0));
      final after = design.outlineOf(design.openings.single)!;

      expect(after.width, greaterThan(before.width + 300));
      expect(after, design.sectionById(opening.sectionId)!.outline);
    });
  });

  group('internal geometry names the opening as its parent', () {
    test('the line, the glass, the panel and the hardware are all its', () {
      final design = example();
      final opening = design.openings.single;
      final inside = design.contentsOf(opening);
      final ids = {for (final e in inside) e.id};

      expect(ids, contains('internal-line'));
      expect(design.sectionHolding(design.dividerById('internal-line')!.parentId),
          opening.parentId);

      final panes = design.childSectionsOf(opening.parentId);
      expect(panes, hasLength(2));
      for (final pane in panes) {
        expect(design.sectionHolding(pane.parentId), opening.parentId);
        expect(ids, contains(pane.id));
      }
      expect(
        {for (final p in panes) p.finish.material},
        containsAll(<MaterialKind>[MaterialKind.panel]),
      );

      final hardware = [
        for (final piece in design.hardware)
          if (piece.parentId == opening.parentId) piece.id,
      ];
      expect(hardware, isNotEmpty);
      expect(ids, containsAll(hardware));
    });

    test('nothing outside the opening names it', () {
      final design = example();
      final opening = design.openings.single;
      final ids = {for (final e in design.contentsOf(opening)) e.id};

      expect(ids, isNot(contains('transom')));
      expect(ids, isNot(contains('mull-a')));
      expect(ids, isNot(contains('mull-b')));
      expect(ids, isNot(contains('f')));
      for (final fixed in DesignTree.of(design).fixedSections) {
        expect(ids, isNot(contains(fixed.sectionId)));
      }

      // And the design's own bars belong to nobody.
      for (final id in ['transom', 'mull-a', 'mull-b']) {
        expect(design.dividerById(id)!.parentId, isNull);
      }
    });

    test('ownership is not a flat list searched afterwards', () {
      final design = example();
      final opening = design.openings.single;

      // Every bar and every section says outright whose it is. Nothing here
      // measures anything: the answer is read off the model.
      for (final bar in design.dividers) {
        final mine = design.sectionHolding(bar.parentId) == opening.parentId;
        expect(mine, bar.id == 'internal-line');
      }
      for (final section in design.sections) {
        final mine =
            design.sectionHolding(section.parentId) == opening.parentId;
        expect(mine, design.childSectionsOf(opening.parentId)
            .any((p) => p.id == section.id));
      }
    });
  });

  group('the model refuses what it used to store in silence', () {
    test('an opening on the frame cannot be written', () {
      final design = example().copyWith(openings: [
        const OpeningElement(
          id: 'whole-door',
          sectionId: 'f',
          mechanism: OpeningMechanism.hingedLeft,
          confirmed: true,
        ),
      ]);
      expect(design.openings, isEmpty);
    });

    test('an opening on a section that is gone cannot be written', () {
      final design = example().copyWith(openings: [
        const OpeningElement(
          id: 'ghost',
          sectionId: 'a-section-that-is-gone',
          mechanism: OpeningMechanism.hingedLeft,
          confirmed: true,
        ),
      ]);
      expect(design.openings, isEmpty);
    });

    test('two openings on one section cannot be written', () {
      final base = example();
      final on = base.openings.single.sectionId;
      final design = base.copyWith(openings: [
        OpeningElement(
            id: 'a',
            sectionId: on,
            mechanism: OpeningMechanism.hingedLeft,
            confirmed: true),
        OpeningElement(
            id: 'b',
            sectionId: on,
            mechanism: OpeningMechanism.topHung,
            confirmed: true),
      ]);
      expect(design.openings, hasLength(1));
      expect(design.openings.single.id, 'a');
    });

    test('a section inside itself is put back among the main divisions', () {
      final base = example();
      final x = base.openings.single.sectionId;
      final design = base.copyWith(sections: [
        for (final s in base.sections)
          if (s.id == x) s.copyWith(parentId: x) else s,
      ]);

      // The section is still there — geometry the user drew is never lost to
      // a loop — and it is a main division again.
      expect(design.sectionById(x), isNotNull);
      expect(design.sectionById(x)!.parentId, isNull);
      expect(DesignTree.of(design).everySection.map((s) => s.sectionId),
          contains(x));
    });

    test('a section whose parent is gone is not lost with it', () {
      final base = example();
      final pane = base.childSectionsOf(base.openings.single.sectionId).first;
      final design = base.copyWith(sections: [
        for (final s in base.sections)
          if (s.id == pane.id) s.copyWith(parentId: 'gone') else s,
      ]);

      expect(design.sectionById(pane.id), isNotNull);
      expect(design.sectionById(pane.id)!.parentId, isNull);
    });

    test('a design saved with any of that is read as what it means', () {
      final base = example();
      final broken = base.toJson();
      (broken['openings']! as List<Object?>).add({
        'type': 'opening',
        'id': 'whole-door',
        'sectionId': 'f',
        'mechanism': OpeningMechanism.hingedLeft.name,
        'direction': OpeningDirection.inward.name,
        'confirmed': true,
      });

      final loaded = Design.fromJson(broken);
      expect(loaded.openings, hasLength(1));
      expect(loaded.openings.single.sectionId, isNot('f'));
      expect(loaded.openings.single.id, 'opening-x');
    });

    test('the rules hold on their own, without a design around them', () {
      const sections = [
        SectionElement(id: 'a', outline: Polygon([])),
        SectionElement(id: 'b', outline: Polygon([]), parentId: 'a'),
        SectionElement(id: 'c', outline: Polygon([]), parentId: 'gone'),
      ];

      final settled = Hierarchy.settle(sections);
      expect(settled.map((s) => s.parentId), [null, 'a', null]);

      expect(
        Hierarchy.settleOpenings(const [
          OpeningElement(
              id: '1', sectionId: 'a', mechanism: OpeningMechanism.hingedLeft),
          OpeningElement(
              id: '2', sectionId: 'a', mechanism: OpeningMechanism.topHung),
          OpeningElement(
              id: '3', sectionId: 'f', mechanism: OpeningMechanism.topHung),
          OpeningElement(
              id: '4', sectionId: 'b', mechanism: OpeningMechanism.topHung),
        ], settled).map((o) => o.id),
        ['1', '4'],
      );

      expect(
        Hierarchy.settleDividers(const [
          DividerElement(id: 'x', a: Vec2.zero, b: Vec2(10, 0)),
          DividerElement(
              id: 'y', a: Vec2.zero, b: Vec2(10, 0), parentId: 'b'),
          DividerElement(
              id: 'z', a: Vec2.zero, b: Vec2(10, 0), parentId: 'gone'),
        ], settled).map((d) => d.parentId),
        [null, 'b', null],
      );
    });
  });
}
