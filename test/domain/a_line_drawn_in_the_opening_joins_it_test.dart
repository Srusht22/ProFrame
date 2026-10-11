import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// A line drawn inside a region the design ALREADY opens is that opening's.
//
// The user marks a light, reads the sheet, sees the sash drawn — and then
// draws a line inside it. That line divides the sash. It used to divide the
// whole window and cut the opening down to one side of the line.
//
// The distinction that makes this safe is *already*: the opening exists
// before the line is drawn, from the reading before this one, so no region
// here depends on the answer. On a first reading there are no openings yet
// and every drawn line divides the design, exactly as before — which is
// what `only_the_marked_section_opens_test.dart` requires in five stroke
// orders.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A 200 × 160 window, a mullion 60 cm from the left, and a `<` in the left
/// light. Read, so the opening is there to draw in.
Design opened() => SketchInterpreter.interpret(Design(
      id: 'd',
      name: 'Window',
      kind: DesignKind.window,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sketch: Sketch(strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(2000, 0),
          Vec2(2000, 1600),
          Vec2(0, 1600),
          Vec2(0, 0),
        ]),
        pen('mullion', const [Vec2(600, 0), Vec2(600, 1600)]),
        pen('mark', const [Vec2(420, 700), Vec2(300, 800), Vec2(420, 900)]),
      ]),
    )).design;

Design andThen(Design design, Stroke stroke) =>
    SketchInterpreter.interpret(design.copyWith(
      sketch: design.sketch.add(stroke),
    )).design;

DividerElement barFrom(Design design, String strokeId) =>
    design.dividers.firstWhere((bar) => bar.fromStrokeId == strokeId);

void main() {
  test('the sash is there to draw in', () {
    final design = opened();
    expect(design.openings, hasLength(1));
    expect(design.topLevelSections, hasLength(2));
    final sash = design.sectionById(design.openings.single.sectionId)!.outline;
    expect(sash.left, lessThan(200));
    expect(sash.right, lessThan(700));
  });

  test('a line drawn inside it is the opening’s', () {
    final before = opened();
    final sash = before.sectionById(before.openings.single.sectionId)!.outline;

    final design = andThen(
        before,
        pen('inner', [
          Vec2(sash.left + 8, sash.top + sash.height * 0.4),
          Vec2(sash.right - 8, sash.top + sash.height * 0.4),
        ]));

    final bar = barFrom(design, 'inner');
    expect(design.openingHolding(bar.parentId)?.id, before.openings.single.id);
    expect(design.topLevelDividers.map((b) => b.id), isNot(contains(bar.id)));
    expect(DesignTree.of(design).openings.single.barIds, [bar.id]);
  });

  test('and the opening is still one opening, where it was', () {
    final before = opened();
    final sash = before.sectionById(before.openings.single.sectionId)!.outline;
    final design = andThen(
        before,
        pen('inner', [
          Vec2(sash.left + 8, sash.top + sash.height * 0.4),
          Vec2(sash.right - 8, sash.top + sash.height * 0.4),
        ]));

    expect(design.openings, hasLength(1));
    expect(design.openings.single.id, before.openings.single.id);
    expect(design.topLevelSections, hasLength(2),
        reason: 'the window still has the two lights it had');
    expect(design.topLevelDividers, hasLength(1), reason: 'the mullion');

    final now = design.sectionById(design.openings.single.sectionId)!.outline;
    expect(now.width, closeTo(sash.width, 0.01));
    expect(now.height, closeTo(sash.height, 0.01));

    // And it is divided into two panes, which is what the line was for.
    expect(design.childSectionsOf(design.openings.single.sectionId),
        hasLength(2));
  });

  test('it is laid right across the sash, so the panes actually close', () {
    final before = opened();
    final sash = before.sectionById(before.openings.single.sectionId)!.outline;
    // Drawn well short of both stiles, as a hand does.
    final design = andThen(
        before,
        pen('inner', [
          Vec2(sash.left + 40, sash.top + 600),
          Vec2(sash.right - 40, sash.top + 600),
        ]));

    final bar = barFrom(design, 'inner');
    expect(bar.a.x, closeTo(sash.left, 1));
    expect(bar.b.x, closeTo(sash.right, 1));
    expect(design.childSectionsOf(design.openings.single.sectionId),
        hasLength(2));
  });

  group('and nothing else joins it', () {
    test('a line drawn in the fixed light divides the design', () {
      final before = opened();
      final fixed = before.topLevelSections
          .reduce((a, b) => a.outline.area > b.outline.area ? a : b)
          .outline;

      final design = andThen(
          before,
          pen('elsewhere', [
            Vec2(fixed.left + 20, fixed.top + 500),
            Vec2(fixed.right - 20, fixed.top + 500),
          ]));

      final bar = barFrom(design, 'elsewhere');
      expect(bar.parentId, isNull);
      expect(design.topLevelDividers.map((b) => b.id), contains(bar.id));
    });

    test('a line right across the window divides the design', () {
      final before = opened();
      final design = andThen(
          before, pen('across', const [Vec2(0, 800), Vec2(2000, 800)]));

      final bar = barFrom(design, 'across');
      expect(bar.parentId, isNull);
      expect(design.topLevelDividers.map((b) => b.id), contains(bar.id));
    });

    test('a line along the sash’s own jamb bounds it, so it does not join',
        () {
      final before = opened();
      final sash = before.sectionById(before.openings.single.sectionId)!
          .outline;

      final design = andThen(
          before,
          pen('jamb', [
            Vec2(sash.right, sash.top + 30),
            Vec2(sash.right, sash.bottom - 30),
          ]));

      final bar = barFrom(design, 'jamb');
      expect(bar.parentId, isNull,
          reason: 'a line on the edge divides what it separates');
    });

    test('on a first reading nothing is decided: the line divides', () {
      // Mark and line drawn together, read once. There is no opening yet
      // when the line is read, so it divides the design — and the mark then
      // picks the region it is in, which is the rule that has always held.
      final design = SketchInterpreter.interpret(Design(
        id: 'd',
        name: 'Window',
        kind: DesignKind.window,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        sketch: Sketch(strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(2000, 0),
            Vec2(2000, 1600),
            Vec2(0, 1600),
            Vec2(0, 0),
          ]),
          pen('mullion', const [Vec2(600, 0), Vec2(600, 1600)]),
          pen('mark', const [Vec2(420, 500), Vec2(300, 600), Vec2(420, 700)]),
          pen('inner', const [Vec2(30, 1000), Vec2(570, 1000)]),
        ]),
      )).design;

      expect(barFrom(design, 'inner').parentId, isNull);
      expect(design.openings, hasLength(1));
    });
  });

  test('a second line drawn in the sash joins it too, and makes three panes',
      () {
    var design = opened();
    final sash = design.sectionById(design.openings.single.sectionId)!.outline;

    design = andThen(
        design,
        pen('first', [
          Vec2(sash.left + 8, sash.top + 400),
          Vec2(sash.right - 8, sash.top + 400),
        ]));
    design = andThen(
        design,
        pen('second', [
          Vec2(sash.left + 8, sash.top + 900),
          Vec2(sash.right - 8, sash.top + 900),
        ]));

    final opening = design.openings.single;
    for (final id in ['first', 'second']) {
      expect(design.openingHolding(barFrom(design, id).parentId)?.id,
          opening.id,
          reason: '$id is not the opening’s');
    }
    expect(design.topLevelDividers, hasLength(1), reason: 'the mullion only');
    expect(design.childSectionsOf(opening.sectionId), hasLength(3));
  });
}
