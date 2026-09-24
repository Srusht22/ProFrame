import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import 'hinges_round_the_back_test.dart' show pen;

// **A sliding design is chosen on the start screen, and then the drawing
// says the rest.** Its panels are the lights the user drew; a `<` or a `>`
// in one says that panel slides, the way the chevron points; a panel with
// no mark stays where it is. Two panels marked is a pair that both slide,
// one marked beside a fixed light is a single slider — the two kinds in the
// user's photographs — and neither is a template.
//
// A sliding panel hangs on no hinge. It is drawn along by a pull on the
// stile it closes with, away from the way it slides. In the solid every
// panel stands in the frame on a track, the fixed ones outermost, and a
// slider glides along its own track past the panel beside it — its own
// width and never past the jamb, never out of the frame — while nothing
// else moves.

/// Two lights side by side, with [left] and [right] drawn in them: `'<'`,
/// `'>'`, or null for no mark.
Design sheet({
  String? left,
  String? right,
  DesignKind begunAs = DesignKind.sliding,
}) {
  List<Vec2> chevron(double x, String glyph) => glyph == '>'
      ? [Vec2(x - 55, 940), Vec2(x + 55, 1050), Vec2(x - 55, 1160)]
      : [Vec2(x + 55, 940), Vec2(x - 55, 1050), Vec2(x + 55, 1160)];
  final time = DateTime(2026);
  return SketchInterpreter.interpret(
    Design(
      id: 'd',
      name: 'test',
      kind: begunAs,
      createdAt: time,
      updatedAt: time,
      sketch: Sketch(
        strokes: [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(2400, 0),
            Vec2(2400, 2100),
            Vec2(0, 2100),
            Vec2(0, 0),
          ]),
          pen('mullion', const [Vec2(1200, 0), Vec2(1200, 2100)]),
          if (left != null) pen('left', chevron(600, left)),
          if (right != null) pen('right', chevron(1800, right)),
        ],
      ),
    ),
  ).design;
}

List<Facet> facetsOf(Mesh mesh, Set<String> ids) => [
  for (final f in mesh.facets)
    if (ids.contains(f.elementId)) f,
];

/// Everything that belongs to [opening]: its section and its ironmongery.
Set<String> partsOf(Design design, OpeningElement opening) => {
  opening.sectionId,
  for (final piece in design.hardware)
    if (piece.parentId == opening.id) piece.id,
};

void main() {
  group('the drawing says which panels slide', () {
    test('one marked beside a fixed light is a single slider', () {
      final design = sheet(right: '<');
      expect(design.openings, hasLength(1));
      final slider = design.openings.single;
      expect(slider.mechanism, OpeningMechanism.slidingLeft);
      final section = design.sectionById(slider.sectionId)!;
      expect(section.outline.left, greaterThan(1100), reason: 'the right one');
      expect(design.topLevelSections, hasLength(2));
    });

    test('two marked are a pair that both slide, each its own way', () {
      final design = sheet(left: '>', right: '<');
      final order = design.openingsInOrder;
      expect(order, hasLength(2));
      expect(order[0].mechanism, OpeningMechanism.slidingRight);
      expect(order[1].mechanism, OpeningMechanism.slidingLeft);
    });

    test('the same sheet begun as a door is hinged, as it always was', () {
      final design = sheet(left: '>', right: '<', begunAs: DesignKind.door);
      final order = design.openingsInOrder;
      expect(order[0].mechanism, OpeningMechanism.hingedLeft);
      expect(order[1].mechanism, OpeningMechanism.hingedRight);
    });

    test('reading the sheet again keeps what it says', () {
      final design = sheet(left: '>', right: '<');
      final again = SketchInterpreter.interpret(design).design;
      expect(
        [for (final o in again.openingsInOrder) o.mechanism],
        [OpeningMechanism.slidingRight, OpeningMechanism.slidingLeft],
      );
    });

    test('a save and a reload keep the category and the panels', () {
      final design = sheet(right: '<');
      final back = Design.fromJson(design.toJson());
      expect(back.kind, DesignKind.sliding);
      expect(back.openings.single.mechanism, OpeningMechanism.slidingLeft);
    });
  });

  group('a sliding panel is pulled, not hung', () {
    test('no hinges, and one pull on the stile it closes with', () {
      final design = sheet(left: '>', right: '<');
      for (final opening in design.openings) {
        final pieces = [
          for (final p in design.hardware)
            if (p.parentId == opening.id) p,
        ];
        expect(pieces.where((p) => p.kind == HardwareKind.hinge), isEmpty);
        expect(pieces, hasLength(1));
        final pull = pieces.single;
        expect(pull.kind, HardwareKind.pull);
        expect(pull.kind.isHandle, isTrue);

        final box = design.sectionById(opening.sectionId)!.outline;
        // Away from the way it slides: a panel sliding left is pulled from
        // its right stile, which meets the jamb when it is shut.
        final closesWith =
            opening.mechanism == OpeningMechanism.slidingLeft
                ? box.right
                : box.left;
        expect(pull.at.x, closeTo(closesWith, 1e-6));
        expect(pull.at.y, closeTo((box.top + box.bottom) / 2, 1e-6));
      }
    });

    test('the handle height is the user\'s figure when they give one', () {
      final design = sheet(right: '<');
      final opening = design.openings.single;
      final moved = OpeningHardware.settle(
        design.withElement(opening.copyWith(handleAlongMm: 900)),
      );
      final pull = moved.hardware.firstWhere((p) => p.parentId == opening.id);
      final box = moved.sectionById(opening.sectionId)!.outline;
      expect(box.bottom - pull.at.y, closeTo(900, 1e-6));
    });

    test('its pull is built, and on both faces of a door', () {
      final design = sheet(right: '<');
      final pull = design.hardware.single;
      final facets = facetsOf(MeshBuilder.build(design), {pull.id});
      expect(facets, isNotEmpty);
      expect(facets.any((f) => f.part != null), isTrue);
      expect(facets.any((f) => f.part == null), isTrue);
    });
  });

  group('in the solid it slides', () {
    final design = sheet(right: '<');
    final slider = design.openings.single;
    final parts = partsOf(design, slider);
    final box = design.sectionById(slider.sectionId)!.outline;
    final room = design.frame!.innerOutline;
    final depth = design.depthMm;

    test('it moves along, and does not turn', () {
      final shut = facetsOf(MeshBuilder.build(design), parts);
      final open = facetsOf(MeshBuilder.build(design, openFraction: 1), parts);
      expect(open, hasLength(shut.length));
      final by = open.first.corners.first - shut.first.corners.first;
      for (var i = 0; i < shut.length; i++) {
        for (var j = 0; j < shut[i].corners.length; j++) {
          final d = open[i].corners[j] - shut[i].corners[j];
          expect((d - by).length, lessThan(1e-6), reason: 'one translation');
        }
      }
      expect(by.y, 0);
      // Its own width to the left, where the frame has room for it.
      final expected = -[box.width, box.left - room.left].reduce(
        (a, b) => a < b ? a : b,
      );
      expect(by.x, closeTo(expected, 1e-6));
      expect(by.x.abs(), greaterThan(box.width * 0.9));
    });

    test('it stays in the frame, on a track behind the fixed panel', () {
      final mesh = MeshBuilder.build(design, openFraction: 1);
      final fixed = design.topLevelSections.firstWhere(
        (s) => s.id != slider.sectionId,
      );
      List<double> zs(String id) => [
        for (final f in facetsOf(mesh, {id}))
          for (final c in f.corners) c.z,
      ];
      final slid = facetsOf(mesh, {slider.sectionId});
      for (final c in slid.expand((f) => f.corners)) {
        expect(c.z, lessThanOrEqualTo(1e-6), reason: 'not out of the face');
        expect(c.z, greaterThanOrEqualTo(-depth - 1e-6), reason: 'nor out '
            'of the back');
        expect(c.x, greaterThanOrEqualTo(room.left - 1e-6), reason: 'jamb');
      }
      // Seen from outside, the fixed panel is on the outer track and the
      // slider passes behind it.
      final fixedBack = zs(fixed.id).reduce((a, b) => a < b ? a : b);
      final sliderFront = zs(slider.sectionId).reduce((a, b) => a > b ? a : b);
      expect(sliderFront, lessThanOrEqualTo(fixedBack + 1e-6));
    });

    test('it glides from the start: along its track, never out of it', () {
      final shut = facetsOf(MeshBuilder.build(design), {slider.sectionId});
      final early = facetsOf(
        MeshBuilder.build(design, openFraction: 0.1),
        {slider.sectionId},
      );
      final d = early.first.corners.first - shut.first.corners.first;
      expect(d.x, lessThan(0), reason: 'already moving along');
      expect(d.z, 0, reason: 'and only along');
    });

    test('the fixed panel is a sash on its track, like the one that slides',
        () {
      final fixed = design.topLevelSections.firstWhere(
        (s) => s.id != slider.sectionId,
      );
      final mesh = MeshBuilder.build(design);
      expect(
        facetsOf(mesh, {fixed.id}).any((f) => f.role == FacetRole.sash),
        isTrue,
      );
    });

    test('where the two panels meet is their stiles, not a post', () {
      final mullion = design.topLevelDividers.single;
      final mesh = MeshBuilder.build(design);
      expect(facetsOf(mesh, {mullion.id}), isEmpty);
      // Both panels reach to the middle of the line between them, so from
      // the front there is no gap where it was drawn.
      final middle = mullion.segment.midpoint.x;
      final fixed = design.topLevelSections.firstWhere(
        (s) => s.id != slider.sectionId,
      );
      double reach(String id, bool right) {
        final xs = [
          for (final f in facetsOf(mesh, {id}))
            for (final c in f.corners) c.x,
        ];
        return right
            ? xs.reduce((a, b) => a > b ? a : b)
            : xs.reduce((a, b) => a < b ? a : b);
      }
      expect(reach(fixed.id, true), closeTo(middle, 1e-6));
      expect(reach(slider.sectionId, false), closeTo(middle, 1e-6));
      // And the line is still the user's, on the drawing and in the design.
      expect(design.dividers.map((d) => d.id), contains(mullion.id));
    });

    test('nothing else moves', () {
      final shut = MeshBuilder.build(design);
      final open = MeshBuilder.build(design, openFraction: 1);
      String others(Mesh mesh) => [
        for (final f in mesh.facets)
          if (!parts.contains(f.elementId))
            '${f.elementId}:${f.corners.map((c) => '${c.x},${c.y},${c.z}')}',
      ].join('\n');
      expect(others(open), others(shut));
    });

    test('four panels, the middle two parting: they share one track', () {
      final time = DateTime(2026);
      final four = SketchInterpreter.interpret(
        Design(
          id: 'd4',
          name: 'test',
          kind: DesignKind.sliding,
          createdAt: time,
          updatedAt: time,
          sketch: Sketch(
            strokes: [
              pen('outline', const [
                Vec2(0, 0),
                Vec2(3200, 0),
                Vec2(3200, 2100),
                Vec2(0, 2100),
                Vec2(0, 0),
              ]),
              for (final x in [800.0, 1600.0, 2400.0])
                pen('m$x', [Vec2(x, 0), Vec2(x, 2100)]),
              // The second slides left, the third slides right.
              pen('a', const [Vec2(1255, 940), Vec2(1145, 1050),
                Vec2(1255, 1160)]),
              pen('b', const [Vec2(1945, 940), Vec2(2055, 1050),
                Vec2(1945, 1160)]),
            ],
          ),
        ),
      ).design;
      final order = four.openingsInOrder;
      expect(
        [for (final o in order) o.mechanism],
        [OpeningMechanism.slidingLeft, OpeningMechanism.slidingRight],
      );
      final mesh = MeshBuilder.build(four, openFraction: 1);
      (double, double) zRange(String id) {
        final zs = [
          for (final f in facetsOf(mesh, {id}))
            if (f.role != FacetRole.hardware)
              for (final c in f.corners) c.z,
        ];
        return (
          zs.reduce((a, b) => a < b ? a : b),
          zs.reduce((a, b) => a > b ? a : b),
        );
      }

      final a = zRange(order[0].sectionId), b = zRange(order[1].sectionId);
      expect(a.$1, closeTo(b.$1, 1e-6), reason: 'the same track');
      expect(a.$2, closeTo(b.$2, 1e-6));
      // Behind the two fixed panels, which are on the outer track.
      for (final fixed in four.topLevelSections) {
        if (order.any((o) => o.sectionId == fixed.id)) continue;
        expect(a.$2, lessThanOrEqualTo(zRange(fixed.id).$1 + 1e-6));
      }
    });

    test('two sliders run on two tracks and pass each other', () {
      final pair = sheet(left: '>', right: '<');
      final mesh = MeshBuilder.build(pair, openFraction: 1);
      final spans = [
        for (final o in pair.openingsInOrder)
          [
            for (final f in facetsOf(mesh, {o.sectionId}))
              for (final c in f.corners) c.z,
          ],
      ];
      final firstBack = spans[0].reduce((a, b) => a < b ? a : b);
      final secondFront = spans[1].reduce((a, b) => a > b ? a : b);
      expect(
        secondFront,
        lessThanOrEqualTo(firstBack + 1e-6),
        reason: 'the second track is wholly behind the first',
      );
    });
  });
}
