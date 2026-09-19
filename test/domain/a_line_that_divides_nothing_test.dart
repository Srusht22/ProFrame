import 'package:flutter_test/flutter_test.dart';
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
