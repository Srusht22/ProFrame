import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// Reading the sheet again must not undo what the user said.
//
// A line drawn on the sheet divides the design until the user says it is an
// opening's — that is the rule, and the **Divides** control is where they
// say it. Saying it is a decision, not a reading, and a reading has no
// business overturning it: the bar was rebuilt from its stroke every time
// the sheet was read, with a new id and no parent, so **Read again** put
// the line back across the whole door and the opening back to half of it.
//
// The drawing: a door, one line across it, and a `>` drawn in the light
// below that line. The mark is drawn clear of the line on purpose. A mark
// drawn *through* a line says by itself that the line is inside what it
// opens, and the reading takes it — `the_mark_drawn_through_a_line_test`
// holds that. Here nothing is said by the drawing, so the user says it, and
// what this file is about is that saying it lasts.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

Design sheet() => Design(
      id: 'd',
      name: 'Door',
      kind: DesignKind.door,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1000, 0),
          Vec2(1000, 2000),
          Vec2(0, 2000),
          Vec2(0, 0),
        ]),
        // A `>` drawn in the lower light: its point on the right.
        pen('mark', const [
          Vec2(200, 1200),
          Vec2(800, 1500),
          Vec2(200, 1800),
        ]),
        // And one line across the door, which the mark is drawn clear of.
        pen('line', const [Vec2(0, 900), Vec2(1000, 900)]),
      ]),
    );

Design read(Design design) => SketchInterpreter.interpret(design).design;

String barFromStroke(Design design, String strokeId) => design.dividers
    .firstWhere((bar) => bar.fromStrokeId == strokeId)
    .id;

void main() {
  test('the sheet as read: the line divides the door', () {
    final design = read(sheet());

    expect(design.openings, hasLength(1));
    expect(design.topLevelSections, hasLength(2),
        reason: 'the line the user drew divides the design, as it must');
    final bar = design.dividerById(barFromStroke(design, 'line'))!;
    expect(bar.parentId, isNull);
  });

  test('the user says the line is the opening’s, and it is', () {
    var design = read(sheet());
    final barId = barFromStroke(design, 'line');
    design = DesignEdits.setDividerParent(
        design, barId, design.openings.single.sectionId);

    final opening = design.openings.single;
    expect(design.dividerById(barId)!.parentId, opening.id);
    expect(design.topLevelDividers.map((b) => b.id), isNot(contains(barId)));
    expect(DesignTree.of(design).openings.single.barIds, [barId]);
    expect(design.childSectionsOf(opening.sectionId), hasLength(2),
        reason: 'the line divides the opening into two panes');
  });

  test('and reading the sheet again does not take it back', () {
    var design = read(sheet());
    final barId = barFromStroke(design, 'line');
    design = DesignEdits.setDividerParent(
        design, barId, design.openings.single.sectionId);

    final wasOpening = design.openings.single.id;
    final panes = design.childSectionsOf(design.openings.single.sectionId);
    expect(panes, hasLength(2));

    // Read again — the user pressing the button on the toolbar.
    final again = read(design);

    expect(again.openings, hasLength(1));
    expect(again.openings.single.id, wasOpening,
        reason: 'the opening is the mark’s, and the mark has not moved');

    final bar = again.dividers.firstWhere((b) => b.fromStrokeId == 'line');
    expect(bar.parentId, isNotNull,
        reason: 'Read again put the line back on the whole design');
    expect(again.openingHolding(bar.parentId)?.id, wasOpening);
    expect(again.topLevelDividers.map((b) => b.id), isNot(contains(bar.id)));
    expect(DesignTree.of(again).openings.single.barIds, [bar.id]);
    expect(again.childSectionsOf(again.openings.single.sectionId),
        hasLength(2),
        reason: 'the two panes the user made are still there');
  });

  test('and again, and again — it is settled', () {
    var design = read(sheet());
    design = DesignEdits.setDividerParent(design,
        barFromStroke(design, 'line'), design.openings.single.sectionId);

    for (var i = 0; i < 3; i++) {
      design = read(design);
      final bar = design.dividers.firstWhere((b) => b.fromStrokeId == 'line');
      expect(design.openingHolding(bar.parentId), isNotNull,
          reason: 'lost on reading ${i + 1}');
    }
  });

  test('rubbing the line out still removes it', () {
    var design = read(sheet());
    design = DesignEdits.setDividerParent(design,
        barFromStroke(design, 'line'), design.openings.single.sectionId);

    design = read(design.copyWith(
      sketch: Sketch(strokes: [
        for (final stroke in design.sketch.strokes)
          if (stroke.id != 'line') stroke,
      ]),
    ));

    expect(design.dividers.where((b) => b.fromStrokeId == 'line'), isEmpty);
    expect(design.openings, hasLength(1),
        reason: 'the opening stays; only the line went');
  });
}
