import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';

Design designWith({
  required double width,
  required double height,
  List<DividerElement> dividers = const [],
}) {
  final at = DateTime(2026);
  return Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, width, height),
      profileMm: 50,
    ),
    dividers: dividers,
  );
}

void main() {
  test('no dividers gives one section, the daylight opening', () {
    final built = SectionBuilder.rebuild(designWith(width: 1000, height: 2000));
    expect(built.sections, hasLength(1));
    expect(built.sections.single.widthMm, closeTo(900, 1));
    expect(built.sections.single.heightMm, closeTo(1900, 1));
  });

  test('an off-centre divider is not nudged to the middle', () {
    final built = SectionBuilder.rebuild(designWith(
      width: 1000,
      height: 2000,
      dividers: [
        DividerElement(
          id: 'm',
          a: const Vec2(320, 0),
          b: const Vec2(320, 2000),
          widthMm: 0.1,
        ),
      ],
    ));
    expect(built.sections, hasLength(2));
    final widths = [for (final s in built.sections) s.widthMm]..sort();
    expect(widths[0], closeTo(270, 1)); // 320 - 50 frame
    expect(widths[1], closeTo(630, 1)); // 950 - 320
  });

  test('a divider drawn past the frame is used only where it crosses', () {
    final built = SectionBuilder.rebuild(designWith(
      width: 1000,
      height: 2000,
      dividers: [
        DividerElement(
          id: 'm',
          a: const Vec2(400, -600),
          b: const Vec2(400, 2600),
          widthMm: 0.1,
        ),
      ],
    ));
    expect(built.sections, hasLength(2));
    for (final section in built.sections) {
      expect(section.outline.top, closeTo(50, 1));
      expect(section.outline.bottom, closeTo(1950, 1));
    }
  });

  test('a section keeps the colour the user gave it when a bar moves', () {
    var design = SectionBuilder.rebuild(designWith(
      width: 1000,
      height: 2000,
      dividers: [
        DividerElement(
          id: 'm',
          a: const Vec2(300, 0),
          b: const Vec2(300, 2000),
          widthMm: 0.1,
        ),
      ],
    ));

    // The user paints the right-hand section red.
    final right = design.sections
        .reduce((a, b) => a.outline.left > b.outline.left ? a : b);
    design = design.withElement(right.copyWith(
      finish: const Finish(colour: 0xFFCC0000, material: MaterialKind.panel),
    ));

    // Then drags the bar well over to the right.
    design = design.copyWith(dividers: [
      design.dividers.single.copyWith(a: const Vec2(700, 0), b: const Vec2(700, 2000)),
    ]);
    design = SectionBuilder.rebuild(design);

    final stillRight = design.sections
        .reduce((a, b) => a.outline.left > b.outline.left ? a : b);
    expect(stillRight.id, right.id);
    expect(stillRight.finish.colour, 0xFFCC0000);
    expect(stillRight.widthMm, closeTo(250, 1));
  });

  test('an opening on a section that no longer exists is dropped', () {
    var design = SectionBuilder.rebuild(designWith(
      width: 1000,
      height: 2000,
      dividers: [
        DividerElement(
          id: 'm',
          a: const Vec2(500, 0),
          b: const Vec2(500, 2000),
          widthMm: 0.1,
        ),
      ],
    ));
    design = design.copyWith(openings: [
      OpeningElement(
        id: 'o',
        sectionId: design.sections.first.id,
        mechanism: OpeningMechanism.hingedLeft,
        confirmed: true,
      ),
      const OpeningElement(
        id: 'ghost',
        sectionId: 'gone',
        mechanism: OpeningMechanism.hingedRight,
      ),
    ]);
    design = SectionBuilder.rebuild(design);
    expect(design.openings, hasLength(1));
    expect(design.openings.single.id, 'o');
  });

  test('sections read top to bottom then left to right', () {
    final built = SectionBuilder.rebuild(designWith(
      width: 1200,
      height: 2000,
      dividers: [
        DividerElement(
          id: 'v',
          a: const Vec2(400, 0),
          b: const Vec2(400, 2000),
          widthMm: 0.1,
        ),
        DividerElement(
          id: 'h',
          a: const Vec2(0, 600),
          b: const Vec2(1200, 600),
          widthMm: 0.1,
        ),
      ],
    ));
    expect(built.sections, hasLength(4));
    final order = [
      for (final s in built.sections)
        '${s.outline.top.round()}/${s.outline.left.round()}',
    ];
    expect(order, ['50/50', '50/400', '600/50', '600/400']);
  });

  test('tapping inside a section finds that section', () {
    final built = SectionBuilder.rebuild(designWith(
      width: 1000,
      height: 2000,
      dividers: [
        DividerElement(
          id: 'm',
          a: const Vec2(300, 0),
          b: const Vec2(300, 2000),
          widthMm: 0.1,
        ),
      ],
    ));
    final hit = SectionBuilder.sectionAt(built, const Vec2(600, 1000));
    expect(hit, isNotNull);
    expect(hit!.outline.left, closeTo(300, 1));
    expect(SectionBuilder.sectionAt(built, const Vec2(-50, 1000)), isNull);
  });
}
