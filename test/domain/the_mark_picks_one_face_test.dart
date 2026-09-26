import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/recognition/opening_symbol.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The phase's own drawing, drawn rather than built, so the whole reading is
// under test:
//
//   ┌──────────────────────────┐
//   │         FIXED            │
//   ├──────────────┬───────────┤
//   │      >       │   FIXED   │
//   │   OPENING    │           │
//   └──────────────┴───────────┘
//
// Three closed faces. The mark is in the lower left. Only the lower left
// opens — not the rectangle, not the upper face, not the right face, and not
// everything connected to it.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// The frame, a transom, and a mullion below the transom — and wherever the
/// caller puts the mark.
Design sheet(List<Vec2> mark, {String id = 'mark'}) {
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
      pen(id, mark),
    ]),
  );
}

/// A `>` about [at], drawn the size of a hand.
List<Vec2> chevron(Vec2 at, {double size = 150}) => [
      Vec2(at.x - size / 2, at.y - size),
      Vec2(at.x + size / 2, at.y),
      Vec2(at.x - size / 2, at.y + size),
    ];

Design read(Design design) => SketchInterpreter.interpret(design).design;

SectionElement faceAt(Design design, Vec2 point) => design.topLevelSections
    .firstWhere((s) => s.outline.contains(point));

void main() {
  group('the mark picks the face it is in', () {
    test('the drawing has three faces, and the mark is in one of them', () {
      final design = read(sheet(chevron(const Vec2(600, 1250))));

      expect(design.topLevelSections, hasLength(3));
      expect(design.openings, hasLength(1));

      final opened = design.sectionById(design.openings.single.sectionId)!;
      final lowerLeft = faceAt(design, const Vec2(600, 1250));
      expect(opened.id, lowerLeft.id);
      expect(opened.outline.contains(const Vec2(600, 1250)), isTrue);
    });

    test('not the whole rectangle', () {
      final design = read(sheet(chevron(const Vec2(600, 1250))));
      final opened = design.sectionById(design.openings.single.sectionId)!;
      final daylight = design.frame!.innerOutline;

      expect(opened.outline.area, lessThan(daylight.area * 0.45));
      expect(opened.outline.width, lessThan(daylight.width * 0.65));
      expect(opened.outline.height, lessThan(daylight.height * 0.75));
    });

    test('not the upper face and not the right face', () {
      final design = read(sheet(chevron(const Vec2(600, 1250))));
      final opened = design.openings.single.sectionId;

      expect(opened, isNot(faceAt(design, const Vec2(1200, 300)).id));
      expect(opened, isNot(faceAt(design, const Vec2(1900, 1250)).id));
      for (final section in design.topLevelSections) {
        expect(design.openingOf(section.id) != null, section.id == opened);
      }
    });

    test('not everything connected to it', () {
      final design = read(sheet(chevron(const Vec2(600, 1250))));

      // The transom and the mullion both bound the opened face, and neither
      // is the opening's: they divide the design.
      expect(design.topLevelDividers, hasLength(2));
      for (final bar in design.dividers) {
        expect(bar.parentId, isNull);
      }
      expect(design.childSectionsOf(design.openings.single.sectionId),
          isEmpty);
    });

    test('the direction the mark points is what is stored', () {
      final right = read(sheet(chevron(const Vec2(600, 1250))));
      expect(right.openings.single.markGlyph, '>');
      expect(right.openings.single.mechanism, OpeningMechanism.hingedLeft);

      final left = read(sheet([
        const Vec2(675, 1100),
        const Vec2(525, 1250),
        const Vec2(675, 1400),
      ]));
      expect(left.openings.single.markGlyph, '<');
      expect(left.openings.single.mechanism, OpeningMechanism.hingedRight);
    });

    test('each of the three faces can be the one, and only ever one', () {
      for (final at in const [
        (Vec2(1200, 300), 'the upper light'),
        (Vec2(600, 1250), 'the lower left'),
        (Vec2(1900, 1250), 'the lower right'),
      ]) {
        final design = read(sheet(chevron(at.$1)));
        expect(design.openings, hasLength(1), reason: at.$2);
        expect(
          design.sectionById(design.openings.single.sectionId)!
              .outline
              .contains(at.$1),
          isTrue,
          reason: at.$2,
        );
      }
    });
  });

  group('no face holds it, so nothing opens', () {
    test('a mark right off the design opens nothing and asks once', () {
      final read = SketchInterpreter.interpret(
        sheet(chevron(const Vec2(3400, 900))),
      );
      expect(read.design.openings, isEmpty);
      expect(read.questions.map((q) => q.id), ['symbol-mark']);
    });

    test('a mark on a bar is still in the face holding the rest of it', () {
      // Its middle sits on the mullion; its point and both ends are in the
      // lower left. That is containment of the mark, not nearness to a line.
      final design = read(sheet(const [
        Vec2(1280, 1130),
        Vec2(1430, 1250),
        Vec2(1280, 1370),
      ]));

      expect(design.openings, hasLength(1));
      final opened = design.sectionById(design.openings.single.sectionId)!;
      expect(opened.outline.contains(const Vec2(600, 1250)), isTrue);
      expect(opened.outline.contains(const Vec2(1900, 1250)), isFalse);
    });

    test('the nearest face is never the answer', () {
      // A mark inside the frame ring — in the profile, in no face at all.
      // Nearness to a face would open one; containment opens none.
      final read = SketchInterpreter.interpret(sheet(
        chevron(const Vec2(25, 900), size: 14),
        id: 'in-the-frame',
      ));

      for (final opening in read.design.openings) {
        final face = read.design.sectionById(opening.sectionId);
        expect(face, isNotNull);
        expect(
          face!.outline.contains(opening.markAt!),
          isTrue,
          reason: 'an opening was made on a face the mark is not in',
        );
      }
    });
  });

  group('the smallest face containing it, not the first', () {
    test('a mark on the line between two faces takes the smaller', () {
      final at = DateTime(2026);
      // Two faces, deliberately unequal, sharing an edge at x = 900. The
      // point is exactly on that edge, so it is inside both.
      final design = Design(
        id: 'd',
        name: 'test',
        kind: DesignKind.window,
        createdAt: at,
        updatedAt: at,
        frame: FrameElement(
          id: 'f',
          outline: Polygon.rect(0, 0, 2400, 1800),
          profileMm: 50,
        ),
        sections: const [
          // The larger one first, so "the first containing it" would be wrong.
          SectionElement(id: 'wide', outline: Polygon([
            Vec2(900, 50), Vec2(2350, 50), Vec2(2350, 1750), Vec2(900, 1750),
          ])),
          SectionElement(id: 'narrow', outline: Polygon([
            Vec2(50, 50), Vec2(900, 50), Vec2(900, 1750), Vec2(50, 1750),
          ])),
        ],
      );

      const symbol = OpeningSymbol(
        strokeId: 's',
        apex: Vec2(960, 900),
        armA: Vec2(840, 810),
        armB: Vec2(840, 990),
        direction: SymbolDirection.pointsRight,
      );
      expect(symbol.centre.x, closeTo(880, 1));

      final chosen = SketchInterpreter.sectionFor(design, symbol);
      expect(chosen, isNotNull);
      expect(chosen!.id, 'narrow');
      expect(design.sectionById('wide')!.outline.contains(symbol.centre),
          isFalse);
    });

    test('a pane of an opening is not a face of the design', () {
      // The mark opened this section; the user then divided it. Reading the
      // sheet again must not find the mark inside a pane it caused and
      // shrink the opening to it.
      var design = read(sheet(chevron(const Vec2(600, 1250))));
      final openingId = design.openings.single.sectionId;
      final was = design.sectionById(openingId)!.outline;

      final box = was;
      design = design.copyWith(dividers: [
        ...design.dividers,
        DividerElement(
          id: 'inner',
          a: Vec2(box.left, box.top + 300),
          b: Vec2(box.right, box.top + 300),
          widthMm: 30,
          parentId: openingId,
        ),
      ]);
      design = read(design);

      expect(design.childSectionsOf(design.openings.single.sectionId),
          hasLength(2));
      final now = design.sectionById(design.openings.single.sectionId)!;
      expect(now.outline.width, closeTo(was.width, 0.01));
      expect(now.outline.height, closeTo(was.height, 0.01));
    });
  });
}
