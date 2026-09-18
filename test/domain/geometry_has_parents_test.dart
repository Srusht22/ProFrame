import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// This phase's question, in one sentence:
//
//   Can a line belong specifically to an opening?
//
// Not to the design, not to a flat list searched afterwards, and not to a
// section id that is made again from a counter every time the sheet is read.
// To *that opening* — the one the user authored by drawing their mark.
//
//   Door/Window
//   ├── Mullion            top-level geometry
//   ├── Fixed light        top-level geometry
//   └── Opening  ◀── the mark
//        ├── Internal line     the opening's
//        ├── Glass             the opening's
//        └── Panel             the opening's

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A window with a mullion, and a `>` drawn in the left light.
Design drawn() {
  final at = DateTime(2026);
  return Design(
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
    ]),
  );
}

Design read(Design design) => SketchInterpreter.interpret(design).design;

/// The mullion, found by where it is rather than by an id a counter made.
DividerElement mullion(Design design) =>
    design.dividers.firstWhere((d) => d.isVertical);

/// The mark read, and a line then drawn inside the opening it made.
Design example() {
  final design = read(drawn());
  final on = design.openings.single.sectionId;
  return DesignEdits.addLineInside(
    design,
    on,
    id: 'inner',
    at: Vec2(design.sectionById(on)!.outline.centroid.x, 1300),
    horizontal: true,
  );
}

void main() {
  group('a line can belong specifically to an opening', () {
    test('it names the opening, and the opening is what it names', () {
      final design = example();
      final opening = design.openings.single;
      final bar = design.dividerById('inner')!;

      expect(bar.parentId, isNotNull, reason: 'it is not top-level geometry');
      expect(bar.parentId, opening.id);
      expect(design.openingById(bar.parentId!), isNotNull);

      // And the reference resolves both ways: to the opening it belongs to,
      // and to the region of the design that opening occupies.
      expect(design.openingHolding(bar.parentId)!.id, opening.id);
      expect(design.sectionHolding(bar.parentId), opening.sectionId);
    });

    test('top-level geometry is told from an opening’s own by asking', () {
      final design = example();
      final opening = design.openings.single;

      for (final other in design.dividers) {
        final owner = design.openingHolding(other.parentId);
        expect(owner?.id, other.id == 'inner' ? opening.id : isNull,
            reason: '${other.id} is on the wrong side of the line');
      }

      expect(design.topLevelDividers.map((d) => d.id), [mullion(design).id]);
      expect(design.childDividersOf(opening.sectionId).map((d) => d.id),
          ['inner']);
      expect(design.topLevelSections, hasLength(2),
          reason: 'it made no new main division');
      for (final section in design.topLevelSections) {
        expect(section.parentId, isNull);
      }
    });

    test('the panes it makes are the opening’s too', () {
      final design = example();
      final opening = design.openings.single;
      final panes = design.childSectionsOf(opening.sectionId);

      expect(panes, hasLength(2));
      for (final pane in panes) {
        expect(pane.parentId, opening.id);
        expect(design.openingHolding(pane.parentId)!.id, opening.id);
      }
      expect(design.hasChildren(opening.sectionId), isTrue);
    });
  });

  group('the reference holds because the opening’s id is the user’s mark', () {
    test('the id is the mark’s, not a number from a counter', () {
      final design = example();
      final opening = design.openings.single;

      expect(opening.fromStrokeId, 'mark');
      expect(opening.id, 'opening-mark');
    });

    test('a second reading of the sheet leaves the line where it is', () {
      var design = example();
      final was = design.openings.single.id;

      // The user draws another line, in the fixed light this time, and the
      // sheet is read again. That used to orphan everything in the opening.
      design = design.copyWith(sketch: Sketch(strokes: [
        ...design.sketch.strokes,
        pen('transom', const [Vec2(900, 1000), Vec2(2400, 1000)]),
      ]));
      design = read(design);

      expect(design.openings.single.id, was);
      final bar = design.dividerById('inner')!;
      expect(bar.parentId, was);
      expect(design.topLevelDividers.map((d) => d.id), isNot(contains('inner')));
      expect(design.childSectionsOf(design.openings.single.sectionId),
          hasLength(2));
    });

    test('a save and a reload keep it the opening’s', () {
      final design = example();
      final back = Design.fromJson(design.toJson());

      expect(back.dividerById('inner')!.parentId, design.openings.single.id);
      expect(back.openingHolding(back.dividerById('inner')!.parentId), isNotNull);
      expect(back.childSectionsOf(back.openings.single.sectionId), hasLength(2));
    });

    test('resizing, moving a neighbour and moving the opening all keep it',
        () {
      final start = example();
      final openingId = start.openings.single.id;

      for (final step in <(String, Design Function(Design))>[
        ('the opening is made wider',
            (d) => DesignEdits.moveDivider(d, mullion(d).id, const Vec2(300, 0))),
        ('the opening is resized by its figure', (d) {
          return DesignEdits.setSectionWidth(
              d, d.openings.single.sectionId, 700);
        }),
        ('the opening is moved to the other light', (d) {
          final other = d.topLevelSections
              .firstWhere((s) => s.id != d.openings.single.sectionId);
          return DesignEdits.moveOpeningToSection(d, openingId, other.id);
        }),
      ]) {
        final after = step.$2(start);
        // Each step really does move the ground under the opening, so none
        // of what follows can pass by nothing having happened.
        String ground(Design d) {
          final on = d.openings.single.sectionId;
          return '$on/${d.sectionById(on)!.outline}';
        }

        expect(ground(after), isNot(ground(start)),
            reason: '${step.$1}: nothing changed, so nothing was tested');

        final bar = after.dividerById('inner');
        expect(bar, isNotNull, reason: '${step.$1}: the line was lost');
        expect(bar!.parentId, openingId, reason: step.$1);
        expect(after.childSectionsOf(after.openings.single.sectionId),
            hasLength(2), reason: step.$1);
        expect(
          after.sectionById(after.openings.single.sectionId)!.outline
              .holds(bar.segment, reach: bar.widthMm),
          isTrue,
          reason: '${step.$1}: the line left the opening it belongs to',
        );
      }
    });
  });

  group('a document that says otherwise is read as what it means', () {
    test('a design written before this, naming the section, still loads', () {
      final design = example();
      final opening = design.openings.single;

      // The older form on disk: every child named the section, not the
      // opening on it. It means the same thing, so it is read the same way.
      final older = design.toJson();
      for (final key in ['dividers', 'sections']) {
        for (final raw in older[key]! as List<Object?>) {
          final map = raw! as Map<String, Object?>;
          if (map['parentId'] == opening.id) map['parentId'] = opening.sectionId;
        }
      }

      final back = Design.fromJson(older);
      expect(back.dividerById('inner')!.parentId, opening.id);
      expect(back.childSectionsOf(opening.sectionId), hasLength(2));
      expect(back.topLevelDividers.map((d) => d.id), [mullion(back).id]);
    });

    test('a parent that is neither a live section nor a live opening goes', () {
      final design = example();
      final broken = design.toJson();
      for (final raw in broken['dividers']! as List<Object?>) {
        final map = raw! as Map<String, Object?>;
        if (map['id'] == 'inner') map['parentId'] = 'an-opening-that-is-gone';
      }

      // The line is never lost — losing a line the user drew is worse than
      // any question of what it now divides — but it divides the design.
      final back = Design.fromJson(broken);
      expect(back.dividerById('inner'), isNotNull);
      expect(back.dividerById('inner')!.parentId, isNull);
    });

    test('the model still refuses to make the whole window an opening', () {
      final design = example().copyWith(openings: [
        const OpeningElement(
          id: 'whole-window',
          sectionId: 'f',
          mechanism: OpeningMechanism.hingedLeft,
          confirmed: true,
        ),
      ]);
      expect(design.openings, isEmpty);
    });
  });

  group('the parent link is a fact about the model, not about a builder', () {
    test('it is there without any reading, on a design built by hand', () {
      final at = DateTime(2026);
      final built = SectionBuilder.rebuild(Design(
        id: 'h',
        name: 'by hand',
        kind: DesignKind.door,
        createdAt: at,
        updatedAt: at,
        frame: FrameElement(
          id: 'f',
          outline: Polygon.rect(0, 0, 1000, 2100),
          profileMm: 50,
        ),
      ));
      final opened = DesignEdits.setOpening(
        built,
        built.topLevelSections.single.id,
        openingId: 'leaf',
        mechanism: OpeningMechanism.hingedLeft,
        markGlyph: '>',
        markAt: built.topLevelSections.single.outline.centroid,
      );
      final on = opened.openings.single.sectionId;
      final design = DesignEdits.addLineInside(
        opened,
        on,
        id: 'rail',
        at: Vec2(opened.sectionById(on)!.outline.centroid.x, 900),
        horizontal: true,
      );

      expect(design.dividerById('rail')!.parentId, 'leaf');
      expect(design.openingHolding('leaf')!.id, 'leaf');
      expect(design.topLevelDividers, isEmpty);
      expect(design.childSectionsOf(on), hasLength(2));
    });
  });
}
