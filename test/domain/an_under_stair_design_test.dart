import 'dart:convert';

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
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import 'geometry_normalizer_test.dart' show pen;

// A window under a stair, in an Angled / Asymmetrical design:
//
//          ┌──────────────
//         /
//        /
//       /
//      │
//      │
//      └────────────────
//
// a short jamb on the left, the stair's slope running up from it to a level
// head, a tall jamb on the right. The user draws it; it is built as drawn —
// the slope kept, the two sides their own heights, the five-sided boundary
// five-sided — with a mullion dropped from the corner where the slope meets
// the head, an opening in the light under the slope, a line inside it, glass
// over a panel; given its real sizes; saved and opened again, and the same.

/// The under-stair outline: a 90 cm jamb on the left, the slope up to a
/// level head at 150 cm across, the head to the right jamb, 220 cm.
const stair = [
  Vec2(0, 2400),
  Vec2(0, 1500),
  Vec2(1500, 200),
  Vec2(2800, 200),
  Vec2(2800, 2400),
  Vec2(0, 2400),
];

/// The same, as a hand draws it: every side a little out, the slope
/// included.
const byHand = [
  Vec2(4, 2398),
  Vec2(-3, 1505),
  Vec2(1497, 206),
  Vec2(2803, 197),
  Vec2(2796, 2404),
  Vec2(4, 2398),
];

/// The design: the outline, a mullion down from the corner the slope meets
/// the head at, and a `>` in the light under the slope.
Design drawn({List<Vec2> outline = stair}) =>
    Design.empty(id: 'under-stair', kind: DesignKind.angled).copyWith(
      name: 'Under-stair Window',
      customerId: 'customer-1',
      sketch: Sketch(
        strokes: [
          pen('outline', outline),
          pen('mullion', [outline[2], Vec2(outline[2].x, outline[0].y)]),
          pen('mark', chevron(const Vec2(700, 1900))),
        ],
      ),
    );

Design readSheet(Design d) =>
    Measurements.keepAfterReading(d, SketchInterpreter.interpret(d).design);

/// The design read, said to be a window, its opening divided by a line
/// 40 cm up from the sill, glass above and a white panel below.
Design built({List<Vec2> outline = stair}) {
  var d = readSheet(drawn(outline: outline));
  d = OpeningHardware.settle(
    d.copyWith(
      openings: [
        for (final o in d.openings) o.copyWith(kind: DesignKind.window),
      ],
    ),
  );
  final opening = d.openings.single;
  final region = d.sectionById(opening.sectionId)!.outline;
  d = DesignEdits.addLineInside(
    d,
    opening.sectionId,
    id: 'inside',
    at: Vec2(region.centroid.x, region.bottom - 400),
    horizontal: true,
  );
  final lower = d
      .childSectionsOf(opening.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return d.withElement(lower.copyWith(finish: PanelColour.white.finish));
}

bool square(Segment s) => s.a.x == s.b.x || s.a.y == s.b.y;

/// The outline's corner nearest [p].
Vec2 near(Polygon outline, Vec2 p) =>
    outline.corners.reduce((a, b) => a.distanceTo(p) < b.distanceTo(p) ? a : b);

/// The five corners of an under-stair outline: the foot of the short jamb,
/// its top, the top of the slope, the head's far end and the tall jamb's
/// foot.
List<Vec2> cornersOf(Design d) => [
  for (final p in stair.take(5)) near(d.frame!.outline, p),
];

/// The design's whole text, for "the same" to mean the same.
String textOf(Design d) => jsonEncode(d.toJson());

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the shape is the one drawn', () {
    test('five sides, the slope, and two sides of their own heights — not '
        'a rectangle', () {
      final d = readSheet(drawn());
      final outline = d.frame!.outline;
      expect(outline.corners, hasLength(5));
      final [foot, jambTop, slopeTop, headEnd, tallFoot] = cornersOf(d);
      expect(jambTop, const Vec2(0, 1500));
      expect(slopeTop, const Vec2(1500, 200));
      // The short side 90 cm, the tall 220: never made equal.
      expect(foot.y - jambTop.y, 900);
      expect(tallFoot.y - headEnd.y, 2200);
      // The slope at the angle it was drawn.
      expect(Segment(jambTop, slopeTop).offAxisDegrees, closeTo(40.91, 0.01));
      expect(outline.edges.where((e) => !square(e)), hasLength(1));
      expect(outline.width, 2800);
    });

    test('drawn by hand, the wobble comes out and the slope stays', () {
      final d = readSheet(drawn(outline: byHand));
      final outline = d.frame!.outline;
      expect(outline.corners, hasLength(5));
      final sloped = outline.edges.where((e) => !square(e)).toList();
      expect(sloped, hasLength(1), reason: '$outline');
      expect(sloped.single.offAxisDegrees, closeTo(40.9, 0.5));
      final [foot, jambTop, _, headEnd, tallFoot] = cornersOf(d);
      expect(foot.y - jambTop.y, closeTo(900, 10));
      expect(tallFoot.y - headEnd.y, closeTo(2200, 10));
    });
  });

  group('what is built in it', () {
    test('the mullion from the slope\'s corner divides the two lights at its '
        'faces — neither light takes the mullion\'s own material', () {
      // The fault this phase found: a bar meeting the raked head ended in a
      // level cut, its face on the high side stopped short of the slope, and
      // the light beside it ran round into the bar — 4.8 cm of mullion
      // counted as glass.
      for (final x in [1500.0, 1300.0, 900.0]) {
        final yTop = 1500 - x / 1500 * 1300;
        final d = readSheet(
          Design.empty(id: 'm', kind: DesignKind.angled).copyWith(
            sketch: Sketch(
              strokes: [
                pen('outline', stair),
                pen('mullion', [Vec2(x, yTop), Vec2(x, 2400)]),
              ],
            ),
          ),
        );
        final bar = d.dividers.single;
        final half = bar.widthMm / 2;
        final mid = bar.segment.midpoint.x;
        final lights = d.topLevelSections.toList()
          ..sort((a, b) => a.outline.left.compareTo(b.outline.left));
        expect(lights, hasLength(2));
        // Each light reaches the mullion's face and not into it — to within
        // the weld that snaps a light's corner onto the frame's.
        final weld = 0.004 * Vec2(2800, 2200).length;
        expect(
          lights.first.outline.right,
          closeTo(mid - half, weld),
          reason: 'at $x',
        );
        expect(
          lights.last.outline.left,
          closeTo(mid + half, weld),
          reason: 'at $x',
        );
        for (final light in lights) {
          for (final c in light.outline.corners) {
            expect(
              (c.x - mid).abs() >= half - weld,
              isTrue,
              reason: 'at $x: a corner inside the mullion: $c',
            );
          }
        }
      }
    });

    test('an opening under the slope, a line inside it, glass over a panel, '
        'its hinges and handle on the leaf', () {
      final d = built();
      expect(d.openings, hasLength(1));
      final opening = d.openings.single;
      final leaf = d.sectionById(opening.sectionId)!.outline;
      // The leaf is the light under the slope: raked, not a box.
      expect(leaf.edges.where((e) => !square(e)), isNotEmpty);
      final line = d.dividers.firstWhere((b) => b.id == 'inside');
      expect(line.parentId, opening.id);
      expect(d.topLevelDividers, hasLength(1), reason: 'the mullion only');
      final panes = d.childSectionsOf(opening.sectionId)
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      expect(panes, hasLength(2));
      expect(panes.first.finish.material.isGlazing, isTrue);
      expect(panes.last.finish.material, MaterialKind.panel);
      for (final h in d.hardware) {
        expect(d.openingHolding(h.parentId)?.id, opening.id);
        expect(leaf.contains(h.at), isTrue, reason: h.kind.name);
      }
      expect(d.hardware.where((h) => h.kind == HardwareKind.hinge), isNotEmpty);
      expect(d.hardware.where((h) => h.kind.isHandle), isNotEmpty);
      expect(GeometryNormalizer.validateAngledGeometry(d), isEmpty);
      expect(MeshBuilder.build(d).facets, isNotEmpty);
    });
  });

  group('its real sizes', () {
    test('given its width and height, it is that size and still the shape '
        'drawn — the slope kept, the short side short', () {
      final d = built();
      final given = Measurements.apply(d, {
        for (final m in Measurements.of(d))
          if (m.asked)
            m.key: switch (m.key) {
              Measurements.widthKey => 2600,
              Measurements.heightKey => 2300,
              _ => m.currentMm(d),
            },
      });
      expect(given.ok, isTrue, reason: given.problems.toString());
      final sized = given.design;
      final outline = sized.frame!.outline;
      expect(outline.width, closeTo(2600, 1e-6));
      expect(outline.height, closeTo(2300, 1e-6));
      expect(outline.corners, hasLength(5));
      expect(outline.edges.where((e) => !square(e)), hasLength(1));
      final [foot, jambTop, _, headEnd, tallFoot] = cornersOf(sized);
      expect(foot.y - jambTop.y, lessThan(tallFoot.y - headEnd.y));
      expect(Measurements.knowsOverall(sized, MeasureAxis.across), isTrue);
      expect(Measurements.knowsOverall(sized, MeasureAxis.down), isTrue);
      expect(GeometryNormalizer.validateAngledGeometry(sized), isEmpty);
      // Read again: the sizes kept, the shape the same.
      final again = readSheet(sized);
      expect(again.frame!.outline, outline);
    });
  });

  group('a size inside the frame', () {
    test('the glass in the opening under the slope given a height: that '
        'height, and the frame — its slope, its short side — not moved', () {
      // The fault this phase found: giving a pane a height stretched the
      // sheet between the bars round it, which on an under-stair frame
      // moved the corner where the slope meets the short jamb, carried the
      // opening's line away with the raked light, and then refused the size.
      final d = built();
      final opening = d.openings.single;
      for (final height in [1300.0, 1500.0, 1700.0]) {
        final given = Measurements.apply(d, {'y:inside': height});
        expect(given.ok, isTrue, reason: given.problems.toString());
        final sized = given.design;
        expect(cornersOf(sized), cornersOf(d), reason: 'the frame at $height');
        final glass = sized
            .childSectionsOf(opening.sectionId)
            .reduce((a, b) => a.outline.top < b.outline.top ? a : b);
        expect(glass.outline.height, closeTo(height, 1), reason: '$height');
        expect(
          sized.dividers.firstWhere((b) => b.id == 'inside').parentId,
          opening.id,
        );
        expect(GeometryNormalizer.validateAngledGeometry(sized), isEmpty);
        // And a reading after it keeps it.
        final again = readSheet(sized);
        expect(cornersOf(again), cornersOf(d));
      }
    });

    test('the light beside the mullion given a width: the mullion moves, '
        'the frame does not', () {
      final d = built();
      final width = [
        for (final m in Measurements.of(d))
          if (m.asked && m.key.startsWith('x:')) m,
      ].single;
      final given = Measurements.apply(d, {
        width.key: width.currentMm(d) + 150,
      });
      expect(given.ok, isTrue, reason: given.problems.toString());
      expect(cornersOf(given.design), cornersOf(d));
      expect(
        given.design.topLevelDividers.single.segment.a.x,
        isNot(d.topLevelDividers.single.segment.a.x),
      );
    });
  });

  group('every size at once, as the form gives them', () {
    test('the border, the bars, the width, the height and the fixed light '
        'beside the mullion, together: each exactly what was typed, the '
        'mullion where the light puts it, the frame the shape drawn', () {
      // Seen in the browser: a 7 cm border and a fixed light of 120 cm were
      // refused. The mullion's face then came down two millimetres from the
      // corner the slope meets the head at, and the subdivision welded the
      // light's corner onto the frame's, so the light measured from the
      // wrong place.
      final d = built();
      final light = [
        for (final m in Measurements.of(d))
          if (m.asked && m.key.startsWith('x:')) m.key,
      ].single;
      for (final width in [1100.0, 1150.0, 1200.0, 1250.0, 1300.0]) {
        final given = Measurements.apply(d, {
          Measurements.profileKey: 70,
          Measurements.barsKey: 60,
          Measurements.widthKey: 2800,
          Measurements.heightKey: 2200,
          light: width,
        });
        expect(given.ok, isTrue, reason: '$width: ${given.problems}');
        final sized = given.design;
        final right = sized.topLevelSections.reduce(
          (a, b) => a.outline.left > b.outline.left ? a : b,
        );
        expect(right.outline.width, closeTo(width, 1), reason: '$width');
        // It starts at the mullion's face — under the level head, or with
        // a little of the slope where the mullion stands under it.
        final mullion = sized.topLevelDividers.single;
        expect(
          right.outline.left,
          closeTo(mullion.segment.a.x + mullion.widthMm / 2, 1e-6),
          reason: '$width',
        );
        expect(sized.frame!.outline.corners, hasLength(5));
        expect(sized.frame!.outline.width, closeTo(2800, 1e-6));
        expect(sized.frame!.outline.height, closeTo(2200, 1e-6));
        expect(GeometryNormalizer.validateAngledGeometry(sized), isEmpty);
      }
    });

    test('the mullion moved past the slope\'s corner: each light keeps its '
        'own glass, on its own side', () {
      var d = readSheet(drawn());
      final right = d.topLevelSections.reduce(
        (a, b) => a.outline.left > b.outline.left ? a : b,
      );
      d = d.withElement(right.copyWith(finish: GlassLook.frosted.finish));
      final mullion = d.topLevelDividers.single;
      // Dragged under the level head, and back under the slope.
      for (final by in [150.0, -200.0]) {
        final moved = DesignEdits.moveDivider(d, mullion.id, Vec2(by, 0));
        final [west, east] = [...moved.topLevelSections]
          ..sort((a, b) => a.outline.left.compareTo(b.outline.left));
        expect(east.id, right.id, reason: '$by');
        expect(east.finish, GlassLook.frosted.finish, reason: '$by');
        expect(west.finish, isNot(GlassLook.frosted.finish), reason: '$by');
      }
    });
  });

  group('saved and opened again', () {
    test(
      'as a file: the same design, to the character, and the same solid',
      () {
        final d = built();
        final back = Design.fromJson(
          jsonDecode(textOf(d)) as Map<String, Object?>,
        );
        expect(textOf(back), textOf(d));
        expect(back.category, DesignKind.angled);
        expect(cornersOf(back), cornersOf(d));
        final before = MeshBuilder.build(d).facets;
        final after = MeshBuilder.build(back).facets;
        expect(after.length, before.length);
        for (var i = 0; i < before.length; i++) {
          expect(after[i].corners.toString(), before[i].corners.toString());
        }
      },
    );

    test('kept on the device and opened from its card: the same design, and '
        'read again the same shape', () async {
      final d = built();
      final store = DesignStore();
      final kept = await store.save(d);
      final opened = (await store.load(kept.id))!;
      expect(textOf(opened), textOf(kept));
      expect(opened.frame!.outline, d.frame!.outline);
      expect(opened.name, 'Under-stair Window');
      expect(opened.category, DesignKind.angled);
      final reread = readSheet(opened);
      expect(reread.frame!.outline, d.frame!.outline);
      expect(
        {for (final b in reread.dividers) b.id: b.segment},
        {for (final b in d.dividers) b.id: b.segment},
      );
      expect(reread.openings.single.id, d.openings.single.id);
    });
  });
}
