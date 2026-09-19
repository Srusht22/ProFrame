import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/sections/section_builder.dart';

Design build({
  double width = 1000,
  double height = 2000,
  List<DividerElement> dividers = const [],
}) {
  final at = DateTime(2026);
  return SectionBuilder.rebuild(Design(
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
  ));
}

DividerElement vertical(String id, double x, double height) =>
    DividerElement(id: id, a: Vec2(x, 0), b: Vec2(x, height), widthMm: 40);

void main() {
  test('the overall dimensions are the frame, exactly', () {
    final chains = DimensionChains.of(build(width: 1234, height: 2345));
    final across = chains.firstWhere(
      (c) => c.axis == DimensionAxis.horizontal && c.runs.first.note == 'Overall',
    );
    expect(across.runs.single.valueMm, closeTo(1234, 0.01));

    final down = chains.firstWhere(
      (c) => c.axis == DimensionAxis.vertical && c.runs.first.note == 'Overall',
    );
    expect(down.runs.single.valueMm, closeTo(2345, 0.01));
  });

  test('daylight bands measure the sections that are there', () {
    final design = build(dividers: [vertical('m', 320, 2000)]);
    final chains = DimensionChains.of(design);
    final bands = chains.firstWhere(
      (c) =>
          c.axis == DimensionAxis.horizontal && c.runs.first.note == 'Daylight',
    );
    expect(bands.runs, hasLength(2));

    final measured = [for (final r in bands.runs) r.valueMm]..sort();
    final actual = [for (final s in design.sections) s.widthMm]..sort();
    for (var i = 0; i < measured.length; i++) {
      expect(measured[i], closeTo(actual[i], 0.01));
    }
  });

  test('unequal bands are reported unequal, not averaged', () {
    final design = build(dividers: [
      vertical('a', 220, 2000),
      vertical('b', 560, 2000),
    ]);
    final bands = DimensionChains.of(design).firstWhere(
      (c) =>
          c.axis == DimensionAxis.horizontal && c.runs.first.note == 'Daylight',
    );
    final widths = [for (final r in bands.runs) r.valueMm.round()]..sort();
    expect(widths.toSet(), hasLength(3));
  });

  test('a design with a diagonal gets no bands, because they would lie', () {
    final design = build(dividers: [
      const DividerElement(
        id: 'd',
        a: Vec2(0, 0),
        b: Vec2(1000, 2000),
        widthMm: 40,
      ),
    ]);
    expect(DimensionChains.isRectilinear(design), isFalse);
    final chains = DimensionChains.of(design);
    expect(chains.every((c) => c.runs.first.note == 'Overall'), isTrue);
  });

  test('nothing is dimensioned when there is no frame', () {
    final at = DateTime(2026);
    final empty = Design(
      id: 'd',
      name: 'x',
      kind: DesignKind.door,
      createdAt: at,
      updatedAt: at,
    );
    expect(DimensionChains.of(empty), isEmpty);
  });

  test('reading the dimensions does not touch the design', () {
    final design = build(dividers: [vertical('m', 320, 2000)]);
    final before = design.toJson().toString();
    DimensionChains.of(design);
    expect(design.toJson().toString(), before);
  });
}
