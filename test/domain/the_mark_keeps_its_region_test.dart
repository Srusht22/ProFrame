import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The phase's drawing:
//
//   ┌────────────────────────┐
//   │        FIXED           │
//   ├──────────┬─────────────┤
//   │          │             │
//   │    >     │    FIXED    │
//   │ OPENING  │             │
//   │          │             │
//   └──────────┴─────────────┘
//
// Only the region containing the > opens. The root window never does, and the
// surrounding regions stay fixed — when it is read, and afterwards, through
// every edit that moves the ground under the mark.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// A `>` about [at], drawn the size of a hand. [right] false draws a `<`.
List<Vec2> chevron(Vec2 at, {double size = 150, bool right = true}) => [
      Vec2(at.x + (right ? -size / 2 : size / 2), at.y - size),
      Vec2(at.x + (right ? size / 2 : -size / 2), at.y),
      Vec2(at.x + (right ? -size / 2 : size / 2), at.y + size),
    ];

Design sheet(List<Vec2> mark) {
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
      pen('transom', const [Vec2(0, 700), Vec2(2400, 700)]),
      pen('mullion', const [Vec2(1400, 700), Vec2(1400, 1800)]),
      pen('mark', mark),
    ]),
  );
}

Design read(Design design) => SketchInterpreter.interpret(design).design;

const lowerLeft = Vec2(600, 1250);
const upper = Vec2(1200, 300);
const lowerRight = Vec2(1900, 1250);

Design example() => read(sheet(chevron(lowerLeft)));

SectionElement openedIn(Design design) =>
    design.sectionById(design.openings.single.sectionId)!;

SectionElement faceAt(Design design, Vec2 point) => design.topLevelSections
    .firstWhere((s) => s.outline.contains(point));

DividerElement barOf(Design design, {required bool vertical}) =>
    design.topLevelDividers.firstWhere((d) => d.isVertical == vertical);

void main() {
  group('the region containing the symbol is the one that opens', () {
    test('three regions, one opening, and it is the marked one', () {
      final design = example();

      expect(design.topLevelSections, hasLength(3));
      expect(design.openings, hasLength(1));
      expect(openedIn(design).id, faceAt(design, lowerLeft).id);
      expect(openedIn(design).outline.contains(lowerLeft), isTrue);
    });

    test('the root window is not the opening', () {
      final design = example();
      final opening = design.openings.single;

      expect(opening.sectionId, isNot(design.id));
      expect(opening.sectionId, isNot(design.frame!.id));
      expect(design.sectionById(design.frame!.id), isNull);
      expect(openedIn(design).outline.area,
          lessThan(design.frame!.innerOutline.area * 0.45));
    });

    test('the surrounding regions stay fixed', () {
      final design = example();
      final opened = openedIn(design).id;

      for (final section in design.topLevelSections) {
        expect(design.openingOf(section.id) != null, section.id == opened,
            reason: '${section.id} is on the wrong side of the mark');
      }
      expect(faceAt(design, upper).id, isNot(opened));
      expect(faceAt(design, lowerRight).id, isNot(opened));
    });

    test('the direction is the symbol the user drew', () {
      final right = read(sheet(chevron(lowerLeft)));
      expect(right.openings.single.markGlyph, '>');
      expect(right.openings.single.mechanism, OpeningMechanism.hingedLeft);

      final left = read(sheet(chevron(lowerLeft, right: false)));
      expect(left.openings.single.markGlyph, '<');
      expect(left.openings.single.mechanism, OpeningMechanism.hingedRight);
      expect(left.openings.single.sectionId, isNot(right.id));
      expect(openedIn(left).outline.contains(lowerLeft), isTrue);
    });

    test('no second opening is invented anywhere', () {
      for (final at in const [lowerLeft, upper, lowerRight]) {
        final design = read(sheet(chevron(at)));
        expect(design.openings, hasLength(1), reason: '$at');
        expect(openedIn(design).outline.contains(at), isTrue, reason: '$at');
      }
    });
  });

  group('none of the forbidden regions is ever the answer', () {
    test('not the outer rectangle and not the whole drawing', () {
      final design = example();
      final daylight = design.frame!.innerOutline;
      final opened = openedIn(design).outline;

      expect(opened, isNot(daylight));
      expect(opened, isNot(design.frame!.outline));
      expect(opened.width, lessThan(daylight.width * 0.65));
      expect(opened.height, lessThan(daylight.height * 0.75));
    });

    test('not the largest region — unless the mark is in the largest', () {
      final design = example();
      final largest = design.topLevelSections
          .reduce((a, b) => a.areaMmSq > b.areaMmSq ? a : b);
      expect(design.openingOf(largest.id), isNull,
          reason: 'the largest region opened without being marked');

      // And the rule is containment, not size: marked, the largest opens.
      final marked = read(sheet(chevron(upper)));
      final biggest = marked.topLevelSections
          .reduce((a, b) => a.areaMmSq > b.areaMmSq ? a : b);
      expect(biggest.outline.contains(upper), isTrue,
          reason: 'this drawing no longer exercises the case');
      expect(marked.openings.single.sectionId, biggest.id);
    });

    test('not everything the symbol is connected to', () {
      final design = example();

      // Both bars bound the opened region and neither is the opening's: they
      // divide the design. Nor does the opening reach across either of them.
      expect(design.topLevelDividers, hasLength(2));
      for (final bar in design.dividers) {
        expect(bar.parentId, isNull);
      }
      final opened = openedIn(design).outline;
      expect(opened.contains(lowerRight), isFalse);
      expect(opened.contains(upper), isFalse);
    });
  });

  group('the mark keeps its region when the ground moves under it', () {
    /// Every edit must leave exactly one opening, on the region that holds
    /// the mark. Which region that is may change — the user moved the lines
    /// that make the regions — but it is never a region the mark is outside.
    void stillTheMarkedRegion(String what, Design after) {
      expect(after.openings, hasLength(1), reason: '$what: not one opening');
      final opening = after.openings.single;
      final on = after.sectionById(opening.sectionId);
      expect(on, isNotNull, reason: '$what: the opening is on nothing');
      expect(on!.outline.contains(opening.markAt!), isTrue,
          reason: '$what: the opening is on a region its mark is not in');
      expect(opening.sectionId, isNot(after.frame!.id), reason: what);
    }

    test('a bar dragged straight past the mark', () {
      final start = example();

      // The mullion goes left, past the mark: the mark is now in the region
      // to the right of it, and that is what opens. It used to be left
      // behind on the sliver the bar had cut off, with the mark outside it.
      stillTheMarkedRegion(
        'the mullion dragged left past the mark',
        DesignEdits.moveDivider(
            start, barOf(start, vertical: true).id, const Vec2(-1100, 0)),
      );
      stillTheMarkedRegion(
        'the transom dragged down past the mark',
        DesignEdits.moveDivider(
            start, barOf(start, vertical: false).id, const Vec2(0, 800)),
      );
    });

    test('a bar moved, deleted, or the design rescaled', () {
      final start = example();
      final mull = barOf(start, vertical: true).id;
      final tran = barOf(start, vertical: false).id;

      stillTheMarkedRegion('the mullion moved a little',
          DesignEdits.moveDivider(start, mull, const Vec2(300, 0)));
      stillTheMarkedRegion(
          'the mullion deleted', DesignEdits.delete(start, mull));
      stillTheMarkedRegion(
          'the transom deleted', DesignEdits.delete(start, tran));
      stillTheMarkedRegion('the design rescaled',
          DesignEdits.resizeFrame(start, widthMm: 3600, heightMm: 2700));
    });

    test('a rescale keeps the very same region, in proportion', () {
      final start = example();
      final was = openedIn(start);
      final share = was.areaMmSq / start.frame!.innerOutline.area;

      final after = DesignEdits.resizeFrame(start,
          widthMm: 3600, heightMm: 2700);

      // A rescale is not a re-cut: the mark travels with the design, so the
      // opening is the same region and the same fraction of the window.
      expect(after.openings.single.sectionId, start.openings.single.sectionId);
      expect(openedIn(after).areaMmSq / after.frame!.innerOutline.area,
          closeTo(share, 0.01));
      expect(after.openings.single.markAt, isNot(start.openings.single.markAt),
          reason: 'the mark did not travel with the design');
    });

    test('resizing the opening itself keeps it the opening', () {
      final start = example();
      final on = start.openings.single.sectionId;

      for (final step in <(String, Design)>[
        ('narrower', DesignEdits.setSectionWidth(start, on, 600)),
        ('shorter', DesignEdits.setSectionHeight(start, on, 600)),
      ]) {
        stillTheMarkedRegion('the opening made ${step.$1}', step.$2);
        expect(step.$2.openings.single.sectionId, on,
            reason: 'the opening walked off when it was made ${step.$1}');
      }
    });

    test('no edit invents an opening on a region nobody marked', () {
      final start = example();
      final mull = barOf(start, vertical: true).id;

      for (final after in [
        DesignEdits.moveDivider(start, mull, const Vec2(-1100, 0)),
        DesignEdits.delete(start, mull),
        DesignEdits.resizeFrame(start, heightMm: 2600),
        DesignEdits.setSectionWidth(start, start.openings.single.sectionId, 600),
      ]) {
        expect(after.openings, hasLength(1));
        final opened = after.openings.single.sectionId;
        for (final section in after.topLevelSections) {
          expect(after.openingOf(section.id) != null, section.id == opened);
        }
      }
    });
  });
}
