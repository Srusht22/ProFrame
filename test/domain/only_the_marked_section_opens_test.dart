import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

var _n = 0;

Stroke drawn(List<Vec2> through, {double wobble = 7}) {
  final random = math.Random(_n + 3);
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 16; i++) {
      final at = through[leg].lerp(through[leg + 1], i / 16);
      samples.add(StrokeSample(Vec2(
        at.x + (random.nextDouble() - 0.5) * wobble * 2,
        at.y + (random.nextDouble() - 0.5) * wobble * 2,
      )));
    }
  }
  samples.add(StrokeSample(through.last));
  return Stroke(id: 'stroke-${_n++}', samples: samples);
}

Design read(List<List<Vec2>> strokes) {
  _n = 0;
  final at = DateTime(2026);
  return SketchInterpreter.interpret(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    sketch: Sketch(strokes: [for (final v in strokes) drawn(v)]),
  )).design;
}

SectionElement openingOf(Design design) =>
    design.sectionById(design.openings.single.sectionId)!;

/// How much of the daylight the opening takes up, as a fraction.
double shareOf(Design design) =>
    openingOf(design).areaMmSq / design.frame!.innerOutline.area;

// The specification's design:
//
//   ┌──────────────────────────┐
//   │          FIXED           │
//   ├──────────────┬───────────┤
//   │      >       │   FIXED   │
//   │   OPENING    │           │
//   └──────────────┴───────────┘
const frame = [
  Vec2(0, 0),
  Vec2(2000, 0),
  Vec2(2000, 1600),
  Vec2(0, 1600),
  Vec2(0, 0),
];
const transom = [Vec2(0, 800), Vec2(2000, 800)];
const mullion = [Vec2(900, 800), Vec2(900, 1600)];
const mark = [Vec2(560, 1100), Vec2(700, 1200), Vec2(560, 1300)];

void main() {
  group('only the section holding the mark opens', () {
    final orders = <String, List<List<Vec2>>>{
      'the mark drawn last': [frame, transom, mullion, mark],
      'the mark drawn first': [frame, mark, transom, mullion],
      'the mark drawn in the middle': [frame, transom, mark, mullion],
      'the mullion drawn last': [frame, transom, mark, mullion],
      'the transom drawn last': [frame, mullion, mark, transom],
    };

    orders.forEach((order, strokes) {
      test('$order — three sections, and one of them opens', () {
        final design = read(strokes);

        expect(design.topLevelSections, hasLength(3),
            reason: 'the transom and the mullion both divide the design');
        expect(design.openings, hasLength(1),
            reason: 'one mark, one opening');
      });

      test('$order — the opening is the lower left section, and no more', () {
        final design = read(strokes);
        final opening = openingOf(design);

        // The mark is in it.
        expect(opening.outline.contains(const Vec2(620, 1200)), isTrue);
        // And it is the lower left quarter of the design, not a band and
        // certainly not the window.
        expect(opening.outline.right, lessThan(1000));
        expect(opening.outline.top, greaterThan(700));
        expect(shareOf(design), lessThan(0.35));
      });

      test('$order — every other section stays fixed', () {
        final design = read(strokes);
        final openedId = design.openings.single.sectionId;

        final fixed = [
          for (final section in design.topLevelSections)
            if (section.id != openedId) section,
        ];
        expect(fixed, hasLength(2));
        for (final section in fixed) {
          expect(design.openingOf(section.id), isNull);
        }
      });

      test('$order — the frame itself is not an opening', () {
        final design = read(strokes);
        final openedId = design.openings.single.sectionId;
        expect(openedId, isNot(design.frame!.id));
        expect(shareOf(design), lessThan(0.99));
      });
    });

    test('the order the strokes were made in changes nothing', () {
      final shapes = <String>{};
      for (final strokes in orders.values) {
        final design = read(strokes);
        final opening = openingOf(design);
        // The structure exactly, and the size to within a hand's wobble:
        // each order redraws the frame with a different shake, and half a
        // centimetre of that is not a difference in the design.
        shapes.add([
          design.topLevelSections.length,
          design.topLevelDividers.length,
          (opening.widthMm / 50).round(),
          (opening.heightMm / 50).round(),
        ].join('|'));
      }
      expect(shapes, hasLength(1));
    });
  });

  group('the opening never grows past the region the mark is in', () {
    test('a mark anywhere inside a window does not open the window', () {
      // The mark is well inside the design, with lines on every side of it.
      final design = read([frame, transom, mullion, mark]);
      expect(shareOf(design), lessThan(0.35));
    });

    test('a design with no divisions opens the daylight, because that is '
        'the section the mark is in', () {
      final design = read([frame, mark]);
      expect(design.topLevelSections, hasLength(1));
      expect(design.openings, hasLength(1));
      // Not an opening grown to fit the window: the window has exactly one
      // section, and it is the one the mark was drawn in.
      expect(design.topLevelDividers, isEmpty);
    });

    test('a mullion is never swallowed by the opening beside it', () {
      final design = read([frame, transom, mullion, mark]);

      expect(design.topLevelDividers, hasLength(2));
      for (final bar in design.dividers) {
        expect(bar.parentId, isNull,
            reason: 'a line drawn on the sheet divides the design');
      }
    });

    test('adding a line beside the opening does not enlarge it', () {
      final before = read([frame, transom, mullion, mark]);
      final after = read([
        frame,
        transom,
        mullion,
        mark,
        const [Vec2(1400, 800), Vec2(1400, 1600)],
      ]);

      expect(after.openings, hasLength(1));
      expect(after.topLevelSections, hasLength(4));
      expect(
        openingOf(after).areaMmSq,
        closeTo(openingOf(before).areaMmSq, 1000),
        reason: 'a line drawn elsewhere is nothing to do with the opening',
      );
    });

    test('two marks make two openings, each its own section', () {
      final design = read([
        frame,
        transom,
        mullion,
        mark,
        const [Vec2(1300, 1100), Vec2(1440, 1200), Vec2(1300, 1300)],
      ]);

      expect(design.openings, hasLength(2));
      final opened = {for (final o in design.openings) o.sectionId};
      expect(opened, hasLength(2));
      // The upper light was marked by neither, so it stays fixed.
      expect(design.topLevelSections.length - opened.length, 1);
    });
  });

  group('lines still become the opening’s when the user says so', () {
    test('the line tool puts a line inside the opening', () {
      final before = read([frame, transom, mullion, mark]);
      final opening = openingOf(before);

      final after = DesignEdits.addLineInside(
        before,
        opening.id,
        id: 'inner',
        at: Vec2(opening.outline.centroid.x, opening.outline.top + 200),
        horizontal: true,
      );

      expect(after.childDividersOf(opening.id), hasLength(1));
      expect(after.childSectionsOf(opening.id), hasLength(2));
      // And the design is unchanged outside it.
      expect(after.topLevelSections, hasLength(3));
      expect(after.topLevelDividers, hasLength(2));
      expect(after.openings, hasLength(1));
      expect(
        after.sectionById(opening.id)!.areaMmSq,
        closeTo(opening.areaMmSq, 1),
      );
    });

    test('the Divides control moves a drawn line into the opening', () {
      // A line drawn on the sheet inside the marked section: a division of
      // the design until the user says it is the opening's.
      final before = read([
        frame,
        transom,
        mullion,
        mark,
        const [Vec2(0, 1200), Vec2(900, 1200)],
      ]);
      expect(before.topLevelDividers, hasLength(3));

      final opened = before.openings.single.sectionId;
      final loose = before.topLevelDividers
          .firstWhere((bar) => bar.isHorizontal && bar.segment.midpoint.y > 1000);

      final after = DesignEdits.setDividerParent(before, loose.id, opened);

      expect(after.openings, hasLength(1),
          reason: 'the opening survives the line moving into it');
      final now = after.openings.single.sectionId;
      expect(after.childDividersOf(now), hasLength(1));
      expect(after.childSectionsOf(now), hasLength(2));
      expect(after.topLevelDividers, hasLength(2));
      expect(after.topLevelSections, hasLength(3));
    });
  });
}
