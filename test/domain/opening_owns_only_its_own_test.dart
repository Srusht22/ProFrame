import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/opening_leaf.dart';
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

// ┌──────────────────────────────┐
// │            FIXED             │
// ├────────────────┬─────────────┤
// │    OPENING >   │    FIXED    │
// └────────────────┴─────────────┘
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
const besideIt = [Vec2(1400, 800), Vec2(1400, 1600)];

Design design() => read([frame, transom, mullion, mark, besideIt]);

void main() {
  group('the opening has a boundary of its own', () {
    test('it is the section, never the window', () {
      final made = design();
      final opening = openingOf(made);
      final daylight = made.frame!.innerOutline;

      final leaf = OpeningLeaf.of(made, made.openings.single)!;
      expect(leaf.outer.corners, opening.outline.corners);
      expect(leaf.outer.width, lessThan(daylight.width * 0.6));
      expect(leaf.outer.height, lessThan(daylight.height * 0.6));
      // And it sits where the mark is, not over the whole design.
      expect(leaf.outer.contains(const Vec2(620, 1200)), isTrue);
      expect(leaf.outer.contains(const Vec2(1400, 400)), isFalse);
    });

    test('the leaf has its own frame inside that boundary', () {
      final made = design();
      final leaf = OpeningLeaf.of(made, made.openings.single)!;

      expect(leaf.inner, isNotNull);
      expect(leaf.inner!.area, lessThan(leaf.outer.area));
      expect(leaf.inner!.width, lessThan(leaf.outer.width));
      // And the frame between them is the leaf's own profile, all round.
      final profile = OpeningLeaf.profileFor(made.frame!);
      expect(leaf.inner!.width, closeTo(leaf.outer.width - profile * 2, 1));
      expect(leaf.inner!.height, closeTo(leaf.outer.height - profile * 2, 1));
    });

    test('the drawing and the solid describe one leaf', () {
      // Both views read OpeningLeaf, so the leaf in the elevation and the
      // leaf that swings are the same shape, to the millimetre.
      final made = design();
      final section = openingOf(made);
      final frameOf = made.frame!;

      expect(
        OpeningLeaf.innerOf(section, frameOf)!.corners,
        section.outline.inset(OpeningLeaf.profileFor(frameOf)).corners,
      );
    });

    test('a leaf too small to have a daylight has none, rather than a bad one',
        () {
      final made = design();
      final tiny = SectionElement(
        id: 'tiny',
        outline: Polygon.rect(0, 0, 20, 20),
      );
      expect(OpeningLeaf.innerOf(tiny, made.frame!), isNull);
    });
  });

  group('what is outside the opening is not the opening’s', () {
    test('the frame and the fixed sections are nobody’s children', () {
      final made = design();
      final opening = openingOf(made);

      for (final section in made.topLevelSections) {
        expect(section.parentId, isNull);
      }
      expect(made.descendantsOf(opening.id), isEmpty,
          reason: 'nothing has been drawn inside it yet');
      // The frame is not a section at all, so it cannot be a child of one.
      expect(made.sectionById(made.frame!.id), isNull);
    });

    test('a bar in the section beside it cannot be made its child', () {
      final made = design();
      final opening = openingOf(made);
      final outside = made.topLevelDividers
          .firstWhere((bar) => bar.isVertical && bar.segment.midpoint.x > 1200);

      // It is not offered.
      expect(
        DesignEdits.containersFor(made, outside.id).map((s) => s.id),
        isNot(contains(opening.id)),
      );

      // And it is refused if asked for anyway.
      final after = DesignEdits.setDividerParent(made, outside.id, opening.id);
      expect(
        after.dividers.firstWhere((b) => b.id == outside.id).parentId,
        isNull,
      );
      expect(after.childDividersOf(opening.id), isEmpty);
    });

    test('and so the opening cannot drag it about', () {
      final made = design();
      final opening = openingOf(made);
      final outside = made.topLevelDividers
          .firstWhere((bar) => bar.isVertical && bar.segment.midpoint.x > 1200);
      final was = outside.segment.midpoint.x;

      final forced =
          DesignEdits.setDividerParent(made, outside.id, opening.id);
      // Move the mullion, which changes the opening's size.
      final moved = DesignEdits.moveDivider(
        forced,
        made.topLevelDividers
            .firstWhere((bar) => bar.isVertical && bar.segment.midpoint.x < 1000)
            .id,
        const Vec2(-200, 0),
      );

      expect(
        moved.dividers.firstWhere((b) => b.id == outside.id).segment.midpoint.x,
        closeTo(was, 1),
        reason: 'a bar in the fixed light is nothing to do with the opening',
      );
    });

    test('a bar inside the opening is still offered and accepted', () {
      final made = design();
      final opening = openingOf(made);

      final withBar = DesignEdits.addLineInside(
        made,
        opening.id,
        id: 'inner',
        at: Vec2(opening.outline.centroid.x, opening.outline.top + 200),
        horizontal: true,
      );

      expect(withBar.childDividersOf(opening.id), hasLength(1));
      // The design outside the opening is untouched: the transom, the
      // mullion and the bar in the right-hand light all still divide it,
      // and the four main sections are still four.
      expect(withBar.topLevelSections, hasLength(4));
      expect(withBar.topLevelDividers, hasLength(3));
    });
  });

  group('editing the opening leaves everything outside it alone', () {
    /// Everything about a section that a change elsewhere must not touch.
    String fingerprint(SectionElement section) =>
        '${section.outline.corners}|${section.finish.colour}'
        '|${section.finish.material}|${section.parentId}';

    test('putting a bar inside it changes nothing outside it', () {
      final before = design();
      final opening = openingOf(before);
      final others = {
        for (final section in before.topLevelSections)
          if (section.id != opening.id) section.id: fingerprint(section),
      };

      final after = DesignEdits.addLineInside(
        before,
        opening.id,
        id: 'inner',
        at: Vec2(opening.outline.centroid.x, opening.outline.top + 200),
        horizontal: true,
      );

      for (final entry in others.entries) {
        expect(fingerprint(after.sectionById(entry.key)!), entry.value,
            reason: '${entry.key} must be untouched');
      }
      // And the opening itself kept its own boundary.
      expect(
        after.sectionById(opening.id)!.outline.corners,
        opening.outline.corners,
      );
    });

    test('changing its direction changes nothing outside it', () {
      final before = design();
      final opening = openingOf(before);
      final others = {
        for (final section in before.topLevelSections)
          if (section.id != opening.id) section.id: fingerprint(section),
      };

      final after = DesignEdits.setOpeningMechanism(
        before,
        before.openings.single.id,
        OpeningMechanism.topHung,
      );

      expect(after.openings.single.mechanism, OpeningMechanism.topHung);
      for (final entry in others.entries) {
        expect(fingerprint(after.sectionById(entry.key)!), entry.value);
      }
    });

    test('its hardware never lands outside its own boundary', () {
      final made = design();
      final opening = openingOf(made);
      final box = opening.outline;

      final mine = [
        for (final piece in made.hardware)
          if (piece.parentId == opening.id) piece,
      ];
      expect(mine, isNotEmpty);
      for (final piece in mine) {
        expect(piece.at.x, greaterThanOrEqualTo(box.left - 1));
        expect(piece.at.x, lessThanOrEqualTo(box.right + 1));
        expect(piece.at.y, greaterThanOrEqualTo(box.top - 1));
        expect(piece.at.y, lessThanOrEqualTo(box.bottom + 1));
      }
    });
  });
}
