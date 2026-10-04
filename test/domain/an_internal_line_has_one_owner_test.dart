import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The user's words: *a line completed inside an opening becomes a CHILD of
// that opening — InternalLine.parentId = Opening.id — and must not be stored
// as a global, top-level bar. Its coordinates are relative to its opening: if
// the opening moves, the line moves with it; if it is resized, the line stays
// associated with it; if it is deleted, its child geometry is handled
// correctly rather than becoming orphaned global geometry. One line must not
// exist as a global line and an opening child at once: it has one owner.*
//
// Design
// ├── Fixed geometry
// └── Opening #1
//      ├── Internal line #1
//      └── Internal line #2

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

const mark = [Vec2(300, 480), Vec2(600, 700), Vec2(300, 920)];

/// A 160 × 210 cm window with a mullion, the left light marked `>` and read,
/// so the opening is there before any line is drawn — as it is for the user.
Design oneOpening() => SketchInterpreter.interpret(
  Design(
    id: 'w',
    name: 'Window',
    kind: DesignKind.door,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sketch: Sketch(
      strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1600, 0),
          Vec2(1600, 2100),
          Vec2(0, 2100),
          Vec2(0, 0),
        ]),
        pen('mullion', const [Vec2(1000, 0), Vec2(1000, 2100)]),
        pen('mark', mark),
      ],
    ),
  ),
).design;

Design drawn(Design design, List<Stroke> lines) => SketchInterpreter.interpret(
  design.copyWith(
    sketch: Sketch(strokes: [...design.sketch.strokes, ...lines]),
  ),
).design;

/// The opening with one incomplete line drawn inside it: started well in
/// from the jamb and stopped well short of the mullion.
Design withLine() => drawn(oneOpening(), [
  pen('line-1', const [Vec2(250, 1300), Vec2(700, 1300)]),
]);

DividerElement line(Design d, [String strokeId = 'line-1']) =>
    d.dividers.singleWhere((b) => b.fromStrokeId == strokeId);

String topLevelOf(Design d) => jsonEncode({
  'frame': d.frame!.toJson(),
  'bars': [for (final b in d.topLevelDividers) b.toJson()],
  'sections': [for (final s in d.topLevelSections) s.outline.toJson()],
});

void main() {
  test('the user\'s test: the line drawn inside belongs to the opening, is '
      'completed to its boundary, stays inside it and moves with it', () {
    final before = oneOpening();
    final opening = before.openings.single;
    final region = before.sectionById(opening.sectionId)!.outline;
    final after = withLine();
    final bar = line(after);

    // It belongs to the opening.
    expect(bar.parentId, opening.id);
    expect(after.openingHolding(bar.parentId)?.id, opening.id);
    expect(after.contentsOf(opening).map((e) => e.id), contains(bar.id));

    // It is completed to the opening's boundary, and no further.
    final xs = [bar.a.x, bar.b.x]..sort();
    expect(xs.first, closeTo(region.left, 1));
    expect(xs.last, closeTo(region.right, 1));
    expect(bar.a.y, closeTo(1300, 1));
    expect(bar.b.y, closeTo(1300, 1));

    // It stays inside the opening.
    expect(region.holds(Segment(bar.a, bar.b), reach: 1), isTrue);

    // It moves with the opening: taken to the other light, it is in that
    // light, the same distance down it, and still the opening's.
    final down = DesignEdits.alongWithin(after, bar)!;
    final fixed = after.topLevelSections.singleWhere(
      (s) => s.id != opening.sectionId,
    );
    final moved = DesignEdits.moveOpeningToSection(after, opening.id, fixed.id);
    final there = moved.dividerById(bar.id)!;
    final newRegion = moved
        .sectionById(moved.openingById(opening.id)!.sectionId)!
        .outline;
    expect(newRegion.left, greaterThan(region.right), reason: 'it moved');
    expect(there.parentId, opening.id);
    expect(newRegion.holds(Segment(there.a, there.b), reach: 1), isTrue);
    expect([there.a.x, there.b.x]..sort(), [
      closeTo(newRegion.left, 1),
      closeTo(newRegion.right, 1),
    ]);
    expect(DesignEdits.alongWithin(moved, there), closeTo(down, 1e-6));
    // And nothing of the opening's is left behind in the light it left.
    expect(
      moved.dividers.where((d) => region.holds(Segment(d.a, d.b), reach: 1)),
      isEmpty,
    );
  });

  group('one owner', () {
    test('the line is one bar, and it is not a line of the design', () {
      final design = withLine();
      final opening = design.openings.single;
      expect(
        design.dividers.where((d) => d.fromStrokeId == 'line-1'),
        hasLength(1),
      );
      final bar = line(design);
      expect(design.topLevelDividers.map((d) => d.id), isNot(contains(bar.id)));
      expect(design.childDividersOf(opening.sectionId).map((d) => d.id), [
        bar.id,
      ]);
      // The tree every view walks has it once, in the opening's branch and
      // nowhere else.
      final tree = DesignTree.of(design);
      expect(tree.everyBar.where((id) => id == bar.id), hasLength(1));
      expect(tree.barIds, isNot(contains(bar.id)));
      final branch = tree.openings.single;
      expect(branch.openingId, opening.id);
      expect(branch.barIds, [bar.id]);
      // Its panes are the opening's too, and none is a main division.
      expect(design.childSectionsOf(opening.sectionId), hasLength(2));
      for (final pane in design.childSectionsOf(opening.sectionId)) {
        expect(pane.parentId, opening.id);
      }
    });

    test('the design outside the opening is exactly what it was', () {
      expect(topLevelOf(withLine()), topLevelOf(oneOpening()));
    });

    test('two lines inside are two children of the one opening', () {
      final design = drawn(withLine(), [
        pen('line-2', const [Vec2(500, 1700), Vec2(500, 1900)]),
      ]);
      final opening = design.openings.single;
      expect(line(design, 'line-2').parentId, opening.id);
      expect(DesignTree.of(design).openings.single.barIds, [
        line(design).id,
        line(design, 'line-2').id,
      ]);
      expect(design.topLevelDividers, hasLength(1), reason: 'the mullion');
    });

    test('a second reading, a save and a reload keep the one owner', () {
      final once = withLine();
      final twice = SketchInterpreter.interpret(once).design;
      final loaded = Design.fromJson(
        jsonDecode(jsonEncode(twice.toJson())) as Map<String, Object?>,
      );
      for (final d in [twice, loaded]) {
        expect(jsonEncode(line(d).toJson()), jsonEncode(line(once).toJson()));
        expect(
          d.dividers.where((b) => b.fromStrokeId == 'line-1'),
          hasLength(1),
        );
      }
    });
  });

  group('its coordinates are the opening\'s', () {
    test('resized, the opening keeps the line, the same distance down it', () {
      final before = withLine();
      final opening = before.openings.single;
      final down = DesignEdits.alongWithin(before, line(before))!;
      final mullion = line(before, 'mullion');
      final resized = DesignEdits.moveDivider(
        before,
        mullion.id,
        const Vec2(150, 0),
      );
      final bar = line(resized);
      final region = resized
          .sectionById(resized.openingById(opening.id)!.sectionId)!
          .outline;
      expect(bar.parentId, opening.id);
      expect(region.holds(Segment(bar.a, bar.b), reach: 1), isTrue);
      expect([bar.a.x, bar.b.x]..sort(), [
        closeTo(region.left, 1),
        closeTo(region.right, 1),
      ]);
      expect(DesignEdits.alongWithin(resized, bar), closeTo(down, 1e-6));
    });
  });

  group('when the opening goes, its lines are not orphaned', () {
    void heldByTheRegion(Design after, Design before) {
      final region = before.sectionById(before.openings.single.sectionId)!;
      final bar = line(after);
      expect(after.openings, isEmpty);
      expect(bar.parentId, isNotNull, reason: 'not a line of the design');
      expect(
        after.sectionHolding(bar.parentId),
        region.id,
        reason: 'the region it was drawn in, not an opening that is gone',
      );
      expect(after.topLevelDividers.map((d) => d.id), isNot(contains(bar.id)));
      // The line is exactly where it was: nothing is stretched across the
      // design and nothing is lost.
      expect(
        [bar.a.x, bar.a.y, bar.b.x, bar.b.y],
        [
          line(before).a.x,
          line(before).a.y,
          line(before).b.x,
          line(before).b.y,
        ],
      );
      // Its panes are still inside that region, and not main divisions.
      final panes = after.childSectionsOf(region.id);
      expect(panes, hasLength(2));
      expect(
        after.topLevelSections.map((s) => s.id),
        isNot(contains(anyOf(panes.map((p) => p.id)))),
      );
      expect(after.topLevelSections, hasLength(2));
      // Every view still draws it — once, in that region's branch.
      final tree = DesignTree.of(after);
      expect(tree.everyBar.where((id) => id == bar.id), hasLength(1));
      expect(
        tree.sections.singleWhere((s) => s.sectionId == region.id).barIds,
        [bar.id],
      );
    }

    test('deleted', () {
      final before = withLine();
      heldByTheRegion(
        DesignEdits.delete(before, before.openings.single.id),
        before,
      );
    });

    test('cancelled — said to be fixed after all', () {
      final before = withLine();
      final opening = before.openings.single;
      heldByTheRegion(
        DesignEdits.setOpening(
          before,
          opening.sectionId,
          openingId: opening.id,
          mechanism: OpeningMechanism.fixed,
        ),
        before,
      );
    });

    test('its mark rubbed out, and the sheet read again', () {
      final before = withLine();
      final after = SketchInterpreter.interpret(
        before.copyWith(
          sketch: Sketch(
            strokes: [
              for (final s in before.sketch.strokes)
                if (s.id != 'mark') s,
            ],
          ),
        ),
      ).design;
      heldByTheRegion(after, before);
      // Read again, it is still that region's.
      heldByTheRegion(SketchInterpreter.interpret(after).design, before);
    });

    test('marked again, the line is the new opening\'s', () {
      final before = withLine();
      final rubbed = SketchInterpreter.interpret(
        before.copyWith(
          sketch: Sketch(
            strokes: [
              for (final s in before.sketch.strokes)
                if (s.id != 'mark') s,
            ],
          ),
        ),
      ).design;
      final again = drawn(rubbed, [pen('mark-2', mark)]);
      final opening = again.openings.single;
      expect(line(again).parentId, opening.id);
      expect(DesignTree.of(again).openings.single.barIds, [line(again).id]);
    });
  });
}
