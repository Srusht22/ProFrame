import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sections/section_builder.dart';

// A line that encloses nothing still leaves the design whole.
//
// A line hanging from one end, a line touching nothing at all, a line drawn
// right past the sill: none of them closes a region, so none of them makes
// a section. What they must never do is take the sections that *are* there
// with them. A door with a line drawn in the lower half came back with no
// sections at all — no leaf, no opening, nothing to draw and nothing to
// build — because the bar's own body was found by asking whether the
// middle of a face fell inside it, and the middle of a daylight with a slot
// down it falls in the slot.

Design design(List<DividerElement> dividers) => SectionBuilder.rebuild(Design(
      id: 'd',
      name: 'Door',
      kind: DesignKind.door,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      frame: FrameElement(
        id: 'f',
        outline: Polygon.rect(0, 0, 1343, 1720),
        profileMm: 60,
      ),
      dividers: dividers,
    ));

DividerElement bar(String id, Vec2 a, Vec2 b) =>
    DividerElement(id: id, a: a, b: b, widthMm: 48);

void main() {
  group('a line that closes no region leaves the design whole', () {
    final cases = <String, List<DividerElement>>{
      'hanging from nothing at the top, and past the sill':
          [bar('b', const Vec2(671, 713), const Vec2(671, 1712))],
      'hanging from nothing at the top, and short of the sill':
          [bar('b', const Vec2(671, 713), const Vec2(671, 1500))],
      'hanging from nothing at the bottom':
          [bar('b', const Vec2(671, 200), const Vec2(671, 900))],
      'touching nothing at either end':
          [bar('b', const Vec2(500, 700), const Vec2(900, 700))],
      'drawn right across, past both jambs':
          [bar('b', const Vec2(-40, 713), const Vec2(1400, 713))],
    };

    cases.forEach((what, dividers) {
      test('a line $what', () {
        final made = design(dividers);

        expect(made.topLevelSections, isNotEmpty,
            reason: 'the daylight is still there to be drawn');
        // Nothing is lost: the line the user drew is still in the design,
        // exactly where they drew it.
        final drawn = made.dividerById('b')!;
        expect(drawn.a, dividers.single.a);
        expect(drawn.b, dividers.single.b);
      });
    });

    test('a line right across makes two sections; one that hangs makes one',
        () {
      expect(
        design([bar('b', const Vec2(0, 713), const Vec2(1343, 713))])
            .topLevelSections,
        hasLength(2),
      );
      expect(
        design([bar('b', const Vec2(671, 713), const Vec2(671, 1712))])
            .topLevelSections,
        hasLength(1),
      );
    });

    test('and the same is true drawn, not constructed', () {
      // The route the user actually takes. This is where it was first seen:
      // a short line dropped in the middle of a door, touching nothing, and
      // the whole design went with it.
      const drawn = <String, (Vec2, Vec2)>{
        'a short line floating in the middle':
            (Vec2(600, 800), Vec2(660, 800)),
        'a short upright floating in the middle':
            (Vec2(600, 800), Vec2(600, 860)),
        'a short diagonal floating in the middle':
            (Vec2(600, 800), Vec2(660, 860)),
        'a line from one jamb, stopping half way':
            (Vec2(60, 800), Vec2(700, 800)),
        'a long diagonal that reaches neither edge':
            (Vec2(100, 100), Vec2(1200, 1600)),
        'a line lying along the sill':
            (Vec2(60, 1660), Vec2(1283, 1660)),
      };

      drawn.forEach((what, ends) {
        final after = DesignEdits.addDivider(design(const []),
            id: 'drawn', a: ends.$1, b: ends.$2);

        expect(after.topLevelSections, isNotEmpty, reason: what);
        final bar = after.dividerById('drawn');
        expect(bar, isNotNull, reason: '$what — the line is never lost');
        expect(bar!.a, ends.$1, reason: what);
        expect(bar.b, ends.$2, reason: what);
      });
    });

    test('and two of them at once are still two lines and one daylight', () {
      var made = DesignEdits.addDivider(design(const []),
          id: 'one', a: const Vec2(400, 700), b: const Vec2(500, 700));
      made = DesignEdits.addDivider(made,
          id: 'two', a: const Vec2(800, 1100), b: const Vec2(900, 1100));

      expect(made.topLevelSections, hasLength(1));
      expect(made.dividers, hasLength(2));
    });

    test('no section is a bar’s own material', () {
      // The two crossing bars cut the daylight into four. The bodies of the
      // bars themselves are not among the sections.
      final made = design([
        bar('across', const Vec2(0, 713), const Vec2(1343, 713)),
        bar('down', const Vec2(671, 0), const Vec2(671, 1720)),
      ]);

      expect(made.topLevelSections, hasLength(4));
      for (final section in made.topLevelSections) {
        for (final id in const ['across', 'down']) {
          final body = made.dividerById(id)!.segment;
          expect(section.outline.awayFrom(body.midpoint), greaterThan(1),
              reason: '${section.id} is daylight, not the bar itself');
        }
      }
    });
  });
}
