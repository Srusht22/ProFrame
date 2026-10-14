import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import 'geometry_normalizer_test.dart' show pen;

// Normalisation keeps the hierarchy. When the reading corrects the frame —
// on the first reading, on a later one, and when a figure the user states
// moves it again — everything the user built inside an opening stays the
// opening's: its divider inside it and its child, its glass and its panel
// inside it and its panes, its handle and its hinges on its leaf and its
// children. Nothing is left in the frame's old coordinates, and nothing
// inside the opening becomes a line of the design.

/// A door drawn by hand and not quite square — the head sloping, every
/// side a little out — with a mullion and a `>` in the left light.
Design drawn(DesignKind kind) =>
    Design.empty(id: 'design', kind: kind).copyWith(
      customerId: 'customer',
      sketch: Sketch(
        strokes: [
          pen('outline', const [
            Vec2(2, 6),
            Vec2(1212, 150),
            Vec2(1192, 2000),
            Vec2(5, 1990),
            Vec2(2, 6),
          ]),
          pen('mullion', const [Vec2(600, 70), Vec2(606, 1994)]),
          pen('mark', chevron(const Vec2(300, 1000))),
        ],
      ),
    );

/// The sheet read, as the workspace reads it: sizes the user gave kept.
Design readSheet(Design d) =>
    Measurements.keepAfterReading(d, SketchInterpreter.interpret(d).design);

/// [design] with its opening divided by a line [down] millimetres below its
/// top, the lower pane a brown panel — and, in a design begun as holding
/// both, the leaf said to be a door, so it has its handle.
Design built(Design design, {double down = 600}) {
  var d = design;
  if (d.kind == DesignKind.both) {
    d = OpeningHardware.settle(
      d.copyWith(
        openings: [
          for (final o in d.openings) o.copyWith(kind: DesignKind.door),
        ],
      ),
    );
  }
  final opening = d.openings.single;
  final box = d.sectionById(opening.sectionId)!.outline;
  d = DesignEdits.addLineInside(
    d,
    opening.sectionId,
    id: 'inside',
    at: Vec2(box.centroid.x, box.top + down),
    horizontal: true,
  );
  final lower = d
      .childSectionsOf(opening.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return d.withElement(
    lower.copyWith(
      finish: const Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel),
    ),
  );
}

bool square(Segment s) =>
    (s.a.x - s.b.x).abs() < 1e-6 || (s.a.y - s.b.y).abs() < 1e-6;

/// Whether [p] is inside [shape], or within [slack] of it.
bool within(Polygon shape, Vec2 p, {double slack = 1e-6}) =>
    shape.contains(p) || shape.awayFrom(p) <= slack;

/// The opening's region, the frame's daylight and the mullion bound it, and
/// it holds its own mark.
void expectOpeningInPlace(Design d, String why) {
  final opening = d.openings.single;
  final section = d.sectionById(opening.sectionId)!;
  expect(section.parentId, isNull, reason: '$why: a main division');
  final daylight = d.frame!.innerOutline;
  final region = section.outline;
  expect(region.top, closeTo(daylight.top, 1e-6), reason: '$why: head');
  expect(region.bottom, closeTo(daylight.bottom, 1e-6), reason: '$why: sill');
  expect(region.left, closeTo(daylight.left, 1e-6), reason: '$why: jamb');
  final mullion = d.topLevelDividers.single;
  expect(
    region.right,
    closeTo(mullion.segment.midpoint.x - mullion.widthMm / 2, 1e-6),
    reason: '$why: the mullion\'s face',
  );
  if (opening.markAt case final mark?) {
    expect(region.contains(mark), isTrue, reason: '$why: its own mark');
  }
}

/// Every relationship the brief names, true of [d].
void expectHierarchy(Design d, String why, {int lines = 1}) {
  // The frame corrected.
  for (final edge in d.frame!.outline.edges) {
    expect(square(edge), isTrue, reason: '$why: frame $edge');
  }
  expectOpeningInPlace(d, why);
  final opening = d.openings.single;
  final region = d.sectionById(opening.sectionId)!.outline;

  // The design's own lines: the mullion and nothing else.
  expect(d.topLevelDividers, hasLength(1), reason: '$why: no line promoted');

  // The divider: the opening's child, inside it.
  final inside = [
    for (final bar in d.dividers)
      if (bar.parentId != null) bar,
  ];
  expect(inside, hasLength(lines), reason: why);
  for (final bar in inside) {
    expect(d.openingHolding(bar.parentId)?.id, opening.id, reason: why);
    expect(
      region.holds(bar.segment, reach: 1e-6),
      isTrue,
      reason: '$why: $bar',
    );
    expect(square(bar.segment), isTrue, reason: '$why: ${bar.segment}');
  }

  // The panes: the opening's, inside it — glass above, the panel below.
  final panes = d.childSectionsOf(opening.sectionId);
  expect(panes, hasLength(lines + 1), reason: why);
  for (final pane in panes) {
    expect(d.openingHolding(pane.parentId)?.id, opening.id, reason: why);
    for (final corner in pane.outline.corners) {
      expect(within(region, corner), isTrue, reason: '$why: pane $corner');
    }
  }
  final top = panes.reduce((a, b) => a.outline.top < b.outline.top ? a : b);
  final bottom = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  expect(top.finish.material.isGlazing, isTrue, reason: '$why: glass above');
  expect(bottom.finish.material, MaterialKind.panel, reason: '$why: panel');
  expect(bottom.finish.colour, 0xFF7B4A2B, reason: why);

  // The handle and the hinges: the opening's, on its leaf.
  final kinds = <HardwareKind>{};
  for (final piece in d.hardware) {
    expect(d.openingHolding(piece.parentId)?.id, opening.id, reason: why);
    expect(
      within(region, piece.at, slack: d.frame!.profileMm),
      isTrue,
      reason: '$why: ${piece.kind.name} at ${piece.at}, leaf $region',
    );
    kinds.add(piece.kind);
  }
  expect(kinds, contains(HardwareKind.hinge), reason: why);
  expect(kinds.where((k) => k.isHandle), isNotEmpty, reason: why);

  // And the model's own answer agrees: all of it is in the opening.
  final contents = {for (final e in d.contentsOf(opening)) e.id};
  expect(
    contents,
    containsAll([
      for (final b in inside) b.id,
      for (final p in panes) p.id,
      for (final h in d.hardware) h.id,
    ]),
    reason: why,
  );

  // The solid builds the glass and the panel inside the opening.
  final paneIds = {for (final p in panes) p.id};
  for (final facet in MeshBuilder.build(d).facets) {
    if (!paneIds.contains(facet.elementId)) continue;
    for (final c in facet.corners) {
      expect(
        within(region, Vec2(c.x, c.y), slack: 1e-3),
        isTrue,
        reason: '$why: solid pane at $c',
      );
    }
  }
}

/// How far [d]'s internal divider is below its opening's top.
double downTheOpening(Design d) {
  final region = d.sectionById(d.openings.single.sectionId)!.outline;
  final bar = d.dividers.firstWhere((b) => b.id == 'inside');
  return bar.segment.midpoint.y - region.top;
}

void main() {
  const kinds = [DesignKind.door, DesignKind.window, DesignKind.both];

  for (final kind in kinds) {
    group(kind.label, () {
      test('the frame corrected on the first reading: the opening, its '
          'divider, glass, panel, handle and hinges built inside it', () {
        final first = readSheet(drawn(kind));
        final why = '${kind.name}, first reading';
        // The reading did correct it: the head was drawn sloping.
        final head = first.frame!.outline.top;
        expect(head, greaterThan(6));
        expect(head, lessThan(150));
        expectHierarchy(built(first), why);
      });

      test('read again: every relationship, and every position, the '
          'same', () {
        final before = built(readSheet(drawn(kind)));
        final again = readSheet(before);
        expectHierarchy(again, '${kind.name}, read again');
        expect(again.frame!.outline, before.frame!.outline);
        expect(
          again.dividers.firstWhere((b) => b.id == 'inside').segment,
          before.dividers.firstWhere((b) => b.id == 'inside').segment,
        );
      });

      test('the frame corrected again by a figure the user states: the '
          'opening grows with it and takes its contents along', () {
        final before = built(readSheet(drawn(kind)));
        // The left side, as drawn, stated: the head goes to its top.
        final stated = before.copyWith(
          dimensions: [
            const DimensionElement(
              id: 'left',
              a: Vec2(2, 6),
              b: Vec2(2, 1990),
              offsetMm: 0,
              statedMm: 1984,
            ),
          ],
        );
        final after = readSheet(stated);
        final why = '${kind.name}, corrected again';
        expect(after.frame!.outline.top, 6, reason: why);
        expectHierarchy(after, why);
        // The opening is taller by what the frame grew — the head and the
        // sill both went to the figure's ends — and the line in it is still
        // between its glass and its panel, carried with it.
        final grewBy =
            after.frame!.outline.height - before.frame!.outline.height;
        expect(grewBy, greaterThan(0), reason: why);
        final was = before.sectionById(before.openings.single.sectionId)!;
        final now = after.sectionById(after.openings.single.sectionId)!;
        expect(
          now.outline.height,
          closeTo(was.outline.height + grewBy, 1e-6),
          reason: why,
        );
        final down = downTheOpening(after);
        expect(down, greaterThan(0));
        expect(down, lessThan(now.outline.height));
        expect(after.openings.single.id, before.openings.single.id);
        expect(after.id, 'design');
        expect(after.customerId, 'customer');
      });

      test('a line drawn on the sheet inside the opening — leaning and '
          'stopped short — is squared, joins the opening and stays its '
          'child through the frame being corrected again', () {
        final before = built(readSheet(drawn(kind)));
        final region = before
            .sectionById(before.openings.single.sectionId)!
            .outline;
        final y = region.top + 1300;
        final sheet = before.copyWith(
          sketch: Sketch(
            strokes: [
              ...before.sketch.strokes,
              pen('rail', [
                Vec2(region.left + 40, y),
                Vec2(region.right - 60, y + 18),
              ]),
            ],
          ),
        );
        final joined = readSheet(sheet);
        expectHierarchy(joined, '${kind.name}, rail drawn', lines: 2);
        final rail = joined.dividers.firstWhere(
          (b) => b.fromStrokeId == 'rail',
        );
        expect(rail.parentId, joined.openings.single.id);

        final corrected = readSheet(
          joined.copyWith(
            dimensions: [
              const DimensionElement(
                id: 'left',
                a: Vec2(2, 6),
                b: Vec2(2, 1990),
                offsetMm: 0,
                statedMm: 1984,
              ),
            ],
          ),
        );
        expectHierarchy(corrected, '${kind.name}, rail, corrected', lines: 2);
        expect(
          corrected.dividers
              .firstWhere((b) => b.fromStrokeId == 'rail')
              .parentId,
          corrected.openings.single.id,
        );
      });

      test('the sizes given in the form: the frame stretched to them, the '
          'opening and everything in it stretched with it', () {
        final before = built(readSheet(drawn(kind)));
        final given = Measurements.apply(before, {
          for (final m in Measurements.of(before))
            if (m.asked)
              m.key: switch (m.key) {
                Measurements.widthKey => 1400,
                Measurements.heightKey => 2100,
                _ => m.currentMm(before),
              },
        });
        expect(given.ok, isTrue, reason: '${given.problems}');
        expectHierarchy(given.design, '${kind.name}, sized');
        expectHierarchy(readSheet(given.design), '${kind.name}, sized, read');
      });
    });
  }
}
