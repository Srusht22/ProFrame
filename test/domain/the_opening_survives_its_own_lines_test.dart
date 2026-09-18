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

// A 40 x 160 cm opening, and a horizontal divider 40 cm down it.
//
//   Opening                        not:   Window
//   ├── Glass                             ├── Opening
//   ├── Divider                           ├── New Section
//   └── Panel                             └── New Section
//
// The opening remains the parent, and its boundary does not move. One line
// or five, across or upright: it stays one opening.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A window with a 40 cm light standing across it, marked `<`.
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

SectionElement sashOf(Design d) =>
    d.sectionById(d.openings.single.sectionId)!;

/// The design's own structure, which no internal line may alter.
String designShape(Design d) => [
      d.topLevelSections.length,
      [for (final b in d.topLevelDividers) b.id].join('+'),
      for (final s in d.topLevelSections)
        '${s.widthMm.round()}x${s.heightMm.round()}',
    ].join('|');

/// The opening's own identity and boundary, which no internal line may move.
String openingShape(Design d) {
  final o = d.openings.single;
  final box = d.sectionById(o.sectionId)!.outline;
  return '${d.openings.length}|${o.id}|${o.sectionId}|'
      '${box.left.round()},${box.top.round()},'
      '${box.right.round()},${box.bottom.round()}';
}

/// Adds [count] lines inside the opening, one at a time.
Design lined(Design start, {required int count, required bool horizontal}) {
  var d = start;
  final box = sashOf(start).outline;
  for (var i = 1; i <= count; i++) {
    final on = d.openings.single.sectionId;
    d = DesignEdits.addLineInside(
      d,
      on,
      id: '${horizontal ? "h" : "v"}$i',
      at: horizontal
          ? Vec2(box.centroid.x, box.top + box.height * i / (count + 1))
          : Vec2(box.left + box.width * i / (count + 1), box.centroid.y),
      horizontal: horizontal,
    );
  }
  return d;
}

void main() {
  group('the opening remains the parent', () {
    test('a divider 40 cm down makes glass, divider, panel', () {
      final before = marked();
      final on = before.openings.single.sectionId;
      final box = before.sectionById(on)!.outline;
      final after = DesignEdits.addLineInside(before, on,
          id: 'divider', at: Vec2(box.centroid.x, box.top + 400),
          horizontal: true);

      final branch = DesignTree.of(after).openings.single;
      expect(branch.barIds, ['divider']);
      expect(branch.panes, hasLength(2));
      for (final pane in branch.panes) {
        expect(after.sectionById(pane.sectionId)!.parentId,
            after.openings.single.id);
      }
      expect(
        Units.format(DesignEdits.alongWithin(after, after.dividerById('divider'))!),
        '40',
      );
    });

    test('it is not two new top-level sections', () {
      final before = marked();
      final on = before.openings.single.sectionId;
      final box = before.sectionById(on)!.outline;
      final after = DesignEdits.addLineInside(before, on,
          id: 'divider', at: Vec2(box.centroid.x, box.top + 400),
          horizontal: true);

      expect(designShape(after), designShape(before),
          reason: 'the design itself was re-cut by a line inside an opening');
      expect(openingShape(after), openingShape(before),
          reason: 'the opening was replaced or its boundary moved');
      expect(after.dividerById('divider')!.parentId, isNotNull);
      expect(after.topLevelDividers.map((b) => b.id),
          ['transom', 'mull-a', 'mull-b']);
    });
  });

  group('one opening, however many lines', () {
    test('five horizontals leave one opening and six panes', () {
      final before = marked();
      final after = lined(before, count: 5, horizontal: true);

      expect(after.openings, hasLength(1));
      expect(DesignTree.of(after).openings, hasLength(1));
      expect(after.childDividersOf(sashOf(after).id), hasLength(5));
      expect(after.childSectionsOf(sashOf(after).id), hasLength(6));
      expect(openingShape(after), openingShape(before));
      expect(designShape(after), designShape(before));
    });

    test('three verticals leave one opening and four panes', () {
      final before = marked();
      final after = lined(before, count: 3, horizontal: false);

      expect(after.openings, hasLength(1));
      expect(after.childDividersOf(sashOf(after).id), hasLength(3));
      expect(after.childSectionsOf(sashOf(after).id), hasLength(4));
      expect(openingShape(after), openingShape(before));
      expect(designShape(after), designShape(before));
    });

    test('across and upright together leave one opening and four panes', () {
      final before = marked();
      var after = lined(before, count: 1, horizontal: true);
      after = lined(after, count: 1, horizontal: false);

      expect(after.openings, hasLength(1));
      expect(after.childSectionsOf(sashOf(after).id), hasLength(4));
      expect(openingShape(after), openingShape(before));
      expect(designShape(after), designShape(before));
    });

    test('the boundary does not move at any point along the way', () {
      final before = marked();
      final was = openingShape(before);
      final design = designShape(before);

      var d = before;
      final box = sashOf(before).outline;
      for (var i = 1; i <= 5; i++) {
        d = DesignEdits.addLineInside(d, d.openings.single.sectionId,
            id: 'line-$i',
            at: Vec2(box.centroid.x, box.top + 250.0 * i), horizontal: true);
        expect(openingShape(d), was, reason: 'after line $i');
        expect(designShape(d), design, reason: 'after line $i');
        expect(d.childSectionsOf(sashOf(d).id), hasLength(i + 1),
            reason: 'after line $i');
      }
    });
  });

  group('a line drawn on the sheet and put in afterwards', () {
    // Two lines drawn across the sash on the sheet. Each divides the design
    // until the user says otherwise; putting one in must not disturb the
    // other, and must not leave the opening undivided.
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
          pen('mark', const [Vec2(380, 430), Vec2(500, 500), Vec2(380, 570)]),
          pen('i1', const [Vec2(30, 900), Vec2(870, 900)]),
          pen('i2', const [Vec2(30, 1300), Vec2(870, 1300)]),
        ]),
      )).design;
    }

    /// Puts the lowest loose horizontal bar into the opening.
    Design moveOneIn(Design d) {
      final loose = [
        for (final b in d.topLevelDividers)
          if (b.isHorizontal) b,
      ]..sort((a, b) => a.segment.midpoint.y.compareTo(b.segment.midpoint.y));
      return DesignEdits.setDividerParent(
          d, loose.first.id, d.openings.single.sectionId);
    }

    test('the first line put in divides the opening at once', () {
      final one = moveOneIn(drawn());

      expect(one.openings, hasLength(1));
      final branch = DesignTree.of(one).openings.single;
      expect(branch.barIds, hasLength(1));
      expect(branch.panes, hasLength(2),
          reason: 'a line inside an opening that divides nothing');

      // It runs right across the sash: a bar stopping short divides nothing.
      final bar = one.dividerById(branch.barIds.single)!;
      final sash = sashOf(one).outline;
      expect(bar.a.x, closeTo(sash.left, 0.5));
      expect(bar.b.x, closeTo(sash.right, 0.5));
    });

    test('putting the second in does not move the first', () {
      final one = moveOneIn(drawn());
      final first = one.dividerById(
          DesignTree.of(one).openings.single.barIds.single)!;
      final wasY = first.segment.midpoint.y;

      final two = moveOneIn(one);
      final branch = DesignTree.of(two).openings.single;

      expect(two.openings, hasLength(1));
      expect(branch.barIds, hasLength(2));
      expect(branch.panes, hasLength(3));
      expect(two.dividerById(first.id)!.segment.midpoint.y,
          closeTo(wasY, 0.5),
          reason: 'the first line was dragged along by the second joining');
    });

    test('the opening is one opening throughout, never the window', () {
      var d = drawn();
      for (final round in [1, 2]) {
        d = moveOneIn(d);
        expect(d.openings, hasLength(1), reason: 'round $round');
        expect(DesignTree.of(d).openings, hasLength(1), reason: 'round $round');
        expect(d.openings.single.sectionId, isNot(d.frame!.id),
            reason: 'round $round');
        // The fixed light across the design is untouched by any of it.
        final fixed = d.topLevelSections
            .reduce((a, b) => a.areaMmSq > b.areaMmSq ? a : b);
        expect(d.openingOf(fixed.id), isNull, reason: 'round $round');
      }
    });
  });
}
